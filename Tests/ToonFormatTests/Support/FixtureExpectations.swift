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
        "decode/arrays-nested.json#4":
            "§10 parses list items whose first field is a tabular array",
        "decode/arrays-nested.json#5":
            "§10 parses single-field list-item object with tabular array",
        "decode/arrays-nested.json#7":
            "§9.2 parses arrays of arrays within objects",
        "decode/arrays-nested.json#9":
            "§9.2 parses quoted strings and mixed lengths in nested arrays",
        "decode/arrays-primitive.json#16":
            "§9.1 decodes canonical empty array key: []",
        "decode/arrays-primitive.json#17":
            "§9.1 decodes canonical empty array with quoted key",
        "decode/arrays-primitive.json#18":
            "§9.1 decodes canonical empty array with empty-string key",
        "decode/arrays-primitive.json#7":
            "§9.1 parses strings with delimiters in arrays",
        "decode/arrays-tabular.json#17":
            "§14.1 keeps every row when the count mismatches in non-strict mode",
        "decode/blank-lines.json#0":
            "§14.2 throws on blank line inside list array",
        "decode/blank-lines.json#1":
            "§14.2 throws on blank line inside tabular array",
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
        "decode/indentation-errors.json#0":
            "§14.2 throws on object field with non-multiple indentation (3 spaces with indentSize 2)",
        "decode/indentation-errors.json#1":
            "§14.2 throws on list item with non-multiple indentation (3 spaces with indentSize 2)",
        "decode/indentation-errors.json#2":
            "§14.2 throws on non-multiple indentation with custom indentSize 4 (3 spaces)",
        "decode/indentation-errors.json#4":
            "§14.2 throws on tab character used in indentation",
        "decode/indentation-errors.json#5":
            "§14.2 throws on mixed tabs and spaces in indentation",
        "decode/indentation-errors.json#6":
            "§14.2 throws on tab at start of line",
        "decode/objects-keyed.json#14":
            "§10 parses a keyed header on a hyphen line",
        "decode/objects-keyed.json#18":
            "§9.5 skips an entry-depth line without a colon in non-strict mode",
        "decode/objects.json#14":
            "§8 parses quoted object value shaped like an inline array header",
        "decode/objects.json#15":
            "§8 parses quoted object value shaped like a count-matching inline array header",
        "decode/objects.json#16":
            "§6 parses unquoted value shaped like an inline array header after the key",
        "decode/objects.json#17":
            "§6 parses unquoted value shaped like a tabular array header after the key",
        "decode/objects.json#20":
            "§7.1 decodes \\uXXXX in quoted key (U+0004 control character)",
        "decode/objects.json#21":
            "§7.1 decodes \\uXXXX in quoted key (case-insensitive hex)",
        "decode/objects.json#34":
            "§8 parses dotted keys as identifiers",
        "decode/objects.json#53":
            "§5.2 falls through to a key-value line when whitespace precedes the bracket segment",
        "decode/primitives.json#8":
            "§7.1 decodes \\uXXXX escape (U+0004)",
        "decode/primitives.json#9":
            "§7.1 decodes \\uXXXX with mixed-case hex digits",
        "decode/root-form.json#4":
            "§5 parses literal [] at root as empty array",
        "decode/root-form.json#5":
            "§5 throws on trailing content after a root array",
        "decode/root-form.json#6":
            "§5 throws on trailing content after a keyed tabular root",
        "decode/validation-errors.json#12":
            "§6 throws on extra brackets between bracket segment and colon in strict mode",
        "decode/validation-errors.json#13":
            "§6 throws on text between bracket segment and colon in strict mode",
        "decode/validation-errors.json#14":
            "§6 throws on non-integer bracket segment in strict mode",
        "decode/validation-errors.json#15":
            "§14.3 throws on duplicate sibling keys in strict mode",
        "decode/validation-errors.json#19":
            "§6 throws on bracket length with leading zeros in strict mode",
        "decode/validation-errors.json#20":
            "§6 throws on negative bracket length in strict mode",
        "decode/validation-errors.json#21":
            "§6 throws on decimal bracket length in strict mode",
        "decode/validation-errors.json#22":
            "§6 throws on bracket length with plus sign in strict mode",
        "decode/validation-errors.json#23":
            "§6 throws on bracket length in exponent form in strict mode",
        "decode/validation-errors.json#26":
            "§14.3 throws on nested duplicate sibling keys in strict mode",
        "decode/validation-errors.json#27":
            "§14.3 throws on duplicate keys within a list-item object in strict mode",
        "decode/validation-errors.json#28":
            "§14.2 throws on bracket segment without a length",
        "decode/validation-errors.json#3":
            "§14.1 throws on tabular row count mismatch with header length",
        "decode/validation-errors.json#34":
            "§14.1 throws on entry row count mismatch with keyed header length",
        "decode/validation-errors.json#37":
            "§14.2 throws on keyed header without a field list in strict mode",
        "decode/validation-errors.json#38":
            "§6 throws on keyed marker after the delimiter symbol in strict mode",
        "decode/validation-errors.json#39":
            "§6 throws on keyed marker with leading-zero length in strict mode",
        "decode/validation-errors.json#40":
            "§6 throws on whitespace before the keyed marker in strict mode",
        "decode/validation-errors.json#41":
            "§6 throws on explicit comma delimiter after the keyed marker in strict mode",
        "decode/validation-errors.json#44":
            "§14.3 throws on duplicate entry keys in strict mode",
        "decode/validation-errors.json#47":
            "§6 throws on keyless array header in object field position",
        "decode/validation-errors.json#48":
            "§6 throws on keyless array header after a depth-0 field",
        "decode/validation-errors.json#49":
            "§6 throws on keyless fields-bearing header as list item",
        "decode/validation-errors.json#52":
            "§6 throws on whitespace between a key and its bracket segment",
        "decode/validation-errors.json#53":
            "§9.3 throws on duplicate field names in a zero-row tabular header",
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
        "encode/arrays-nested.json#13":
            "§7.2 quotes hash-leading string as list item",
        "encode/arrays-nested.json#14":
            "§9.3 uses list form for a tabular-eligible array in list-item position",
        "encode/arrays-nested.json#7":
            "§9.4 encodes root-level array mixing primitive, object, and array of objects in list form",
        "encode/arrays-nested.json#9":
            "§9.1 encodes empty root-level array",
        "encode/arrays-objects.json#10":
            "§10 uses canonical encoding for multi-field list-item objects with tabular arrays",
        "encode/arrays-objects.json#11":
            "§10 uses canonical encoding for single-field list-item tabular arrays",
        "encode/arrays-objects.json#12":
            "§10 places empty arrays on hyphen line when first",
        "encode/arrays-objects.json#4":
            "§10 uses list form for objects containing arrays of arrays",
        "encode/arrays-objects.json#5":
            "§10 uses tabular form for nested uniform object arrays",
        "encode/arrays-objects.json#6":
            "§10 uses list form for nested object arrays with mismatched keys",
        "encode/arrays-objects.json#9":
            "§10 encodes objects with empty arrays in list form",
        "encode/arrays-primitive.json#12":
            "§7.2 quotes hash-leading string in inline array",
        "encode/arrays-primitive.json#3":
            "§9.1 encodes empty arrays",
        "encode/arrays-primitive.json#5":
            "§9.1 encodes empty string keys for empty arrays",
        "encode/arrays-tabular.json#6":
            "§7.2 quotes hash-leading string in tabular cell",
        "encode/objects-keyed.json#0":
            "§9.5 encodes objects of uniform objects in keyed tabular form",
        "encode/objects-keyed.json#1":
            "§9.5 encodes an eligible root object with a keyless keyed header",
        "encode/objects-keyed.json#11":
            "§10 emits a keyed header on the hyphen line when it is the first field of a list item",
        "encode/objects-keyed.json#2":
            "§9.5 collapses uniform nested object columns inside keyed headers",
        "encode/objects-keyed.json#3":
            "§9.5 orders fields by the first entry value's encounter order",
        "encode/objects-keyed.json#4":
            "§9.5 uses the active delimiter in keyed headers and entry-row cells",
        "encode/objects-keyed.json#5":
            "§9.5 quotes entry keys per key encoding",
        "encode/objects-keyed.json#6":
            "§9.5 quotes entry-row cells containing the active delimiter",
        "encode/objects.json#21":
            "§7.3 quotes non-ASCII key",
        "encode/objects.json#26":
            "§7.1 escapes U+0004 control character in key via \\uXXXX",
        "encode/objects.json#27":
            "§7.1 escapes U+001F control character in key via \\uXXXX",
        "encode/objects.json#33":
            "§7.2 quotes hash-leading string in object field value",
        "encode/primitives.json#13":
            "§7.1 encodes string with U+0004 control character via \\uXXXX",
        "encode/primitives.json#37":
            "§2 encodes repeating decimal with full precision",
        "encode/primitives.json#41":
            "§7.2 quotes leading-plus numeric-like string",
        "encode/primitives.json#42":
            "§7.2 quotes string equal to hash",
        "encode/primitives.json#43":
            "§7.2 quotes string starting with hash",
        "encode/whitespace.json#3":
            "§7.2 leaves non-ASCII whitespace unquoted",
    ]
}
