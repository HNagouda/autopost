import { AbsoluteFill, interpolate, useCurrentFrame, useVideoConfig } from "remotion";
import { ReactNode } from "react";

type Props = { frames: number; children: ReactNode };

// Fades a scene in at its start and out at its end, so neighbouring scenes cross-dissolve where they overlap.
export const Fade = ({ frames, children }: Props) => {
  const frame = useCurrentFrame();
  const { durationInFrames } = useVideoConfig();
  const opacity = interpolate(frame, [0, frames, durationInFrames - frames, durationInFrames], [0, 1, 1, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  return <AbsoluteFill style={{ opacity }}>{children}</AbsoluteFill>;
};
