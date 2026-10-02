#import "USPAuthArchitectureTestCase.h"

@implementation USPAuthArchitectureTests (USPNeutralProviderTests)
- (void)testIndependentAuthenticationProviderDeliversStandardProfileForTwoApplicationConfigurations {
  // Fresh authentication, not cached success. No OAuth config/credentials/crypto/browser.
  XCTAssertNil(_provider);
  for (NSString *app in @[@"application-a", @"application-b"]) {
    FakeAuthenticationProvider *provider = [FakeAuthenticationProvider new]; MemoryStore *store = [MemoryStore new];
    FakeTransport *transport = [FakeTransport new];
    USPMobileBackendClient *mobile = [[USPMobileBackendClient alloc] initWithTransport:transport];
    USPAuthService *service = [[USPAuthService alloc] initWithCoordinator:[[USPAuthenticationCoordinator alloc] initWithProvider:provider store:store mobileClient:mobile] legacyProvider:nil];
    USPApplicationConfiguration *configuration = [[USPApplicationConfiguration alloc] initWithBaseURL:[@"https://example.invalid/" stringByAppendingString:app] appKey:app backendHeaderValue:@"fixture-header"];
    [service applyApplicationConfiguration:configuration];
    configuration.appKey = @"mutated-input"; // The instance owns its configuration snapshot.
    __block NSUInteger calls = 0;
    [service ensureLoggedInFromViewController:self.presenter completion:^(USPAuthUser *user, NSError *error) { calls++; XCTAssertNil(error); [self assertStandardProfile:user]; }];
    XCTAssertEqual(provider.calls, 1u); XCTAssertNil(service.config);
    [store updateProviderState:@{@"opaque-envelope":@"fixture"} forProvider:provider.identifier];
    [provider resolveUser:[self standardFixtureUser]];
    XCTAssertEqual(transport.requests.count, 1u); XCTAssertEqual(calls, 0u);
    NSURLRequest *request = transport.requests.firstObject;
    XCTAssertTrue([request.URL.absoluteString containsString:app]); XCTAssertNil([request valueForHTTPHeaderField:@"Authorization"]);
    NSDictionary *body = [NSJSONSerialization JSONObjectWithData:request.HTTPBody options:0 error:nil];
    XCTAssertEqualObjects(body[@"app"], app); XCTAssertEqualObjects(body[@"token"], @"usp-operational-id");
    [transport respond:0 text:@"" status:200 error:nil];
    XCTAssertEqual(calls, 1u); XCTAssertTrue(service.isLoggedIn); [self assertStandardProfile:service.currentUser];
    XCTAssertEqualObjects(service.currentWSUserId, service.currentUser.wsuserid);
    XCTAssertNil(service.oauthToken); XCTAssertNil(service.oauthTokenSecret);
    [service logout]; XCTAssertNil(service.currentUser); [transport.callbacks removeAllObjects]; provider.result = nil;
  }
  XCTAssertNil(_provider); // No protocol-specific fixture was even instantiated.
}
@end
