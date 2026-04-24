import time
from pathlib import Path
import yt_dlp

from utils import sanitize_filename
from metadata import embed_tags


def _build_ydl_opts(output_path: Path) -> dict:
    return {
        "format": "bestaudio/best",
        "postprocessors": [{
            "key": "FFmpegExtractAudio",
            "preferredcodec": "mp3",
            "preferredquality": "320",
        }],
        "outtmpl": str(output_path),
        "quiet": True,
        "no_warnings": True,
        "retries": 3,
        "fragment_retries": 3,
        "sleep_interval": 2,
        "max_sleep_interval": 5,
        "ignoreerrors": False,
    }


def build_output_path(base_dir: Path, track: dict) -> Path:
    artist = sanitize_filename(track["artists"][0] if track["artists"] else "Unknown")
    album = sanitize_filename(track["album"] or "Unknown Album")
    title = sanitize_filename(track["title"])
    num = track.get("track_number", 0)
    filename = f"{num:02d} - {title}.mp3" if num else f"{title}.mp3"
    return base_dir / artist / album / filename


def download_track(youtube_url: str, track: dict, output_path: Path) -> None:
    output_path.parent.mkdir(parents=True, exist_ok=True)

    # yt-dlp adds extension; pass path without .mp3 so it doesn't double-up
    template = str(output_path.with_suffix(""))
    opts = _build_ydl_opts(Path(template))

    with yt_dlp.YoutubeDL(opts) as ydl:
        ydl.download([youtube_url])

    if output_path.exists():
        embed_tags(output_path, track)
