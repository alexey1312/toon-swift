/// The conformance cases that the library does not satisfy yet.
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
enum FixtureExpectations {
    static let knownGaps: [String: String] = [
        "decode/arrays-nested.json#2":
            "§10 parses list arrays with deeply nested objects",
        "decode/arrays-nested.json#9":
            "§9.2 parses quoted strings and mixed lengths in nested arrays",
        "decode/arrays-primitive.json#7":
            "§9.1 parses strings with delimiters in arrays",
        "decode/blank-lines.json#15":
            "§14.2 throws on blank line between list items after nested tabular rows",
        "decode/comments.json#13":
            "§5.1 decodes tab-indented hash row as data in non-strict mode",
        "decode/delimiters.json#28":
            "§6 falls through to a key-value line on a header delimiter mismatch",
        "decode/objects-keyed.json#18":
            "§9.5 skips an entry-depth line without a colon in non-strict mode",
        "decode/validation-errors.json#49":
            "§6 throws on keyless fields-bearing header as list item",
        "encode/arrays-nested.json#14":
            "§9.3 uses list form for a tabular-eligible array in list-item position",
        "encode/arrays-nested.json#7":
            "§9.4 encodes root-level array mixing primitive, object, and array of objects in list form",
        "encode/objects-keyed.json#11":
            "§10 emits a keyed header on the hyphen line when it is the first field of a list item",
        "encode/primitives.json#37":
            "§2 encodes repeating decimal with full precision",
    ]
}
