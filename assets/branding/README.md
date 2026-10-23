# ADBroom artwork

<p align="center"><img src="adbroom-icon.png" width="192" alt="ADBroom"></p>

The Android TV / magic wand artwork is used by the Mac companion and repository documentation. The standalone TV launcher maintains its own copy in [adbroom-launcher](https://github.com/tahsingibi/adbroom-launcher). The transparent cutout preserves the rounded silhouette; it must remain square and be resized proportionally.

| File | Purpose |
| --- | --- |
| `source.png` | Original artwork supplied by Tahsin Sungur, including its white surround |
| `adbroom-icon.png` | 1024 × 1024 transparent master for documentation and platform assets |
| `../../Resources/icon-1024.png` | Mac input; the build generates the complete ICNS size set |

Do not flatten the master onto white, stretch it to fill a banner, or apply a second rounded mask. Rounded corners and the transparent surrounding margin are already part of the master. The Mac About block uses the bundled application icon automatically.

The background extraction uses the built-in imagegen tool; platform resizing uses `sips`. No generation service is involved when building or running ADBroom. The exact extraction instruction is recorded in [EDIT-PROMPT.md](EDIT-PROMPT.md).

After updating the transparent master, regenerate the committed Mac PNG on macOS:

```sh
bash scripts/prepare-icons.sh
```

Run this command from the repository root. Normal Mac builds use the prepared file. The standalone launcher maintains and builds its own icon resources.
