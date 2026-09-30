/** @type {import('tailwindcss').Config} */
export default {
  content: ["./index.html","./src/**/*.{svelte,js,ts}"],
  theme: { extend: { colors: { dark: "#0a0a0a", card: "#171717" } } },
  plugins: []
}
