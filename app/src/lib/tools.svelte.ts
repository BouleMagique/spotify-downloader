import { invoke } from "@tauri-apps/api/core";
import { listen } from "@tauri-apps/api/event";

export type ToolsStatus = {
  ytdlpVersion: string | null;
  ffmpeg: "system" | "app" | null;
  deno: boolean;
  ready: boolean;
};

type ToolsProgress = {
  tool: string;
  stage: "download" | "extract" | "update";
  downloaded: number;
  total: number | null;
};

/** État partagé des outils externes (yt-dlp, ffmpeg). */
export const tools = $state({
  status: null as ToolsStatus | null,
  preparing: false,
  progress: null as ToolsProgress | null,
  error: null as string | null,
});

let started = false;

/** Lancé une seule fois au démarrage : installe ce qui manque, met yt-dlp à jour. */
export async function prepareTools() {
  if (started) return;
  started = true;
  const unlisten = await listen<ToolsProgress>("tools-progress", (e) => (tools.progress = e.payload));
  tools.preparing = true;
  try {
    tools.status = await invoke<ToolsStatus>("tools_status");
    tools.status = await invoke<ToolsStatus>("prepare_tools");
    tools.error = null;
  } catch (e) {
    tools.error = String(e);
    started = false; // permet de réessayer
  } finally {
    tools.preparing = false;
    tools.progress = null;
    unlisten();
  }
}

export function progressLabel(p: ToolsProgress): string {
  if (p.stage === "update") return `Mise à jour de ${p.tool}…`;
  if (p.stage === "extract") return `Extraction de ${p.tool}…`;
  const mb = (n: number) => (n / 1e6).toFixed(0);
  return p.total
    ? `Téléchargement de ${p.tool} : ${mb(p.downloaded)} / ${mb(p.total)} Mo`
    : `Téléchargement de ${p.tool} : ${mb(p.downloaded)} Mo`;
}
