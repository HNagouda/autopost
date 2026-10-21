import { AbsoluteFill, useCurrentFrame } from "remotion";
import { INK } from "../theme";

// A dark stage with a soft top light, a vignette and moving film grain, behind every scene.
export const Backdrop = () => {
  return (
    <AbsoluteFill style={{ backgroundColor: INK }}>
      <AbsoluteFill
        style={{
          background: "radial-gradient(ellipse 70% 55% at 50% 0%, rgba(255, 244, 228, 0.07), transparent 70%)",
        }}
      />
      <AbsoluteFill
        style={{ background: "radial-gradient(ellipse at center, transparent 55%, rgba(0, 0, 0, 0.55) 100%)" }}
      />
    </AbsoluteFill>
  );
};

// Grain sits on top of everything, so the UI footage and the titles share one texture.
export const Grain = () => {
  const frame = useCurrentFrame();
  // A new noise pattern every other frame reads as film; every frame reads as static.
  const seed = Math.floor(frame / 2) % 97;

  return (
    <AbsoluteFill style={{ pointerEvents: "none", opacity: 0.07, mixBlendMode: "overlay" }}>
      <svg width="100%" height="100%">
        <filter id={`grain-${seed}`}>
          <feTurbulence type="fractalNoise" baseFrequency="0.9" numOctaves="2" seed={seed} stitchTiles="stitch" />
        </filter>
        <rect width="100%" height="100%" filter={`url(#grain-${seed})`} />
      </svg>
    </AbsoluteFill>
  );
};
