use serde::Serialize;
use tauri::Manager;

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct AppInfo {
    version: String,
    config_dir: String,
}

/// Infos affichées dans Réglages. Le dossier de config est celui de l'OS
/// (jamais à côté de l'exécutable : une AppImage est en lecture seule).
#[tauri::command]
fn app_info(app: tauri::AppHandle) -> Result<AppInfo, String> {
    let dir = app.path().app_config_dir().map_err(|e| e.to_string())?;
    std::fs::create_dir_all(&dir).map_err(|e| e.to_string())?;
    Ok(AppInfo {
        version: app.package_info().version.to_string(),
        config_dir: dir.display().to_string(),
    })
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_opener::init())
        .invoke_handler(tauri::generate_handler![app_info])
        .run(tauri::generate_context!())
        .expect("erreur au lancement de l'application");
}
