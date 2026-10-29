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

@MainActor protocol JourneyFirebaseSink: AnyObject {
    var isConfigured: Bool { get }
    func log(_ event: JourneyEvent) throws
    func record(_ diagnostic: JourneyDiagnostic) throws
}

public enum FirebaseJourneyReportingError: Error, Equatable, Sendable {
    case firebaseNotConfigured
    case unsupportedPlatform
}

/// Uses the app's already configured default Firebase project. No configure(),
/// consent changes, user IDs, raw errors or global Crashlytics custom keys.
@MainActor public final class FirebaseJourneyReporter: JourneyReporting, JourneyDiagnosticReporting {
    private let sink: any JourneyFirebaseSink
    private let policy: JourneyCollectionPolicy

    public convenience init(policy: JourneyCollectionPolicy = JourneyCollectionPolicy()) {
        #if os(iOS)
        self.init(policy: policy, sink: FirebaseSDKJourneySink())
        #else
        self.init(policy: policy, sink: UnavailableJourneyFirebaseSink())
        #endif
    }

    init(policy: JourneyCollectionPolicy, sink: any JourneyFirebaseSink) {
        self.policy = policy
        self.sink = sink
    }

    public func record(_ event: JourneyEvent) throws {
        guard policy.allowsAnalytics() else { return }
        guard sink.isConfigured else { throw FirebaseJourneyReportingError.firebaseNotConfigured }
        try sink.log(event)
    }

    public func record(_ diagnostic: JourneyDiagnostic) throws {
        guard policy.allowsDiagnostics() else { return }
        guard sink.isConfigured else { throw FirebaseJourneyReportingError.firebaseNotConfigured }
        try sink.record(diagnostic)
    }
}

#if !os(iOS)
@MainActor private final class UnavailableJourneyFirebaseSink: JourneyFirebaseSink {
    var isConfigured: Bool { false }
    func log(_ event: JourneyEvent) throws { throw FirebaseJourneyReportingError.unsupportedPlatform }
    func record(_ diagnostic: JourneyDiagnostic) throws { throw FirebaseJourneyReportingError.unsupportedPlatform }
}
#endif
