from pathlib import Path
import yt_dlp

from utils import sanitize_filename
from metadata import embed_tags

_COOKIE_BROWSERS = ("edge", "chrome", "chromium", "firefox", "brave", "opera", "vivaldi")


def _build_ydl_opts(output_path: Path, browser: str | None = None) -> dict:
    opts = {
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
        "extractor_args": {"youtube": {"player_client": ["ios", "android", "web"]}},
    }
    if browser:
        opts["cookiesfrombrowser"] = (browser,)
    return opts


def build_output_path(base_dir: Path, track: dict, flat: bool = False, playlist_name: str = "") -> Path:
    title = sanitize_filename(track["title"])
    if flat:
        folder = sanitize_filename(playlist_name) if playlist_name else "playlist"
        return base_dir / folder / f"{title}.mp3"
    artist = sanitize_filename(track["artists"][0] if track["artists"] else "Unknown")
    album = sanitize_filename(track["album"] or "Unknown Album")
    num = track.get("track_number", 0)
    filename = f"{num:02d} - {title}.mp3" if num else f"{title}.mp3"
    return base_dir / artist / album / filename


def _run_download(opts: dict, url: str) -> None:
    with yt_dlp.YoutubeDL(opts) as ydl:
        ydl.download([url])


def download_track(youtube_url: str, track: dict, output_path: Path) -> None:
    output_path.parent.mkdir(parents=True, exist_ok=True)

    # yt-dlp appends extension; strip .mp3 so it doesn't double-up
    template = str(output_path.with_suffix(""))

    try:
        _run_download(_build_ydl_opts(Path(template)), youtube_url)
    except Exception as e:
        if "Sign in" not in str(e) and "bot" not in str(e).lower():
            raise
        # Retry with browser cookies to bypass bot detection
        for browser in _COOKIE_BROWSERS:
            try:
                _run_download(_build_ydl_opts(Path(template), browser=browser), youtube_url)
                break
            except Exception:
                continue
        else:
            raise

    if output_path.exists():
        embed_tags(output_path, track)
