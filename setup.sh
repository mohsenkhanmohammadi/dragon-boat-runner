#!/usr/bin/env bash
# Dragon Boat Runner - one-time project setup (macOS / Linux / CI)
#   chmod +x setup.sh && ./setup.sh
set -e
cd "$(dirname "$0")"

flutter create --org de.dragonboatrunner --project-name dragon_boat_runner --platforms android,ios .

for g in android/app/build.gradle.kts android/app/build.gradle; do
  if [ -f "$g" ]; then
    perl -pi -e 's/minSdk\s*=\s*flutter\.minSdkVersion/minSdk = 24/; s/minSdkVersion\s+flutter\.minSdkVersion/minSdkVersion 24/' "$g"
  fi
done

if [ -f ios/Runner.xcodeproj/project.pbxproj ]; then
  perl -pi -e 's/IPHONEOS_DEPLOYMENT_TARGET = \d+\.\d+;/IPHONEOS_DEPLOYMENT_TARGET = 15.0;/g' ios/Runner.xcodeproj/project.pbxproj
fi

flutter pub get
dart run flutter_launcher_icons
echo "Done. Next: flutterfire configure (see README.md)"
