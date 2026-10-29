#if os(iOS)
import Foundation
import FirebaseCore
import FirebaseAnalytics
import FirebaseCrashlytics

@MainActor final class FirebaseSDKJourneySink: JourneyFirebaseSink {
    var isConfigured: Bool { FirebaseApp.app() != nil }

    func log(_ event: JourneyEvent) {
        Analytics.logEvent(event.name.rawValue, parameters: event.parameters)
    }

    func record(_ diagnostic: JourneyDiagnostic) {
        // Context is attached to this occurrence, never setCustomValue/global keys.
        // Stable domain/code avoid grouping each attempt into a distinct issue.
        let error = NSError(domain: "br.usp.mobile.journey", code: 1, userInfo: [
            NSLocalizedDescriptionKey: "Reportable journey technical failure"
        ])
        Crashlytics.crashlytics().record(error: error, userInfo: diagnostic.parameters)
    }
}
#endif
