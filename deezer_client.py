import re
import requests


def extract_playlist_id(url_or_id: str) -> str:
    m = re.search(r"deezer\.com/(?:\w+/)?playlist/(\d+)", url_or_id)
    return m.group(1) if m else url_or_id.strip()


def get_playlist_info(url_or_id: str) -> dict:
    pid = extract_playlist_id(url_or_id)
    r = requests.get(f"https://api.deezer.com/playlist/{pid}", timeout=10)
    r.raise_for_status()
    d = r.json()
    if "error" in d:
        raise RuntimeError(f"Deezer API: {d['error'].get('message', 'Unknown error')}")
    return {"id": f"dz_{pid}", "name": d["title"], "total": d["nb_tracks"]}


def get_playlist_tracks(url_or_id: str) -> list[dict]:
    pid = extract_playlist_id(url_or_id)
    tracks = []
    url: str | None = f"https://api.deezer.com/playlist/{pid}/tracks?limit=100&index=0"
    while url:
        r = requests.get(url, timeout=10)
        r.raise_for_status()
        data = r.json()
        if "error" in data:
            raise RuntimeError(f"Deezer API: {data['error'].get('message', 'Unknown error')}")
        for t in data.get("data", []):
            tracks.append({
                "spotify_id": f"dz_{t['id']}",
                "title": t["title"],
                "artists": [t["artist"]["name"]],
                "album": t["album"]["title"],
                "duration_ms": t["duration"] * 1000,
                "track_number": 0,
                "disc_number": 1,
                "year": "",
                "isrc": t.get("isrc", ""),
                "cover_url": t["album"].get("cover_xl") or t["album"].get("cover_big"),
            })
        url = data.get("next")
    return tracks
