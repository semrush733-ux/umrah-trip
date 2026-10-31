#!/usr/bin/env bash
# Generates android/ and ios/ platform folders for the committed Dart app,
# then patches them (permissions, Maps key, app name) and applies launcher
# icons. Safe to run repeatedly. Run from the repo's app/ directory.
set -euo pipefail

if [ ! -f pubspec.yaml ]; then
  echo "Run from the app/ directory." >&2
  exit 1
fi

if [ ! -d android ] || [ ! -d ios ]; then
  flutter create . --org com.bwpexperts --project-name volo_chat --platforms android,ios
fi

# flutter create adds a counter-app test that doesn't apply to this app.
if [ -f test/widget_test.dart ] && grep -q 'MyApp' test/widget_test.dart; then rm test/widget_test.dart; fi

flutter pub get
python3 "$(dirname "$0")/patch_platforms.py"

# Generate launcher icons from assets/images/logo.png (Android adaptive + iOS)
dart run flutter_launcher_icons || flutter pub run flutter_launcher_icons

echo "Bootstrap complete. Build with:"
echo "  flutter build apk --release --dart-define=MAPS_API_KEY=\${MAPS_API_KEY:-}"
echo "  flutter build ios --release --no-codesign --dart-define=MAPS_API_KEY=\${MAPS_API_KEY:-}"
