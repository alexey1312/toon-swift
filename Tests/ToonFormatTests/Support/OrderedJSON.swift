import Foundation

@testable import ToonFormat

/// A JSON reader that keeps the order of the keys of an object.
///
/// `JSONSerialization` returns an `NSDictionary`, and the order of
/// `KeyedDecodingContainer.allKeys` is undefined for `JSONDecoder`. Neither one
/// can report the order of the keys, and the conformance fixtures need it: on
/// encode the order of the keys of the input sets the order of the output
/// lines (TOON specification § 2).
///
/// The reader unescapes strings on its own, and does not call into
/// ``ToonFormat``. A shared escape routine would make a fault in the library
/// and a fault in the test agree with each other, and the test would pass.
enum OrderedJSON {
    struct ParseError: Error, CustomStringConvertible {
        let message: String
        let offset: Int

        var description: String { "\(message) at scalar offset \(offset)" }
    }

    static func parse(_ data: Data) throws -> TOONValue {
        guard let text = String(data: data, encoding: .utf8) else {
            throw ParseError(message: "The input is not valid UTF-8", offset: 0)
        }
        return try parse(text)
    }

    static func parse(_ text: String) throws -> TOONValue {
        var parser = Parser(scalars: Array(text.unicodeScalars))
        let value = try parser.parseValue()
        parser.skipWhitespace()
        guard parser.isAtEnd else {
            throw ParseError(message: "Unexpected trailing content", offset: parser.offset)
        }
        return value
    }

    private struct Parser {
        let scalars: [Unicode.Scalar]
        var offset = 0

        var isAtEnd: Bool { offset >= scalars.count }

        private var current: Unicode.Scalar? {
            offset < scalars.count ? scalars[offset] : nil
        }

        mutating func skipWhitespace() {
            while let scalar = current,
                scalar == " " || scalar == "\t" || scalar == "\n" || scalar == "\r"
            {
                offset += 1
            }
        }

        mutating func parseValue() throws -> TOONValue {
            skipWhitespace()
            guard let scalar = current else {
                throw ParseError(message: "Unexpected end of input", offset: offset)
            }
            switch scalar {
            case "{": return try parseObject()
            case "[": return try parseArray()
            case "\"": return .string(try parseString())
            case "t":
                try expect("true")
                return .bool(true)
            case "f":
                try expect("false")
                return .bool(false)
            case "n":
                try expect("null")
                return .null
            default:
                return try parseNumber()
            }
        }

        private mutating func expect(_ literal: String) throws {
            for expected in literal.unicodeScalars {
                guard current == expected else {
                    throw ParseError(message: "Expected '\(literal)'", offset: offset)
                }
                offset += 1
            }
        }

        private mutating func parseObject() throws -> TOONValue {
            offset += 1  // '{'
            var object = TOONObject()
            skipWhitespace()
            if current == "}" {
                offset += 1
                return .object(object)
            }
            while true {
                skipWhitespace()
                guard current == "\"" else {
                    throw ParseError(message: "Expected a key", offset: offset)
                }
                let key = try parseString()
                skipWhitespace()
                guard current == ":" else {
                    throw ParseError(message: "Expected ':'", offset: offset)
                }
                offset += 1
                object[key] = try parseValue()
                skipWhitespace()
                switch current {
                case ",":
                    offset += 1
                case "}":
                    offset += 1
                    return .object(object)
                default:
                    throw ParseError(message: "Expected ',' or '}'", offset: offset)
                }
            }
        }

        private mutating func parseArray() throws -> TOONValue {
            offset += 1  // '['
            var items: [TOONValue] = []
            skipWhitespace()
            if current == "]" {
                offset += 1
                return .array(items)
            }
            while true {
                items.append(try parseValue())
                skipWhitespace()
                switch current {
                case ",":
                    offset += 1
                case "]":
                    offset += 1
                    return .array(items)
                default:
                    throw ParseError(message: "Expected ',' or ']'", offset: offset)
                }
            }
        }

        private mutating func parseString() throws -> String {
            offset += 1  // opening quote
            var result = String.UnicodeScalarView()
            while true {
                guard let scalar = current else {
                    throw ParseError(message: "Unterminated string", offset: offset)
                }
                offset += 1
                switch scalar {
                case "\"":
                    return String(result)
                case "\\":
                    result.append(try parseEscape())
                default:
                    result.append(scalar)
                }
            }
        }

        private mutating func parseEscape() throws -> Unicode.Scalar {
            guard let marker = current else {
                throw ParseError(message: "Unterminated escape", offset: offset)
            }
            offset += 1
            switch marker {
            case "\"": return "\""
            case "\\": return "\\"
            case "/": return "/"
            case "b": return Unicode.Scalar(0x08)!
            case "f": return Unicode.Scalar(0x0C)!
            case "n": return "\n"
            case "r": return "\r"
            case "t": return "\t"
            case "u": return try parseUnicodeEscape()
            default:
                throw ParseError(message: "Unknown escape '\\\(marker)'", offset: offset)
            }
        }

        /// Reads `\uXXXX`, and joins a surrogate pair. JSON allows a surrogate
        /// pair here; the TOON format does not, which is why this routine is
        /// deliberately separate from the escape code of the library.
        private mutating func parseUnicodeEscape() throws -> Unicode.Scalar {
            let first = try parseHexQuad()
            if first >= 0xD800, first <= 0xDBFF {
                guard current == "\\", offset + 1 < scalars.count, scalars[offset + 1] == "u" else {
                    throw ParseError(message: "Expected a low surrogate", offset: offset)
                }
                offset += 2
                let second = try parseHexQuad()
                guard second >= 0xDC00, second <= 0xDFFF else {
                    throw ParseError(message: "Invalid low surrogate", offset: offset)
                }
                let combined = 0x10000 + ((first - 0xD800) << 10) + (second - 0xDC00)
                guard let scalar = Unicode.Scalar(combined) else {
                    throw ParseError(message: "Invalid surrogate pair", offset: offset)
                }
                return scalar
            }
            guard let scalar = Unicode.Scalar(first) else {
                throw ParseError(message: "Invalid code point", offset: offset)
            }
            return scalar
        }

        private mutating func parseHexQuad() throws -> UInt32 {
            var value: UInt32 = 0
            for _ in 0 ..< 4 {
                guard let scalar = current, let digit = scalar.hexDigitValue else {
                    throw ParseError(message: "Expected a hexadecimal digit", offset: offset)
                }
                value = value << 4 | UInt32(digit)
                offset += 1
            }
            return value
        }

        private mutating func parseNumber() throws -> TOONValue {
            let start = offset
            if current == "-" { offset += 1 }
            var isDouble = false
            while let scalar = current {
                if scalar.isASCIIDigit {
                    offset += 1
                } else if scalar == "." || scalar == "e" || scalar == "E" {
                    isDouble = true
                    offset += 1
                } else if scalar == "+" || scalar == "-" {
                    offset += 1
                } else {
                    break
                }
            }
            let token = String(String.UnicodeScalarView(scalars[start ..< offset]))
            guard !token.isEmpty, token != "-" else {
                throw ParseError(message: "Expected a number", offset: start)
            }
            if !isDouble, let integer = Int64(token) {
                return .int(integer)
            }
            guard let number = Double(token) else {
                throw ParseError(message: "Invalid number '\(token)'", offset: start)
            }
            return .double(number)
        }
    }
}

extension Unicode.Scalar {
    fileprivate var isASCIIDigit: Bool { self >= "0" && self <= "9" }

    fileprivate var hexDigitValue: Int? {
        switch self {
        case "0" ... "9": return Int(value - 0x30)
        case "a" ... "f": return Int(value - 0x61) + 10
        case "A" ... "F": return Int(value - 0x41) + 10
        default: return nil
        }
    }
}
