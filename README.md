# vanilla

`vanilla` is a Flutter Android app for learning basic circuits through a mobile-first canvas, visible electrical feedback, and explainable diagnostics.

The current scope follows the design document in this repository:

- Flutter app shell with Material UI.
- Canvas-first workbench using `CustomPainter` instead of widget-per-wire rendering.
- Document-scale component catalog with 45 component specs, ports, default parameters, teaching notes, and MVP/advanced/later stages.
- Port-based wires, component anchors, graph-built nets, and graph-driven DC path diagnostics for the LED current-limiting lesson.
- Diagnostics that explain open circuit, invalid wires, source short, over-current, missing ground, and normal current flow.
- Interactive port-to-port wire creation, component dragging, undo/redo, and dynamic lesson validation.
- GitHub Actions Android release build with a fixed committed signing key.

## Build

The repository is designed to build in GitHub Actions. The workflow installs Flutter on Ubuntu, runs:

```sh
flutter pub get
flutter analyze
flutter test
flutter build apk --release
flutter build appbundle --release
```

Artifacts are uploaded from:

- `build/app/outputs/flutter-apk/app-release.apk`
- `build/app/outputs/bundle/release/app-release.aab`

## Signing

`android/key.properties` points at `android/keystore/vanilla-release.jks`, which is committed so every CI release build has the same signing identity.

This is acceptable for an empty MVP repository. Before public store release, rotate the key into GitHub Secrets or enroll with Play App Signing.
