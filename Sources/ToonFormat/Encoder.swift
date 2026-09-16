import Foundation

/// An encoder that converts Swift values into TOON format.
///
/// This encoder conforms to the TOON (Token-Oriented Object Notation) specification version 3.0.
/// For more information, see https://github.com/toon-format/spec
public final class TOONEncoder {
    /// The number of spaces per indentation level.
    public var indent: Int = 2

    /// The delimiter character used to separate array values and tabular row cells.
    ///
    /// The delimiter determines how multiple values are separated in inline arrays
    /// and tabular data rows.
    ///
    /// Example with `.comma`:
    /// ```toon
    /// tags[3]: reading,gaming,coding
    /// ```
    ///
    /// Example with `.tab`:
    /// ```toon
    /// items[2	]{sku	name}:
    ///   A1	Widget
    ///   B2	Gadget
    /// ```
    ///
    /// Example with `.pipe`:
    /// ```toon
    /// items[2|]{sku|name}:
    ///   A1|Widget
    ///   B2|Gadget
    /// ```
    public enum Delimiter: String, CaseIterable, Hashable, Sendable {
        /// Comma separator (`,`).
        case comma = ","

        /// Tab separator (`\t`).
        case tab = "\t"

        /// Pipe separator (`|`).
        case pipe = "|"
    }

    /// The delimiter to use for array values and tabular rows.
    public var delimiter: Delimiter = .comma

    /// Strategy for encoding negative zero values.
    public enum NegativeZeroEncodingStrategy: Hashable, Sendable {
        /// Normalizes `-0.0` to `0`.
        case normalize

        /// Preserves `-0.0` as `-0`.
        case preserve
    }

    /// The strategy to use for encoding negative zero values.
    public var negativeZeroEncodingStrategy: NegativeZeroEncodingStrategy = .normalize

    /// Strategy for encoding non-conforming floating-point values.
    public enum NonConformingFloatEncodingStrategy: Hashable, Sendable {
        /// Encodes non-finite values as `null`.
        case null

        /// Throws an error on non-finite values.
        case `throw`

        /// Encodes non-finite values as string literals.
        case convertToString(positiveInfinity: String, negativeInfinity: String, nan: String)
    }

    /// The strategy to use for encoding non-conforming floating-point values.
    public var nonConformingFloatEncodingStrategy: NonConformingFloatEncodingStrategy = .null

    /// Key folding mode.
    public enum KeyFolding: Hashable, Sendable {
        /// No key folding.
        case disabled

        /// Safe key folding.
        ///
        /// Only folds when all segments are valid identifiers.
        case safe
    }

    /// Key folding mode for collapsing single-key object chains into dotted paths.
    ///
    /// When enabled, single-key nested objects like `{ a: { b: { c: 1 } } }`
    /// are collapsed into `a.b.c: 1`. Only applies when all segments are valid identifiers.
    ///
    /// Example with `.safe`:
    /// ```toon
    /// user.profile.name: John
    /// user.profile.age: 30
    /// ```
    public var keyFolding: KeyFolding = .disabled

    /// The maximum number of segments to include in a folded path when `keyFolding` is `.safe`.
    ///
    /// Controls how many nested single-key objects are collapsed into a dotted path.
    /// - Default is `Int.max` (unlimited folding depth).
    /// - Values less than 2 have no practical folding effect.
    ///
    /// Example with `flattenDepth = 2`:
    /// - Input: `{ a: { b: { c: { d: 1 } } } }`
    /// - Output: `a.b:` followed by nested `c:` and `d: 1`
    ///
    /// Example with `flattenDepth = Int.max` (default):
    /// - Input: `{ a: { b: { c: 1 } } }`
    /// - Output: `a.b.c: 1`
    public var flattenDepth: Int = .max

    /// Limits for encoding to prevent resource exhaustion.
    public struct EncodingLimits: Hashable, Sendable {
        /// Maximum nesting depth.
        public var maxDepth: Int

        /// Default limits suitable for most use cases.
        ///
        /// - `maxDepth`: 32 (prevents stack overflow from deep nesting)
        public static let `default` = EncodingLimits(maxDepth: 32)

        /// Encoding limits that impose no restrictions.
        ///
        /// - Warning: This configuration is unsafe for untrusted input
        ///   and should only be used with trusted data.
        public static let unlimited = EncodingLimits(maxDepth: .max)

        public init(maxDepth: Int) {
            self.maxDepth = maxDepth
        }
    }

    /// Limits for encoding to prevent resource exhaustion.
    ///
    /// Use this to protect against accidental or malicious deep nesting
    /// when encoding untrusted data.
    public var limits: EncodingLimits = .default

    /// Creates a new TOON encoder with default configuration.
    ///
    /// Default settings:
    /// - `indent`: 2 spaces
    /// - `delimiter`: `.comma`
    /// - `negativeZeroEncodingStrategy`: `.normalize`
    /// - `nonConformingFloatEncodingStrategy`: `.null`
    /// - `keyFolding`: `.disabled`
    /// - `flattenDepth`: `Int.max`
    /// - `limits`: `.default`
    public init() {}

    /// Encodes the given value into TOON format.
    ///
    /// - Parameter value: An `Encodable` value to convert to TOON format.
    /// - Returns: UTF-8 encoded data containing the TOON representation.
    /// - Throws: An error if encoding fails.
    ///
    /// This method handles special Foundation types (`Date`, `URL`, `Data`) as well as
    /// standard Swift types and custom `Encodable` types. Arrays of objects with consistent
    /// keys are automatically formatted as tabular data.
    public func encode<T: Encodable>(_ value: T) throws -> Data {
        // Handle special types before they encode themselves
        let mirror = Mirror(reflecting: value)
        let v: Value

        if mirror.subjectType == Date.self, let date = value as? Date {
            v = .date(date)
        } else if mirror.subjectType == URL.self, let url = value as? URL {
            v = .url(url)
        } else if mirror.subjectType == Data.self, let data = value as? Data {
            v = .data(data)
        } else {
            var userInfo = [CodingUserInfoKey: Any]()
            userInfo[.toonEncodingMaxDepth] = limits.maxDepth
            let encoder = Encoder(userInfo: userInfo)
            try value.encode(to: encoder)
            v = encoder.encodedValue
        }

        if case .throw = nonConformingFloatEncodingStrategy {
            try validateNonConformingFloats(in: v, codingPath: [])
        }

        var output: [String] = []
        encodeValue(v, output: &output, depth: 0)

        let result = output.joined(separator: "\n")
        return result.data(using: .utf8) ?? Data()
    }

    // MARK: - Encoding Entry Point

    private func encodeValue(_ value: Value, output: inout [String], depth: Int) {
        switch value {
        case .null, .bool, .int, .double, .string, .date, .url, .data:
            // Special case for root-level primitives
            if depth == 0 {
                if let encoded = encodePrimitive(value, delimiter: delimiter.rawValue, inObject: false) {
                    write(depth: depth, content: encoded, to: &output)
                }
            }

        case .array(let array):
            encodeArray(key: nil, array: array, output: &output, depth: depth)

        case .object(let values, let keyOrder):
            // At the root the keyed header carries no key (specification 9.5).
            if depth == 0, let header = detectKeyedTabularHeader(values, keyOrder: keyOrder) {
                encodeKeyedTabular(
                    key: nil,
                    values: values,
                    keyOrder: keyOrder,
                    header: header,
                    output: &output,
                    depth: depth
                )
            } else {
                encodeObject(values, keyOrder: keyOrder, output: &output, depth: depth)
            }
        }
    }

    // MARK: - Object Encoding

    private func encodeObject(
        _ values: [String: Value],
        keyOrder: [String],
        output: inout [String],
        depth: Int,
        allowFolding: Bool = true
    ) {
        for key in keyOrder {
            guard let value = values[key] else { continue }
            encodeKeyValuePair(
                key: key,
                value: value,
                output: &output,
                depth: depth,
                siblingKeys: keyOrder,
                allowFolding: allowFolding
            )
        }
    }

    /// Attempts to fold a key path by following single-key object chains.
    ///
    /// Returns the folded path, final value, and whether the depth limit was reached,
    /// or `nil` if folding is not safe.
    ///
    /// - Parameters:
    ///   - key: The starting key of the chain.
    ///   - value: The value associated with the key.
    ///   - siblingKeys: Other keys at the same object depth (for collision avoidance).
    private func tryFoldKeyPath(
        key: String,
        value: Value,
        siblingKeys: [String] = []
    ) -> (path: String, value: Value, hitDepthLimit: Bool)? {
        guard keyFolding == .safe else { return nil }

        // Values less than 2 have no practical folding effect
        guard flattenDepth >= 2 else { return nil }

        var pathComponents: [String] = [key]
        var currentValue = value
        var hitDepthLimit = false

        // Follow the chain of single-key objects, respecting flattenDepth limit
        while case .object(let nestedValues, let nestedKeyOrder) = currentValue,
            nestedKeyOrder.count == 1,
            let singleKey = nestedKeyOrder.first,
            let nextValue = nestedValues[singleKey]
        {
            // Stop if we've reached the flattenDepth limit
            guard pathComponents.count < flattenDepth else {
                hitDepthLimit = true
                break
            }

            // Validate that the key is a safe identifier
            guard singleKey.isValidIdentifierSegment else {
                break
            }

            pathComponents.append(singleKey)
            currentValue = nextValue
        }

        // Only fold if we found at least one nested level
        guard pathComponents.count > 1 else { return nil }

        // Validate all components are safe identifiers
        guard pathComponents.allSatisfy({ $0.isValidIdentifierSegment }) else {
            return nil
        }

        let foldedPath = pathComponents.joined(separator: ".")

        // Collision avoidance: folded key must not equal any existing sibling key
        if siblingKeys.contains(foldedPath) {
            return nil
        }

        return (path: foldedPath, value: currentValue, hitDepthLimit: hitDepthLimit)
    }

    private func encodeKeyValuePair(
        key: String,
        value: Value,
        output: inout [String],
        depth: Int,
        siblingKeys: [String] = [],
        allowFolding: Bool = true
    ) {
        // Try key folding if enabled and allowed
        if allowFolding,
            case let (path, value, hitDepthLimit)? = tryFoldKeyPath(key: key, value: value, siblingKeys: siblingKeys)
        {
            let encodedKey = encodeKey(path)

            switch value {
            case .null, .bool, .int, .double, .string, .date, .url, .data:
                if let encodedValue = encodePrimitive(value, delimiter: delimiter.rawValue, inObject: true) {
                    write(depth: depth, content: "\(encodedKey): \(encodedValue)", to: &output)
                }

            case .array(let array):
                encodeArray(key: path, array: array, output: &output, depth: depth)

            case .object(let values, let keyOrder):
                write(depth: depth, content: "\(encodedKey):", to: &output)
                if !keyOrder.isEmpty {
                    encodeObject(
                        values,
                        keyOrder: keyOrder,
                        output: &output,
                        depth: depth + 1,
                        allowFolding: !hitDepthLimit
                    )
                }
            }
            return
        }

        // Regular encoding without folding
        let encodedKey = encodeKey(key)

        switch value {
        case .null, .bool, .int, .double, .string, .date, .url, .data:
            if let encodedValue = encodePrimitive(value, delimiter: delimiter.rawValue, inObject: true) {
                write(depth: depth, content: "\(encodedKey): \(encodedValue)", to: &output)
            }

        case .array(let array):
            encodeArray(key: key, array: array, output: &output, depth: depth)

        case .object(let values, let keyOrder):
            if keyOrder.isEmpty {
                write(depth: depth, content: "\(encodedKey):", to: &output)
            } else if let header = detectKeyedTabularHeader(values, keyOrder: keyOrder) {
                // Specification 9.5 makes the keyed tabular form mandatory in
                // object-field position wherever detection succeeds.
                encodeKeyedTabular(
                    key: key,
                    values: values,
                    keyOrder: keyOrder,
                    header: header,
                    output: &output,
                    depth: depth
                )
            } else {
                write(depth: depth, content: "\(encodedKey):", to: &output)
                encodeObject(values, keyOrder: keyOrder, output: &output, depth: depth + 1)
            }
        }
    }

    private func encodeObjectAsListItem(
        values: [String: Value],
        keyOrder: [String],
        output: inout [String],
        depth: Int
    ) {
        if keyOrder.isEmpty {
            write(depth: depth, content: "-", to: &output)
            return
        }

        // First key-value on the same line as "- "
        let firstKey = keyOrder[0]
        let encodedKey = encodeKey(firstKey)
        let firstValue = values[firstKey]!

        switch firstValue {
        case .null, .bool, .int, .double, .string, .date, .url, .data:
            if let encodedValue = encodePrimitive(
                firstValue,
                delimiter: delimiter.rawValue,
                inObject: true
            ) {
                write(
                    depth: depth,
                    content: "- \(encodedKey): \(encodedValue)",
                    to: &output
                )
            }

        case .array(let array):
            if array.allSatisfy({ $0.isPrimitive }) {
                let formatted = formatInlineArray(values: array, key: firstKey)
                write(depth: depth, content: "- \(formatted)", to: &output)
            } else if array.allSatisfy({ $0.isObject }) {
                if let header = detectTabularHeader(array) {
                    let headerStr = formatHeader(
                        length: array.count,
                        key: firstKey,
                        fields: header,
                        delimiter: delimiter.rawValue
                    )
                    write(
                        depth: depth,
                        content: "- \(headerStr)",
                        to: &output
                    )
                    writeTabularRows(rows: array, header: header, output: &output, depth: depth + 1)
                } else {
                    write(
                        depth: depth,
                        content: "- \(encodedKey)[\(array.count)]:",
                        to: &output
                    )
                    for item in array {
                        if let (values, keyOrder) = item.objectValue {
                            encodeObjectAsListItem(
                                values: values,
                                keyOrder: keyOrder,
                                output: &output,
                                depth: depth + 1
                            )
                        }
                    }
                }
            } else {
                write(
                    depth: depth,
                    content: "- \(encodedKey)[\(array.count)]:",
                    to: &output
                )
                for item in array {
                    switch item {
                    case .null, .bool, .int, .double, .string, .date, .url, .data:
                        if let encoded = encodePrimitive(
                            item,
                            delimiter: delimiter.rawValue,
                            inObject: false
                        ) {
                            write(
                                depth: depth + 1,
                                content: "- \(encoded)",
                                to: &output
                            )
                        }
                    case .array(let innerArray):
                        if innerArray.allSatisfy({ $0.isPrimitive }) {
                            let inline = formatInlineArray(values: innerArray, key: nil, inListItem: true)
                            write(
                                depth: depth + 1,
                                content: "- \(inline)",
                                to: &output
                            )
                        }
                    case .object(let innerValues, let innerKeyOrder):
                        encodeObjectAsListItem(
                            values: innerValues,
                            keyOrder: innerKeyOrder,
                            output: &output,
                            depth: depth + 1
                        )
                    }
                }
            }

        case .object(let nestedValues, let nestedKeyOrder):
            if nestedKeyOrder.isEmpty {
                write(depth: depth, content: "- \(encodedKey):", to: &output)
            } else {
                write(depth: depth, content: "- \(encodedKey):", to: &output)
                encodeObject(nestedValues, keyOrder: nestedKeyOrder, output: &output, depth: depth + 2)
            }
        }

        // Remaining keys on indented lines
        for i in 1 ..< keyOrder.count {
            let key = keyOrder[i]
            guard let value = values[key] else { continue }
            encodeKeyValuePair(key: key, value: value, output: &output, depth: depth + 1, siblingKeys: keyOrder)
        }
    }

    // MARK: - Array Encoding

    private func encodeArray(key: String?, array: [Value], output: inout [String], depth: Int) {
        if array.isEmpty {
            let header = formatHeader(
                length: 0,
                key: key,
                delimiter: delimiter.rawValue
            )
            write(depth: depth, content: header, to: &output)
            return
        }

        // Primitive array
        if array.allSatisfy({ $0.isPrimitive }) {
            encodeInlinePrimitiveArray(key: key, values: array, output: &output, depth: depth)
            return
        }

        // Array of arrays (all primitives)
        if array.allSatisfy({ $0.isArray }) {
            let allPrimitiveArrays = array.allSatisfy { arrayValue in
                guard let innerArray = arrayValue.arrayValue else { return false }
                return innerArray.allSatisfy { $0.isPrimitive }
            }
            if allPrimitiveArrays {
                encodeArrayOfArraysAsListItems(
                    key: key,
                    values: array,
                    output: &output,
                    depth: depth
                )
                return
            }
        }

        // Array of objects
        if array.allSatisfy({ $0.isObject }) {
            if let header = detectTabularHeader(array) {
                encodeArrayOfObjectsAsTabular(
                    key: key,
                    rows: array,
                    header: header,
                    output: &output,
                    depth: depth
                )
            } else {
                encodeMixedArrayAsListItems(key: key, items: array, output: &output, depth: depth)
            }
            return
        }

        // Mixed array: fallback to expanded format
        encodeMixedArrayAsListItems(key: key, items: array, output: &output, depth: depth)
    }

    private func encodeInlinePrimitiveArray(
        key: String?,
        values: [Value],
        output: inout [String],
        depth: Int
    ) {
        let formatted = formatInlineArray(values: values, key: key)
        write(depth: depth, content: formatted, to: &output)
    }

    private func encodeArrayOfArraysAsListItems(
        key: String?,
        values: [Value],
        output: inout [String],
        depth: Int
    ) {
        let header = formatHeader(
            length: values.count,
            key: key,
            delimiter: delimiter.rawValue
        )
        write(depth: depth, content: header, to: &output)

        for arrayValue in values {
            guard let innerArray = arrayValue.arrayValue else { continue }
            let inline = formatInlineArray(values: innerArray, key: nil, inListItem: true)
            write(depth: depth + 1, content: "- \(inline)", to: &output)
        }
    }

    private func encodeArrayOfObjectsAsTabular(
        key: String?,
        rows: [Value],
        header: [FieldNode],
        output: inout [String],
        depth: Int
    ) {
        let headerStr = formatHeader(
            length: rows.count,
            key: key,
            fields: header,
            delimiter: delimiter.rawValue
        )
        write(depth: depth, content: headerStr, to: &output)

        writeTabularRows(rows: rows, header: header, output: &output, depth: depth + 1)
    }

    private func encodeMixedArrayAsListItems(
        key: String?,
        items: [Value],
        output: inout [String],
        depth: Int
    ) {
        let header = formatHeader(
            length: items.count,
            key: key,
            delimiter: delimiter.rawValue
        )
        write(depth: depth, content: header, to: &output)

        for item in items {
            switch item {
            case .null, .bool, .int, .double, .string, .date, .url, .data:
                if let encoded = encodePrimitive(item, delimiter: delimiter.rawValue, inObject: false) {
                    write(depth: depth + 1, content: "- \(encoded)", to: &output)
                }

            case .array(let array):
                if array.allSatisfy({ $0.isPrimitive }) {
                    let inline = formatInlineArray(values: array, key: nil, inListItem: true)
                    write(
                        depth: depth + 1,
                        content: "- \(inline)",
                        to: &output
                    )
                }

            case .object(let values, let keyOrder):
                encodeObjectAsListItem(
                    values: values,
                    keyOrder: keyOrder,
                    output: &output,
                    depth: depth + 1
                )
            }
        }
    }

    // MARK: - Tabular Encoding

    /// The field list for an array of uniform objects, or `nil` when the
    /// array does not take the tabular form.
    ///
    /// TOON specification 9.3 requires every column - the values at one key
    /// across the rows - to be uniform-primitive or nested-uniform. A
    /// nested-uniform column collapses into a nested field group, and the
    /// rule applies again inside it, with no depth cap.
    ///
    /// An array that holds an empty object never takes the tabular form,
    /// because an empty object has no column to describe.
    private func detectTabularHeader(_ rows: [Value]) -> [FieldNode]? {
        guard let (_, keyOrder) = rows.first?.objectValue, !keyOrder.isEmpty else {
            return nil
        }

        // Every row is an object with the same set of keys. The order inside a
        // row may differ; the header order wins, per section 9.3.
        for row in rows {
            guard let (values, order) = row.objectValue, order.count == keyOrder.count else {
                return nil
            }
            for key in keyOrder where values[key] == nil {
                return nil
            }
        }

        var fields: [FieldNode] = []
        for key in keyOrder {
            let column = rows.compactMap { $0.objectValue?.values[key] }
            if column.allSatisfy({ $0.isPrimitive }) {
                fields.append(FieldNode(name: key))
            } else if let children = detectTabularHeader(column) {
                fields.append(FieldNode(name: key, children: children))
            } else {
                return nil
            }
        }

        return fields
    }

    /// The field list for an object that takes the keyed tabular form, or
    /// `nil` when it does not.
    ///
    /// TOON specification 9.5 requires at least two entries, and every entry
    /// value to be a non-empty object. The columns then follow the rules of
    /// section 9.3, so the detection reuses ``detectTabularHeader``.
    private func detectKeyedTabularHeader(
        _ values: [String: Value],
        keyOrder: [String]
    ) -> [FieldNode]? {
        guard keyOrder.count >= 2 else { return nil }

        let entries = keyOrder.compactMap { values[$0] }
        guard entries.count == keyOrder.count, entries.allSatisfy({ $0.isObject }) else {
            return nil
        }

        return detectTabularHeader(entries)
    }

    /// Writes a keyed tabular scope: the header, then one row per entry.
    private func encodeKeyedTabular(
        key: String?,
        values: [String: Value],
        keyOrder: [String],
        header: [FieldNode],
        output: inout [String],
        depth: Int
    ) {
        var headerStr = ""
        if let key = key {
            headerStr += encodeKey(key)
        }
        let delimiterSuffix = delimiter.rawValue != "," ? delimiter.rawValue : ""
        headerStr += "[\(keyOrder.count):\(delimiterSuffix)]"
        headerStr += "{\(formatFieldList(header, delimiter: delimiter.rawValue))}:"
        write(depth: depth, content: headerStr, to: &output)

        for entryKey in keyOrder {
            guard let entry = values[entryKey] else { continue }
            let cells = collectRowLeaves(entry, fields: header)
            let row = joinEncodedValues(cells, delimiter: delimiter.rawValue)
            write(depth: depth + 1, content: "\(encodeKey(entryKey)): \(row)", to: &output)
        }
    }

    /// The cells of one row, in the depth-first order of the leaves.
    private func collectRowLeaves(_ row: Value, fields: [FieldNode]) -> [Value] {
        guard let (values, _) = row.objectValue else { return [] }

        var cells: [Value] = []
        for field in fields {
            guard let value = values[field.name] else { continue }
            if let children = field.children {
                cells.append(contentsOf: collectRowLeaves(value, fields: children))
            } else {
                cells.append(value)
            }
        }
        return cells
    }

    private func writeTabularRows(
        rows: [Value],
        header: [FieldNode],
        output: inout [String],
        depth: Int
    ) {
        for row in rows {
            let cells = collectRowLeaves(row, fields: header)
            let joinedValue = joinEncodedValues(cells, delimiter: delimiter.rawValue)
            write(depth: depth, content: joinedValue, to: &output)
        }
    }

    // MARK: - Primitive Encoding

    private func encodePrimitive(_ value: Value, delimiter: String = ",", inObject: Bool = false)
        -> String?
    {
        switch value {
        case .null:
            return "null"
        case .bool(let boolValue):
            return String(boolValue)
        case .int(let intValue):
            return String(intValue)
        case .double(let doubleValue):
            // Check for non-finite numbers first
            if !doubleValue.isFinite {
                switch nonConformingFloatEncodingStrategy {
                case .null:
                    return "null"
                case .throw:
                    preconditionFailure(
                        "Encountered non-finite Double while nonConformingFloatEncodingStrategy is .throw. "
                            + "This path should be unreachable because validation occurs earlier."
                    )
                case .convertToString(let positiveInfinity, let negativeInfinity, let nan):
                    let literal: String
                    if doubleValue.isNaN {
                        literal = nan
                    } else if doubleValue.sign == .minus {
                        literal = negativeInfinity
                    } else {
                        literal = positiveInfinity
                    }
                    return encodeStringLiteral(literal, delimiter: delimiter)
                }
            }

            // Format numbers in decimal form without scientific notation
            if doubleValue == 0.0 && doubleValue.sign == .minus {
                switch negativeZeroEncodingStrategy {
                case .normalize:
                    return "0"
                case .preserve:
                    return "-0"
                }
            }

            if let formatted = numberFormatter.string(from: NSNumber(value: doubleValue)) {
                return formatted
            }

            // Fallback to string representation
            return String(doubleValue)
        case .string(let stringValue):
            return encodeStringLiteral(stringValue, delimiter: delimiter)
        case .date(let date):
            let iso8601 = ISO8601DateFormatter()
            iso8601.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let dateString = iso8601.string(from: date)
            return encodeStringLiteral(dateString, delimiter: delimiter)
        case .url(let url):
            return encodeStringLiteral(url.absoluteString, delimiter: delimiter)
        case .data(let data):
            let base64 = data.base64EncodedString()
            return encodeStringLiteral(base64, delimiter: delimiter)
        case .array, .object:
            return nil
        }
    }

    private func validateNonConformingFloats(
        in value: Value,
        codingPath: [CodingKey]
    ) throws {
        struct ValidationCodingKey: CodingKey {
            let stringValue: String
            let intValue: Int?

            init(stringValue: String) {
                self.stringValue = stringValue
                self.intValue = nil
            }

            init(intValue: Int) {
                self.stringValue = String(intValue)
                self.intValue = intValue
            }
        }

        switch value {
        case .double(let doubleValue):
            guard doubleValue.isFinite else {
                throw EncodingError.invalidValue(
                    doubleValue,
                    EncodingError.Context(
                        codingPath: codingPath,
                        debugDescription: "Non-conforming float value: \(doubleValue)"
                    )
                )
            }
        case .array(let array):
            for (index, item) in array.enumerated() {
                var nextPath = codingPath
                nextPath.append(ValidationCodingKey(intValue: index))
                try validateNonConformingFloats(in: item, codingPath: nextPath)
            }
        case .object(let values, let keyOrder):
            for key in keyOrder {
                guard let nestedValue = values[key] else { continue }
                var nextPath = codingPath
                nextPath.append(ValidationCodingKey(stringValue: key))
                try validateNonConformingFloats(in: nestedValue, codingPath: nextPath)
            }
        case .null, .bool, .int, .string, .date, .url, .data:
            break
        }
    }

    private func encodeStringLiteral(_ value: String, delimiter: String = ",")
        -> String
    {
        if value.isSafeUnquoted(delimiter: delimiter) {
            return value
        }

        return "\"\(value.escaped)\""
    }

    private func encodeKey(_ key: String) -> String {
        if key.isValidUnquotedKey {
            return key
        }

        return "\"\(key.escaped)\""
    }

    // MARK: - Formatting Helpers

    /// Renders an inline array.
    ///
    /// - Parameter inListItem: `true` when the array is an inner array on a
    ///   hyphen line. Specification 9.2 keeps the `[0]:` form there, while
    ///   section 9.1 gives every other position the canonical empty form.
    private func formatInlineArray(
        values: [Value],
        key: String?,
        inListItem: Bool = false
    ) -> String {
        // Specification 9.1 gives an empty array the canonical form `key: []`
        // at a field and `[]` at the root. The old `key[0]:` form is still
        // accepted on decode, but an encoder must not emit it.
        if values.isEmpty, !inListItem {
            guard let key = key else { return "[]" }
            return "\(encodeKey(key)): []"
        }

        let header = formatHeader(
            length: values.count,
            key: key,
            delimiter: delimiter.rawValue
        )

        if values.isEmpty {
            return header
        }

        let joinedValue = joinEncodedValues(values, delimiter: delimiter.rawValue)
        return "\(header) \(joinedValue)"
    }

    /// Renders a field list, and recurses into a nested field group.
    ///
    /// A name follows the key encoding of specification 7.3 at every level.
    private func formatFieldList(_ fields: [FieldNode], delimiter: String) -> String {
        fields.map { field in
            guard let children = field.children else { return encodeKey(field.name) }
            let inner = formatFieldList(children, delimiter: delimiter)
            return "\(encodeKey(field.name)){\(inner)}"
        }
        .joined(separator: delimiter)
    }

    private func formatHeader(
        length: Int,
        key: String? = nil,
        fields: [FieldNode]? = nil,
        delimiter: String = ","
    ) -> String {
        var header = ""

        if let key = key {
            header += encodeKey(key)
        }

        // Only include delimiter if it's not the default (comma)
        let delimiterSuffix = delimiter != "," ? delimiter : ""
        header += "[\(length)\(delimiterSuffix)]"

        if let fields = fields {
            header += "{\(formatFieldList(fields, delimiter: delimiter))}"
        }

        header += ":"

        return header
    }

    private func joinEncodedValues(_ values: [Value], delimiter: String = ",")
        -> String
    {
        return values.compactMap { encodePrimitive($0, delimiter: delimiter) }.joined(separator: delimiter)
    }

    private func write(depth: Int, content: String, to output: inout [String]) {
        let indentation = String(repeating: String(repeating: " ", count: indent), count: depth)
        output.append(indentation + content)
    }
}

fileprivate extension CodingUserInfoKey {
    static let toonEncodingMaxDepth = CodingUserInfoKey(rawValue: "toonEncodingMaxDepth")!
}

// MARK: - Internal Encoder

extension TOONEncoder {
    /// Internal encoder implementation that conforms to the `Encoder` protocol.
    private final class Encoder: Swift.Encoder {
        let codingPath: [any Swift.CodingKey]
        let userInfo: [CodingUserInfoKey: Any]

        fileprivate var storage: [Value]

        init(codingPath: [any Swift.CodingKey] = [], userInfo: [CodingUserInfoKey: Any] = [:]) {
            self.codingPath = codingPath
            self.userInfo = userInfo
            self.storage = []
        }

        func container<Key>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key>
        where Key: Swift.CodingKey {
            let container = KeyedContainer<Key>(encoder: self, codingPath: codingPath)
            return KeyedEncodingContainer(container)
        }

        func unkeyedContainer() -> UnkeyedEncodingContainer {
            return UnkeyedContainer(encoder: self, codingPath: codingPath)
        }

        func singleValueContainer() -> SingleValueEncodingContainer {
            return SingleValueContainer(encoder: self, codingPath: codingPath)
        }

        var canEncodeNewValue: Bool {
            return storage.count == 0
        }

        func encode<T: Encodable>(_ value: T) throws {
            try value.encode(to: self)
        }

        var encodedValue: Value {
            if storage.count == 0 {
                // If no values in storage, return null as a fallback
                return .null
            }
            return storage.removeLast()
        }
    }
}

// MARK: - Keyed Encoding Container

extension TOONEncoder {
    private final class KeyedContainer<Key: Swift.CodingKey>: KeyedEncodingContainerProtocol {
        let encoder: Encoder
        let codingPath: [any Swift.CodingKey]

        private var container: [String: Value] = [:]

        private var keyOrder: [String] = []

        /// Heuristic: Swift's `Dictionary` encoding uses an internal
        /// `DictionaryCodingKey` type.
        ///
        /// We detect this by checking whether `String(reflecting: Key.self)`
        /// is in the `Swift` module and contains the substring `"DictionaryCodingKey"`.
        /// If so, we treat the container as a dictionary and sort its keys lexicographically.
        ///
        /// This relies on Swift's internal implementation details
        /// and is therefore inherently fragile.
        /// If the type name changes in a future Swift version,
        /// this detection will stop working and dictionary key ordering may become
        /// non-deterministic again without a compile-time error.
        private let isDictionaryCodingKey: Bool = {
            let reflected = String(reflecting: Key.self)
            return reflected.hasPrefix("Swift.") && reflected.contains("DictionaryCodingKey")
        }()
        private var didFinishEncoding = false

        private var finalKeyOrder: [String] {
            isDictionaryCodingKey ? container.keys.sorted() : keyOrder
        }

        init(encoder: Encoder, codingPath: [CodingKey]) {
            self.encoder = encoder
            self.codingPath = codingPath
        }

        private func trackKey(_ key: String) {
            guard !isDictionaryCodingKey else { return }
            if !keyOrder.contains(key) {
                keyOrder.append(key)
            }
        }

        func encodeNil(forKey key: Key) throws {
            trackKey(key.stringValue)
            container[key.stringValue] = .null
        }

        func encode(_ value: Bool, forKey key: Key) throws {
            trackKey(key.stringValue)
            container[key.stringValue] = .bool(value)
        }

        func encode(_ value: String, forKey key: Key) throws {
            trackKey(key.stringValue)
            container[key.stringValue] = .string(value)
        }

        func encode(_ value: Double, forKey key: Key) throws {
            trackKey(key.stringValue)
            container[key.stringValue] = .double(value)
        }

        func encode(_ value: Float, forKey key: Key) throws {
            trackKey(key.stringValue)
            container[key.stringValue] = .double(Double(value))
        }

        func encode(_ value: Int, forKey key: Key) throws {
            trackKey(key.stringValue)
            container[key.stringValue] = .int(Int64(value))
        }

        func encode(_ value: Int8, forKey key: Key) throws {
            trackKey(key.stringValue)
            container[key.stringValue] = .int(Int64(value))
        }

        func encode(_ value: Int16, forKey key: Key) throws {
            trackKey(key.stringValue)
            container[key.stringValue] = .int(Int64(value))
        }

        func encode(_ value: Int32, forKey key: Key) throws {
            trackKey(key.stringValue)
            container[key.stringValue] = .int(Int64(value))
        }

        func encode(_ value: Int64, forKey key: Key) throws {
            trackKey(key.stringValue)
            container[key.stringValue] = .int(value)
        }

        func encode(_ value: UInt, forKey key: Key) throws {
            trackKey(key.stringValue)
            container[key.stringValue] = .int(Int64(value))
        }

        func encode(_ value: UInt8, forKey key: Key) throws {
            trackKey(key.stringValue)
            container[key.stringValue] = .int(Int64(value))
        }

        func encode(_ value: UInt16, forKey key: Key) throws {
            trackKey(key.stringValue)
            container[key.stringValue] = .int(Int64(value))
        }

        func encode(_ value: UInt32, forKey key: Key) throws {
            trackKey(key.stringValue)
            container[key.stringValue] = .int(Int64(value))
        }

        func encode(_ value: UInt64, forKey key: Key) throws {
            trackKey(key.stringValue)
            if value <= Int64.max {
                container[key.stringValue] = .int(Int64(value))
            } else {
                container[key.stringValue] = .string(String(value))
            }
        }

        func encode<T: Encodable>(_ value: T, forKey key: Key) throws {
            if let limit = encoder.userInfo[.toonEncodingMaxDepth] as? Int, encoder.codingPath.count > limit {
                throw EncodingError.invalidValue(
                    value,
                    EncodingError.Context(
                        codingPath: codingPath + [key],
                        debugDescription: "Recursion limit of \(limit) exceeded"
                    )
                )
            }
            trackKey(key.stringValue)

            // Handle special types by checking the mirror of the value
            // We need to use the Mirror because Date, URL, and Data conform to Codable
            // and would otherwise encode themselves using their default implementations

            let mirror = Mirror(reflecting: value)
            if mirror.subjectType == Date.self, let date = value as? Date {
                container[key.stringValue] = .date(date)
                return
            }

            if mirror.subjectType == URL.self, let url = value as? URL {
                container[key.stringValue] = .url(url)
                return
            }

            if mirror.subjectType == Data.self, let data = value as? Data {
                container[key.stringValue] = .data(data)
                return
            }

            let nestedEncoder = Encoder(
                codingPath: codingPath + [key],
                userInfo: encoder.userInfo
            )
            try value.encode(to: nestedEncoder)
            container[key.stringValue] = nestedEncoder.encodedValue
        }

        func encodeIfPresent(_ value: Bool?, forKey key: Key) throws {
            guard let value = value else {
                try encodeNil(forKey: key)
                return
            }
            try encode(value, forKey: key)
        }

        func encodeIfPresent(_ value: String?, forKey key: Key) throws {
            guard let value = value else {
                try encodeNil(forKey: key)
                return
            }
            try encode(value, forKey: key)
        }

        func encodeIfPresent(_ value: Double?, forKey key: Key) throws {
            guard let value = value else {
                try encodeNil(forKey: key)
                return
            }
            try encode(value, forKey: key)
        }

        func encodeIfPresent(_ value: Float?, forKey key: Key) throws {
            guard let value = value else {
                try encodeNil(forKey: key)
                return
            }
            try encode(value, forKey: key)
        }

        func encodeIfPresent(_ value: Int?, forKey key: Key) throws {
            guard let value = value else {
                try encodeNil(forKey: key)
                return
            }
            try encode(value, forKey: key)
        }

        func encodeIfPresent(_ value: Int8?, forKey key: Key) throws {
            guard let value = value else {
                try encodeNil(forKey: key)
                return
            }
            try encode(value, forKey: key)
        }

        func encodeIfPresent(_ value: Int16?, forKey key: Key) throws {
            guard let value = value else {
                try encodeNil(forKey: key)
                return
            }
            try encode(value, forKey: key)
        }

        func encodeIfPresent(_ value: Int32?, forKey key: Key) throws {
            guard let value = value else {
                try encodeNil(forKey: key)
                return
            }
            try encode(value, forKey: key)
        }

        func encodeIfPresent(_ value: Int64?, forKey key: Key) throws {
            guard let value = value else {
                try encodeNil(forKey: key)
                return
            }
            try encode(value, forKey: key)
        }

        func encodeIfPresent(_ value: UInt?, forKey key: Key) throws {
            guard let value = value else {
                try encodeNil(forKey: key)
                return
            }
            try encode(value, forKey: key)
        }

        func encodeIfPresent(_ value: UInt8?, forKey key: Key) throws {
            guard let value = value else {
                try encodeNil(forKey: key)
                return
            }
            try encode(value, forKey: key)
        }

        func encodeIfPresent(_ value: UInt16?, forKey key: Key) throws {
            guard let value = value else {
                try encodeNil(forKey: key)
                return
            }
            try encode(value, forKey: key)
        }

        func encodeIfPresent(_ value: UInt32?, forKey key: Key) throws {
            guard let value = value else {
                try encodeNil(forKey: key)
                return
            }
            try encode(value, forKey: key)
        }

        func encodeIfPresent(_ value: UInt64?, forKey key: Key) throws {
            guard let value = value else {
                try encodeNil(forKey: key)
                return
            }
            try encode(value, forKey: key)
        }

        func encodeIfPresent<T: Encodable>(_ value: T?, forKey key: Key) throws {
            guard let value = value else {
                try encodeNil(forKey: key)
                return
            }
            try encode(value, forKey: key)
        }

        func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type, forKey key: Key)
            -> KeyedEncodingContainer<NestedKey> where NestedKey: Swift.CodingKey
        {
            let nestedEncoder = Encoder(
                codingPath: codingPath + [key],
                userInfo: encoder.userInfo
            )
            let container = KeyedContainer<NestedKey>(
                encoder: nestedEncoder,
                codingPath: nestedEncoder.codingPath
            )
            return KeyedEncodingContainer(container)
        }

        func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer {
            let nestedEncoder = Encoder(
                codingPath: codingPath + [key],
                userInfo: encoder.userInfo
            )
            return UnkeyedContainer(
                encoder: nestedEncoder,
                codingPath: nestedEncoder.codingPath
            )
        }

        func superEncoder() -> Swift.Encoder {
            return encoder
        }

        func superEncoder(forKey key: Key) -> Swift.Encoder {
            return encoder
        }

        func finishEncoding() {
            guard !didFinishEncoding else { return }
            didFinishEncoding = true
            encoder.storage.append(.object(container, keyOrder: finalKeyOrder))
        }

        deinit {
            // Ensure the container is finished when it goes out of scope
            finishEncoding()
        }
    }
}

// MARK: - Unkeyed Encoding Container

extension TOONEncoder {
    private final class UnkeyedContainer: UnkeyedEncodingContainer {
        let encoder: Encoder
        let codingPath: [any Swift.CodingKey]

        private var container: [Value] = []

        init(encoder: Encoder, codingPath: [any Swift.CodingKey]) {
            self.encoder = encoder
            self.codingPath = codingPath
        }

        var count: Int {
            return container.count
        }

        func encodeNil() throws {
            container.append(.null)
        }

        func encode(_ value: Bool) throws {
            container.append(.bool(value))
        }

        func encode(_ value: String) throws {
            container.append(.string(value))
        }

        func encode(_ value: Double) throws {
            container.append(.double(value))
        }

        func encode(_ value: Float) throws {
            container.append(.double(Double(value)))
        }

        func encode(_ value: Int) throws {
            container.append(.int(Int64(value)))
        }

        func encode(_ value: Int8) throws {
            container.append(.int(Int64(value)))
        }

        func encode(_ value: Int16) throws {
            container.append(.int(Int64(value)))
        }

        func encode(_ value: Int32) throws {
            container.append(.int(Int64(value)))
        }

        func encode(_ value: Int64) throws {
            container.append(.int(value))
        }

        func encode(_ value: UInt) throws {
            container.append(.int(Int64(value)))
        }

        func encode(_ value: UInt8) throws {
            container.append(.int(Int64(value)))
        }

        func encode(_ value: UInt16) throws {
            container.append(.int(Int64(value)))
        }

        func encode(_ value: UInt32) throws {
            container.append(.int(Int64(value)))
        }

        func encode(_ value: UInt64) throws {
            if value <= Int64.max {
                container.append(.int(Int64(value)))
            } else {
                container.append(.string(String(value)))
            }
        }

        func encode<T: Encodable>(_ value: T) throws {
            if let limit = encoder.userInfo[.toonEncodingMaxDepth] as? Int, encoder.codingPath.count > limit {
                throw EncodingError.invalidValue(
                    value,
                    EncodingError.Context(
                        codingPath: codingPath + [IndexedCodingKey(intValue: count)],
                        debugDescription: "Recursion limit of \(limit) exceeded"
                    )
                )
            }
            // Handle special types
            let mirror = Mirror(reflecting: value)
            if mirror.subjectType == Date.self, let date = value as? Date {
                container.append(.date(date))
                return
            }

            if mirror.subjectType == URL.self, let url = value as? URL {
                container.append(.url(url))
                return
            }

            if mirror.subjectType == Data.self, let data = value as? Data {
                container.append(.data(data))
                return
            }

            let nestedEncoder = Encoder(
                codingPath: codingPath + [IndexedCodingKey(intValue: count)],
                userInfo: encoder.userInfo
            )
            try value.encode(to: nestedEncoder)
            container.append(nestedEncoder.encodedValue)
        }

        func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type) -> KeyedEncodingContainer<
            NestedKey
        > where NestedKey: Swift.CodingKey {
            let nestedEncoder = Encoder(
                codingPath: codingPath + [IndexedCodingKey(intValue: count)],
                userInfo: encoder.userInfo
            )
            let container = KeyedContainer<NestedKey>(
                encoder: nestedEncoder,
                codingPath: nestedEncoder.codingPath
            )
            return KeyedEncodingContainer(container)
        }

        func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
            let nestedEncoder = Encoder(
                codingPath: codingPath + [IndexedCodingKey(intValue: count)],
                userInfo: encoder.userInfo
            )
            return UnkeyedContainer(
                encoder: nestedEncoder,
                codingPath: nestedEncoder.codingPath
            )
        }

        func superEncoder() -> Swift.Encoder {
            return encoder
        }

        func finishEncoding() {
            encoder.storage.append(.array(container))
        }

        deinit {
            // Ensure the container is finished when it goes out of scope
            encoder.storage.append(.array(container))
        }
    }
}

// MARK: - Single Value Encoding Container

extension TOONEncoder {
    private final class SingleValueContainer: SingleValueEncodingContainer {
        let encoder: Encoder
        let codingPath: [any Swift.CodingKey]

        init(encoder: Encoder, codingPath: [any Swift.CodingKey]) {
            self.encoder = encoder
            self.codingPath = codingPath
        }

        func encodeNil() throws {
            encoder.storage.append(.null)
        }

        func encode(_ value: Bool) throws {
            encoder.storage.append(.bool(value))
        }

        func encode(_ value: String) throws {
            encoder.storage.append(.string(value))
        }

        func encode(_ value: Double) throws {
            encoder.storage.append(.double(value))
        }

        func encode(_ value: Float) throws {
            encoder.storage.append(.double(Double(value)))
        }

        func encode(_ value: Int) throws {
            encoder.storage.append(.int(Int64(value)))
        }

        func encode(_ value: Int8) throws {
            encoder.storage.append(.int(Int64(value)))
        }

        func encode(_ value: Int16) throws {
            encoder.storage.append(.int(Int64(value)))
        }

        func encode(_ value: Int32) throws {
            encoder.storage.append(.int(Int64(value)))
        }

        func encode(_ value: Int64) throws {
            encoder.storage.append(.int(value))
        }

        func encode(_ value: UInt) throws {
            encoder.storage.append(.int(Int64(value)))
        }

        func encode(_ value: UInt8) throws {
            encoder.storage.append(.int(Int64(value)))
        }

        func encode(_ value: UInt16) throws {
            encoder.storage.append(.int(Int64(value)))
        }

        func encode(_ value: UInt32) throws {
            encoder.storage.append(.int(Int64(value)))
        }

        func encode(_ value: UInt64) throws {
            if value <= Int64.max {
                encoder.storage.append(.int(Int64(value)))
            } else {
                encoder.storage.append(.string(String(value)))
            }
        }

        func encode<T: Encodable>(_ value: T) throws {
            if let limit = encoder.userInfo[.toonEncodingMaxDepth] as? Int, encoder.codingPath.count > limit {
                throw EncodingError.invalidValue(
                    value,
                    EncodingError.Context(
                        codingPath: codingPath,
                        debugDescription: "Recursion limit of \(limit) exceeded"
                    )
                )
            }
            // Handle special types
            let mirror = Mirror(reflecting: value)
            if mirror.subjectType == Date.self, let date = value as? Date {
                encoder.storage.append(.date(date))
                return
            }

            if mirror.subjectType == URL.self, let url = value as? URL {
                encoder.storage.append(.url(url))
                return
            }

            if mirror.subjectType == Data.self, let data = value as? Data {
                encoder.storage.append(.data(data))
                return
            }

            let nestedEncoder = Encoder(codingPath: codingPath, userInfo: encoder.userInfo)
            try value.encode(to: nestedEncoder)
            encoder.storage.append(nestedEncoder.encodedValue)
        }

        deinit {
            // Single value containers don't need finishEncoding, they push values directly
        }
    }
}

// MARK: - Number Formatter

// Shared number formatter that's used to avoid scientific notation
// and format numbers in canonical decimal form (no trailing zeros)
private let numberFormatter: NumberFormatter = {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.usesGroupingSeparator = false
    formatter.maximumFractionDigits = 15
    formatter.minimumFractionDigits = 0  // Prevents trailing zeros
    formatter.locale = Locale(identifier: "en_US_POSIX")
    return formatter
}()

// MARK: - String Extensions

private extension String {
    /// Escapes a string for a quoted span, per TOON specification 7.1.
    ///
    /// The table has five short forms. Every other character in U+0000 through
    /// U+001F takes the `\uXXXX` form, which the specification requires.
    var escaped: String {
        var result = String.UnicodeScalarView()
        for scalar in unicodeScalars {
            switch scalar {
            case "\\": result.append(contentsOf: "\\\\".unicodeScalars)
            case "\"": result.append(contentsOf: "\\\"".unicodeScalars)
            case "\n": result.append(contentsOf: "\\n".unicodeScalars)
            case "\r": result.append(contentsOf: "\\r".unicodeScalars)
            case "\t": result.append(contentsOf: "\\t".unicodeScalars)
            default:
                if scalar.value <= 0x1F {
                    let hex = String(format: "%04X", scalar.value)
                    result.append(contentsOf: "\\u\(hex)".unicodeScalars)
                } else {
                    result.append(scalar)
                }
            }
        }
        return String(result)
    }

    /// Whether the string matches `^[+-]?[0-9]+(\.[0-9]+)?(e[+-]?[0-9]+)?$`
    /// with ASCII digits, per specification 7.2.
    ///
    /// This is wider than the decoder grammar of section 4: it also covers
    /// `+1` and `05`, which decode as strings. An encoder quotes them so that
    /// the value cannot read as a number.
    var isNumericLike: Bool {
        let scalars = Array(unicodeScalars)
        var index = 0

        if index < scalars.count, scalars[index] == "+" || scalars[index] == "-" {
            index += 1
        }

        let integerStart = index
        while index < scalars.count, scalars[index].isASCIIDigit {
            index += 1
        }
        guard index > integerStart else { return false }

        if index < scalars.count, scalars[index] == "." {
            index += 1
            let fractionStart = index
            while index < scalars.count, scalars[index].isASCIIDigit {
                index += 1
            }
            guard index > fractionStart else { return false }
        }

        if index < scalars.count, scalars[index] == "e" || scalars[index] == "E" {
            index += 1
            if index < scalars.count, scalars[index] == "+" || scalars[index] == "-" {
                index += 1
            }
            let exponentStart = index
            while index < scalars.count, scalars[index].isASCIIDigit {
                index += 1
            }
            guard index > exponentStart else { return false }
        }

        return index == scalars.count
    }

    /// Whether the string starts or ends with U+0020 or U+0009.
    ///
    /// Specification 7.2 names exactly those two. CharacterSet.whitespaces
    /// also holds every Unicode space separator, and section 12 states that
    /// such a character is part of the token.
    var isPaddedWithWhitespace: Bool {
        guard let first = unicodeScalars.first, let last = unicodeScalars.last else {
            return false
        }
        let isPad = { (scalar: Unicode.Scalar) in scalar == " " || scalar == "\t" }
        return isPad(first) || isPad(last)
    }

    /// Whether the string may appear without quotes, per specification 7.2.
    func isSafeUnquoted(delimiter: String = ",") -> Bool {
        if isEmpty {
            return false
        }

        if isPaddedWithWhitespace {
            return false
        }

        if self == "true" || self == "false" || self == "null" {
            return false
        }

        if isNumericLike {
            return false
        }

        for scalar in unicodeScalars {
            switch scalar {
            case ":", "\"", "\\", "[", "]", "{", "}":
                return false
            default:
                if scalar.value <= 0x1F {
                    return false
                }
            }
        }

        if contains(delimiter) {
            return false
        }

        // A hyphen at position 0 reads as the list marker, and a number sign
        // at position 0 reads as a comment line (section 5.1).
        if hasPrefix("-") || hasPrefix("#") {
            return false
        }

        // Stricter than the specification, which obliges only a decoder to
        // strip a leading byte-order mark (section 12). Without this, a root
        // string that starts with U+FEFF loses its first character on a round
        // trip. Reported upstream as toon-format/toon issue 339.
        if unicodeScalars.first == "\u{FEFF}" {
            return false
        }

        return true
    }

    /// Whether the key may appear without quotes.
    ///
    /// Specification 7.3 gives the pattern `^[A-Za-z_][A-Za-z0-9_.]*$`. The
    /// `\w` class of NSRegularExpression covers every Unicode letter, so the
    /// old pattern left a key such as `naive` with a diaeresis unquoted,
    /// against section 16.
    var isValidUnquotedKey: Bool {
        var scalars = Array(unicodeScalars).makeIterator()
        guard let first = scalars.next(), first.isASCIILetter || first == "_" else {
            return false
        }
        while let scalar = scalars.next() {
            guard scalar.isASCIILetter || scalar.isASCIIDigit || scalar == "_" || scalar == "."
            else {
                return false
            }
        }
        return true
    }

    /// A single segment of a folded key path: the pattern of specification
    /// 7.3 without the dot.
    var isValidIdentifierSegment: Bool {
        !isEmpty && !contains(".") && isValidUnquotedKey
    }
}

extension Unicode.Scalar {
    /// `true` for an ASCII letter only.
    fileprivate var isASCIILetter: Bool {
        (self >= "A" && self <= "Z") || (self >= "a" && self <= "z")
    }
}
