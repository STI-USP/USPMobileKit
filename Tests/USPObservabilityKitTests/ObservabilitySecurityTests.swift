import XCTest
@testable import USPObservabilityKit

final class ObservabilitySecurityTests: XCTestCase {

    func testIterationOneInitializersRemainAvailableWithSafeDefault() throws {
        let standard = USPContextInstrumenter()
        let injected = USPContextInstrumenter(
            appInfo: SecurityTestAppInfo(),
            osVersion: SecurityTestOSVersion(),
            deviceModel: SecurityTestDeviceModel(),
            installationID: SecurityTestInstallationID()
        )
        let original = request("https://api.usp.br/resource")

        XCTAssertEqual(try standard.instrument(original), original)
        XCTAssertEqual(try injected.instrument(original), original)
    }

    func testAllowedHostReceivesTraceparentAndUSPHeaders() throws {
        let result = try makeInstrumenter().instrumentWithTraceContext(
            request("https://api.usp.br/cardapio")
        )

        XCTAssertNotNil(result.traceContext)
        XCTAssertEqual(
            result.request.value(forHTTPHeaderField: "traceparent"),
            result.traceContext?.traceparent
        )
        XCTAssertEqual(result.request.value(forHTTPHeaderField: "USP-App-Platform"), "ios")
        XCTAssertEqual(result.request.value(forHTTPHeaderField: "USP-Installation-Id"), "installation")
    }

    func testUnauthorizedHostReceivesNoObservabilityHeaders() throws {
        let original = request(
            "https://third-party.example/resource",
            headers: ["Authorization": "Bearer token", "Content-Type": "application/json"]
        )
        let result = try makeInstrumenter().instrumentWithTraceContext(original)

        XCTAssertNil(result.traceContext)
        XCTAssertNil(result.request.value(forHTTPHeaderField: "traceparent"))
        XCTAssertNil(result.request.value(forHTTPHeaderField: "USP-App-Platform"))
        XCTAssertNil(result.request.value(forHTTPHeaderField: "USP-Installation-Id"))
        XCTAssertEqual(result.request.value(forHTTPHeaderField: "Authorization"), "Bearer token")
        XCTAssertEqual(result.request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertEqual(result.request, original)
    }

    func testMaliciousSubstringDoesNotPassAllowlist() throws {
        let result = try makeInstrumenter().instrument(
            request("https://api.usp.br.attacker.com/resource")
        )

        XCTAssertNil(result.value(forHTTPHeaderField: "traceparent"))
        XCTAssertNil(result.value(forHTTPHeaderField: "USP-App-Platform"))
    }

    func testSubdomainIsNotImplicitlyAllowed() throws {
        let result = try makeInstrumenter().instrument(
            request("https://sub.api.usp.br/resource")
        )

        XCTAssertNil(result.value(forHTTPHeaderField: "traceparent"))
    }

    func testHostMatchingIsCaseInsensitiveAndAcceptsDNSFinalDot() throws {
        let instrumenter = makeInstrumenter(allowedHosts: ["API.USP.BR."])
        let result = try instrumenter.instrument(request("https://api.usp.br/resource"))

        XCTAssertNotNil(result.value(forHTTPHeaderField: "traceparent"))
    }

    func testEmptyAllowlistLeavesRequestUntouched() throws {
        let original = request("https://api.usp.br/resource")
        let result = try makeInstrumenter(allowedHosts: []).instrument(original)

        XCTAssertEqual(result, original)
    }

    func testInvalidAllowlistEntriesAreIgnored() throws {
        let instrumenter = makeInstrumenter(allowedHosts: [
            "https://api.usp.br",
            "api.usp.br:443",
            "api.usp.br/path",
            "*.usp.br",
        ])
        let result = try instrumenter.instrument(request("https://api.usp.br/resource"))

        XCTAssertTrue(ObservabilityConfiguration(allowedHosts: ["*.usp.br"]).allowedHosts.isEmpty)
        XCTAssertNil(result.value(forHTTPHeaderField: "traceparent"))
    }

    func testIndependentRequestsReceiveDifferentTraceIDs() throws {
        let instrumenter = makeInstrumenter()
        let first = try instrumenter.instrumentWithTraceContext(request("https://api.usp.br/cardapio"))
        let second = try instrumenter.instrumentWithTraceContext(request("https://api.usp.br/cardapio"))

        XCTAssertNotEqual(first.traceContext?.traceID, second.traceContext?.traceID)
    }

    func testRetryPreservesTraceIDAndRenewsParentID() throws {
        let instrumenter = makeInstrumenter()
        let first = try instrumenter.instrumentWithTraceContext(request("https://api.usp.br/cardapio"))
        let retryContext = try XCTUnwrap(first.traceContext).nextAttempt()
        let retry = try instrumenter.instrumentWithTraceContext(
            request("https://api.usp.br/cardapio"),
            context: retryContext
        )

        XCTAssertEqual(retry.traceContext?.traceID, first.traceContext?.traceID)
        XCTAssertNotEqual(retry.traceContext?.parentID, first.traceContext?.parentID)
        XCTAssertEqual(retry.request.value(forHTTPHeaderField: "traceparent"), retryContext.traceparent)
    }

    func testRepeatedInstrumentationPreservesValidTraceparent() throws {
        let instrumenter = makeInstrumenter()
        let first = try instrumenter.instrumentWithTraceContext(request("https://api.usp.br/resource"))
        let second = try instrumenter.instrumentWithTraceContext(first.request)

        XCTAssertEqual(second.request, first.request)
        XCTAssertEqual(second.traceContext, first.traceContext)
    }

    func testValidPreexistingTraceparentIsPreserved() throws {
        let existing = "00-0123456789abcdef0123456789abcdef-0123456789abcdef-01"
        let result = try makeInstrumenter().instrumentWithTraceContext(
            request("https://api.usp.br/resource", headers: ["traceparent": existing])
        )

        XCTAssertEqual(result.request.value(forHTTPHeaderField: "traceparent"), existing)
        XCTAssertEqual(result.traceContext?.traceID, "0123456789abcdef0123456789abcdef")
    }

    func testInvalidPreexistingTraceparentIsReplacedForAllowedHost() throws {
        let result = try makeInstrumenter().instrumentWithTraceContext(
            request("https://api.usp.br/resource", headers: ["traceparent": "invalid"])
        )

        let replacement = try XCTUnwrap(result.request.value(forHTTPHeaderField: "traceparent"))
        XCTAssertNotEqual(replacement, "invalid")
        XCTAssertNotNil(TraceContext(traceparent: replacement))
    }

    func testExplicitRetryContextReplacesPreviousAttemptHeader() throws {
        let instrumenter = makeInstrumenter()
        let first = try instrumenter.instrumentWithTraceContext(request("https://api.usp.br/resource"))
        let retryContext = try XCTUnwrap(first.traceContext).nextAttempt()
        let retry = try instrumenter.instrumentWithTraceContext(first.request, context: retryContext)

        XCTAssertEqual(retry.request.value(forHTTPHeaderField: "traceparent"), retryContext.traceparent)
    }

    func testPreexistingUSPHeadersArePreserved() throws {
        let result = try makeInstrumenter().instrument(
            request(
                "https://api.usp.br/resource",
                headers: ["USP-App-Version": "explicit-version"]
            )
        )

        XCTAssertEqual(result.value(forHTTPHeaderField: "USP-App-Version"), "explicit-version")
    }

    func testAuthorizationAndContentTypeArePreservedForAllowedHost() throws {
        let result = try makeInstrumenter().instrument(
            request(
                "https://api.usp.br/resource",
                headers: ["Authorization": "Bearer token", "Content-Type": "application/json"]
            )
        )

        XCTAssertEqual(result.value(forHTTPHeaderField: "Authorization"), "Bearer token")
        XCTAssertEqual(result.value(forHTTPHeaderField: "Content-Type"), "application/json")
    }

    func testTraceparentDoesNotContainInstallationOrUserData() throws {
        let result = try makeInstrumenter().instrumentWithTraceContext(
            request(
                "https://api.usp.br/resource",
                headers: ["Authorization": "Bearer user-123"]
            )
        )
        let traceparent = try XCTUnwrap(
            result.request.value(forHTTPHeaderField: "traceparent")
        )

        XCTAssertFalse(traceparent.contains("installation"))
        XCTAssertFalse(traceparent.contains("user-123"))
        XCTAssertFalse(traceparent.contains("Bearer"))
    }

    func testConcurrentRequestsDoNotShareTraceID() async throws {
        let instrumenter = makeInstrumenter()
        let traceIDs = try await withThrowingTaskGroup(of: String.self) { group in
            for _ in 0..<100 {
                group.addTask {
                    let result = try instrumenter.instrumentWithTraceContext(
                        request("https://api.usp.br/resource")
                    )
                    return try XCTUnwrap(result.traceContext?.traceID)
                }
            }

            var values = [String]()
            for try await value in group {
                values.append(value)
            }
            return values
        }

        XCTAssertEqual(Set(traceIDs).count, traceIDs.count)
    }
}

private struct SecurityTestAppInfo: AppInfoProviding {
    let platform = "ios"
    let version = "1.2.3"
    let build = "123"
}

private struct SecurityTestOSVersion: OSVersionProviding {
    let osVersion = "26.0"
}

private struct SecurityTestDeviceModel: DeviceModelProviding {
    let deviceModel = "iPhone17,1"
}

private struct SecurityTestInstallationID: InstallationIDProviding {
    let installationID = "installation"
}

private func makeInstrumenter(
    allowedHosts: [String] = ["api.usp.br"]
) -> USPContextInstrumenter {
    USPContextInstrumenter(
        configuration: ObservabilityConfiguration(allowedHosts: allowedHosts),
        appInfo: SecurityTestAppInfo(),
        osVersion: SecurityTestOSVersion(),
        deviceModel: SecurityTestDeviceModel(),
        installationID: SecurityTestInstallationID()
    )
}

private func request(
    _ url: String,
    headers: [String: String] = [:]
) -> URLRequest {
    var request = URLRequest(url: URL(string: url)!)
    for (field, value) in headers {
        request.setValue(value, forHTTPHeaderField: field)
    }
    return request
}
