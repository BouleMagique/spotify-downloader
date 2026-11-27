<script lang="ts">
  import { invoke } from "@tauri-apps/api/core";
  import { listen } from "@tauri-apps/api/event";
  import { revealItemInDir } from "@tauri-apps/plugin-opener";
  import { onMount } from "svelte";
  import { tools, prepareTools, progressLabel } from "$lib/tools.svelte";

  let url = $state("");
  let busy = $state(false);
  let fraction = $state<number | null>(null);
  let result = $state<string | null>(null);
  let error = $state<string | null>(null);

  const sources = [
    { name: "Spotify", note: "Identifiants requis" },
    { name: "Deezer", note: "Sans compte" },
    { name: "YouTube", note: "Sans compte" },
    { name: "Apple Music", note: "Bientôt", soon: true },
  ];

  onMount(() => {
    prepareTools();
  });

  // Phase 2 : télécharge directement une URL de morceau (YouTube…) en MP3.
  async function load(e: Event) {
    e.preventDefault();
    busy = true;
    error = result = null;
    fraction = 0;
    const unlisten = await listen<{ fraction: number | null }>("dl-progress", (ev) => (fraction = ev.payload.fraction));
    try {
      result = await invoke<string>("download_url", { url });
    } catch (err) {
      error = String(err);
    } finally {
      busy = false;
      unlisten();
    }
  }

  const fileName = (p: string) => p.split(/[\\/]/).pop();
</script>

<div class="wrap">
  <div class="intro">
    <h1>Colle une playlist.</h1>
    <p>La source est reconnue toute seule. Chaque piste est retrouvée sur YouTube, convertie en MP3 et taguée avec sa pochette.</p>
  </div>

  <form onsubmit={load}>
    <label for="url">URL de la playlist</label>
    <div class="row">
      <input id="url" type="url" bind:value={url} placeholder="https://open.spotify.com/playlist/…" disabled={busy} />
      <button type="submit" disabled={!url || busy || !tools.status?.ready}>
        {busy ? "En cours…" : "Charger"}
        <svg aria-hidden="true" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"><path d="M5 12h14M13 6l6 6-6 6" /></svg>
      </button>
    </div>
  </form>

  {#if busy}
    <div class="card" aria-live="polite">
      <span>{fraction === null ? "Conversion en MP3…" : `Téléchargement : ${Math.round(fraction * 100)} %`}</span>
      <div class="bar"><div style="width: {fraction === null ? 100 : fraction * 100}%"></div></div>
    </div>
  {:else if result}
    <div class="card ok">
      <span>Terminé : <strong>{fileName(result)}</strong></span>
      <button type="button" class="ghost" onclick={() => revealItemInDir(result!)}>Ouvrir le dossier</button>
    </div>
  {:else if error}
    <p class="err" role="alert">{error}</p>
  {/if}

  <ul class="sources">
    {#each sources as s}
      <li class:soon={s.soon}><strong>{s.name}</strong><span>{s.note}</span></li>
    {/each}
  </ul>

  <p class="tools" aria-live="polite">
    {#if tools.preparing && tools.progress}
      {progressLabel(tools.progress)}
    {:else if tools.preparing}
      Vérification des outils…
    {:else if tools.error}
      <span class="err">Outils indisponibles : {tools.error}</span>
      <button type="button" class="link" onclick={prepareTools}>Réessayer</button>
    {:else if tools.status?.ready}
      <svg aria-hidden="true" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="var(--ok)" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"><path d="M5 12.5l4.5 4.5L19 7.5" /></svg>
      yt-dlp {tools.status.ytdlpVersion} · ffmpeg {tools.status.ffmpeg === "system" ? "du système" : "installé par l'app"}
    {/if}
  </p>
</div>

<style>
  .wrap { max-width: 640px; margin: 0 auto; min-height: 100%; display: flex; flex-direction: column; justify-content: center; gap: 28px; }
  .intro { display: flex; flex-direction: column; gap: 12px; }
  h1 { margin: 0; font: 700 48px/1.05 var(--display); letter-spacing: -0.02em; }
  .intro p { margin: 0; color: var(--muted); font-size: 16px; line-height: 1.5; }
  form { display: flex; flex-direction: column; gap: 12px; }
  label { font-weight: 600; }
  .row { display: flex; gap: 10px; flex-wrap: wrap; }
  input { flex: 1 1 320px; min-width: 0; height: 52px; border-radius: 12px; border: 1px solid var(--line-strong); background: var(--field); padding: 0 16px; font-size: 15px; }
  input:focus-visible, button:focus-visible { outline: 2px solid var(--accent); outline-offset: 2px; }
  button[type="submit"] { height: 52px; padding: 0 22px; border-radius: 12px; border: none; background: var(--accent); color: var(--on-accent); font-weight: 700; display: flex; align-items: center; gap: 8px; cursor: pointer; }
  button:disabled { opacity: 0.5; cursor: default; }
  .card { display: flex; flex-direction: column; gap: 10px; background: var(--panel); border: 1px solid var(--line); border-radius: 14px; padding: 16px 18px; }
  .card.ok { flex-direction: row; align-items: center; justify-content: space-between; gap: 12px; flex-wrap: wrap; }
  .bar { height: 8px; border-radius: 99px; background: var(--line); overflow: hidden; }
  .bar div { height: 100%; border-radius: 99px; background: var(--accent); transition: width 0.2s; }
  .ghost { height: 40px; padding: 0 14px; border-radius: 10px; border: 1px solid var(--line-strong); background: transparent; cursor: pointer; }
  .link { background: none; border: none; color: var(--accent); cursor: pointer; padding: 0; text-decoration: underline; }
  .err { color: var(--err); margin: 0; }
  .sources { list-style: none; margin: 0; padding: 0; display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: 10px; }
  .sources li { display: flex; flex-direction: column; gap: 6px; padding: 14px; border-radius: 12px; background: var(--panel); border: 1px solid var(--line); }
  .sources li span { font-size: 12px; color: var(--muted); }
  .sources li.soon { border-style: dashed; border-color: var(--line-strong); }
  .sources li.soon strong { color: var(--text-2); }
  .tools { margin: 0; min-height: 20px; display: flex; align-items: center; gap: 8px; color: var(--muted); font-size: 13px; }
</style>
