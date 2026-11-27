<script lang="ts">
  import "../app.css";
  import { page } from "$app/state";
  let { children } = $props();
</script>

<div class="shell">
  <nav aria-label="Navigation">
    <a class="brand" href="/">
      <span class="logo" aria-hidden="true">
        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><path d="M12 4v11" /><path d="M7 11l5 5 5-5" /><path d="M5 20h14" /></svg>
      </span>
      Playlist DL
    </a>

    <div class="group">
      <span class="label">Récents</span>
      <p class="empty">Aucune playlist pour l'instant.</p>
    </div>

    <a class="item settings" href="/reglages" aria-current={page.url.pathname === "/reglages" ? "page" : undefined}>
      <svg aria-hidden="true" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><circle cx="12" cy="12" r="3" /><path d="M12 2v3M12 19v3M4.2 4.2l2.1 2.1M17.7 17.7l2.1 2.1M2 12h3M19 12h3M4.2 19.8l2.1-2.1M17.7 6.3l2.1-2.1" /></svg>
      Réglages
    </a>
  </nav>

  <main>{@render children()}</main>
</div>

<style>
  .shell { display: flex; height: 100vh; }
  nav { flex: none; width: 240px; background: var(--panel); border-right: 1px solid var(--line); padding: 24px 16px; display: flex; flex-direction: column; gap: 28px; }
  .brand { display: flex; align-items: center; gap: 10px; padding: 0 8px; color: var(--text); text-decoration: none; font: 700 17px var(--display); letter-spacing: -0.01em; }
  .logo { width: 32px; height: 32px; border-radius: 9px; background: var(--accent); color: var(--on-accent); display: grid; place-items: center; }
  .group { display: flex; flex-direction: column; gap: 4px; }
  .label { font-size: 11px; font-weight: 600; text-transform: uppercase; letter-spacing: 0.08em; color: var(--muted); padding: 0 10px 6px; }
  .empty { margin: 0; padding: 0 10px; color: var(--muted); font-size: 13px; }
  .item { display: flex; align-items: center; gap: 10px; padding: 10px; border-radius: 8px; color: var(--text-2); text-decoration: none; }
  .item:hover, .item[aria-current="page"] { background: var(--hover); color: var(--text); }
  .settings { margin-top: auto; }
  main { flex: 1; min-width: 0; overflow-y: auto; padding: 36px; }
</style>
