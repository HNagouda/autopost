import { Config } from "@remotion/cli/config";

// The screen recordings are 2800 px wide, so JPEG frames would soften the UI text; PNG keeps it sharp.
Config.setVideoImageFormat("png");
Config.setConcurrency(6);
