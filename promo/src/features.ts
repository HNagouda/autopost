import { FeatureProps } from "./scenes/Feature";
import { SCREEN_ASPECT } from "./theme";

// Every recorded feature, in the order the video shows them, in one place.
// Times are seconds into each recording (see the .log files written while recording),
// and x / y are fractions of the Autopost window, which is 1400 x 860 points.
const WIDE = { x: 0.5, y: 0.5, zoom: 1 };

export const LIGHTROOM: FeatureProps = {
  clip: "lightroom",
  aspect: SCREEN_ASPECT,
  kicker: "The problem",
  title: "Lightroom on the Mac can't add a border.",
  segments: [
    // File menu, then Export.
    { from: 1.6, to: 4.8, shots: [{ at: 1.6, x: 0.2, y: 0.2, zoom: 2.2 }] },
    // The export settings, read top to bottom. There is no border option.
    { from: 8.6, to: 15.2, shots: [{ at: 8.6, x: 0.88, y: 0.36, zoom: 2.5 }, { at: 11.5, x: 0.88, y: 0.46, zoom: 2.5 }] },
  ],
};

export const FEATURES: FeatureProps[] = [
  {
    clip: "import",
    isReveal: true,
    kicker: "Import",
    title: "Drop in a folder. Get a post.",
    segments: [
      {
        from: 0.8,
        to: 8.0,
        shots: [{ at: 0.8, ...WIDE }, { at: 1.7, x: 0.34, y: 0.5, zoom: 1.35 }, { at: 4.2, ...WIDE }],
      },
    ],
  },
  {
    clip: "ratios",
    kicker: "Aspect ratio",
    title: "Every Instagram shape, one click away.",
    segments: [
      {
        from: 0.8,
        to: 11.8,
        shots: [{ at: 0.8, ...WIDE }, { at: 1.3, x: 0.86, y: 0.2, zoom: 1.9 }, { at: 3.4, ...WIDE }],
      },
    ],
  },
  {
    clip: "border",
    kicker: "Borders",
    title: "Any width, any colour, or the photo itself.",
    segments: [
      // Border size, dragged wide, thin, then back.
      {
        from: 1.0,
        to: 9.2,
        rate: 1.2,
        shots: [{ at: 1.0, ...WIDE }, { at: 1.2, x: 0.86, y: 0.39, zoom: 1.8 }, { at: 3.1, ...WIDE }],
      },
      // Warm paper, black, then the blurred photo.
      {
        from: 10.2,
        to: 16.8,
        rate: 1.1,
        shots: [{ at: 10.2, ...WIDE }, { at: 13.8, x: 0.42, y: 0.5, zoom: 1.12 }],
      },
    ],
  },
  {
    clip: "camera",
    kicker: "Camera settings",
    title: "Your camera settings, read from the file.",
    segments: [
      {
        from: 1.0,
        to: 11.6,
        shots: [
          { at: 1.0, ...WIDE },
          { at: 1.3, x: 0.86, y: 0.76, zoom: 1.9 },
          { at: 4.3, ...WIDE },
          { at: 7.6, x: 0.48, y: 0.82, zoom: 2.7 },
        ],
      },
    ],
  },
  {
    clip: "text",
    kicker: "Text",
    title: "Titles that line up across the whole carousel.",
    segments: [
      // Add a text box, type, pick Didot, italic, bigger.
      { from: 1.0, to: 11.8, rate: 1.5, shots: [{ at: 1.0, ...WIDE }, { at: 1.7, x: 0.68, y: 0.72, zoom: 1.55 }] },
      // With the grid on, drag it to the top border and back; it snaps to the middle.
      { from: 14.6, to: 21.4, rate: 1.25, shots: [{ at: 14.6, x: 0.48, y: 0.5, zoom: 1.3 }] },
      // The next photo's text lands in the same spot.
      { from: 21.6, to: 26.2, rate: 1.1, shots: [{ at: 21.6, ...WIDE }, { at: 23.0, x: 0.48, y: 0.58, zoom: 1.3 }] },
    ],
  },
  {
    clip: "phone",
    kicker: "Phone preview",
    title: "See the post before your followers do.",
    segments: [
      {
        from: 1.0,
        to: 16.8,
        rate: 1.2,
        shots: [{ at: 1.0, ...WIDE }, { at: 2.4, x: 0.785, y: 0.52, zoom: 1.15 }],
      },
    ],
  },
  {
    clip: "export",
    kicker: "Export",
    title: "JPEGs Instagram won't squash.",
    // Slowed down so the voiceover fits; after the click it is a still Finder window anyway.
    segments: [{ from: 0.6, to: 7.9, rate: 0.78, shots: [{ at: 0.6, ...WIDE }, { at: 2.8, x: 0.5, y: 0.36, zoom: 1.25 }] }],
  },
  {
    clip: "themes",
    kicker: "Themes",
    title: "Light, dark and pure black.",
    segments: [{ from: 1.4, to: 9.6, shots: [{ at: 1.4, ...WIDE }, { at: 2.4, x: 0.47, y: 0.47, zoom: 1.08 }] }],
  },
];
