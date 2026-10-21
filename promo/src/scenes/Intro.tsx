import { AbsoluteFill, Easing, Img, Sequence, interpolate, staticFile, useCurrentFrame } from "remotion";
import { DISPLAY, DISPLAY_WEIGHT, MUTED, PAPER, SANS, seconds } from "../theme";

// Real Autopost exports, borders and all, cut on a steady beat.
const MONTAGE = ["p13", "p23", "p01", "p09", "p29", "p14", "p20", "p25"];
const BEAT = seconds(0.42);
const LEAD_IN = seconds(0.6);

export const INTRO_FRAMES = LEAD_IN + MONTAGE.length * BEAT + seconds(4.2);

const ease = Easing.bezier(0.16, 1, 0.3, 1);

export const Intro = () => {
  const titleStart = LEAD_IN + MONTAGE.length * BEAT;

  return (
    <AbsoluteFill>
      {MONTAGE.map((photo, index) => (
        <Sequence key={photo} from={LEAD_IN + index * BEAT} durationInFrames={BEAT}>
          <MontagePhoto photo={photo} />
        </Sequence>
      ))}
      <Sequence from={titleStart}>
        <Title />
      </Sequence>
    </AbsoluteFill>
  );
};

const MontagePhoto = ({ photo }: { photo: string }) => {
  const frame = useCurrentFrame();
  // A slow push on each photo keeps the cuts from feeling like a slideshow.
  const scale = interpolate(frame, [0, BEAT], [1.06, 1.0]);

  return (
    <AbsoluteFill style={{ alignItems: "center", justifyContent: "center" }}>
      <Img
        src={staticFile(`photos/${photo}.jpg`)}
        style={{ height: 860, transform: `scale(${scale})`, boxShadow: "0 30px 90px rgba(0, 0, 0, 0.6)" }}
      />
    </AbsoluteFill>
  );
};

const Title = () => {
  const frame = useCurrentFrame();
  const word = ease(interpolate(frame, [0, seconds(1.4)], [0, 1], { extrapolateRight: "clamp" }));
  const line = ease(interpolate(frame, [seconds(0.8), seconds(2.0)], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" }));

  return (
    <AbsoluteFill style={{ alignItems: "center", justifyContent: "center", textAlign: "center" }}>
      <Img
        src={staticFile("icon.png")}
        style={{ width: 132, opacity: word, transform: `translateY(${(1 - word) * 16}px)`, marginBottom: 28 }}
      />
      <div
        style={{
          fontFamily: DISPLAY,
          fontWeight: DISPLAY_WEIGHT,
          fontSize: 188,
          lineHeight: 1,
          color: PAPER,
          opacity: word,
          letterSpacing: interpolate(word, [0, 1], [18, -2]),
        }}
      >
        Autopost
      </div>
      <div style={{ fontFamily: SANS, fontSize: 30, color: MUTED, marginTop: 30, opacity: line, letterSpacing: 0.4 }}>
        White borders for Instagram, done properly, on your Mac.
      </div>
    </AbsoluteFill>
  );
};
