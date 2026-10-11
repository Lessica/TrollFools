# Devkit

## App icon resource cropping

`crop-app-icon.swift` is an executable Swift script for macOS with Xcode or the
Command Line Tools installed. It uses Core Graphics and Image I/O, without any
third-party packages. It writes rounded corners into the PNG's alpha channel.

```sh
devkit/crop-app-icon.swift square-icon.png rounded-icon.png
devkit/crop-app-icon.swift square-icon.png rounded-icon.png --size 120
```

You can also run it explicitly with the Swift interpreter:

```sh
xcrun --sdk macosx swift devkit/crop-app-icon.swift square-icon.png rounded-icon.png
```

The default output is 128 × 128. Both the artwork and mask must be square PNGs.
The artwork is resized proportionally, keeping its existing transparency and RGB
color space. The bundled `app-icon-mask.png` is Apple's 180 × 180 iPhone App icon
alpha mask, decoded losslessly from `MobileIcons.framework/AppIconMask@3x~iphone.png`
in the iOS 18.1 simulator runtime. Its actual outline defines the corners; no
corner-radius percentage is estimated.

Output sizes greater than the mask's resolution are rejected. Supply a larger
square alpha mask when needed:

```sh
devkit/crop-app-icon.swift square-icon.png rounded-icon.png --size 1024 --mask high-resolution-mask.png
```

Input and output can be the same PNG; the script encodes the complete image before
replacing the file atomically. Start from the original square artwork each time,
because masking an already-rounded PNG compounds its antialiased edge alpha.

For this project's advertisements, use `--size 128` and save the output as
`icon_128x128.png` in the appropriate `TrollFools/Assets.xcassets/*.imageset`.
Run `devkit/crop-app-icon.swift --help` for the full command-line usage.
