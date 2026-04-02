#!/bin/sh
set -eu

REPO_ROOT="$(CDPATH= cd -- "$(dirname "$0")"/.. && pwd)"
cd "$REPO_ROOT"

export HOMEBREW_NO_AUTO_UPDATE=1

if ! command -v xcodegen >/dev/null 2>&1; then
  if ! command -v brew >/dev/null 2>&1; then
    echo "Homebrew is required to install XcodeGen in ci_post_clone.sh" >&2
    exit 1
  fi

  brew install xcodegen
fi

xcodegen generate
