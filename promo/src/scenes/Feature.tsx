import { AbsoluteFill, Easing, Sequence, interpolate, useCurrentFrame } from "remotion";
import { Caption } from "../components/Caption";
import { ScreenClip, Shot } from "../components/ScreenClip";
import { FPS, WINDOW_ASPECT, seconds } from "../theme";

// One continuous stretch of a recording: [from, to] in recording seconds, played at `rate`.
export type Segment = { from: number; to: number; rate?: number; shots: Shot[] };

export type FeatureProps = {
  clip: string;
  kicker: string;
  title: string;
  segments: Segment[];
  aspect?: number;
  // The first time the app appears, it tilts up into place instead of fading in flat.
  isReveal?: boolean;
};

export const segmentFrames = (segment: Segment) => Math.round(((segment.to - segment.from) / (segment.rate ?? 1)) * FPS);

export const featureFrames = (feature: FeatureProps) =>
  feature.segments.reduce((total, segment) => total + segmentFrames(segment), 0);

// A feature is its recording, cut into segments, with its name in the corner.
export const Feature = ({ clip, kicker, title, segments, aspect = WINDOW_ASPECT, isReveal = false }: FeatureProps) => {
  const frame = useCurrentFrame();
  const reveal = isReveal ? _revealEase(interpolate(frame, [0, seconds(1.6)], [0, 1], { extrapolateRight: "clamp" })) : 1;
  let start = 0;

  return (
    <AbsoluteFill style={{ perspective: 1600 }}>
      <AbsoluteFill
        style={{
          transform: `rotateX(${(1 - reveal) * 24}deg) scale(${0.82 + reveal * 0.18}) translateY(${(1 - reveal) * 120}px)`,
        }}
      >
        {segments.map((segment) => {
          const frames = segmentFrames(segment);
          const sequence = (
            <Sequence key={segment.from} from={start} durationInFrames={frames}>
              <ScreenClip clip={clip} aspect={aspect} from={segment.from} rate={segment.rate} shots={segment.shots} />
            </Sequence>
          );
          start += frames;
          return sequence;
        })}
      </AbsoluteFill>
      <Caption kicker={kicker} title={title} />
    </AbsoluteFill>
  );
};

const _revealEase = Easing.bezier(0.16, 1, 0.3, 1);
