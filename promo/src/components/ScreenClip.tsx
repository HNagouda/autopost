import { AbsoluteFill, Easing, OffthreadVideo, interpolate, staticFile, useCurrentFrame } from "remotion";
import { BASE_WIDTH, FPS, HEIGHT, WIDTH } from "../theme";

// Where the camera looks: x and y are fractions of the recording, zoom 1 shows all of it.
// `at` is a time in the recording, in seconds, so shots line up with the recording's action log.
export type Shot = { at: number; x: number; y: number; zoom: number };

type Props = {
  clip: string;
  aspect: number;
  from: number;
  rate?: number;
  shots: Shot[];
};

// How long the camera takes to move from one shot to the next.
const MOVE_SECONDS = 1.1;
const ease = Easing.bezier(0.65, 0, 0.35, 1);

// A screen recording on the stage, with a camera that eases between shots.
export const ScreenClip = ({ clip, aspect, from, rate = 1, shots }: Props) => {
  const frame = useCurrentFrame();
  const clipTime = from + (frame / FPS) * rate;
  const camera = _cameraAt(clipTime, shots);

  const width = BASE_WIDTH * camera.zoom;
  const height = width / aspect;
  const left = WIDTH / 2 - camera.x * width;
  const top = HEIGHT / 2 - camera.y * height;

  return (
    <AbsoluteFill>
      <div
        style={{
          position: "absolute",
          left,
          top,
          width,
          height,
          borderRadius: 14 * camera.zoom,
          overflow: "hidden",
          boxShadow: "0 40px 120px rgba(0, 0, 0, 0.65), 0 0 0 1px rgba(255, 255, 255, 0.06)",
        }}
      >
        <OffthreadVideo
          src={staticFile(`clips/${clip}.mp4`)}
          startFrom={Math.round(from * FPS)}
          playbackRate={rate}
          muted
          style={{ width: "100%", height: "100%" }}
        />
      </div>
    </AbsoluteFill>
  );
};

function _cameraAt(time: number, shots: Shot[]) {
  let camera = shots[0];

  for (const shot of shots.slice(1)) {
    const progress = ease(interpolate(time, [shot.at, shot.at + MOVE_SECONDS], [0, 1], {
      extrapolateLeft: "clamp",
      extrapolateRight: "clamp",
    }));
    camera = {
      at: shot.at,
      x: camera.x + (shot.x - camera.x) * progress,
      y: camera.y + (shot.y - camera.y) * progress,
      zoom: camera.zoom + (shot.zoom - camera.zoom) * progress,
    };
  }

  return camera;
}
