# YouTube release

Everything the upload needs is in `out/`:

1. `autopost-promo-4k-vo.mp4` is the video, 3840x2160 at 30 fps, 2:01, with the voiceover mixed in at -14 LUFS (the level YouTube plays at, so it is not turned down or up).
2. `thumbnail.png` is the 1280x720 thumbnail, from the `Thumbnail` composition in `src/scenes/Thumbnail.tsx`. Its hook ("Lightroom can't do this.") and the title tell the same story without repeating each other's words.
3. `autopost-promo.en.srt` is the English captions, built from the Whisper word timings. Upload it under Subtitles so YouTube does not auto-generate its own.

The title, description and chapters to paste in are below. YouTube makes chapters from the timestamps in the description; each one has to be at least 10 seconds long, which is why import and aspect ratios share one, and the outro sits inside the last.

#! NOTE[release, music] : No music yet; the 8-second cold open is silent without a track

## Title

Lightroom can't add white borders, so I built an app that does

## Description

I edit everything in Lightroom on my Mac, and it can't export a photo with a white border. Autopost turns a folder of edits into an Instagram carousel: one shape for the whole post, any border you like, camera settings and text in the border, a phone preview, and JPEGs Instagram won't squash.

It's free and open source, for macOS 14 or newer.
Download: https://github.com/HNagouda/autopost/releases/latest
Source: https://github.com/HNagouda/autopost

0:00 Why I built Autopost
0:27 Import and aspect ratios
0:44 Borders
0:57 Camera settings
1:07 Text
1:23 Phone preview
1:36 Export and themes

## Tags

instagram, white border, instagram border, lightroom, lightroom export border, instagram carousel, photography, mac app, macos, open source, film photography
