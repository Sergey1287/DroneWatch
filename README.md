# DroneWatch MVP — iPhone

SwiftUI starter application with a map, radar-style display, event log, settings, location permission handling, local event persistence, and local test notifications.

## Current status
- This archive contains source code and build configuration, not an installed iPhone app.
- No official live data provider is connected yet.
- Demo entries are not real alerts or detections.
- An iPhone alone cannot function as a radar or guarantee UAV detection at 5 km.

## Build with GitHub Actions
The workflow at `.github/workflows/ios-build.yml` runs an iOS Simulator build on pushes and pull requests. It uses a GitHub-hosted macOS runner.

## Build locally on a Mac
Install Xcode and XcodeGen, then run:

    brew install xcodegen
    xcodegen generate
    xcodebuild -project DroneWatch.xcodeproj -scheme DroneWatch -sdk iphonesimulator CODE_SIGNING_ALLOWED=NO build

## Source files
Swift files are in `DroneWatch/`. `project.yml` defines the iOS app target and location usage description.

## Data-source limitation
The provider adapter is intentionally unconfigured. Before adding automatic warnings, verify an official, documented and permitted feed, its schema and update frequency. Do not treat airspace notices as proof of physical UAV presence.
