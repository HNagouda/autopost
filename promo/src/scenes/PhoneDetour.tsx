import { AbsoluteFill, Easing, Img, interpolate, staticFile, useCurrentFrame } from "remotion";
import { Caption } from "../components/Caption";
import { MUTED, PAPER, SANS, seconds } from "../theme";

export const PHONE_DETOUR_FRAMES = seconds(7.6);

const PHONE_WIDTH = 400;
const PHONE_HEIGHT = 820;
const ease = Easing.bezier(0.65, 0, 0.35, 1);

// The detour through the phone, drawn as a plain phone rather than any app's real screen:
// a border slider dragged by hand on one photo, then the counter ticking to the next one.
export const PhoneDetour = () => {
  const frame = useCurrentFrame();
  const drag = ease(interpolate(frame, [seconds(1.0), seconds(2.6)], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" }));
  const border = drag * 28;
  const photoNumber = frame < seconds(3.6) ? 1 : frame < seconds(4.6) ? 2 : frame < seconds(5.6) ? 3 : 4;
  const rise = ease(interpolate(frame, [0, seconds(0.8)], [0, 1], { extrapolateRight: "clamp" }));

  return (
    <AbsoluteFill>
      <div
        style={{
          position: "absolute",
          right: 300,
          top: (1080 - PHONE_HEIGHT) / 2 + (1 - rise) * 60,
          width: PHONE_WIDTH,
          height: PHONE_HEIGHT,
          borderRadius: 64,
          background: "#050505",
          boxShadow: "0 0 0 10px #1c1c1e, 0 0 0 11px rgba(255,255,255,0.12), 0 50px 140px rgba(0,0,0,0.7)",
          overflow: "hidden",
          opacity: rise,
        }}
      >
        <div style={{ position: "absolute", top: 130, left: 24, right: 24, height: 440, background: "#fff", padding: border }}>
          <Img src={staticFile("willow.jpg")} style={{ width: "100%", height: "100%", objectFit: "contain" }} />
        </div>
        <div style={{ position: "absolute", top: 70, width: "100%", textAlign: "center", fontFamily: SANS, fontSize: 18, color: MUTED }}>
          {photoNumber} of 8
        </div>
        <div style={{ position: "absolute", top: 640, left: 48, right: 48 }}>
          <div style={{ fontFamily: SANS, fontSize: 17, color: PAPER, marginBottom: 18 }}>Border</div>
          <div style={{ height: 4, borderRadius: 2, background: "rgba(255,255,255,0.2)" }}>
            <div style={{ height: 4, borderRadius: 2, width: `${12 + drag * 46}%`, background: PAPER }} />
          </div>
          <div
            style={{
              position: "relative",
              top: -14,
              left: `calc(${12 + drag * 46}% - 12px)`,
              width: 24,
              height: 24,
              borderRadius: 12,
              background: PAPER,
            }}
          />
        </div>
      </div>
      <Caption kicker="The workaround" title="Re-open every photo on your phone, one at a time." delay={0.6} />
    </AbsoluteFill>
  );
};
