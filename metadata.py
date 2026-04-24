from pathlib import Path
import requests
from mutagen.id3 import (
    ID3, ID3NoHeaderError,
    TIT2, TPE1, TALB, TRCK, TDRC, TPOS, APIC, TSRC,
)


def embed_tags(mp3_path: Path, track: dict) -> None:
    try:
        tags = ID3(str(mp3_path))
    except ID3NoHeaderError:
        tags = ID3()

    tags.add(TIT2(encoding=3, text=track["title"]))
    tags.add(TPE1(encoding=3, text="; ".join(track["artists"])))
    tags.add(TALB(encoding=3, text=track["album"]))
    tags.add(TRCK(encoding=3, text=str(track["track_number"])))
    tags.add(TPOS(encoding=3, text=str(track.get("disc_number", 1))))

    if track.get("year"):
        tags.add(TDRC(encoding=3, text=track["year"]))

    if track.get("isrc"):
        tags.add(TSRC(encoding=3, text=track["isrc"]))

    if track.get("cover_url"):
        try:
            resp = requests.get(track["cover_url"], timeout=10)
            resp.raise_for_status()
            tags.add(APIC(
                encoding=3,
                mime="image/jpeg",
                type=3,  # Cover (front)
                desc="Cover",
                data=resp.content,
            ))
        except Exception:
            pass  # cover art is best-effort

    tags.save(str(mp3_path))
