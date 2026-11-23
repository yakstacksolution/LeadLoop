#!/usr/bin/env bash
# Runs the security-rules suite against the Firestore emulator.
set -euo pipefail
cd "$(dirname "$0")/.."

# The emulator requires JDK 21+; prefer a newer one if the default is older.
for candidate in openjdk@24 openjdk@25 openjdk; do
  home="/opt/homebrew/opt/$candidate/libexec/openjdk.jdk/Contents/Home"
  if [ -x "$home/bin/java" ]; then
    export JAVA_HOME="$home"
    export PATH="$JAVA_HOME/bin:$PATH"
    break
  fi
done

exec firebase emulators:exec --only firestore --project futsal-rules-test \
  "node rules_test/run.mjs"
