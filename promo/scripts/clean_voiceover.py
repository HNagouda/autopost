"""Turn the raw voiceover takes in voiceover/ into the levelled clips the video plays.

Each take is cleaned the same way so the lines sound like one recording: rumble
below 80 Hz is cut, peaks are gently compressed, the trailing silence is trimmed
(the video leaves its own gap), and the loudness is measured and set to -14 LUFS,
the level YouTube normalises to, so it neither turns the video down nor up.
"""

import json
import subprocess
import sys
from pathlib import Path

PROMO = Path(__file__).resolve().parent.parent
RAW = PROMO / "voiceover"
OUT = PROMO / "public" / "vo"

TARGET_LUFS = -14
TRUE_PEAK = -1.5
LOUDNESS_RANGE = 7
SAMPLE_RATE = 48000

# Rumble cut, then a gentle 2.5:1 compressor so loud words do not jump out.
CLEANUP = "highpass=f=80,acompressor=threshold=-20dB:ratio=2.5:attack=5:release=80:makeup=2"
# Silence at the end only: reverse, strip leading silence, reverse back.
TRIM_TAIL = "areverse,silenceremove=start_periods=1:start_threshold=-45dB:start_silence=0.05,areverse"
# A short fade-in so the first word never clicks; the tail is already silence.
FADES = "afade=t=in:d=0.01"


def _measure(take, chain):
    """First loudnorm pass: returns the measured loudness values."""
    loudnorm = f"loudnorm=I={TARGET_LUFS}:TP={TRUE_PEAK}:LRA={LOUDNESS_RANGE}:print_format=json"
    result = subprocess.run(
        ["ffmpeg", "-hide_banner", "-i", str(take), "-af", f"{chain},{loudnorm}", "-f", "null", "-"],
        capture_output=True, text=True, check=True,
    )
    # loudnorm prints its JSON block last, after the usual ffmpeg summary lines.
    report = result.stderr[result.stderr.rindex("{"):]
    return json.loads(report[: report.index("}") + 1])


def _clean(take, clip):
    chain = f"{CLEANUP},{TRIM_TAIL}"
    measured = _measure(take, chain)
    loudnorm = (
        f"loudnorm=I={TARGET_LUFS}:TP={TRUE_PEAK}:LRA={LOUDNESS_RANGE}:linear=true"
        f":measured_I={measured['input_i']}:measured_TP={measured['input_tp']}"
        f":measured_LRA={measured['input_lra']}:measured_thresh={measured['input_thresh']}"
        f":offset={measured['target_offset']}"
    )
    subprocess.run(
        ["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", str(take),
         "-af", f"{chain},{loudnorm},{FADES}", "-ar", str(SAMPLE_RATE), "-ac", "1", str(clip)],
        check=True,
    )


def main():
    takes = sorted(RAW.glob("*.mp3"), key=lambda path: int(path.stem))
    if not takes:
        sys.exit(f"No takes in {RAW}, expected 1.mp3, 2.mp3 and so on in script order.")

    OUT.mkdir(parents=True, exist_ok=True)
    for take in takes:
        clip = OUT / f"{int(take.stem):02d}.wav"
        _clean(take, clip)
        print(f"{take.name} -> {clip.relative_to(PROMO)}")


if __name__ == "__main__":
    main()
