#if os(iOS)
import XCTest
import USPAuthKit

/// Compiled, linked and invoked by the iOS tests. Uses only the public import,
/// so imported Swift names and types are part of the characterization baseline.
func exerciseSwiftSessionConsumer(defaults: UserDefaults) {
    let singleton: USPAuthService = USPAuthService.shared()
    USPAuthService.configure(with: .prod,
                             consumerKey: "fixture-key",
                             consumerSecret: "fixture-secret",
                             appKey: "fixture-app")
    XCTAssertEqual(singleton.config.environment, .prod)
    XCTAssertEqual(singleton.appKey, "fixture-app")
    let config = USPAuthConfig.custom(withBaseURL: "https://example.invalid",
                                      consumerKey: "fixture-key",
                                      consumerSecret: "fixture-secret",
                                      appKey: "fixture-custom-app")
    USPAuthService.configure(with: config)
    XCTAssertTrue(singleton.config === config)
    XCTAssertEqual(singleton.appKey, "fixture-custom-app")

    let service = USPAuthService(userDefaults: defaults)
    service.config = config
    service.appKey = "fixture-instance-app"
    service.backendHeaderValue = "fixture-header"
    service.oauthToken = "fixture-oauth"
    service.oauthTokenSecret = "fixture-secret"
    service.notificationToken = "fixture-push"
    service.notificationPlatform = "A"
    XCTAssertTrue(service.config === config)
    XCTAssertEqual(service.appKey, "fixture-instance-app")
    XCTAssertEqual(service.backendHeaderValue, "fixture-header")
    XCTAssertEqual(service.oauthToken, "fixture-oauth")
    XCTAssertEqual(service.oauthTokenSecret, "fixture-secret")
    XCTAssertEqual(service.notificationToken, "fixture-push")
    XCTAssertEqual(service.notificationPlatform, "A")
    let loggedIn: Bool = service.isLoggedIn()
    let user: USPAuthUser? = service.currentUser()
    let mobileCredential: String? = service.currentWSUserId()
    let rawUser: [String: Any] = service.userData
    XCTAssertFalse(loggedIn) // No profile seeded at this point.
    XCTAssertNil(user)
    XCTAssertNil(mobileCredential)
    XCTAssertTrue(rawUser.isEmpty)
    service.logout()
    XCTAssertNil(service.oauthToken)
    XCTAssertNil(service.oauthTokenSecret)
    XCTAssertNil(service.notificationToken)
    XCTAssertEqual(service.notificationPlatform, "F")
}
#endif
