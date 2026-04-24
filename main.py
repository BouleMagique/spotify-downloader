from __future__ import annotations

import concurrent.futures
import sys
from pathlib import Path
from typing import Optional

import typer
from rich.console import Console
from rich.progress import Progress, SpinnerColumn, TextColumn, BarColumn, TaskProgressColumn
from rich.table import Table

from spotify_client import get_playlist_info, get_playlist_tracks
from matcher import find_youtube_url
from downloader import download_track, build_output_path
from utils import load_state, save_state

app = typer.Typer(add_completion=False)
console = Console()


def _process_track(args: tuple) -> tuple[str, str, str]:
    """Returns (spotify_id, status, message)"""
    track, base_dir, skip_existing = args
    spotify_id = track["spotify_id"]
    out_path = build_output_path(base_dir, track)

    if skip_existing and out_path.exists():
        return spotify_id, "skipped", str(out_path)

    url = find_youtube_url(track)
    if not url:
        return spotify_id, "failed", "No YouTube match found"

    try:
        download_track(url, track, out_path)
        return spotify_id, "done", str(out_path)
    except Exception as exc:
        return spotify_id, "failed", str(exc)


@app.command()
def download(
    playlist: str = typer.Argument(..., help="Spotify playlist URL or ID"),
    output: Path = typer.Option(Path("downloads"), "--output", "-o", help="Output directory"),
    workers: int = typer.Option(3, "--workers", "-w", help="Parallel downloads (max 5)"),
    skip_existing: bool = typer.Option(True, "--skip-existing/--no-skip", help="Skip already downloaded tracks"),
    dry_run: bool = typer.Option(False, "--dry-run", help="List tracks without downloading"),
):
    """Download a complete Spotify playlist as MP3 320kbps."""
    workers = min(workers, 5)

    console.print(f"[bold cyan]Fetching playlist metadata...[/bold cyan]")
    try:
        info = get_playlist_info(playlist)
    except RuntimeError as e:
        console.print(f"[bold red]Error:[/bold red] {e}")
        raise typer.Exit(1)

    console.print(f"[green]Playlist:[/green] {info['name']}  ([dim]{info['total']} tracks[/dim])")

    tracks = get_playlist_tracks(playlist)
    console.print(f"[green]Loaded:[/green] {len(tracks)} tracks\n")

    if dry_run:
        table = Table(title=info["name"])
        table.add_column("#", style="dim", width=4)
        table.add_column("Title")
        table.add_column("Artist")
        table.add_column("Album")
        for i, t in enumerate(tracks, 1):
            table.add_row(str(i), t["title"], t["artists"][0] if t["artists"] else "", t["album"])
        console.print(table)
        return

    state_path = output / f"{info['id']}.state.json"
    state = load_state(state_path)

    # Filter tracks already done
    pending = [t for t in tracks if state.get(t["spotify_id"], {}).get("status") != "done" or not skip_existing]
    already_done = len(tracks) - len(pending)
    if already_done:
        console.print(f"[dim]Skipping {already_done} already downloaded tracks.[/dim]\n")

    if not pending:
        console.print("[bold green]All tracks already downloaded.[/bold green]")
        return

    done = skipped = failed = 0

    with Progress(
        SpinnerColumn(),
        TextColumn("[progress.description]{task.description}"),
        BarColumn(),
        TaskProgressColumn(),
        console=console,
    ) as progress:
        task = progress.add_task(f"Downloading {len(pending)} tracks...", total=len(pending))

        with concurrent.futures.ThreadPoolExecutor(max_workers=workers) as pool:
            args_list = [(t, output, skip_existing) for t in pending]
            futures = {pool.submit(_process_track, a): a[0] for a in args_list}

            for future in concurrent.futures.as_completed(futures):
                spotify_id, status, msg = future.result()
                track_obj = futures[future]
                state[spotify_id] = {"status": status, "info": msg}
                save_state(state_path, state)

                if status == "done":
                    done += 1
                elif status == "skipped":
                    skipped += 1
                else:
                    failed += 1
                    console.print(f"[red]FAILED[/red] {track_obj['title']}: {msg}")

                progress.advance(task)

    console.print(f"\n[bold green]Done:[/bold green] {done}  [yellow]Skipped:[/yellow] {skipped}  [red]Failed:[/red] {failed}")
    if failed:
        console.print(f"[dim]Failed tracks recorded in {state_path}[/dim]")


if __name__ == "__main__":
    app()
