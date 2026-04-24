import os
import re
import spotipy
from spotipy.oauth2 import SpotifyOAuth
from dotenv import load_dotenv

load_dotenv()

_SCOPES = "playlist-read-private playlist-read-collaborative"


def _build_client() -> spotipy.Spotify:
    client_id = os.getenv("SPOTIFY_CLIENT_ID")
    client_secret = os.getenv("SPOTIFY_CLIENT_SECRET")
    redirect_uri = os.getenv("SPOTIFY_REDIRECT_URI", "http://127.0.0.1:8888/callback")
    if not client_id or not client_secret:
        raise RuntimeError(
            "Missing Spotify credentials. Copy .env.example to .env and fill in "
            "SPOTIFY_CLIENT_ID and SPOTIFY_CLIENT_SECRET from developer.spotify.com"
        )
    auth = SpotifyOAuth(
        client_id=client_id,
        client_secret=client_secret,
        redirect_uri=redirect_uri,
        scope=_SCOPES,
        open_browser=True,
        cache_path=".spotify_cache",
    )
    return spotipy.Spotify(auth_manager=auth)


def extract_playlist_id(url_or_id: str) -> str:
    # Handle spotify:playlist:xxx URI
    if url_or_id.startswith("spotify:playlist:"):
        return url_or_id.split(":")[-1]
    # Handle https://open.spotify.com/playlist/xxxxx?...
    match = re.search(r"playlist/([A-Za-z0-9]+)", url_or_id)
    if match:
        return match.group(1)
    # Assume raw ID
    return url_or_id.strip()


def get_playlist_info(url_or_id: str) -> dict:
    sp = _build_client()
    playlist_id = extract_playlist_id(url_or_id)
    data = sp.playlist(playlist_id, fields="id,name")
    page = sp.playlist_items(playlist_id, limit=1, fields="total")
    return {"id": data["id"], "name": data["name"], "total": page["total"]}


def get_playlist_tracks(url_or_id: str) -> list[dict]:
    sp = _build_client()
    playlist_id = extract_playlist_id(url_or_id)

    tracks = []
    offset = 0
    limit = 100

    while True:
        page = sp.playlist_items(
            playlist_id,
            offset=offset,
            limit=limit,
        )
        for item in page["items"]:
            track = item.get("item") or item.get("track")
            if not track or not track.get("id"):
                continue  # skip local/unavailable tracks
            artists = [a["name"] for a in track.get("artists", [])]
            album = track.get("album", {})
            images = album.get("images", [])
            cover_url = images[0]["url"] if images else None
            release_date = album.get("release_date", "")
            year = release_date[:4] if release_date else ""
            tracks.append({
                "spotify_id": track["id"],
                "title": track["name"],
                "artists": artists,
                "album": album.get("name", ""),
                "duration_ms": track.get("duration_ms", 0),
                "track_number": track.get("track_number", 0),
                "disc_number": track.get("disc_number", 1),
                "year": year,
                "isrc": track.get("external_ids", {}).get("isrc", ""),
                "cover_url": cover_url,
            })
        if page.get("next") is None:
            break
        offset += limit

    return tracks
