import XCTest

#if os(iOS)
import USPAuthKit
#if canImport(USPAuthKitObjCFixture)
import USPAuthKitObjCFixture
#endif

/// These tests record current behavior, including known legacy inconsistencies.
/// They neither validate remote credentials nor perform authentication/networking.
final class USPAuthServiceSessionTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUpWithError() throws {
        suiteName = "USPAuthKit.SessionBaseline.\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDownWithError() throws {
        defaults?.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
    }

    private func service() -> USPAuthService { USPAuthService(userDefaults: defaults) }

    // userData is readonly. Seed the existing persisted JSON schema, without
    // importing the internal store or adding a production-only testing API.
    private func seedUser(_ user: [String: Any]) throws {
        defaults.set(try JSONSerialization.data(withJSONObject: user), forKey: "userData")
    }

    func testEmptyDefaultsInitializerExposesEmptyLocalState() {
        let auth = service()
        XCTAssertNil(auth.oauthToken)
        XCTAssertNil(auth.oauthTokenSecret)
        XCTAssertNil(auth.notificationToken)
        XCTAssertEqual(auth.notificationPlatform, "F")
        XCTAssertEqual(auth.appKey, "")
        XCTAssertFalse(auth.backendHeaderValue.isEmpty)
        // Header says config is nonnull; runtime baseline is nil before setup.
        XCTAssertNil(auth.value(forKey: "config"))
        XCTAssertFalse(auth.isLoggedIn())
        XCTAssertNil(auth.currentUser())
        XCTAssertNil(auth.currentWSUserId())
        XCTAssertTrue(auth.userData.isEmpty)
        XCTAssertTrue((defaults.persistentDomain(forName: suiteName) ?? [:]).isEmpty)
    }

    func testInitializerRestoresAllPersistedPublicCredentialsAndPush() {
        defaults.set("fixture-oauth", forKey: "oauthToken")
        defaults.set("fixture-secret", forKey: "oauthTokenSecret")
        defaults.set("fixture-push", forKey: "notificationToken")
        defaults.set("A", forKey: "notificationPlatform")
        let auth = service()
        XCTAssertEqual(auth.oauthToken, "fixture-oauth")
        XCTAssertEqual(auth.oauthTokenSecret, "fixture-secret")
        XCTAssertEqual(auth.notificationToken, "fixture-push")
        XCTAssertEqual(auth.notificationPlatform, "A")
        XCTAssertFalse(auth.isLoggedIn()) // Restoration of tokens alone is insufficient.
    }

    func testCredentialAndPushSettersRoundTripAndRestoreInAnotherInstance() {
        let auth = service()
        auth.oauthToken = "fixture-oauth"
        auth.oauthTokenSecret = "fixture-secret"
        auth.notificationToken = "fixture-push"
        auth.notificationPlatform = "A"
        XCTAssertEqual(auth.oauthToken, "fixture-oauth")
        XCTAssertEqual(auth.oauthTokenSecret, "fixture-secret")
        XCTAssertEqual(auth.notificationToken, "fixture-push")
        XCTAssertEqual(auth.notificationPlatform, "A")
        for (key, value) in ["oauthToken": "fixture-oauth", "oauthTokenSecret": "fixture-secret",
                             "notificationToken": "fixture-push", "notificationPlatform": "A"] {
            XCTAssertEqual(defaults.string(forKey: key), value, key)
        }
        let restored = service()
        XCTAssertEqual(restored.oauthToken, auth.oauthToken)
        XCTAssertEqual(restored.oauthTokenSecret, auth.oauthTokenSecret)
        XCTAssertEqual(restored.notificationToken, auth.notificationToken)
        XCTAssertEqual(restored.notificationPlatform, auth.notificationPlatform)
    }

    func testNilCredentialAndPushSettersRemovePersistedKeys() {
        let auth = service()
        auth.oauthToken = "fixture-oauth"
        auth.oauthTokenSecret = "fixture-secret"
        auth.notificationToken = "fixture-push"
        auth.oauthToken = nil
        auth.oauthTokenSecret = nil
        auth.notificationToken = nil
        XCTAssertNil(auth.oauthToken)
        XCTAssertNil(auth.oauthTokenSecret)
        XCTAssertNil(auth.notificationToken)
        for key in ["oauthToken", "oauthTokenSecret", "notificationToken"] {
            XCTAssertNil(defaults.object(forKey: key), key)
        }
        XCTAssertNil(service().notificationToken)
    }

    func testLegacyBaseline_EmptyPushRemainsInMemoryButIsNotPersisted() {
        let auth = service()
        auth.oauthToken = ""
        auth.oauthTokenSecret = ""
        auth.notificationToken = ""
        // OAuth getters reload after an empty setter; push getter does not.
        XCTAssertNil(auth.oauthToken)
        XCTAssertNil(auth.oauthTokenSecret)
        XCTAssertEqual(auth.notificationToken, "")
        XCTAssertNil(service().notificationToken)
        for key in ["oauthToken", "oauthTokenSecret", "notificationToken"] {
            XCTAssertNil(defaults.object(forKey: key), key)
        }
    }

    func testNotificationPlatformDefaultsAndNormalizesEmptyValue() {
        defaults.set("", forKey: "notificationPlatform")
        XCTAssertEqual(service().notificationPlatform, "F")
        let auth = service()
        auth.notificationPlatform = "A"
        auth.notificationPlatform = ""
        XCTAssertEqual(auth.notificationPlatform, "F")
        XCTAssertEqual(defaults.string(forKey: "notificationPlatform"), "F")
        XCTAssertEqual(service().notificationPlatform, "F")
    }

    func testLegacyBaseline_AppKeyHeaderAndConfigAreMemoryOnlyAndIndependent() {
        let auth = service()
        let originalHeader = auth.backendHeaderValue
        let config = USPAuthConfig.custom(withBaseURL: "https://example.invalid",
                                          consumerKey: "fixture-key", consumerSecret: "fixture-secret", appKey: "config-app")
        auth.appKey = "instance-app"
        auth.backendHeaderValue = "fixture-header"
        auth.config = config
        XCTAssertEqual(auth.appKey, "instance-app") // Assigning config does not sync appKey.
        XCTAssertEqual(auth.backendHeaderValue, "fixture-header")
        XCTAssertTrue(auth.config === config)
        XCTAssertTrue((defaults.persistentDomain(forName: suiteName) ?? [:]).isEmpty)
        let restored = service()
        XCTAssertEqual(restored.appKey, "")
        XCTAssertEqual(restored.backendHeaderValue, originalHeader)
        XCTAssertNil(restored.value(forKey: "config"))
    }

    func testSeparateDefaultsSuitesDoNotShareCredentialsOrProfile() throws {
        let otherName = "USPAuthKit.SessionBaseline.\(UUID().uuidString)"
        let other = try XCTUnwrap(UserDefaults(suiteName: otherName))
        other.removePersistentDomain(forName: otherName)
        defer { other.removePersistentDomain(forName: otherName) }
        let auth = service()
        auth.oauthToken = "fixture-oauth"
        auth.oauthTokenSecret = "fixture-secret"
        auth.notificationToken = "fixture-push"
        try seedUser(["wsuserid": "fixture-mobile"])
        let isolated = USPAuthService(userDefaults: other)
        XCTAssertNil(isolated.oauthToken)
        XCTAssertNil(isolated.oauthTokenSecret)
        XCTAssertNil(isolated.notificationToken)
        XCTAssertFalse(isolated.isLoggedIn())
        XCTAssertNil(isolated.currentUser())
        XCTAssertNil(isolated.currentWSUserId())
        XCTAssertTrue(isolated.userData.isEmpty)
        isolated.logout()
        XCTAssertTrue(auth.isLoggedIn())
    }

    func testLegacyBaseline_EightPartialCacheStates() throws {
        // Explicit expectations rather than deriving expected behavior from SDK logic.
        let states: [(token: Bool, secret: Bool, user: Bool, loggedIn: Bool)] = [
            (false, false, false, false), (true, false, false, false),
            (false, true, false, false), (true, true, false, false),
            (false, false, true, false), (true, false, true, false),
            (false, true, true, false), (true, true, true, true)
        ]
        for state in states {
            defaults.removePersistentDomain(forName: suiteName)
            if state.token { defaults.set("fixture-oauth", forKey: "oauthToken") }
            if state.secret { defaults.set("fixture-secret", forKey: "oauthTokenSecret") }
            if state.user { try seedUser(["wsuserid": "fixture-mobile", "nomeUsuario": "Fixture"]) }
            let auth = service()
            let label = "token=\(state.token), secret=\(state.secret), user=\(state.user)"
            XCTAssertEqual(auth.isLoggedIn(), state.loggedIn, label)
            XCTAssertEqual(auth.currentUser() != nil, state.user, label)
            XCTAssertEqual(auth.currentWSUserId(), state.user ? "fixture-mobile" : nil, label)
            XCTAssertEqual(auth.currentUser()?.wsuserid, state.user ? "fixture-mobile" : nil, label)
            XCTAssertEqual(auth.userData.isEmpty, !state.user, label)
            XCTAssertNotEqual(auth.currentWSUserId(), auth.oauthToken ?? "fixture-not-a-mobile-token", label)
        }
    }

    func testLegacyBaseline_IncompleteNonemptyProfileCountsAsLoggedIn() throws {
        defaults.set("fixture-oauth", forKey: "oauthToken")
        defaults.set("fixture-secret", forKey: "oauthTokenSecret")
        try seedUser(["unrecognizedField": "fixture"])
        let auth = service()
        XCTAssertTrue(auth.isLoggedIn()) // Presence only, not profile/remote validity.
        let user = try XCTUnwrap(auth.currentUser())
        XCTAssertEqual(user.wsuserid, "")
        XCTAssertEqual(user.nomeUsuario, "")
        XCTAssertTrue(user.vinculos.isEmpty)
        XCTAssertNil(auth.currentWSUserId())
        XCTAssertEqual(auth.userData["unrecognizedField"] as? String, "fixture")
    }

    func testLegacyBaseline_NullOrMissingMobileCredentialDiffersFromEmptyString() throws {
        let profiles: [([String: Any], String?)] = [
            (["wsuserid": NSNull(), "nomeUsuario": NSNull()], nil),
            (["wsuserid": 123], nil),
            (["nomeUsuario": "Fixture"], nil),
            (["wsuserid": ""], "")
        ]
        for (profile, expectedMobile) in profiles {
            try seedUser(profile)
            let auth = service()
            XCTAssertFalse(auth.isLoggedIn()) // No OAuth credentials in this suite.
            let user = try XCTUnwrap(auth.currentUser())
            XCTAssertEqual(auth.currentWSUserId(), expectedMobile)
            XCTAssertEqual(user.wsuserid, expectedMobile ?? "")
            XCTAssertTrue((auth.userData as NSDictionary).isEqual(to: profile))
        }
    }

    func testInvalidEmptyOrNonDictionaryPersistedJSONIsIgnoredWithoutDeletingIt() {
        let payloads: [Any] = [Data("not-json".utf8), Data(), Data("[]".utf8),
                               Data("null".utf8), Data("{}".utf8), "not-data",
                               ["wsuserid": "raw-dictionary-is-not-the-stored-format"]]
        for payload in payloads {
            defaults.set(payload, forKey: "userData")
            defaults.set("fixture-oauth", forKey: "oauthToken")
            defaults.set("fixture-secret", forKey: "oauthTokenSecret")
            let auth = service()
            XCTAssertFalse(auth.isLoggedIn())
            XCTAssertNil(auth.currentUser())
            XCTAssertNil(auth.currentWSUserId())
            XCTAssertTrue(auth.userData.isEmpty)
            XCTAssertNotNil(defaults.object(forKey: "userData")) // No corruption cleanup today.
        }
    }

    func testLegacyBaseline_RegistrationFlagDoesNotDetermineLocalSessionValidity() throws {
        defaults.set("fixture-oauth", forKey: "oauthToken")
        defaults.set("fixture-secret", forKey: "oauthTokenSecret")
        try seedUser(["wsuserid": "fixture-mobile"])
        for registered in [false, true] {
            defaults.set(registered, forKey: "isRegistered")
            XCTAssertTrue(service().isLoggedIn())
        }
    }

    func testCurrentUserIsRemappedOnEachReadAndUserDataReflectsPersistedJSON() throws {
        try seedUser(["wsuserid": "fixture-mobile-a"])
        let auth = service()
        let first = try XCTUnwrap(auth.currentUser())
        let second = try XCTUnwrap(auth.currentUser())
        XCTAssertFalse(first === second)
        try seedUser(["wsuserid": "fixture-mobile-b"])
        XCTAssertEqual(auth.currentUser()?.wsuserid, "fixture-mobile-b")
        XCTAssertEqual(auth.currentWSUserId(), "fixture-mobile-b")
        XCTAssertEqual(auth.userData["wsuserid"] as? String, "fixture-mobile-b")
        XCTAssertEqual(first.wsuserid, "fixture-mobile-a")
    }

    func testLegacyBaseline_InMemoryTokensCanOutliveExternalDefaultsRemoval() throws {
        defaults.set("fixture-oauth", forKey: "oauthToken")
        defaults.set("fixture-secret", forKey: "oauthTokenSecret")
        try seedUser(["wsuserid": "fixture-mobile"])
        let auth = service()
        defaults.removeObject(forKey: "oauthToken")
        defaults.removeObject(forKey: "oauthTokenSecret")
        XCTAssertEqual(auth.oauthToken, "fixture-oauth")
        XCTAssertEqual(auth.oauthTokenSecret, "fixture-secret")
        XCTAssertFalse(auth.isLoggedIn()) // Uses defaults, while getters use memory.
        XCTAssertNotNil(auth.currentUser())
        XCTAssertEqual(auth.currentWSUserId(), "fixture-mobile")
        XCTAssertNil(service().oauthToken)
    }

    func testLegacyBaseline_LogoutClearsCredentialsProfilePushAndRegistrationLocally() throws {
        let auth = service()
        auth.oauthToken = "fixture-oauth"
        auth.oauthTokenSecret = "fixture-secret"
        auth.notificationToken = "fixture-push"
        auth.notificationPlatform = "A"
        auth.appKey = "fixture-app"
        auth.backendHeaderValue = "fixture-header"
        let config = USPAuthConfig.custom(withBaseURL: "https://example.invalid",
                                          consumerKey: "fixture-key", consumerSecret: "fixture-secret", appKey: "fixture-config-app")
        auth.config = config
        try seedUser(["wsuserid": "fixture-mobile"])
        defaults.set(true, forKey: "isRegistered")
        defaults.set("unrelated-value", forKey: "unrelated-key")
        XCTAssertTrue(auth.isLoggedIn())
        auth.logout()
        XCTAssertNil(auth.oauthToken)
        XCTAssertNil(auth.oauthTokenSecret)
        XCTAssertNil(auth.notificationToken)
        XCTAssertEqual(auth.notificationPlatform, "F")
        XCTAssertFalse(auth.isLoggedIn())
        XCTAssertNil(auth.currentUser())
        XCTAssertNil(auth.currentWSUserId())
        XCTAssertTrue(auth.userData.isEmpty)
        for key in ["oauthToken", "oauthTokenSecret", "userData", "notificationToken",
                    "notificationPlatform", "isRegistered"] {
            XCTAssertNil(defaults.object(forKey: key), key)
        }
        XCTAssertEqual(defaults.string(forKey: "unrelated-key"), "unrelated-value")
        XCTAssertEqual(auth.appKey, "fixture-app")
        XCTAssertEqual(auth.backendHeaderValue, "fixture-header")
        XCTAssertTrue(auth.config === config)
        let restored = service()
        XCTAssertEqual(restored.notificationPlatform, "F")
        XCTAssertNil(restored.notificationToken)
        XCTAssertFalse(restored.isLoggedIn())
        auth.logout() // Idempotent on an already empty session.
        XCTAssertFalse(auth.isLoggedIn())
    }

    func testLegacyBaseline_LogoutDoesNotCallEitherPublicRemoteInvalidationMethod() {
        let observation = USPAuthObserveLegacyLocalLogout(defaults)
        XCTAssertEqual(observation["invalidationCalls"]?.intValue, 0)
        XCTAssertEqual(observation["clearedSynchronously"]?.boolValue, true)
        // This observes public invalidation dispatch; it is not a transport spy
        // and does not claim to detect every possible outgoing request.
    }

    func testPublicDefaultInitConfigurationAndSwiftObjectiveCConsumersInIsolatedScope() {
        USPAuthWithIsolatedStandardDefaults(defaults) { [self] in
            // Only this synchronous test uses init/shared/configure. The singleton
            // is first constructed here against the disposable suite, never real defaults.
            let singleton = USPAuthService.shared()
            defer {
                singleton.logout()
                singleton.setValue(nil, forKey: "config") // Restore initial nil legacy state.
                singleton.appKey = ""
            }
            defaults.set("fixture-restored-oauth", forKey: "oauthToken")
            defaults.set("fixture-restored-secret", forKey: "oauthTokenSecret")
            defaults.set("fixture-restored-push", forKey: "notificationToken")
            defaults.set("A", forKey: "notificationPlatform")
            let auth = USPAuthService()
            XCTAssertEqual(auth.oauthToken, "fixture-restored-oauth")
            XCTAssertEqual(auth.oauthTokenSecret, "fixture-restored-secret")
            XCTAssertEqual(auth.notificationToken, "fixture-restored-push")
            XCTAssertEqual(auth.notificationPlatform, "A")
            auth.oauthToken = "fixture-default-init-write"
            XCTAssertEqual(defaults.string(forKey: "oauthToken"), "fixture-default-init-write")
            auth.logout()
            exerciseSwiftSessionConsumer(defaults: defaults)
            let results = USPAuthExerciseObjectiveCConsumer(defaults)
            XCTAssertEqual(results.count, 6)
            for (name, passed) in results { XCTAssertTrue(passed.boolValue, name) }
        }
    }
}
#else
final class USPAuthServiceSessionTests: XCTestCase {
    func testSessionContractRequiresIOSImplementation() throws {
        throw XCTSkip("USPAuthService is excluded without UIKit. Run the iOS harness; host success is not session coverage.")
    }
}
#endif
