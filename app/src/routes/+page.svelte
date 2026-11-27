<script lang="ts">
  let url = $state("");
  const sources = [
    { name: "Spotify", note: "Identifiants requis" },
    { name: "Deezer", note: "Sans compte" },
    { name: "YouTube", note: "Sans compte" },
    { name: "Apple Music", note: "Bientôt", soon: true },
  ];
</script>

<div class="wrap">
  <div class="intro">
    <h1>Colle une playlist.</h1>
    <p>La source est reconnue toute seule. Chaque piste est retrouvée sur YouTube, convertie en MP3 et taguée avec sa pochette.</p>
  </div>

  <form onsubmit={(e) => e.preventDefault()}>
    <label for="url">URL de la playlist</label>
    <div class="row">
      <input id="url" type="url" bind:value={url} placeholder="https://open.spotify.com/playlist/…" />
      <button type="submit" disabled={!url}>
        Charger
        <svg aria-hidden="true" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"><path d="M5 12h14M13 6l6 6-6 6" /></svg>
      </button>
    </div>
  </form>

  <ul class="sources">
    {#each sources as s}
      <li class:soon={s.soon}><strong>{s.name}</strong><span>{s.note}</span></li>
    {/each}
  </ul>
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
  button { height: 52px; padding: 0 22px; border-radius: 12px; border: none; background: var(--accent); color: var(--on-accent); font-weight: 700; display: flex; align-items: center; gap: 8px; cursor: pointer; }
  button:disabled { opacity: 0.5; cursor: default; }
  .sources { list-style: none; margin: 0; padding: 0; display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: 10px; }
  .sources li { display: flex; flex-direction: column; gap: 6px; padding: 14px; border-radius: 12px; background: var(--panel); border: 1px solid var(--line); }
  .sources li span { font-size: 12px; color: var(--muted); }
  .sources li.soon { border-style: dashed; border-color: var(--line-strong); }
  .sources li.soon strong { color: var(--text-2); }
</style>
