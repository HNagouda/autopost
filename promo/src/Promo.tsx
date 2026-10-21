import { AbsoluteFill, Html5Audio, Sequence, staticFile } from "remotion";
import { Backdrop, Grain } from "./components/Backdrop";
import { Fade } from "./components/Fade";
import { FEATURES, LIGHTROOM } from "./features";
import { OUTRO_FRAMES, Outro, STATEMENT_FRAMES, Statement } from "./scenes/Cards";
import { Feature, featureFrames } from "./scenes/Feature";
import { INTRO_FRAMES, Intro } from "./scenes/Intro";
import { PHONE_DETOUR_FRAMES, PhoneDetour } from "./scenes/PhoneDetour";
import { seconds } from "./theme";
import { VOICEOVER, VOICEOVER_LEAD } from "./voiceover";

// Neighbouring scenes overlap by this much and cross-dissolve.
const OVERLAP = seconds(0.4);

// The whole film, in order. Each entry is a scene and its length in frames.
export const SCENES = [
  { name: "Intro", frames: INTRO_FRAMES, element: <Intro /> },
  { name: "Lightroom", frames: featureFrames(LIGHTROOM), element: <Feature {...LIGHTROOM} /> },
  { name: "Phone detour", frames: PHONE_DETOUR_FRAMES, element: <PhoneDetour /> },
  { name: "Statement", frames: STATEMENT_FRAMES, element: <Statement text="So I built Autopost." /> },
  ...FEATURES.map((feature) => ({ name: feature.kicker, frames: featureFrames(feature), element: <Feature {...feature} /> })),
  { name: "Outro", frames: OUTRO_FRAMES, element: <Outro /> },
];

export const PROMO_FRAMES = SCENES.reduce((total, scene) => total + scene.frames - OVERLAP, OVERLAP);

export const Promo = () => {
  let start = 0;

  return (
    <AbsoluteFill>
      <Backdrop />
      {SCENES.map((scene) => {
        const sequence = (
          <Sequence key={scene.name} name={scene.name} from={start} durationInFrames={scene.frames}>
            <Fade frames={OVERLAP}>{scene.element}</Fade>
            {VOICEOVER[scene.name] && (
              <Sequence from={VOICEOVER_LEAD} layout="none">
                <Html5Audio src={staticFile(VOICEOVER[scene.name])} />
              </Sequence>
            )}
          </Sequence>
        );
        start += scene.frames - OVERLAP;
        return sequence;
      })}
      <Grain />
    </AbsoluteFill>
  );
};
