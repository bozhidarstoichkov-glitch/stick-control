#!/usr/bin/env bash
set -euo pipefail
repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_dir"
if ! command -v xcodebuild >/dev/null || ! command -v xcrun >/dev/null; then
    echo 'iOS validation requires macOS and Xcode. This host cannot build or run Apple frameworks.' >&2
    exit 78
fi
# Select an installed iPhone Simulator without assuming a particular model/runtime.
simulator_id="$(xcrun simctl list devices available -j | python3 -c 'import json,sys; data=json.load(sys.stdin); devices=[d for runtime,items in data["devices"].items() if "iOS" in runtime for d in items if "iPhone" in d["name"] and d.get("isAvailable",False)]; print(devices[0]["udid"] if devices else "")')"
if [[ -z "$simulator_id" ]]; then
    echo 'Install an iOS Simulator runtime in Xcode Settings > Components, then retry.' >&2
    exit 78
fi
xcodebuild test -project StickControl.xcodeproj -scheme StickControl \
    -destination "platform=iOS Simulator,id=$simulator_id" \
    -derivedDataPath .build/ios CODE_SIGNING_ALLOWED=NO
