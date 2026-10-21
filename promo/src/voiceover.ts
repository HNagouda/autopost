import { seconds } from "./theme";

// Each line starts this long after its scene does, once the cross-dissolve has settled.
export const VOICEOVER_LEAD = seconds(0.5);

// Every scene's voiceover line, by scene name, in one place. The clips come from
// scripts/clean_voiceover.py, numbered in script order. The intro has no voice.
export const VOICEOVER: Record<string, string> = {
  Lightroom: "vo/01.wav",
  "Phone detour": "vo/02.wav",
  Statement: "vo/03.wav",
  Import: "vo/04.wav",
  "Aspect ratio": "vo/05.wav",
  Borders: "vo/06.wav",
  "Camera settings": "vo/07.wav",
  Text: "vo/08.wav",
  "Phone preview": "vo/09.wav",
  Export: "vo/10.wav",
  Themes: "vo/11.wav",
  Outro: "vo/12.wav",
};
