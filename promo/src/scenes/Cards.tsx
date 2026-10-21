import { AbsoluteFill, Easing, Img, interpolate, staticFile, useCurrentFrame } from "remotion";
import { DISPLAY, DISPLAY_WEIGHT, MUTED, PAPER, SANS, seconds } from "../theme";

export const STATEMENT_FRAMES = seconds(3.2);
export const OUTRO_FRAMES = seconds(8);

const ease = Easing.bezier(0.16, 1, 0.3, 1);

// One line of display type in the middle of the frame, between chapters.
export const Statement = ({ text }: { text: string }) => {
  const frame = useCurrentFrame();
  const enter = ease(interpolate(frame, [seconds(0.2), seconds(1.3)], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" }));

  return (
    <AbsoluteFill style={{ alignItems: "center", justifyContent: "center" }}>
      <div
        style={{
          fontFamily: DISPLAY,
          fontWeight: DISPLAY_WEIGHT,
          fontSize: 96,
          color: PAPER,
          opacity: enter,
          transform: `translateY(${(1 - enter) * 20}px)`,
          filter: `blur(${(1 - enter) * 8}px)`,
        }}
      >
        {text}
      </div>
    </AbsoluteFill>
  );
};

// Exports drifting past in three rows, darkened, behind the closing title.
const WALL_ROWS = [
  ["p01", "p13", "p20", "p09", "p26", "p15", "p23", "p03", "p30"],
  ["p27", "p05", "p18", "p22", "p10", "p31", "p02", "p16", "p24"],
  ["p14", "p33", "p21", "p06", "p11", "p28", "p19", "p04", "p17"],
];
const WALL_TILE = 300;

export const Outro = () => {
  const frame = useCurrentFrame();
  const enter = ease(interpolate(frame, [seconds(0.6), seconds(2.0)], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" }));
  const link = ease(interpolate(frame, [seconds(1.6), seconds(2.8)], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" }));

  return (
    <AbsoluteFill>
      <AbsoluteFill style={{ opacity: 0.28, transform: "rotate(-6deg) scale(1.25)", justifyContent: "center", gap: 24 }}>
        {WALL_ROWS.map((row, index) => (
          <div
            key={index}
            style={{
              display: "flex",
              gap: 24,
              // Rows drift in opposite directions.
              transform: `translateX(${(index % 2 === 0 ? -1 : 1) * frame * 0.9 - 400}px)`,
            }}
          >
            {row.map((photo) => (
              <Img key={photo} src={staticFile(`photos/${photo}.jpg`)} style={{ height: WALL_TILE * 1.25 }} />
            ))}
          </div>
        ))}
      </AbsoluteFill>
      <AbsoluteFill style={{ background: "radial-gradient(ellipse at center, rgba(11,11,12,0.92) 30%, rgba(11,11,12,0.55) 75%)" }} />
      <AbsoluteFill style={{ alignItems: "center", justifyContent: "center", textAlign: "center" }}>
        <Img src={staticFile("icon.png")} style={{ width: 120, opacity: enter, marginBottom: 26 }} />
        <div style={{ fontFamily: DISPLAY, fontWeight: DISPLAY_WEIGHT, fontSize: 150, lineHeight: 1, color: PAPER, opacity: enter }}>Autopost</div>
        <div style={{ fontFamily: SANS, fontSize: 28, color: MUTED, marginTop: 28, opacity: link }}>
          Free and open source · macOS 14 or newer
        </div>
        <div style={{ fontFamily: SANS, fontWeight: 500, fontSize: 30, color: PAPER, marginTop: 18, opacity: link, letterSpacing: 0.3 }}>
          github.com/HNagouda/autopost
        </div>
      </AbsoluteFill>
    </AbsoluteFill>
  );
};
