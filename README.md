# Ice

Ice is a private personal-use fork of the original Ice macOS menu bar utility.

This fork is intentionally small and local-build focused. Public distribution features, automatic updates, release feeds, donation links, support links, and maintainer contact flows have been removed. The original GPL-3.0 license and copyright notices are preserved.

## Requirements

- macOS 26 Tahoe
- Xcode 26.5 or newer available in this environment
- Swift 6 language mode

## Build and Run

Open `Ice.xcodeproj` in Xcode and run the `Ice` scheme, or build from Terminal:

```sh
xcodebuild -project Ice.xcodeproj -scheme Ice -configuration Debug build
```

The project uses local ad hoc signing for personal builds. If Xcode prompts for privacy permissions, grant Accessibility and Screen Recording as needed for menu bar management features.

## Current Dependencies

- AXSwift
- CompactSlider
- Ifrit
- LaunchAtLogin

Sparkle and the old update feed are no longer included.

## License

Ice remains available under the [GPL-3.0 license](LICENSE).
