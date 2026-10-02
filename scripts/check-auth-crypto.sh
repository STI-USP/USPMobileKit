#!/bin/sh
# Standalone host safety regression; no network or external dependency.
set -eu
repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
crypto_tmp=$(mktemp -d "${TMPDIR:-/tmp}/uspauth-crypto.XXXXXX")
trap 'rm -rf "$crypto_tmp"' EXIT HUP INT TERM
xcrun clang -g -O1 -fsanitize=address,undefined -fno-omit-frame-pointer \
  -I"$repo_root/Sources/USPAuthKit/Authentication/Provider/OAuth1/Crypto" \
  "$repo_root/Tests/USPAuthKitTests/Authentication/OAuth1/Crypto/HMACInputTests.c" \
  "$repo_root/Sources/USPAuthKit/Authentication/Provider/OAuth1/Crypto/hmac.c" \
  "$repo_root/Sources/USPAuthKit/Authentication/Provider/OAuth1/Crypto/sha1.c" -o "$crypto_tmp/check"
"$crypto_tmp/check"
