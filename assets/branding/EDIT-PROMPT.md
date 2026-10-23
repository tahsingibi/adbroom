# Icon extraction instruction

Tool: built-in `image_gen.imagegen`, transparent background enabled. Input: `source.png`.

```text
Precise background extraction for production app icon. Use the provided image itself as the edit target, not a design reference. Cut out the original blue rounded-square tile from the white background. Preserve the entire ORIGINAL interior artwork and ORIGINAL MUTED BLUE/CYAN/PURPLE colors, pixel-faithful: monitor, Android face, wand, stars, and corner silhouette. Do not increase saturation, regenerate, recolor, sharpen or redraw. Remove every white background pixel and external drop shadow. Outside the rounded tile must be completely clean alpha=0 with no detached colored pixels, haze, speckles or border artifacts. Keep original antialiased rounded edge, without squaring corners. Center the extracted tile within a square transparent canvas with 4% clear padding on all sides. This is a clean cutout/crop ONLY, not a new icon design.
```
