export type Theme = "dawn" | "dusk" | "midnight";

export const THEMES: Theme[] = ["dawn", "dusk", "midnight"];

function stored(): Theme | null {
  try {
    const t = localStorage.getItem("petring_theme");
    return t === "dawn" || t === "dusk" || t === "midnight" ? t : null;
  } catch {
    return null;
  }
}

export const theme = $state<{ value: Theme }>({ value: "dawn" });

export function set_theme(t: Theme): void {
  theme.value = t;
  document.documentElement.dataset.theme = t;
  try {
    localStorage.setItem("petring_theme", t);
  } catch {}
}

export function init_theme(): void {
  const saved = stored();
  if (saved) {
    document.documentElement.dataset.theme = saved;
    theme.value = saved;
  } else if (typeof window !== "undefined") {
    theme.value = window.matchMedia("(prefers-color-scheme: dark)").matches
      ? "midnight"
      : "dawn";
  }
}
