mod download;
mod error;
mod tools;

use serde::Serialize;
use tauri::{AppHandle, Manager};

use error::Result;

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct AppInfo {
    version: String,
    config_dir: String,
    output_dir: String,
}

/// Infos affichées dans Réglages. Tout ce qui s'écrit va dans les dossiers
/// de l'OS, jamais à côté de l'exécutable (une AppImage est en lecture seule).
#[tauri::command]
fn app_info(app: AppHandle) -> Result<AppInfo> {
    let config = app.path().app_config_dir()?;
    std::fs::create_dir_all(&config)?;
    Ok(AppInfo {
        version: app.package_info().version.to_string(),
        config_dir: config.display().to_string(),
        output_dir: download::default_output_dir(&app)?.display().to_string(),
    })
}

#[tauri::command]
async fn tools_status(app: AppHandle) -> Result<tools::ToolsStatus> {
    tools::status(&app).await
}

#[tauri::command]
async fn prepare_tools(app: AppHandle) -> Result<tools::ToolsStatus> {
    tools::prepare(&app).await
}

#[tauri::command]
async fn download_url(app: AppHandle, url: String) -> Result<String> {
    Ok(download::download_mp3(&app, &url).await?.display().to_string())
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_opener::init())
        .invoke_handler(tauri::generate_handler![
            app_info,
            tools_status,
            prepare_tools,
            download_url
        ])
        .run(tauri::generate_context!())
        .expect("erreur au lancement de l'application");
}
