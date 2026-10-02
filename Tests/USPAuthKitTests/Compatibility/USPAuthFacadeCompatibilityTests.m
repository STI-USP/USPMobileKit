#import "USPAuthArchitectureTestCase.h"
#import "USPOAuth1AuthenticationProvider.h"

@implementation USPAuthArchitectureTests (USPAuthFacadeCompatibilityTests)
- (void)testLegacyWebViewAdapterCompletesTokensWithoutProfileOrMobileRegistration {
  RecordingWebView *web = [RecordingWebView new]; __block NSUInteger calls = 0;
  [self.provider loginInWebView:web completion:^(BOOL success, NSError *error) { calls++; XCTAssertTrue(success); XCTAssertNil(error); }];
  [self.transport respond:0 text:@"oauth_token=rt&oauth_token_secret=rs" status:200 error:nil];
  [self until:^BOOL{ return web.recordedRequest != nil; }];
  FixtureNavigationAction *action = [FixtureNavigationAction new]; action.fixtureRequest = [NSURLRequest requestWithURL:[NSURL URLWithString:@"http://localhost/?oauth_token=rt&oauth_verifier=v"]];
  [web.navigationDelegate webView:web decidePolicyForNavigationAction:action decisionHandler:^(WKNavigationActionPolicy policy) { XCTAssertEqual(policy, WKNavigationActionPolicyCancel); }];
  [self until:^BOOL{ return self.transport.requests.count == 2; }];
  [self.transport respond:1 text:@"oauth_token=at&oauth_token_secret=as" status:200 error:nil];
  [self until:^BOOL{ return calls == 1; }];
  XCTAssertEqual(calls, 1u); XCTAssertEqual(self.transport.requests.count, 2u); XCTAssertNil(self.store.loadSession.identity);
  XCTAssertEqualObjects(self.provider.legacyToken, @"at"); XCTAssertEqualObjects(self.provider.legacySecret, @"as");
}

- (void)testFacadeInternalCompositionAcceptsProviderWithoutOAuthOrBrowserFields {
  MemoryStore *store = [MemoryStore new]; FakeAuthenticationProvider *provider = [FakeAuthenticationProvider new]; provider.available = YES;
  [store updateProviderState:@{@"opaque-envelope":@"fixture"} forProvider:provider.identifier];
  [store updateIdentity:[[USPIdentity alloc] initWithMetadata:@{@"wsuserid":@"mobile", @"nomeUsuario":@"Fixture"}]];
  USPAuthService *service = [[USPAuthService alloc] initWithCoordinator:[[USPAuthenticationCoordinator alloc] initWithProvider:provider store:store mobileClient:[self mobile]] legacyProvider:nil];
  XCTAssertTrue(service.isLoggedIn); XCTAssertEqualObjects(service.currentWSUserId, @"mobile"); XCTAssertEqualObjects(service.currentUser.nomeUsuario, @"Fixture");
  [service ensureLoggedInFromViewController:self.presenter completion:^(USPAuthUser *user, NSError *error) { XCTAssertNotNil(user); XCTAssertNil(error); }];
  XCTAssertEqual(provider.calls, 0u); XCTAssertNil(service.oauthToken); XCTAssertNil(service.oauthTokenSecret);
  [service logout]; XCTAssertNil(service.currentUser); XCTAssertFalse(service.isLoggedIn);
}

- (void)testFacadeOAuth1InstanceRunsHandshakeIdentityAndMobileRegistrationWithoutSingleton {
  USPAuthenticationCoordinator *coordinator = [[USPAuthenticationCoordinator alloc] initWithProvider:self.provider store:self.store mobileClient:[self mobile]];
  USPAuthService *service = [[USPAuthService alloc] initWithCoordinator:coordinator legacyProvider:self.provider];
  service.config = self.provider.config; service.backendHeaderValue = @"fixture-header";
  __block NSUInteger calls = 0;
  [service ensureLoggedInFromViewController:self.presenter completion:^(USPAuthUser *user, NSError *error) { calls++; XCTAssertNil(error); XCTAssertEqualObjects(user.nomeUsuario, @"Fixture"); }];
  [self advanceToProfile];
  [self.transport respond:2 text:@"{\"wsuserid\":\"mobile\",\"nomeUsuario\":\"Fixture\"}" status:200 error:nil];
  XCTAssertEqual(self.transport.requests.count, 4u); XCTAssertEqualObjects([self bodyAt:3][@"token"], @"mobile");
  [self.transport respond:3 text:@"" status:201 error:nil];
  XCTAssertEqual(calls, 1u); XCTAssertTrue(service.isLoggedIn); XCTAssertEqualObjects(service.currentWSUserId, @"mobile");
  XCTAssertEqualObjects(service.oauthToken, @"at"); XCTAssertEqualObjects(service.oauthTokenSecret, @"as");
  [service logout]; XCTAssertNil(service.currentUser); XCTAssertEqual(self.transport.requests.count, 4u);
}
@end
