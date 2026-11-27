use serde::{Serialize, Serializer};

/// Erreur unique des commandes : envoyée à l'interface sous forme de texte.
#[derive(Debug, thiserror::Error)]
pub enum Error {
    #[error("{0}")]
    Msg(String),
    #[error("fichier : {0}")]
    Io(#[from] std::io::Error),
    #[error("réseau : {0}")]
    Http(#[from] reqwest::Error),
    #[error("archive zip : {0}")]
    Zip(#[from] zip::result::ZipError),
    #[error("{0}")]
    Tauri(#[from] tauri::Error),
}

impl Serialize for Error {
    fn serialize<S: Serializer>(&self, s: S) -> std::result::Result<S::Ok, S::Error> {
        s.serialize_str(&self.to_string())
    }
}

pub type Result<T> = std::result::Result<T, Error>;
