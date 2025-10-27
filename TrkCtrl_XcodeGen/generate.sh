
#!/usr/bin/env bash
set -euo pipefail
if ! command -v xcodegen >/dev/null 2>&1; then
  echo "Installing XcodeGen via Homebrew..."
  brew install xcodegen
fi
xcodegen generate --spec project.yml
echo "✅ Generated TrkCtrl.xcodeproj — open it in Xcode and run."
