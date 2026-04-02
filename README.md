# CatLate

CatLate is a voice-first iOS translator for people who do not want to navigate small controls or type on screen. The app reduces the interaction model to two primary actions: `Speak` and `Hear`.

It is built as a native SwiftUI iPhone app using Apple's speech recognition, on-device translation, and speech synthesis frameworks.

## What It Does

- Listen to a spoken phrase in the source language
- Show the live transcript as you speak
- Translate the final phrase into the selected target language
- Read the translated phrase aloud
- Optionally read the original phrase back aloud

## Design Goals

- Large controls that are easy to see and tap
- Clear labels instead of dense settings UI
- Fast one-screen interaction flow
- No external translation API dependency
- Native iOS frameworks and on-device translation workflow

## Highlights

- Large high-contrast buttons for speaking and playback
- Plain language labels: `I speak` and `They hear`
- Speech recognition with live transcript feedback
- On-device Apple translation workflow using the `Translation` framework
- Spoken playback of both the translated phrase and the original phrase

## Supported Languages

- English
- Spanish
- French
- German
- Italian
- Portuguese
- Japanese
- Korean
- Chinese (Simplified)
- Arabic

## Requirements

- Xcode 26.4 or newer
- iOS 18.0 or newer
- Microphone permission
- Speech Recognition permission

## Project Structure

- `CatLate/ContentView.swift`: main single-screen SwiftUI interface
- `CatLate/AppViewModel.swift`: state management and translation flow
- `CatLate/SpeechRecognizerService.swift`: speech-to-text handling
- `CatLate/SpeechPlaybackService.swift`: spoken audio playback
- `CatLate/AppLanguage.swift`: supported language definitions
- `project.yml`: XcodeGen project specification

## Build

Generate the Xcode project from the XcodeGen spec:

```bash
xcodegen generate
```

Build for the iOS Simulator:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild -project CatLate.xcodeproj -scheme CatLate -destination 'generic/platform=iOS Simulator' build
```

## Run In Simulator

If you want to install and launch it on a booted simulator:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild -project CatLate.xcodeproj -scheme CatLate -destination 'generic/platform=iOS Simulator' -derivedDataPath ./.derivedData build

DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcrun simctl install booted ./.derivedData/Build/Products/Debug-iphonesimulator/CatLate.app

DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcrun simctl launch booted project.catlyte.CatLate
```

## Notes

- On first use, iOS may prompt to download language assets for translation.
- Translation support depends on Apple's supported language pairs on the device.
- The app currently targets iOS only.
