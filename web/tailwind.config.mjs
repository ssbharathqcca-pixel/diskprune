/** @type {import('tailwindcss').Config} */
export default {
  content: ["./src/**/*.{astro,html,js,jsx,md,mdx,mjs,svelte,ts,tsx,vue}"],
  theme: {
    extend: {
      colors: {
        paper: "#f4f3ef",
        ink: "#161615",
        muted: "#5e5c56",
        subtle: "#8a877e",
        hairline: "#e6e4dc",
        panel: "#fffcf7",
        accent: "#1d4ed8",
      },
      fontFamily: {
        sans: [
          "ui-sans-serif",
          "system-ui",
          "-apple-system",
          "BlinkMacSystemFont",
          "Segoe UI",
          "sans-serif",
        ],
        mono: [
          "ui-monospace",
          "SFMono-Regular",
          "Menlo",
          "Consolas",
          "monospace",
        ],
      },
      maxWidth: {
        prose: "40rem",
        site: "68rem",
      },
    },
  },
  plugins: [],
};
