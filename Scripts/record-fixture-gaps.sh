#!/usr/bin/env bash
#
# Regenerates Tests/ToonFormatTests/Support/FixtureExpectations.swift from a
# live test run. Run this script after a migration step, then review the diff:
# every line that disappears is a conformance gap that the step closed.
#
# The script clears the list first, so the run reports every failing case.

set -euo pipefail

readonly ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly TARGET="$ROOT/Tests/ToonFormatTests/Support/FixtureExpectations.swift"
readonly FIXTURES="$ROOT/Tests/ToonFormatTests/Fixtures"

write_list() {
  python3 - "$TARGET" "$FIXTURES" "$@" <<'PY'
import json, pathlib, sys

target = pathlib.Path(sys.argv[1])
fixtures = pathlib.Path(sys.argv[2])
ids = sys.argv[3:]

details = {}
for path in sorted(fixtures.glob("*/*.json")):
    if path.name == "PROVENANCE.json":
        continue
    key = f"{path.parent.name}/{path.name}"
    for index, test in enumerate(json.loads(path.read_text())["tests"]):
        section = test.get("specSection", "")
        section = f"§{section.lstrip('§')} " if section else ""
        details[f"{key}#{index}"] = f"{section}{test['name']}"

lines = []
for identifier in sorted(ids):
    reason = details.get(identifier, "unknown case")
    reason = reason.replace("\\", "\\\\").replace('"', "'")
    lines.append(f'        "{identifier}":\n            "{reason}",')

body = "\n".join(lines) if lines else ""
entries = f"\n{body}\n    " if body else ":"

target.write_text(f'''/// The conformance cases that the library does not satisfy yet.
///
/// The key is `<category>/<file>#<index>`, the identifier that
/// ``FixtureCase/id`` builds. The value names the specification section and the
/// case, so that a diff of this file reads as a list of closed gaps.
///
/// ``FixtureTests`` wraps a listed case in `withKnownIssue`, so the run fails
/// when the case starts to pass. Each step of the migration to specification
/// 4.1 removes its own entries, and cannot forget to. The list must be empty
/// for the release.
///
/// Regenerate this file with `Scripts/record-fixture-gaps.sh`.
enum FixtureExpectations {{
    static let knownGaps: [String: String] = [{entries}]
}}
''')
print(f"Recorded {len(ids)} known gaps.")
PY
}

echo "Clearing the list…"
write_list

echo "Running the fixture suite…"
log="$(mktemp)"
trap 'rm -f "$log"' EXIT
(cd "$ROOT" && swift test --filter FixtureTests > "$log" 2>&1) || true

# Only the issue lines. A "Test case passing …" line names a case that ran,
# not a case that failed.
failing=()
while IFS= read -r identifier; do
  [ -n "$identifier" ] && failing+=("$identifier")
done < <(
  grep 'recorded an issue' "$log" \
    | grep -o 'fixture → [a-z]*/[a-z-]*\.json#[0-9]*' \
    | sed 's/fixture → //' \
    | sort -u
)

if [ "${#failing[@]}" -eq 0 ]; then
  echo "No failing case found. Check the run if that is unexpected."
fi

write_list ${failing[@]+"${failing[@]}"}
