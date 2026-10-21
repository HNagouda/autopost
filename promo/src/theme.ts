import { loadFont as loadMonaSans } from "@remotion/google-fonts/MonaSans";

export const FPS = 30;
export const WIDTH = 1920;
export const HEIGHT = 1080;

export const INK = "#0b0b0c";
export const PAPER = "#f3efe7";
export const MUTED = "rgba(243, 239, 231, 0.58)";

// Mona Sans is the typeface github.com uses, so the video reads as part of the same world as the repo.
export const SANS = loadMonaSans("normal", { weights: ["400", "500", "600", "800"], subsets: ["latin"] }).fontFamily;
export const DISPLAY = SANS;
// Headlines are set heavier and tighter than body text, the way GitHub sets its own.
export const DISPLAY_WEIGHT = 600;

// The Autopost window as recorded: 1400 x 860 points, captured at 2x.
export const WINDOW_ASPECT = 2800 / 1720;
// The whole built-in screen, for the Lightroom recording.
export const SCREEN_ASPECT = 3024 / 1964;

// Width of a recording on screen when the camera is not zoomed in.
export const BASE_WIDTH = 1440;

export const seconds = (s: number) => Math.round(s * FPS);
