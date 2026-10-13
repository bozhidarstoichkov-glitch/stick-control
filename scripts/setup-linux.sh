#!/usr/bin/env bash
set -euo pipefail
# Portable model validation only. Apple UI/audio require Xcode on macOS.
repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
toolchain_dir=/workspace/toolchains/swift-6.2.3-RELEASE-ubuntu22.04
if [[ ! -x "$toolchain_dir/usr/bin/swift" ]]; then
    install_tmp="$(mktemp -d /tmp/stick-control-swift.XXXXXX)"
    trap 'rm -rf "$install_tmp"' EXIT
    curl -fL --retry 2 https://download.swift.org/swift-6.2.3-release/ubuntu2204/swift-6.2.3-RELEASE/swift-6.2.3-RELEASE-ubuntu22.04.tar.gz -o "$install_tmp/swift.tar.gz"
    # SHA-256 of the official artifact, verified against Apple's release signature during onboarding.
    (cd "$install_tmp" && printf '%s\n' '23653abba4b153aa6625f73e63e3f119bdaf18363b00e3770a306fbd9b192aef  swift.tar.gz' | sha256sum --check --strict)
    mkdir -p /workspace/toolchains
    tar -xzf "$install_tmp/swift.tar.gz" -C /workspace/toolchains
fi
export PATH="$toolchain_dir/usr/bin:$PATH"
export XDG_CACHE_HOME=/workspace/toolchains/cache
export CLANG_MODULE_CACHE_PATH="$XDG_CACHE_HOME/clang"
export SWIFT_MODULECACHE_PATH="$XDG_CACHE_HOME/swift"
mkdir -p "$CLANG_MODULE_CACHE_PATH" "$SWIFT_MODULECACHE_PATH" "$XDG_CACHE_HOME"/{swiftpm,config,security}
cd "$repo_dir"
swift --version
swift test --jobs 2 --cache-path "$XDG_CACHE_HOME/swiftpm" --config-path "$XDG_CACHE_HOME/config" --security-path "$XDG_CACHE_HOME/security"
swiftc -frontend -parse StickControl/StickControlApp.swift StickControl/PracticeModel.swift StickControl/Audio/Metronome.swift StickControl/Views/*.swift
