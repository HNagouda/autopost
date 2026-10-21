import { AbsoluteFill, Img, staticFile } from "remotion";
import { Backdrop } from "../components/Backdrop";
import { DISPLAY, MUTED, PAPER, SANS } from "../theme";

// YouTube's thumbnail size.
export const THUMBNAIL_WIDTH = 1280;
export const THUMBNAIL_HEIGHT = 720;

// One loud colour, used only for the hook and the arrow, so the eye lands there first.
const ACCENT = "#ffd43b";
// Thumbnails are seen small, so the hook is set far heavier than anything in the video.
const HOOK_WEIGHT = 800;

// A real Autopost export, big and tilted, with the hook pointing straight at its border.
export const Thumbnail = () => (
  <AbsoluteFill>
    <Backdrop />
    <Img
      src={staticFile("photos/p25.jpg")}
      style={{
        position: "absolute",
        left: 905,
        top: 120,
        width: 330,
        transform: "rotate(7deg)",
        boxShadow: "0 30px 80px rgba(0,0,0,0.8)",
        filter: "brightness(0.55)",
      }}
    />
    <Img
      src={staticFile("photos/p01.jpg")}
      style={{
        position: "absolute",
        left: 690,
        top: 70,
        width: 460,
        transform: "rotate(-4deg)",
        boxShadow: "0 40px 100px rgba(0,0,0,0.85)",
      }}
    />
    <div style={{ position: "absolute", left: 70, top: 120, fontFamily: DISPLAY, fontWeight: HOOK_WEIGHT, lineHeight: 0.95, letterSpacing: -3 }}>
      <div style={{ fontSize: 92, color: PAPER }}>Lightroom</div>
      <div style={{ fontSize: 132, color: ACCENT }}>can't</div>
      <div style={{ fontSize: 132, color: PAPER }}>do this.</div>
    </div>
    <svg width={THUMBNAIL_WIDTH} height={THUMBNAIL_HEIGHT} style={{ position: "absolute" }}>
      <path d="M 520 300 C 600 250, 650 250, 700 290" stroke={ACCENT} strokeWidth={12} fill="none" strokeLinecap="round" />
      <path d="M 668 262 L 708 296 L 660 312" stroke={ACCENT} strokeWidth={12} fill="none" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
    <div style={{ position: "absolute", left: 74, bottom: 78, display: "flex", alignItems: "center", gap: 18 }}>
      <Img src={staticFile("icon.png")} style={{ width: 64 }} />
      <div style={{ fontFamily: SANS, fontWeight: 600, fontSize: 40, color: PAPER }}>
        Autopost <span style={{ color: MUTED, fontWeight: 500 }}>· free, for Mac</span>
      </div>
    </div>
  </AbsoluteFill>
);
