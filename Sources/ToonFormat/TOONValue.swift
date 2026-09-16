import Foundation

/// A TOON value with no static Swift type.
///
/// Use ``TOONValue`` to encode or decode a document whose shape you do not know
/// at compile time. The type models the JSON data model of TOON specification
/// § 2, so it holds no host types such as `Date` or `URL`.
///
/// ```swift
/// let value = try TOONDecoder().decode(TOONValue.self, from: data)
/// if case let .object(root) = value {
///     print(root["users"] ?? .null)
/// }
/// ```
public enum TOONValue: Hashable, Sendable {
    case null
    case bool(Bool)
    case int(Int64)
    case double(Double)
    case string(String)
    case array([TOONValue])
    case object(TOONObject)
}

// MARK: - Object

/// An ordered set of key-value pairs.
///
/// The type keeps the order in which you insert the keys, because TOON
/// specification § 2 requires an encoder to preserve the order of the keys.
///
/// Two keys are equal only when their Unicode scalar sequences are equal.
/// TOON specification § 2 and § 16 state that two keys which are canonically
/// equivalent but differ in normalization form are different keys. The Swift
/// `String` type compares by canonical equivalence, so this type cannot use a
/// plain `[String: TOONValue]` dictionary.
public struct TOONObject: Hashable, Sendable {
    /// One key-value pair.
    public struct Element: Sendable {
        public let key: String
        public var value: TOONValue

        public init(key: String, value: TOONValue) {
            self.key = key
            self.value = value
        }
    }

    private var elements: [Element]
    private var index: [ScalarKey: Int]

    public init() {
        elements = []
        index = [:]
    }

    /// Creates an object from a sequence of pairs.
    ///
    /// A later pair with the same key replaces the value of the earlier pair
    /// and keeps the position of the earlier pair.
    public init(_ pairs: some Sequence<(String, TOONValue)>) {
        self.init()
        for (key, value) in pairs {
            self[key] = value
        }
    }

    /// The keys, in insertion order.
    public var keys: [String] { elements.map(\.key) }

    /// The values, in insertion order.
    public var values: [TOONValue] { elements.map(\.value) }

    public subscript(key: String) -> TOONValue? {
        get {
            guard let position = index[ScalarKey(key)] else { return nil }
            return elements[position].value
        }
        set {
            let scalarKey = ScalarKey(key)
            switch (index[scalarKey], newValue) {
            case let (position?, value?):
                elements[position].value = value
            case let (nil, value?):
                index[scalarKey] = elements.count
                elements.append(Element(key: key, value: value))
            case let (position?, nil):
                elements.remove(at: position)
                index.removeValue(forKey: scalarKey)
                for offset in position ..< elements.count {
                    index[ScalarKey(elements[offset].key)] = offset
                }
            case (nil, nil):
                break
            }
        }
    }

    // Scalar-exact equality, per § 2 and § 16. The synthesized conformance
    // would compare the keys by canonical equivalence.
    public static func == (lhs: TOONObject, rhs: TOONObject) -> Bool {
        guard lhs.elements.count == rhs.elements.count else { return false }
        return zip(lhs.elements, rhs.elements).allSatisfy { left, right in
            left.key.unicodeScalars.elementsEqual(right.key.unicodeScalars)
                && left.value == right.value
        }
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(elements.count)
        for element in elements {
            for scalar in element.key.unicodeScalars {
                hasher.combine(scalar)
            }
            hasher.combine(element.value)
        }
    }
}

extension TOONObject: RandomAccessCollection {
    public var startIndex: Int { elements.startIndex }
    public var endIndex: Int { elements.endIndex }
    public subscript(position: Int) -> Element { elements[position] }
}

extension TOONObject: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral pairs: (String, TOONValue)...) {
        self.init(pairs)
    }
}

/// A dictionary key that compares and hashes by Unicode scalar sequence.
private struct ScalarKey: Hashable {
    let value: String

    init(_ value: String) {
        self.value = value
    }

    static func == (lhs: ScalarKey, rhs: ScalarKey) -> Bool {
        lhs.value.unicodeScalars.elementsEqual(rhs.value.unicodeScalars)
    }

    func hash(into hasher: inout Hasher) {
        for scalar in value.unicodeScalars {
            hasher.combine(scalar)
        }
    }
}

// MARK: - Codable

extension TOONValue: Codable {
    public init(from decoder: any Decoder) throws {
        if let container = try? decoder.singleValueContainer(), container.decodeNil() {
            self = .null
            return
        }
        if var container = try? decoder.unkeyedContainer() {
            var items: [TOONValue] = []
            while !container.isAtEnd {
                items.append(try container.decode(TOONValue.self))
            }
            self = .array(items)
            return
        }
        if let container = try? decoder.container(keyedBy: IndexedCodingKey.self) {
            var object = TOONObject()
            for key in container.allKeys {
                object[key.stringValue] = try container.decode(TOONValue.self, forKey: key)
            }
            self = .object(object)
            return
        }

        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int64.self) {
            self = .int(value)
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else {
            self = .string(try container.decode(String.self))
        }
    }

    public func encode(to encoder: any Encoder) throws {
        switch self {
        case .null:
            var container = encoder.singleValueContainer()
            try container.encodeNil()
        case let .bool(value):
            var container = encoder.singleValueContainer()
            try container.encode(value)
        case let .int(value):
            var container = encoder.singleValueContainer()
            try container.encode(value)
        case let .double(value):
            var container = encoder.singleValueContainer()
            try container.encode(value)
        case let .string(value):
            var container = encoder.singleValueContainer()
            try container.encode(value)
        case let .array(items):
            var container = encoder.unkeyedContainer()
            for item in items {
                try container.encode(item)
            }
        case let .object(object):
            var container = encoder.container(keyedBy: IndexedCodingKey.self)
            for element in object {
                try container.encode(
                    element.value,
                    forKey: IndexedCodingKey(stringValue: element.key)
                )
            }
        }
    }
}
