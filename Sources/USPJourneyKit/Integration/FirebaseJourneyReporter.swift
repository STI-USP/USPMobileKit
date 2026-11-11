import Foundation

/// Decisions are evaluated at each send, so consent/environment may change.
/// This policy never toggles Firebase's own collection configuration.
@MainActor public struct JourneyCollectionPolicy {
    public let allowsAnalytics: @MainActor () -> Bool
    public let allowsDiagnostics: @MainActor () -> Bool

    public init(
        allowsAnalytics: @escaping @MainActor () -> Bool = { false },
        allowsDiagnostics: @escaping @MainActor () -> Bool = { false }
    ) {
        self.allowsAnalytics = allowsAnalytics
        self.allowsDiagnostics = allowsDiagnostics
    }
}

public enum FirebaseJourneyReportingError: Error, Equatable, Sendable {
    case firebaseNotConfigured
}

/// Sends formatted journey events through the Firebase SDK supplied by the app.
/// The app owns SDK configuration and collection settings.
@MainActor public final class FirebaseJourneyReporter: JourneyReporting, JourneyDiagnosticReporting {
    private let policy: JourneyCollectionPolicy
    private let isConfigured: @MainActor () -> Bool
    private let logEvent: @MainActor (String, [String: Any]) throws -> Void
    private let recordError: @MainActor (NSError, [String: Any]) throws -> Void

    public init(
        policy: JourneyCollectionPolicy = JourneyCollectionPolicy(),
        isConfigured: @escaping @MainActor () -> Bool,
        logEvent: @escaping @MainActor (String, [String: Any]) throws -> Void,
        recordError: @escaping @MainActor (NSError, [String: Any]) throws -> Void
    ) {
        self.policy = policy
        self.isConfigured = isConfigured
        self.logEvent = logEvent
        self.recordError = recordError
    }

    public func record(_ event: JourneyEvent) throws {
        guard policy.allowsAnalytics() else { return }
        guard isConfigured() else { throw FirebaseJourneyReportingError.firebaseNotConfigured }
        try logEvent(event.name.rawValue, event.parameters)
    }

    public func record(_ diagnostic: JourneyDiagnostic) throws {
        guard policy.allowsDiagnostics() else { return }
        guard isConfigured() else { throw FirebaseJourneyReportingError.firebaseNotConfigured }

        // Keep the grouping stable and attach context only to this occurrence.
        let error = NSError(domain: "br.usp.mobile.journey", code: 1, userInfo: [
            NSLocalizedDescriptionKey: "Reportable journey technical failure"
        ])
        try recordError(error, diagnostic.parameters)
    }
}
