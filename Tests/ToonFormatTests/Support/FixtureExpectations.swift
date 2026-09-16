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
        "decode/arrays-nested.json#1":
            "§9.4 parses list arrays with empty items",
        "decode/arrays-nested.json#2":
            "§10 parses list arrays with deeply nested objects",
        "decode/arrays-nested.json#22":
            "§9.2 accepts bare bracket pair as empty inner array list item",
        "decode/arrays-nested.json#23":
            "§14.1 keeps every list item when the count mismatches in non-strict mode",
        "decode/arrays-nested.json#9":
            "§9.2 parses quoted strings and mixed lengths in nested arrays",
        "decode/arrays-primitive.json#7":
            "§9.1 parses strings with delimiters in arrays",
        "decode/arrays-tabular.json#17":
            "§14.1 keeps every row when the count mismatches in non-strict mode",
        "decode/blank-lines.json#0":
            "§14.2 throws on blank line inside list array",
        "decode/blank-lines.json#1":
            "§14.2 throws on blank line inside tabular array",
        "decode/blank-lines.json#15":
            "§14.2 throws on blank line between list items after nested tabular rows",
        "decode/blank-lines.json#16":
            "§14.2 throws on blank line between a list item's fields",
        "decode/blank-lines.json#17":
            "§14.2 throws on blank line inside the last list item's fields",
        "decode/blank-lines.json#2":
            "§14.2 throws on blank line between keyed entry rows",
        "decode/blank-lines.json#3":
            "§14.2 throws on multiple blank lines inside array",
        "decode/blank-lines.json#4":
            "§14.2 throws on blank line with spaces inside array",
        "decode/comments.json#11":
            "§5.1 drops hash-leading row silently in non-strict mode",
        "decode/comments.json#13":
            "§5.1 decodes tab-indented hash row as data in non-strict mode",
        "decode/delimiters.json#28":
            "§6 falls through to a key-value line on a header delimiter mismatch",
        "decode/objects-keyed.json#18":
            "§9.5 skips an entry-depth line without a colon in non-strict mode",
        "decode/objects.json#34":
            "§8 parses dotted keys as identifiers",
        "decode/root-form.json#4":
            "§5 parses literal [] at root as empty array",
        "decode/root-form.json#5":
            "§5 throws on trailing content after a root array",
        "decode/root-form.json#6":
            "§5 throws on trailing content after a keyed tabular root",
        "decode/validation-errors.json#15":
            "§14.3 throws on duplicate sibling keys in strict mode",
        "decode/validation-errors.json#26":
            "§14.3 throws on nested duplicate sibling keys in strict mode",
        "decode/validation-errors.json#27":
            "§14.3 throws on duplicate keys within a list-item object in strict mode",
        "decode/validation-errors.json#3":
            "§14.1 throws on tabular row count mismatch with header length",
        "decode/validation-errors.json#34":
            "§14.1 throws on entry row count mismatch with keyed header length",
        "decode/validation-errors.json#44":
            "§14.3 throws on duplicate entry keys in strict mode",
        "decode/validation-errors.json#49":
            "§6 throws on keyless fields-bearing header as list item",
        "decode/validation-errors.json#54":
            "§7.4 throws on characters after a closing quote in non-strict mode",
        "decode/validation-errors.json#7":
            "§14.2 throws on unterminated string",
        "decode/whitespace.json#14":
            "§12 treats a hyphen followed by trailing spaces as the bare marker",
        "decode/whitespace.json#6":
            "§12 preserves NBSP-leading unquoted value",
        "decode/whitespace.json#7":
            "§12 preserves NBSP around inline array tokens",
        "encode/arrays-nested.json#10":
            "§8 encodes complex nested structure",
        "encode/arrays-nested.json#14":
            "§9.3 uses list form for a tabular-eligible array in list-item position",
        "encode/arrays-nested.json#7":
            "§9.4 encodes root-level array mixing primitive, object, and array of objects in list form",
        "encode/arrays-nested.json#9":
            "§9.1 encodes empty root-level array",
        "encode/arrays-objects.json#9":
            "§10 encodes objects with empty arrays in list form",
        "encode/arrays-primitive.json#3":
            "§9.1 encodes empty arrays",
        "encode/arrays-primitive.json#5":
            "§9.1 encodes empty string keys for empty arrays",
        "encode/objects-keyed.json#11":
            "§10 emits a keyed header on the hyphen line when it is the first field of a list item",
        "encode/objects.json#27":
            "§7.1 escapes U+001F control character in key via \\uXXXX",
        "encode/primitives.json#37":
            "§2 encodes repeating decimal with full precision",
    ]
}
