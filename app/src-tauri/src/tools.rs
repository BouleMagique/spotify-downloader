//! Outils externes : yt-dlp, ffmpeg/ffprobe et deno (moteur JavaScript
//! dont yt-dlp a besoin pour YouTube).
//!
//! Rien n'est livré dans l'app : au premier lancement on télécharge ce qui
//! manque dans `<dossier données de l'app>/bin`. ffmpeg et deno du système
//! sont utilisés s'ils existent. yt-dlp se met à jour lui-même (`-U`) à chaque
//! lancement, car YouTube le casse régulièrement.

use std::path::{Path, PathBuf};

use futures_util::StreamExt;
use serde::Serialize;
use tauri::{AppHandle, Emitter, Manager};
use tokio::io::AsyncWriteExt;

use crate::error::{Error, Result};

#[cfg(windows)]
const EXE: &str = ".exe";
#[cfg(not(windows))]
const EXE: &str = "";

/// Où se trouve ffmpeg.
#[derive(Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub enum FfmpegSource {
    /// Installé sur la machine (dans le PATH).
    System,
    /// Téléchargé par l'app.
    App,
}

#[derive(Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct ToolsStatus {
    pub ytdlp_version: Option<String>,
    pub ffmpeg: Option<FfmpegSource>,
    pub deno: bool,
    pub ready: bool,
}

/// Progression envoyée à l'interface pendant la préparation.
#[derive(Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct ToolsProgress {
    pub tool: &'static str,
    pub stage: &'static str, // "download" | "extract" | "update"
    pub downloaded: u64,
    pub total: Option<u64>,
}

pub fn bin_dir(app: &AppHandle) -> Result<PathBuf> {
    let dir = app.path().app_data_dir()?.join("bin");
    std::fs::create_dir_all(&dir)?;
    Ok(dir)
}

pub fn ytdlp_path(app: &AppHandle) -> Result<PathBuf> {
    Ok(bin_dir(app)?.join(format!("yt-dlp{EXE}")))
}

/// Dossier contenant ffmpeg + ffprobe, à passer à `--ffmpeg-location`.
pub fn ffmpeg_dir(app: &AppHandle) -> Result<Option<(PathBuf, FfmpegSource)>> {
    if let (Ok(ff), Ok(_)) = (which::which("ffmpeg"), which::which("ffprobe")) {
        if let Some(dir) = ff.parent() {
            return Ok(Some((dir.to_path_buf(), FfmpegSource::System)));
        }
    }
    let dir = bin_dir(app)?;
    if dir.join(format!("ffmpeg{EXE}")).is_file() && dir.join(format!("ffprobe{EXE}")).is_file() {
        return Ok(Some((dir, FfmpegSource::App)));
    }
    Ok(None)
}

/// deno du système, sinon celui de l'app.
pub fn deno_path(app: &AppHandle) -> Result<Option<PathBuf>> {
    if let Ok(p) = which::which("deno") {
        return Ok(Some(p));
    }
    let p = bin_dir(app)?.join(format!("deno{EXE}"));
    Ok(p.is_file().then_some(p))
}

/// Commande sans fenêtre console sous Windows.
pub fn command(program: &Path) -> tokio::process::Command {
    #[allow(unused_mut)]
    let mut cmd = tokio::process::Command::new(program);
    #[cfg(windows)]
    cmd.creation_flags(0x0800_0000); // CREATE_NO_WINDOW
    cmd.kill_on_drop(true);
    cmd
}

async fn ytdlp_version(path: &Path) -> Option<String> {
    if !path.is_file() {
        return None;
    }
    let out = command(path).arg("--version").output().await.ok()?;
    out.status
        .success()
        .then(|| String::from_utf8_lossy(&out.stdout).trim().to_string())
}

pub async fn status(app: &AppHandle) -> Result<ToolsStatus> {
    let ytdlp_version = ytdlp_version(&ytdlp_path(app)?).await;
    let ffmpeg = ffmpeg_dir(app)?.map(|(_, s)| s);
    let deno = deno_path(app)?.is_some();
    Ok(ToolsStatus {
        ready: ytdlp_version.is_some() && ffmpeg.is_some() && deno,
        deno,
        ytdlp_version,
        ffmpeg,
    })
}

/// Installe ce qui manque, met yt-dlp à jour, renvoie l'état final.
pub async fn prepare(app: &AppHandle) -> Result<ToolsStatus> {
    let ytdlp = ytdlp_path(app)?;
    if ytdlp_version(&ytdlp).await.is_none() {
        download_to(app, "yt-dlp", &ytdlp_url(), &ytdlp).await?;
        make_executable(&ytdlp)?;
    } else {
        emit(app, "yt-dlp", "update", 0, None);
        // Échec de mise à jour (hors ligne…) : on garde la version en place.
        let _ = command(&ytdlp).arg("-U").output().await;
    }

    if ffmpeg_dir(app)?.is_none() {
        install_ffmpeg(app).await?;
    }
    if deno_path(app)?.is_none() {
        install_deno(app).await?;
    }
    status(app).await
}

fn ytdlp_url() -> String {
    let asset = if cfg!(windows) {
        "yt-dlp.exe"
    } else if cfg!(target_os = "macos") {
        "yt-dlp_macos" // binaire universel (arm64 + x86_64)
    } else if cfg!(target_arch = "aarch64") {
        "yt-dlp_linux_aarch64"
    } else {
        "yt-dlp_linux"
    };
    format!("https://github.com/yt-dlp/yt-dlp/releases/latest/download/{asset}")
}

async fn install_deno(app: &AppHandle) -> Result<()> {
    let arch = if cfg!(target_arch = "aarch64") { "aarch64" } else { "x86_64" };
    let target = if cfg!(windows) {
        "pc-windows-msvc"
    } else if cfg!(target_os = "macos") {
        "apple-darwin"
    } else {
        "unknown-linux-gnu"
    };
    let url = format!("https://github.com/denoland/deno/releases/latest/download/deno-{arch}-{target}.zip");
    let bin = bin_dir(app)?;
    let tmp = bin.join("deno-download.tmp");
    download_to(app, "deno", &url, &tmp).await?;
    emit(app, "deno", "extract", 0, None);
    let name = format!("deno{EXE}");
    extract_zip(&tmp, &bin, &[name.as_str()])?;
    let _ = std::fs::remove_file(&tmp);
    let p = bin.join(&name);
    if !p.is_file() {
        return Err(Error::Msg("deno introuvable dans l'archive téléchargée".into()));
    }
    make_executable(&p)
}

async fn install_ffmpeg(app: &AppHandle) -> Result<()> {
    let bin = bin_dir(app)?;
    let tmp = bin.join("ffmpeg-download.tmp");

    if cfg!(target_os = "macos") {
        // Builds statiques de ffmpeg.martin-riedl.de : un zip par binaire.
        let arch = if cfg!(target_arch = "aarch64") { "arm64" } else { "amd64" };
        for name in ["ffmpeg", "ffprobe"] {
            let url = format!(
                "https://ffmpeg.martin-riedl.de/redirect/latest/macos/{arch}/release/{name}.zip"
            );
            download_to(app, name, &url, &tmp).await?;
            emit(app, name, "extract", 0, None);
            extract_zip(&tmp, &bin, &[name])?;
        }
    } else if cfg!(windows) {
        let url = "https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip";
        download_to(app, "ffmpeg", url, &tmp).await?;
        emit(app, "ffmpeg", "extract", 0, None);
        extract_zip(&tmp, &bin, &["ffmpeg.exe", "ffprobe.exe"])?;
    } else {
        let arch = if cfg!(target_arch = "aarch64") { "linuxarm64" } else { "linux64" };
        let url = format!(
            "https://github.com/yt-dlp/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-{arch}-gpl.tar.xz"
        );
        download_to(app, "ffmpeg", &url, &tmp).await?;
        emit(app, "ffmpeg", "extract", 0, None);
        extract_tar_xz(&tmp, &bin, &["ffmpeg", "ffprobe"])?;
    }
    let _ = std::fs::remove_file(&tmp);

    for name in ["ffmpeg", "ffprobe"] {
        let p = bin.join(format!("{name}{EXE}"));
        if !p.is_file() {
            return Err(Error::Msg(format!("{name} introuvable dans l'archive téléchargée")));
        }
        make_executable(&p)?;
    }
    Ok(())
}

fn emit(app: &AppHandle, tool: &'static str, stage: &'static str, downloaded: u64, total: Option<u64>) {
    let _ = app.emit("tools-progress", ToolsProgress { tool, stage, downloaded, total });
}

/// Téléchargement en streaming vers un fichier temporaire, puis renommage.
async fn download_to(app: &AppHandle, tool: &'static str, url: &str, dest: &Path) -> Result<()> {
    let client = reqwest::Client::builder()
        .user_agent(concat!("playlist-dl/", env!("CARGO_PKG_VERSION")))
        .build()?;
    let resp = client.get(url).send().await?.error_for_status()?;
    let total = resp.content_length();

    let part = dest.with_extension("part");
    let mut file = tokio::fs::File::create(&part).await?;
    let mut stream = resp.bytes_stream();
    let mut done: u64 = 0;
    let mut last_emit: u64 = 0;
    while let Some(chunk) = stream.next().await {
        let chunk = chunk?;
        file.write_all(&chunk).await?;
        done += chunk.len() as u64;
        if done - last_emit > 512 * 1024 {
            emit(app, tool, "download", done, total);
            last_emit = done;
        }
    }
    file.flush().await?;
    drop(file);
    emit(app, tool, "download", done, total);
    tokio::fs::rename(&part, dest).await?;
    Ok(())
}

/// Extrait les fichiers dont le nom final est dans `names`, à plat dans `dest`.
fn extract_zip(archive: &Path, dest: &Path, names: &[&str]) -> Result<()> {
    let mut zip = zip::ZipArchive::new(std::fs::File::open(archive)?)?;
    for i in 0..zip.len() {
        let mut entry = zip.by_index(i)?;
        let Some(file_name) = Path::new(entry.name()?.as_ref()).file_name().map(|n| n.to_owned()) else {
            continue;
        };
        if entry.is_file() && names.iter().any(|n| file_name == *n) {
            let mut out = std::fs::File::create(dest.join(&file_name))?;
            std::io::copy(&mut entry, &mut out)?;
        }
    }
    Ok(())
}

fn extract_tar_xz(archive: &Path, dest: &Path, names: &[&str]) -> Result<()> {
    let xz = xz2::read::XzDecoder::new(std::fs::File::open(archive)?);
    let mut tar = tar::Archive::new(xz);
    for entry in tar.entries()? {
        let mut entry = entry?;
        let path = entry.path()?.into_owned();
        let Some(file_name) = path.file_name() else { continue };
        let in_bin = path.parent().and_then(|p| p.file_name()).is_some_and(|p| p == "bin");
        if in_bin && names.iter().any(|n| file_name == *n) {
            entry.unpack(dest.join(file_name))?;
        }
    }
    Ok(())
}

fn make_executable(path: &Path) -> Result<()> {
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        std::fs::set_permissions(path, std::fs::Permissions::from_mode(0o755))?;
    }
    let _ = path;
    Ok(())
}
