# mecho_os

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Build for the web

Build the production web app with:

```sh
flutter build web --release
```

The static site is generated in `build/web`.

## Deploy to Render

Render can use the Blueprint in `render.yaml` to build and publish the Flutter
web app as a static site. In Render, create a new Blueprint from this repository
and select the `mecho-os-web` static site. The Blueprint pins Flutter 3.35.1 and
rewrites app routes to `index.html` so Flutter navigation works on refresh.

The existing Supabase initialization and app flow are unchanged.
