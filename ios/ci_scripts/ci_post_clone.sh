#!/bin/sh
# Xcode Cloud : préparation d'un projet Flutter après le clonage du dépôt.
# Installe Flutter, récupère les paquets Dart, génère les fichiers iOS (Generated.xcconfig) et installe les Pods.
set -e
set -x

cd "$CI_PRIMARY_REPOSITORY_PATH"

# 1. Flutter (version stable, même canal que Codemagic)
git clone https://github.com/flutter/flutter.git --depth 1 -b stable "$HOME/flutter"
export PATH="$PATH:$HOME/flutter/bin"
flutter --version

# 2. Artefacts iOS et paquets Dart
flutter precache --ios
flutter pub get

# 3. Numéro de build unique et croissant (Xcode Cloud repart de 1, Apple exige un numéro croissant)
BUILD_NUMBER=$((CI_BUILD_NUMBER + 300))

# 4. Génère ios/Flutter/Generated.xcconfig avec le bon numéro de build, sans compiler ni signer
flutter build ios --config-only --no-codesign --release --build-number="$BUILD_NUMBER"

# 5. CocoaPods
HOMEBREW_NO_AUTO_UPDATE=1 brew install cocoapods || true
cd ios
pod install --repo-update

exit 0
