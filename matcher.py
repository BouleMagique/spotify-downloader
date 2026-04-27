import re
import yt_dlp

_NOISE_WORDS = re.compile(r"\b(live|cover|remix|karaoke|acoustic|tribute|instrumental)\b", re.I)


def _duration_delta(yt_duration_s: float, spotify_duration_ms: int) -> float:
    return abs(yt_duration_s - spotify_duration_ms / 1000)


def _score(entry: dict, track: dict) -> float:
    score = 0.0

    yt_dur = entry.get("duration") or 0
    delta = _duration_delta(yt_dur, track["duration_ms"])
    if delta > 15:
        return -999
    score += max(0, 10 - delta)

    channel = entry.get("channel") or entry.get("uploader") or ""
    if channel.endswith("- Topic"):
        score += 5

    original_has_noise = bool(_NOISE_WORDS.search(track["title"]))
    if not original_has_noise:
        yt_title = entry.get("title") or ""
        if _NOISE_WORDS.search(yt_title):
            score -= 8

    return score


def find_youtube_url(track: dict) -> str | None:
    artist = track["artists"][0] if track["artists"] else ""
    query = f"{track['title']} {artist} {track['album']}"

    ydl_opts = {
        "quiet": True,
        "no_warnings": True,
        "extract_flat": True,
        "skip_download": True,
    }

    candidates = []

    with yt_dlp.YoutubeDL(ydl_opts) as ydl:
        try:
            results = ydl.extract_info(f"ytmsearch5:{query}", download=False)
            for entry in (results.get("entries") or []):
                if entry:
                    entry["_source"] = "ytm"
                    candidates.append(entry)
        except Exception:
            pass

    if not candidates:
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            try:
                results = ydl.extract_info(f"ytsearch5:{query}", download=False)
                for entry in (results.get("entries") or []):
                    if entry:
                        entry["_source"] = "yt"
                        candidates.append(entry)
            except Exception:
                pass

    if not candidates:
        return None

    scored = [(e, _score(e, track)) for e in candidates]
    best_entry, best_score = max(scored, key=lambda x: x[1])
    if best_score <= -999:
        return None

    url = best_entry.get("url") or best_entry.get("webpage_url")
    vid_id = best_entry.get("id")
    if vid_id and not url:
        url = f"https://www.youtube.com/watch?v={vid_id}"
    return url
