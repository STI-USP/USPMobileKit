import XCTest
@testable import USPObservabilityKit

final class TraceContextTests: XCTestCase {

    func testGeneratedIdentifiersHaveRequiredLengthsAndLowercaseHex() {
        let context = TraceContext.create()

        XCTAssertEqual(context.traceID.count, 32)
        XCTAssertEqual(context.parentID.count, 16)
        XCTAssertTrue(context.traceID.allSatisfy(Self.isLowercaseHex))
        XCTAssertTrue(context.parentID.allSatisfy(Self.isLowercaseHex))
    }

    func testGeneratedIdentifiersAreNotZero() {
        let context = TraceContext.create()

        XCTAssertNotEqual(context.traceID, String(repeating: "0", count: 32))
        XCTAssertNotEqual(context.parentID, String(repeating: "0", count: 16))
    }

    func testTraceparentUsesVersionZeroAndSampledFlag() {
        let context = TraceContext(
            traceID: "0123456789abcdef0123456789abcdef",
            parentID: "0123456789abcdef"
        )!

        XCTAssertEqual(
            context.traceparent,
            "00-0123456789abcdef0123456789abcdef-0123456789abcdef-01"
        )
    }

    func testGenerationCanUseDeterministicRandomBytes() {
        let context = TraceContext.make(using: FixedRandomBytesGenerator(byte: 0xab))

        XCTAssertEqual(context.traceID, String(repeating: "ab", count: 16))
        XCTAssertEqual(context.parentID, String(repeating: "ab", count: 8))
    }

    func testValidationRejectsInvalidTraceparents() {
        let invalidValues = [
            "01-0123456789abcdef0123456789abcdef-0123456789abcdef-01",
            "00-0123456789abcdef0123456789abcde-0123456789abcdef-01",
            "00-0123456789abcdef0123456789abcdef-0123456789abcde-01",
            "00-0123456789abcdef0123456789abcdef-0123456789abcdef-ff",
            "00-0123456789ABCDEF0123456789ABCDEF-0123456789abcdef-01",
            "00-00000000000000000000000000000000-0123456789abcdef-01",
            "00-0123456789abcdef0123456789abcdef-0000000000000000-01",
        ]

        for value in invalidValues {
            XCTAssertNil(TraceContext(traceparent: value), "Deveria rejeitar: \(value)")
        }
    }

    func testValidationAcceptsSupportedFlags() {
        let prefix = "00-0123456789abcdef0123456789abcdef-0123456789abcdef-"

        XCTAssertEqual(TraceContext(traceparent: prefix + "00")?.flags, .notSampled)
        XCTAssertEqual(TraceContext(traceparent: prefix + "01")?.flags, .sampled)
    }

    func testIndependentContextsHaveDifferentTraceIDs() {
        let first = TraceContext.create()
        let second = TraceContext.create()

        XCTAssertNotEqual(first.traceID, second.traceID)
    }

    func testNextAttemptPreservesTraceIDAndChangesParentID() {
        let first = TraceContext.make(using: FixedRandomBytesGenerator(byte: 0xab))
        let retry = first.nextAttempt(using: FixedRandomBytesGenerator(byte: 0xcd))

        XCTAssertEqual(retry.traceID, first.traceID)
        XCTAssertEqual(retry.parentID, String(repeating: "cd", count: 8))
        XCTAssertEqual(retry.flags, first.flags)
    }

    private static func isLowercaseHex(_ character: Character) -> Bool {
        ("0"..."9").contains(character) || ("a"..."f").contains(character)
    }
}

private struct FixedRandomBytesGenerator: RandomBytesGenerating {
    let byte: UInt8

    func bytes(count: Int) -> [UInt8] {
        [UInt8](repeating: byte, count: count)
    }
}
