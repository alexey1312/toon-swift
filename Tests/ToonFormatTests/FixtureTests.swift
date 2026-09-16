import Foundation
import Testing

@testable import ToonFormat

/// Runs the conformance fixtures of the TOON specification.
///
/// Each case is addressable on its own:
///
/// ```
/// swift test --filter 'decode/numbers'
/// swift test --filter 'objects-keyed'
/// ```
///
/// A case that the library does not satisfy yet is listed in
/// ``FixtureExpectations/knownGaps``. The suite wraps such a case in
/// `withKnownIssue`, which makes the run fail when the case starts to pass. A
/// step of the migration therefore has to remove its own entries from that
/// list, and cannot forget to.
@Suite("Specification fixtures")
struct FixtureTests {
    @Test("encode", arguments: Fixtures.encode)
    func encodeFixture(_ fixture: FixtureCase) throws {
        try withKnownIssue(fixture.gapComment, isIntermittent: false) {
            let encoder = TOONEncoder()
            encoder.delimiter = fixture.options.delimiter
            encoder.indent = fixture.options.indentSize

            guard !fixture.shouldError else {
                #expect(throws: (any Error).self) {
                    try encoder.encode(fixture.input)
                }
                return
            }

            guard case let .string(expected) = fixture.expected else {
                Issue.record("The expected value of an encode case must be a string.")
                return
            }

            let data = try encoder.encode(fixture.input)
            let actual = String(decoding: data, as: UTF8.self)
            #expect(actual == expected)
        } when: {
            FixtureExpectations.knownGaps[fixture.id] != nil
        }
    }

    @Test("decode", arguments: Fixtures.decode)
    func decodeFixture(_ fixture: FixtureCase) throws {
        try withKnownIssue(fixture.gapComment, isIntermittent: false) {
            guard case let .string(source) = fixture.input else {
                Issue.record("The input of a decode case must be a string.")
                return
            }

            let decoder = TOONDecoder()
            decoder.indentSize = fixture.options.indentSize
            let data = Data(source.utf8)

            guard !fixture.shouldError else {
                #expect(throws: (any Error).self) {
                    try decoder.decode(TOONValue.self, from: data)
                }
                return
            }

            let actual = try decoder.decode(TOONValue.self, from: data)
            #expect(
                jsonModelEquals(actual, fixture.expected),
                "decoded \(actual), expected \(fixture.expected)"
            )
        } when: {
            FixtureExpectations.knownGaps[fixture.id] != nil
        }
    }

    /// Guards against a partial or stale copy of the fixtures.
    @Test("the fixture corpus is complete")
    func corpusIsComplete() {
        #expect(Fixtures.encode.count == 179)
        #expect(Fixtures.decode.count == 359)
        #expect(Fixtures.provenance["repo"] == .string("toon-format/spec"))
    }
}

extension FixtureCase {
    /// The reason that ``FixtureExpectations`` records for a known gap.
    fileprivate var gapComment: Comment {
        Comment(rawValue: FixtureExpectations.knownGaps[id] ?? "")
    }
}
