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

    private var storage = ScalarOrderedDictionary<TOONValue>()

    public init() {}

    /// Creates an object from a sequence of pairs.
    ///
    /// A later pair with the same key replaces the value of the earlier pair
    /// and keeps the position of the earlier pair.
    public init(_ pairs: some Sequence<(String, TOONValue)>) {
        for (key, value) in pairs {
            storage[key] = value
        }
    }

    /// The keys, in insertion order.
    public var keys: [String] { storage.keys }

    /// The values, in insertion order.
    public var values: [TOONValue] { storage.values }

    public subscript(key: String) -> TOONValue? {
        get { storage[key] }
        set { storage[key] = newValue }
    }
}

extension TOONObject: RandomAccessCollection {
    public var startIndex: Int { storage.startIndex }
    public var endIndex: Int { storage.endIndex }
    public subscript(position: Int) -> Element {
        Element(key: storage[position].key, value: storage[position].value)
    }
}

extension TOONObject: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral pairs: (String, TOONValue)...) {
        self.init(pairs)
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
