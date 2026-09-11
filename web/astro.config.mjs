import { defineConfig } from "astro/config";
import tailwind from "@astrojs/tailwind";

export default defineConfig({
  site: "https://diskprune.com",
  trailingSlash: "always",
  integrations: [tailwind({ applyBaseStyles: false })],
});
