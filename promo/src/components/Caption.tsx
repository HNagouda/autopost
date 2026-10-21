import { AbsoluteFill, Easing, interpolate, useCurrentFrame, useVideoConfig } from "remotion";
import { DISPLAY, DISPLAY_WEIGHT, MUTED, PAPER, SANS, seconds } from "../theme";

type Props = { kicker: string; title: string; delay?: number };

const ease = Easing.bezier(0.16, 1, 0.3, 1);

// The feature name in the lower left, over a dark gradient so it reads on top of any footage.
export const Caption = ({ kicker, title, delay = 0.4 }: Props) => {
  const frame = useCurrentFrame();
  const { durationInFrames } = useVideoConfig();
  const start = seconds(delay);
  const end = durationInFrames - seconds(0.5);

  const enter = ease(interpolate(frame, [start, start + seconds(0.9)], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" }));
  const leave = interpolate(frame, [end - seconds(0.4), end], [1, 0], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });
  const opacity = enter * leave;

  return (
    <AbsoluteFill style={{ pointerEvents: "none" }}>
      <AbsoluteFill
        style={{
          background: "linear-gradient(to top, rgba(8, 8, 9, 0.96) 0%, rgba(8, 8, 9, 0.82) 20%, rgba(8, 8, 9, 0.3) 36%, transparent 50%)",
          opacity,
        }}
      />
      <div style={{ position: "absolute", left: 96, bottom: 84, opacity, transform: `translateY(${(1 - enter) * 24}px)` }}>
        <div style={{ fontFamily: SANS, fontWeight: 500, fontSize: 18, letterSpacing: 4.5, textTransform: "uppercase", color: MUTED }}>
          {kicker}
        </div>
        <div style={{ fontFamily: DISPLAY, fontWeight: DISPLAY_WEIGHT, fontSize: 68, lineHeight: 1.05, color: PAPER, marginTop: 10, letterSpacing: -0.5 }}>
          {title}
        </div>
      </div>
    </AbsoluteFill>
  );
};
