# Autopost launch video

The YouTube launch video, built with [Remotion](https://www.remotion.dev) from scripted screen recordings of the app. Everything you see is laid out in code, so a caption, a cut or a camera move is a one-line change. The voiceover lines as recorded are in `SCRIPT.md`, and the upload checklist is in `RELEASE.md`.

The recordings and photos are not in git because they are large. `public/clips/` holds one cropped recording per feature (`import.mp4`, `ratios.mp4` and so on), `public/photos/` holds real Autopost exports used in the intro and outro, `public/willow.jpg` is the unframed photo on the phone in the Lightroom detour, and `voiceover/` holds the raw takes (`1.mp3` to `12.mp3`, in script order).

1. Install the dependencies.
2. Open the studio to scrub through the video and tweak scenes. `src/features.ts` has every feature's cuts and camera moves, and `src/Promo.tsx` has the scene order.
3. Clean the voiceover takes into `public/vo/`. `src/voiceover.ts` says which scene plays which line.
4. Render the video and the thumbnail. The composition is laid out at 1080p and `--scale=2` renders it at 4K, which YouTube streams at a higher bitrate.

```sh
npm install
npm run studio
python3 scripts/clean_voiceover.py
npx remotion render src/index.ts Promo out/autopost-promo-4k-vo.mp4 --scale=2 --crf=16 --audio-codec=aac --audio-bitrate=320k
npx remotion still src/index.ts Thumbnail out/thumbnail.png
```

#! NOTE[promo, music] : No music yet; the cold open and the outro are timed to carry a track
