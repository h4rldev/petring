import tailwindcss from "@tailwindcss/vite";
import adapter from "@sveltejs/adapter-static";
import { sveltekit } from "@sveltejs/kit/vite";
import { defineConfig } from "vite";

export default defineConfig({
  server: {
    proxy: {
      "/api": { target: "http://localhost:8080", changeOrigin: true, ws: true },
    },
  },
  plugins: [
    tailwindcss(),
    sveltekit({
      compilerOptions: {
        // Force runes mode for the project, except for libraries. Can be removed in svelte 6.
        runes: ({ filename }) =>
          filename.split(/[/\\]/).includes("node_modules") ? undefined : true,
      },
      alias: {
        $appcss: "src/app.css",
        $components: "src/components",
      },
      adapter: adapter({
        pages: "build",
        assets: "build",
        fallback: "200.html",
        precompress: true,
        strict: true,
      }),
    }),
  ],
});
