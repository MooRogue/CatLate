# CatLate

CatLate is a voice-first iOS translator designed for people who do not want to navigate small controls or type on screen. The app keeps the flow to two main actions: `Speak` and `Hear`.

## Highlights

- Large high-contrast buttons for speaking and playback
- Plain language labels: `I speak` and `They hear`
- Speech recognition with live transcript feedback
- On-device Apple translation workflow using the `Translation` framework
- Spoken playback of both the translated phrase and the original phrase

## Requirements

- Xcode 26.4 or newer
- iOS 18.0 or newer
- Microphone permission
- Speech Recognition permission

## Build

Generate the project:

```bash
xcodegen generate
```

Build for the iOS Simulator:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild -project CatLate.xcodeproj -scheme CatLate -destination 'generic/platform=iOS Simulator' build
```

On first use, iOS may prompt to download language assets for translation.
