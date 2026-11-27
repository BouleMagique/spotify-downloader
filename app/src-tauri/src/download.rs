//! Téléchargement d'une URL en MP3 via yt-dlp (phase 2 : une seule URL).

use std::path::PathBuf;
use std::process::Stdio;

use serde::Serialize;
use tauri::{AppHandle, Emitter, Manager};
use tokio::io::{AsyncBufReadExt, AsyncReadExt, BufReader};

use crate::error::{Error, Result};
use crate::tools;

#[derive(Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct DlProgress {
    /// 0.0 → 1.0 pendant le téléchargement ; `None` pendant la conversion.
    pub fraction: Option<f64>,
}

/// Dossier de sortie par défaut : <Musique>/Playlist DL.
pub fn default_output_dir(app: &AppHandle) -> Result<PathBuf> {
    let base = app
        .path()
        .audio_dir()
        .or_else(|_| app.path().download_dir())
        .or_else(|_| app.path().home_dir())?;
    let dir = base.join("Playlist DL");
    std::fs::create_dir_all(&dir)?;
    Ok(dir)
}

/// Télécharge `url` en MP3 320 kbps, renvoie le chemin du fichier final.
pub async fn download_mp3(app: &AppHandle, url: &str) -> Result<PathBuf> {
    let ytdlp = tools::ytdlp_path(app)?;
    let (ffmpeg_dir, _) = tools::ffmpeg_dir(app)?
        .ok_or_else(|| Error::Msg("ffmpeg n'est pas encore installé".into()))?;
    let deno = tools::deno_path(app)?
        .ok_or_else(|| Error::Msg("deno n'est pas encore installé".into()))?;
    let out_dir = default_output_dir(app)?;

    let mut child = tools::command(&ytdlp)
        .args(["--no-playlist", "--newline", "--progress", "--no-colors"])
        .args(["-f", "bestaudio/best", "-x", "--audio-format", "mp3", "--audio-quality", "320K"])
        .arg("--js-runtimes")
        .arg(format!("deno:{}", deno.display()))
        .arg("--ffmpeg-location")
        .arg(&ffmpeg_dir)
        .arg("-P")
        .arg(&out_dir)
        .args(["-o", "%(title)s.%(ext)s"])
        .args([
            "--progress-template",
            "download:PROGRESS %(progress.downloaded_bytes)s %(progress.total_bytes,progress.total_bytes_estimate|0)s",
        ])
        .args(["--print", "after_move:FILE %(filepath)s"])
        .arg("--")
        .arg(url)
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()?;

    let mut stderr = child.stderr.take().expect("stderr piped");
    let err_task = tokio::spawn(async move {
        let mut s = String::new();
        let _ = stderr.read_to_string(&mut s).await;
        s
    });

    let mut final_path = None;
    let mut lines = BufReader::new(child.stdout.take().expect("stdout piped")).lines();
    while let Some(line) = lines.next_line().await? {
        if let Some(rest) = line.strip_prefix("PROGRESS ") {
            let mut it = rest.split_whitespace().map(|v| v.parse::<f64>().ok());
            if let (Some(Some(done)), Some(Some(total))) = (it.next(), it.next()) {
                let fraction = (total > 0.0).then(|| (done / total).min(1.0));
                let _ = app.emit("dl-progress", DlProgress { fraction });
            }
        } else if let Some(p) = line.strip_prefix("FILE ") {
            final_path = Some(PathBuf::from(p.trim()));
            let _ = app.emit("dl-progress", DlProgress { fraction: None });
        }
    }

    let status = child.wait().await?;
    let stderr = err_task.await.unwrap_or_default();
    if !status.success() {
        let msg = stderr
            .lines()
            .rev()
            .find(|l| l.contains("ERROR"))
            .unwrap_or("yt-dlp a échoué")
            .to_string();
        return Err(Error::Msg(msg));
    }
    final_path.ok_or_else(|| Error::Msg("yt-dlp n'a pas indiqué le fichier produit".into()))
}
