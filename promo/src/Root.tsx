import { Composition } from "remotion";
import { PROMO_FRAMES, Promo } from "./Promo";
import { THUMBNAIL_HEIGHT, THUMBNAIL_WIDTH, Thumbnail } from "./scenes/Thumbnail";
import { FPS, HEIGHT, WIDTH } from "./theme";

// Laid out at 1080p; render with --scale=2 for the 4K upload.
export const Root = () => (
  <>
    <Composition id="Promo" component={Promo} durationInFrames={PROMO_FRAMES} fps={FPS} width={WIDTH} height={HEIGHT} />
    <Composition id="Thumbnail" component={Thumbnail} durationInFrames={1} fps={FPS} width={THUMBNAIL_WIDTH} height={THUMBNAIL_HEIGHT} />
  </>
);
