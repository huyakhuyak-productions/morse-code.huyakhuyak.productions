import { OGImageRoute } from "astro-og-canvas";
import { TAGLINE } from "@/lib/site";

const BLACK: [number, number, number] = [0, 0, 0];
const WHITE: [number, number, number] = [255, 255, 255];
const DIM: [number, number, number] = [140, 140, 140];
const COBALT: [number, number, number] = [61, 91, 255];

export const { getStaticPaths, GET } = await OGImageRoute({
  pages: {
    default: { title: "Morse Lamp", description: TAGLINE },
  },
  getImageOptions: (_path, page) => ({
    title: page.title,
    description: page.description,
    bgGradient: [BLACK],
    border: { color: COBALT, width: 12, side: "block-end" },
    padding: 72,
    logo: { path: "./src/assets/icon-1024.png", size: [260] },
    font: {
      title: { families: ["Archivo"], weight: "Black", size: 72, color: WHITE, lineHeight: 1.15 },
      description: { families: ["Archivo"], weight: "Medium", size: 34, color: DIM, lineHeight: 1.4 },
    },
    fonts: ["./src/assets/og/Archivo-Black.ttf", "./src/assets/og/Archivo-Medium.ttf"],
  }),
});
