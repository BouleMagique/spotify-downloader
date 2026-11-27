<script lang="ts">
  import { invoke } from "@tauri-apps/api/core";

  type AppInfo = { version: string; configDir: string };
  let info = $state<AppInfo | null>(null);
  invoke<AppInfo>("app_info").then((i) => (info = i));
</script>

<div class="wrap">
  <h1>Réglages</h1>
  <section>
    <h2>À propos</h2>
    <dl>
      <dt>Version</dt><dd>{info?.version ?? "…"}</dd>
      <dt>Dossier de configuration</dt><dd><code>{info?.configDir ?? "…"}</code></dd>
    </dl>
  </section>
</div>

<style>
  .wrap { max-width: 860px; display: flex; flex-direction: column; gap: 24px; }
  h1 { margin: 0; font: 700 40px var(--display); letter-spacing: -0.02em; }
  section { background: var(--panel); border: 1px solid var(--line); border-radius: 14px; padding: 22px; }
  h2 { margin: 0 0 14px; font-size: 17px; font-weight: 600; }
  dl { margin: 0; display: grid; grid-template-columns: max-content 1fr; gap: 10px 24px; }
  dt { color: var(--muted); }
  dd { margin: 0; }
  code { font-size: 13px; }
</style>
