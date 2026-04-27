from __future__ import annotations

import concurrent.futures
import os
import queue
import sys
import threading
from pathlib import Path

# Portable base dir — works both as .py script and PyInstaller .exe
if getattr(sys, "frozen", False):
    BASE_DIR = Path(sys.executable).parent
else:
    BASE_DIR = Path(__file__).parent

os.chdir(BASE_DIR)  # .env et .spotify_cache résolus en relatif depuis ici

try:
    import truststore
    truststore.inject_into_ssl()
except Exception:
    pass

import tkinter as tk
from tkinter import ttk, filedialog, messagebox, scrolledtext
from dotenv import load_dotenv, set_key

load_dotenv(BASE_DIR / ".env", override=True)

from spotify_client import get_playlist_info as sp_info
from spotify_client import get_playlist_tracks as sp_tracks
import deezer_client
from matcher import find_youtube_url
from downloader import download_track, build_output_path
from utils import load_state, save_state
import yt_dlp

ENV_PATH = BASE_DIR / ".env"
SOURCES = ["Spotify", "YouTube", "Deezer"]
URL_LABELS = {
    "Spotify": "Playlist URL Spotify :",
    "YouTube": "Playlist URL YouTube :",
    "Deezer": "Playlist URL Deezer :",
}


def _ensure_env() -> None:
    if not ENV_PATH.exists():
        ex = BASE_DIR / ".env.example"
        content = ex.read_text(encoding="utf-8") if ex.exists() else (
            "SPOTIFY_CLIENT_ID=\nSPOTIFY_CLIENT_SECRET=\n"
            "SPOTIFY_REDIRECT_URI=http://127.0.0.1:8888/callback\n"
        )
        ENV_PATH.write_text(content, encoding="utf-8")


def _get_youtube_playlist(url: str) -> tuple[str, str, list[dict]]:
    """Fetch a YouTube playlist's track list via yt-dlp without downloading."""
    opts = {"quiet": True, "no_warnings": True, "extract_flat": True, "skip_download": True}
    with yt_dlp.YoutubeDL(opts) as ydl:
        info = ydl.extract_info(url, download=False)
    pid = f"yt_{info.get('id', 'playlist')}"
    name = info.get("title", "YouTube Playlist")
    tracks = []
    for entry in (info.get("entries") or []):
        if not entry or not entry.get("id"):
            continue
        tracks.append({
            "spotify_id": f"yt_{entry['id']}",
            "title": entry.get("title", ""),
            "artists": [entry.get("uploader") or entry.get("channel") or "YouTube"],
            "album": name,
            "duration_ms": int((entry.get("duration") or 0) * 1000),
            "track_number": 0,
            "disc_number": 1,
            "year": "",
            "isrc": "",
            "cover_url": entry.get("thumbnail"),
            "_direct_url": f"https://www.youtube.com/watch?v={entry['id']}",
        })
    return pid, name, tracks


def _process_track(args: tuple) -> tuple[str, str, str]:
    track, base_dir, skip, flat, playlist_name = args
    sid = track["spotify_id"]
    out = build_output_path(base_dir, track, flat=flat, playlist_name=playlist_name)
    if skip and out.exists():
        return sid, "skipped", str(out)
    # YouTube-sourced tracks already have a direct URL — skip the matching step
    url = track.get("_direct_url") or find_youtube_url(track)
    if not url:
        return sid, "failed", "Aucune correspondance YouTube"
    try:
        download_track(url, track, out)
        return sid, "done", str(out)
    except Exception as exc:
        return sid, "failed", str(exc)


class App(tk.Tk):
    def __init__(self):
        super().__init__()
        _ensure_env()
        load_dotenv(ENV_PATH, override=True)

        self.title("Spotify Downloader")
        self.resizable(False, False)
        self.configure(padx=16, pady=12)
        self.geometry("620x740")

        self._cancel = False
        self.q: queue.Queue = queue.Queue()

        self._build_source()
        self._build_credentials()  # created but not yet packed
        self._build_options()
        self._build_controls()
        self._build_progress()
        self._build_log()

        self.protocol("WM_DELETE_WINDOW", self._on_close)
        # Pack credentials conditionally and set URL label
        self._on_source_change()
        self._poll_queue()

    # ── Builders ─────────────────────────────────────────────────────────────

    def _build_source(self):
        self._source_frame = ttk.LabelFrame(self, text="Source", padding=(10, 6))
        self._source_frame.pack(fill="x", pady=(0, 8))
        self.source_var = tk.StringVar(value="Spotify")
        for s in SOURCES:
            ttk.Radiobutton(
                self._source_frame, text=s, variable=self.source_var, value=s,
                command=self._on_source_change,
            ).pack(side="left", padx=(0, 20))

    def _build_credentials(self):
        # Not packed here — _on_source_change manages visibility
        self.cred_frame = ttk.LabelFrame(self, text="Configuration Spotify", padding=(10, 6))
        self.cred_frame.columnconfigure(1, weight=1)

        ttk.Label(self.cred_frame, text="Client ID :").grid(row=0, column=0, sticky="w", padx=(0, 8))
        self.id_var = tk.StringVar(value=os.getenv("SPOTIFY_CLIENT_ID", ""))
        ttk.Entry(self.cred_frame, textvariable=self.id_var).grid(row=0, column=1, sticky="ew")

        ttk.Label(self.cred_frame, text="Client Secret :").grid(
            row=1, column=0, sticky="w", padx=(0, 8), pady=(5, 0)
        )
        self.secret_var = tk.StringVar(value=os.getenv("SPOTIFY_CLIENT_SECRET", ""))
        ttk.Entry(self.cred_frame, textvariable=self.secret_var, show="•").grid(
            row=1, column=1, sticky="ew", pady=(5, 0)
        )

        btn_row = ttk.Frame(self.cred_frame)
        btn_row.grid(row=2, column=0, columnspan=2, sticky="e", pady=(8, 0))
        self.cred_lbl = ttk.Label(btn_row, text="")
        self.cred_lbl.pack(side="left", padx=(0, 10))
        ttk.Button(btn_row, text="Enregistrer", command=self._save_credentials).pack(side="left")

    def _build_options(self):
        self._options_frame = ttk.LabelFrame(self, text="Téléchargement", padding=(10, 6))
        self._options_frame.pack(fill="x", pady=(0, 8))
        self._options_frame.columnconfigure(1, weight=1)

        self.url_label_var = tk.StringVar()
        ttk.Label(self._options_frame, textvariable=self.url_label_var).grid(
            row=0, column=0, sticky="w", padx=(0, 8)
        )
        self.url_var = tk.StringVar()
        ttk.Entry(self._options_frame, textvariable=self.url_var).grid(row=0, column=1, sticky="ew")

        ttk.Label(self._options_frame, text="Dossier de sortie :").grid(
            row=1, column=0, sticky="w", padx=(0, 8), pady=(6, 0)
        )
        out_row = ttk.Frame(self._options_frame)
        out_row.grid(row=1, column=1, sticky="ew", pady=(6, 0))
        out_row.columnconfigure(0, weight=1)
        self.out_var = tk.StringVar(value=str(Path.home() / "Music" / "spotify-dl"))
        ttk.Entry(out_row, textvariable=self.out_var).grid(row=0, column=0, sticky="ew")
        ttk.Button(out_row, text="…", width=3, command=self._browse_output).grid(
            row=0, column=1, padx=(4, 0)
        )

        ttk.Label(self._options_frame, text="Structure :").grid(
            row=2, column=0, sticky="w", padx=(0, 8), pady=(6, 0)
        )
        mode_row = ttk.Frame(self._options_frame)
        mode_row.grid(row=2, column=1, sticky="w", pady=(6, 0))
        self.mode_var = tk.StringVar(value="artist")
        ttk.Radiobutton(mode_row, text="Artiste / Album", variable=self.mode_var, value="artist").pack(side="left")
        ttk.Radiobutton(
            mode_row, text="Flat  (playlist / titre)", variable=self.mode_var, value="flat"
        ).pack(side="left", padx=(16, 0))

        ttk.Label(self._options_frame, text="Parallélisme :").grid(
            row=3, column=0, sticky="w", padx=(0, 8), pady=(6, 0)
        )
        w_row = ttk.Frame(self._options_frame)
        w_row.grid(row=3, column=1, sticky="w", pady=(6, 0))
        self.workers_var = tk.IntVar(value=3)
        ttk.Spinbox(w_row, from_=1, to=5, textvariable=self.workers_var, width=4, state="readonly").pack(
            side="left"
        )
        ttk.Label(w_row, text="workers  (max 5)", foreground="gray").pack(side="left", padx=(6, 0))

        self.skip_var = tk.BooleanVar(value=True)
        ttk.Checkbutton(
            self._options_frame,
            text="Ignorer les pistes déjà téléchargées",
            variable=self.skip_var,
        ).grid(row=4, column=0, columnspan=2, sticky="w", pady=(6, 0))

    def _build_controls(self):
        f = ttk.Frame(self)
        f.pack(fill="x", pady=(0, 8))
        self.btn_dl = ttk.Button(f, text="▶  Télécharger", command=self._start_download)
        self.btn_dl.pack(side="left")
        self.btn_cancel = ttk.Button(f, text="✕  Annuler", command=self._cancel_download, state="disabled")
        self.btn_cancel.pack(side="left", padx=(8, 0))
        self.status_lbl = ttk.Label(f, text="")
        self.status_lbl.pack(side="right")

    def _build_progress(self):
        self.progress = ttk.Progressbar(self, mode="determinate")
        self.progress.pack(fill="x", pady=(0, 8))

    def _build_log(self):
        self.log = scrolledtext.ScrolledText(
            self, height=16, state="disabled", font=("Consolas", 9), wrap="word"
        )
        self.log.pack(fill="both", expand=True)

    # ── Source visibility ────────────────────────────────────────────────────

    def _on_source_change(self):
        src = self.source_var.get()
        self.url_label_var.set(URL_LABELS[src])
        if src == "Spotify":
            # Insert between source_frame and options_frame
            self.cred_frame.pack(fill="x", pady=(0, 8), after=self._source_frame)
            self._refresh_cred_status()
        else:
            self.cred_frame.pack_forget()

    # ── Credentials ──────────────────────────────────────────────────────────

    def _refresh_cred_status(self):
        ok = bool(os.getenv("SPOTIFY_CLIENT_ID", "").strip()) and \
             bool(os.getenv("SPOTIFY_CLIENT_SECRET", "").strip())
        if ok:
            self.cred_lbl.config(text="✓ Configuré", foreground="green")
        else:
            self.cred_lbl.config(
                text="⚠ Credentials manquants — remplis les champs ci-dessus", foreground="orange"
            )

    def _save_credentials(self):
        cid = self.id_var.get().strip()
        sec = self.secret_var.get().strip()
        if not cid or not sec:
            messagebox.showwarning("Champs vides", "Client ID et Client Secret sont requis.")
            return
        _ensure_env()
        set_key(str(ENV_PATH), "SPOTIFY_CLIENT_ID", cid)
        set_key(str(ENV_PATH), "SPOTIFY_CLIENT_SECRET", sec)
        os.environ["SPOTIFY_CLIENT_ID"] = cid
        os.environ["SPOTIFY_CLIENT_SECRET"] = sec
        self.cred_lbl.config(text="✓ Enregistré", foreground="green")

    # ── Browse ───────────────────────────────────────────────────────────────

    def _browse_output(self):
        d = filedialog.askdirectory(initialdir=self.out_var.get(), title="Choisir le dossier de sortie")
        if d:
            self.out_var.set(d)

    # ── Download ─────────────────────────────────────────────────────────────

    def _start_download(self):
        if not self.url_var.get().strip():
            messagebox.showwarning("URL manquante", "Colle l'URL de ta playlist.")
            return
        if self.source_var.get() == "Spotify" and (
            not os.getenv("SPOTIFY_CLIENT_ID") or not os.getenv("SPOTIFY_CLIENT_SECRET")
        ):
            messagebox.showwarning("Credentials manquants", "Configure et enregistre tes credentials Spotify.")
            return
        self._cancel = False
        self.progress["value"] = 0
        self.progress["maximum"] = 1
        self._log_clear()
        self.btn_dl.config(state="disabled")
        self.btn_cancel.config(state="normal")
        self.status_lbl.config(text="Démarrage...")
        threading.Thread(target=self._worker, daemon=True).start()

    def _cancel_download(self):
        self._cancel = True
        self.btn_cancel.config(state="disabled")
        self.status_lbl.config(text="Annulation en cours...")

    def _worker(self):
        try:
            src = self.source_var.get()
            url = self.url_var.get().strip()

            self.q.put(("status", f"Récupération des métadonnées {src}..."))

            if src == "Spotify":
                info = sp_info(url)
                tracks = sp_tracks(url)
                playlist_id, playlist_name = info["id"], info["name"]
            elif src == "Deezer":
                info = deezer_client.get_playlist_info(url)
                tracks = deezer_client.get_playlist_tracks(url)
                playlist_id, playlist_name = info["id"], info["name"]
            else:  # YouTube
                playlist_id, playlist_name, tracks = _get_youtube_playlist(url)

            out_dir = Path(self.out_var.get())
            flat = self.mode_var.get() == "flat"
            skip = self.skip_var.get()
            workers = int(self.workers_var.get())

            state_path = out_dir / f"{playlist_id}.state.json"
            state = load_state(state_path)

            pending = [
                t for t in tracks
                if not skip or state.get(t["spotify_id"], {}).get("status") != "done"
            ]
            already_done = len(tracks) - len(pending)
            self.q.put(("init", playlist_name, len(tracks), len(pending), already_done))

            done = skipped = failed = 0

            with concurrent.futures.ThreadPoolExecutor(max_workers=workers) as pool:
                args_list = [(t, out_dir, skip, flat, playlist_name) for t in pending]
                futures = {pool.submit(_process_track, a): a[0] for a in args_list}

                for future in concurrent.futures.as_completed(futures):
                    if self._cancel:
                        for f in futures:
                            f.cancel()
                        break
                    track = futures[future]
                    try:
                        sid, status, msg = future.result()
                    except Exception as exc:
                        sid, status, msg = track["spotify_id"], "failed", str(exc)

                    state[sid] = {"status": status, "info": msg}
                    save_state(state_path, state)

                    artist = track["artists"][0] if track["artists"] else ""
                    if status == "done":
                        done += 1
                        self.q.put(("row", "✓", track["title"], artist))
                    elif status == "skipped":
                        skipped += 1
                        self.q.put(("row", "–", track["title"], "déjà présent"))
                    else:
                        failed += 1
                        self.q.put(("row", "✗", track["title"], msg[:80]))

                    self.q.put(("progress", done + skipped + failed, len(pending)))

            self.q.put(("done", done, skipped, failed, self._cancel))

        except Exception as exc:
            self.q.put(("error", str(exc)))

    # ── Queue polling ────────────────────────────────────────────────────────

    def _poll_queue(self):
        try:
            while True:
                msg = self.q.get_nowait()
                k = msg[0]
                if k == "status":
                    self.status_lbl.config(text=msg[1])
                elif k == "init":
                    _, name, total, pending, already = msg
                    note = f", {already} déjà ignorées" if already else ""
                    self._log(f"Playlist : {name}  ({total} pistes, {pending} à télécharger{note})\n\n")
                    self.progress["maximum"] = max(pending, 1)
                elif k == "row":
                    _, sym, title, info = msg
                    self._log(f"  {sym}  {title}  —  {info}\n")
                elif k == "progress":
                    _, cur, total = msg
                    self.progress["value"] = cur
                    self.status_lbl.config(text=f"{cur} / {total}")
                elif k == "done":
                    _, done, skipped, failed, cancelled = msg
                    verb = "Annulé" if cancelled else "Terminé"
                    s = f"{verb} — ✓ {done}  – {skipped} ignorés  ✗ {failed} échoués"
                    self._log(f"\n{s}\n")
                    self.status_lbl.config(text=s)
                    self.btn_dl.config(state="normal")
                    self.btn_cancel.config(state="disabled")
                elif k == "error":
                    self._log(f"\n[ERREUR] {msg[1]}\n")
                    self.status_lbl.config(text="Erreur — voir le log")
                    self.btn_dl.config(state="normal")
                    self.btn_cancel.config(state="disabled")
        except queue.Empty:
            pass
        self.after(100, self._poll_queue)

    # ── Log ──────────────────────────────────────────────────────────────────

    def _log(self, text: str):
        self.log.config(state="normal")
        self.log.insert("end", text)
        self.log.see("end")
        self.log.config(state="disabled")

    def _log_clear(self):
        self.log.config(state="normal")
        self.log.delete("1.0", "end")
        self.log.config(state="disabled")

    def _on_close(self):
        self._cancel = True
        self.destroy()


if __name__ == "__main__":
    app = App()
    app.mainloop()
