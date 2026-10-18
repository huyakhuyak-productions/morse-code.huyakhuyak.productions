import { defineConfig } from "astro/config";
import tailwindcss from "@tailwindcss/vite";
import sitemap from "@astrojs/sitemap";

export default defineConfig({
  site: "https://morse-code.huyakhuyak.productions",
  integrations: [sitemap()],
  vite: {
    plugins: [tailwindcss()],
  },
});
