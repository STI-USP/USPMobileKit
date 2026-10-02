#import "USPAuthArchitectureTestCase.h"
#import "USPOAuth1AuthenticationProvider.h"
#import "OAuth1Controller.h"
#import "NSString+URLEncoding.h"

@implementation USPAuthArchitectureTests (USPOAuth1ProviderTests)
- (void)testProviderCompletesHandshakeProfileThroughInjectedBrowser {
  __block USPIdentity *result; __block NSError *failure;
  [self.provider authenticateFromViewController:self.presenter completion:^(USPIdentity *identity, NSError *error) { result = identity; failure = error; }];
  XCTAssertEqual(self.browser.begins, 1u); XCTAssertEqualObjects(self.transport.requests[0].URL.path, @"/wsusuario/oauth/request_token");
  [self advanceToProfile];
  XCTAssertTrue(self.browser.finished); XCTAssertEqualObjects(self.provider.legacyToken, @"at"); XCTAssertEqualObjects(self.provider.legacySecret, @"as");
  XCTAssertEqualObjects(self.transport.requests[2].URL.path, @"/wsusuario/oauth/usuariousp"); XCTAssertNotNil([self.transport.requests[2] valueForHTTPHeaderField:@"Authorization"]);
  [self.transport respond:2 text:@"{\"nomeUsuario\":\"Fixture\",\"wsuserid\":\"mobile\"}" status:200 error:nil];
  XCTAssertNil(failure); XCTAssertEqualObjects(result.user.wsuserid, @"mobile"); XCTAssertEqualObjects(result.user.nomeUsuario, @"Fixture");
  XCTAssertNil(self.store.loadSession.identity); // coordinator owns identity persistence
}

- (void)testProviderRequestTokenErrorAndInvalidResponse {
  __block NSInteger code = 0;
  [self.provider authenticateFromViewController:self.presenter completion:^(USPIdentity *identity, NSError *error) { code = error.code; }];
  [self.transport respond:0 text:@"oauth_token=partial" status:200 error:nil]; [self until:^BOOL { return code != 0; }]; XCTAssertEqual(code, 100);
  [self.provider authenticateFromViewController:self.presenter completion:^(USPIdentity *identity, NSError *error) { code = error.code; }];
  [self.transport respond:1 text:nil status:0 error:[NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorTimedOut userInfo:nil]];
  [self until:^BOOL { return code == NSURLErrorTimedOut; }];
}

- (void)testLegacyBaselineProviderIgnoresHTTPStatusOnTokenAndProfile {
  __block USPIdentity *result;
  [self.provider authenticateFromViewController:self.presenter completion:^(USPIdentity *identity, NSError *error) { XCTAssertNil(error); result = identity; }];
  [self.transport respond:0 text:@"oauth_token=rt&oauth_token_secret=rs" status:500 error:nil]; [self until:^BOOL { return self.browser.url != nil; }];
  self.browser.callback([NSURL URLWithString:@"localhost?oauth_token=rt&oauth_verifier=verify"], nil);
  [self.transport respond:1 text:@"oauth_token=at&oauth_token_secret=as" status:403 error:nil]; [self until:^BOOL { return self.transport.requests.count == 3; }];
  [self.transport respond:2 text:@"{\"wsuserid\":\"mobile\"}" status:500 error:nil]; XCTAssertNotNil(result);
}

- (void)testProviderProfileFailurePreservesPreviouslyAcquiredCredential {
  __block NSError *failure;
  [self.provider authenticateFromViewController:self.presenter completion:^(USPIdentity *identity, NSError *error) { failure = error; }]; [self advanceToProfile];
  [self.transport respond:2 text:@"invalid" status:200 error:nil]; XCTAssertEqual(failure.code, 1005); XCTAssertEqualObjects(self.store.oauthToken, @"at"); XCTAssertNil(self.store.userData);
}

- (void)testProviderRejectsConcurrentAttempt {
  [self.provider authenticateFromViewController:self.presenter completion:^(USPIdentity *identity, NSError *error) {}];
  __block NSInteger code = 0; [self.provider authenticateFromViewController:self.presenter completion:^(USPIdentity *identity, NSError *error) { code = error.code; }]; XCTAssertEqual(code, 1001); XCTAssertEqual(self.transport.requests.count, 1u);
}

- (void)testProviderCancellationBeforeRequestAfterCallbackAndDuringProfileDiscardsLateResults {
  for (NSNumber *stage in @[@0, @1, @2]) {
    self.transport = [FakeTransport new]; self.browser = [FakeBrowser new]; FakeBrowser *browser = self.browser;
    self.provider = [[USPOAuth1AuthenticationProvider alloc] initWithStore:self.store transport:self.transport browserFactory:^id<USPAuthBrowser>(UIViewController *presenter) { return browser; } clock:^{ return NSDate.date; } nonce:^{ return @"nonce"; }];
    self.provider.config = [USPAuthConfig customWithBaseURL:@"https://example.invalid" consumerKey:@"ck" consumerSecret:@"cs" appKey:@"fixture"];
    __block NSUInteger calls = 0; [self.provider authenticateFromViewController:self.presenter completion:^(USPIdentity *identity, NSError *error) { calls++; XCTAssertEqual(error.code, NSUserCancelledError); }];
    if (stage.integerValue >= 1) { [self advanceToAuthorization]; self.browser.callback([NSURL URLWithString:@"http://localhost/?oauth_token=rt&oauth_verifier=verify"], nil); }
    if (stage.integerValue >= 2) { [self.transport respond:1 text:@"oauth_token=at&oauth_token_secret=as" status:200 error:nil]; [self until:^BOOL { return self.transport.requests.count == 3; }]; }
    [self.provider cancel]; [self.provider clearCredential]; [self.store clearAll];
    NSUInteger index = self.transport.requests.count-1;
    XCTAssertTrue(self.transport.handles[index].cancelled);
    [self.transport respond:index text:@"oauth_token=late&oauth_token_secret=late" status:200 error:nil];
    [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
    XCTAssertEqual(calls, 1u); XCTAssertNil(self.store.oauthToken); XCTAssertTrue(self.browser.finished);
  }
}

- (void)testBrowserCancellationCompletesProviderOnce {
  __block NSUInteger calls = 0; [self.provider authenticateFromViewController:self.presenter completion:^(USPIdentity *identity, NSError *error) { calls++; XCTAssertEqual(error.code, NSUserCancelledError); }];
  [self.browser cancel]; [self.browser cancel]; XCTAssertEqual(calls, 1u); XCTAssertTrue(self.transport.handles[0].cancelled);
}

- (void)testCallbackValidationDestinationCorrelationDuplicatesAndFragment {
  for (NSString *valid in @[@"http://localhost/?oauth_token=rt&oauth_verifier=v", @"https://localhost/?oauth_token=rt&oauth_verifier=v#_= _", @"localhost?oauth_token=rt&oauth_verifier=v"]) {
    NSString *normalized = [valid stringByReplacingOccurrencesOfString:@"_= _" withString:@"_=_"];
    XCTAssertNotNil([OAuth1Controller validatedCallbackURL:[NSURL URLWithString:normalized] requestToken:@"rt"]);
  }
  for (NSString *invalid in @[@"https://evil.invalid/?oauth_token=rt&oauth_verifier=v", @"http://localhost/other?oauth_token=rt&oauth_verifier=v", @"http://localhost/?oauth_token=other&oauth_verifier=v", @"http://localhost/?oauth_token=rt&oauth_verifier=", @"http://localhost/?oauth_token=rt&oauth_verifier=v&oauth_verifier=x", @"http://localhost/?oauth_token=rt&oauth_verifier=v#unexpected"]) XCTAssertNil([OAuth1Controller validatedCallbackURL:[NSURL URLWithString:invalid] requestToken:@"rt"]);
}

- (void)testCallbackAcceptsLocalHTTPDestinationsWithOptionalPortAndLoginPath {
  for (NSString *destination in @[@"http://localhost/", @"http://localhost", @"http://localhost:49152/login.aspx", @"https://localhost:49152/login.aspx", @"http://localhost/login.aspx", @"http://localhost:80/", @"http://localhost:1/login.aspx", @"https://localhost:65535/login.aspx"]) {
    NSURL *url = [NSURL URLWithString:[destination stringByAppendingString:@"?oauth_token=rt&oauth_verifier=v"]];
    XCTAssertNotNil(url);
    XCTAssertNil([OAuth1Controller callbackRejectionReason:url requestToken:@"rt"], @"%@", destination);
    XCTAssertNotNil([OAuth1Controller validatedCallbackURL:url requestToken:@"rt"]);
  }
}

- (void)testCallbackRejectionReasonsPreservedForLocalLoginPath {
  NSDictionary *cases = @{
    @"http://other.invalid:49152/login.aspx?oauth_token=rt&oauth_verifier=v": @"destination",
    @"http://localhost:49152/other?oauth_token=rt&oauth_verifier=v": @"destination",
    @"http://user@localhost:49152/login.aspx?oauth_token=rt&oauth_verifier=v": @"destination",
    @"http://user:password@localhost:49152/login.aspx?oauth_token=rt&oauth_verifier=v": @"destination",
    @"http://localhost:0/login.aspx?oauth_token=rt&oauth_verifier=v": @"destination",
    @"http://localhost:65536/login.aspx?oauth_token=rt&oauth_verifier=v": @"destination",
    @"http://localhost:49152/login.aspx?oauth_token=other&oauth_verifier=v": @"token_mismatch",
    @"http://localhost:49152/login.aspx?oauth_token=rt": @"missing_verifier",
    @"http://localhost:49152/login.aspx?oauth_verifier=v": @"missing_token",
    @"http://localhost:49152/login.aspx?oauth_token=rt&oauth_verifier=v&oauth_verifier=x": @"duplicate_query",
    @"http://localhost:49152/login.aspx?oauth_token=rt&oauth_verifier=v#unexpected": @"fragment"
  };
  for (NSString *callback in cases) {
    NSURL *url = [NSURL URLWithString:callback];
    XCTAssertNotNil(url);
    XCTAssertEqualObjects([OAuth1Controller callbackRejectionReason:url requestToken:@"rt"], cases[callback], @"%@", callback);
  }
  XCTAssertNil([OAuth1Controller callbackRejectionReason:[NSURL URLWithString:@"https://localhost:49152/login.aspx?oauth_token=rt&oauth_verifier=v#_=_"] requestToken:@"rt"]);
}

- (void)testInvalidCallbackDoesNotExchangeAccessToken {
  __block NSInteger code = 0; [self.provider authenticateFromViewController:self.presenter completion:^(USPIdentity *identity, NSError *error) { code = error.code; }]; [self advanceToAuthorization];
  self.browser.callback([NSURL URLWithString:@"https://evil.invalid/?oauth_token=rt&oauth_verifier=v"], nil); XCTAssertEqual(code, 101); XCTAssertEqual(self.transport.requests.count, 1u);
}

- (void)testDuplicateBrowserCallbackDoesNotRepeatAccessExchange {
  __block NSUInteger calls = 0; [self.provider authenticateFromViewController:self.presenter completion:^(USPIdentity *identity, NSError *error) { calls++; }]; [self advanceToAuthorization];
  NSURL *url = [NSURL URLWithString:@"http://localhost/?oauth_token=rt&oauth_verifier=v"];
  self.browser.callback(url, nil); self.browser.callback(url, nil);
  XCTAssertEqual(self.transport.requests.count, 2u);
}

- (void)testDeterministicLegacyBaseStringEncodingHeaderAndHMACVectors {
  NSDictionary *params = [OAuth1Controller standardParametersWithConsumerKey:@"ck" date:[NSDate dateWithTimeIntervalSince1970:1700000000.9] nonce:@"abcdef123"];
  XCTAssertEqualObjects([OAuth1Controller baseStringWithMethod:@"POST" url:@"https://example.invalid/wsusuario/oauth/request_token" parameters:params], @"POST&https%3A%2F%2Fexample.invalid%2Fwsusuario%2Foauth%2Frequest_token&oauth_consumer_key%3Dck%26oauth_nonce%3Dabcdef123%26oauth_signature_method%3DHMAC-SHA1%26oauth_timestamp%3D1700000000%26oauth_version%3D1.0");
  XCTAssertEqualObjects([OAuth1Controller signClearText:@"POST&https%3A%2F%2Fexample.invalid%2Fwsusuario%2Foauth%2Frequest_token&oauth_consumer_key%3Dck%26oauth_nonce%3Dabcdef123%26oauth_signature_method%3DHMAC-SHA1%26oauth_timestamp%3D1700000000%26oauth_version%3D1.0" withSecret:@"cs&"], @"pGn5alL8hgJO9UVS+0ZHfgpWYu4=");
  XCTAssertEqualObjects([@"Olá ~+%&" utf8AndURLEncode], @"Ol%C3%A1%20~%2B%25%26");
  XCTAssertTrue([[OAuth1Controller baseStringWithMethod:@"GET" url:@"https://example.invalid" parameters:@{@"fixture":@"~"}] containsString:@"%257E"]);
  [self.provider authenticateFromViewController:self.presenter completion:^(USPIdentity *identity, NSError *error) {}];
  NSDictionary *requestFields = [self authorizationFields:0];
  XCTAssertEqualObjects(requestFields, (@{@"oauth_consumer_key":@"ck",@"oauth_nonce":@"abcdef123",@"oauth_signature_method":@"HMAC-SHA1",@"oauth_timestamp":@"1700000000",@"oauth_version":@"1.0",@"oauth_signature":@"pGn5alL8hgJO9UVS+0ZHfgpWYu4="}));
  [self advanceToAuthorization];
  XCTAssertEqualObjects(self.browser.url.absoluteString, @"https://example.invalid/wsusuario/oauth/authorize?oauth_token=rt&oauth_callback=localhost");
  self.browser.callback([NSURL URLWithString:@"http://localhost/?oauth_token=rt&oauth_verifier=verify"], nil);
  XCTAssertEqualObjects([self authorizationFields:1][@"oauth_signature"], @"ur0j377Q+aMS0fD6y06nZK6w/wI=");
  XCTAssertEqualObjects([self authorizationFields:1][@"oauth_token"], @"rt");
  XCTAssertEqualObjects([self authorizationFields:1][@"oauth_verifier"], @"verify");
}

- (void)testBrowserFailureWithoutCallbackURLPreservesErrorCompletion {
  __block NSUInteger calls = 0;
  [self.provider authenticateFromViewController:self.presenter completion:^(USPIdentity *identity, NSError *error) { calls++; XCTAssertNil(identity); XCTAssertEqual(error.code, NSURLErrorCannotConnectToHost); }];
  [self advanceToAuthorization];
  self.browser.callback(nil, [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCannotConnectToHost userInfo:nil]);
  XCTAssertEqual(calls, 1u); XCTAssertEqual(self.transport.requests.count, 1u);
}

- (void)testUSPCallbackPolicyFailureAfterHandoffDoesNotCancelAccessExchangeAndConsumerCompletion {
  // Real Cardapio trace: valid localhost callback -> access started -> WK error102.
  // Exercise both WK failure delegate entry points with synthetic values only.
  for (NSNumber *provisional in @[@YES, @NO]) {
    [self.store clearAll];
    FakeTransport *transport = [FakeTransport new]; RecordingWebView *web = [RecordingWebView new];
    USPWKAuthBrowser *browser = [[USPWKAuthBrowser alloc] initWithWebView:web];
    USPOAuth1AuthenticationProvider *provider = [[USPOAuth1AuthenticationProvider alloc] initWithStore:self.store transport:transport browserFactory:^id<USPAuthBrowser>(UIViewController *presenter) { return browser; } clock:^{ return [NSDate dateWithTimeIntervalSince1970:1700000000]; } nonce:^{ return @"fixture-nonce"; }];
    USPMobileBackendClient *mobile = [[USPMobileBackendClient alloc] initWithTransport:transport];
    USPAuthService *service = [[USPAuthService alloc] initWithCoordinator:[[USPAuthenticationCoordinator alloc] initWithProvider:provider store:self.store mobileClient:mobile] legacyProvider:provider];
    service.config = [USPAuthConfig customWithBaseURL:@"https://example.invalid" consumerKey:@"ck" consumerSecret:@"cs" appKey:@"fixture-app"];
    service.backendHeaderValue = @"fixture-header";
    __block NSUInteger calls = 0; __block USPAuthUser *consumerUser;
    [service ensureLoggedInFromViewController:self.presenter completion:^(USPAuthUser *user, NSError *error) { calls++; XCTAssertNil(error); consumerUser = user; }];
    [transport respond:0 text:@"oauth_token=rt&oauth_token_secret=rs" status:200 error:nil];
    [self until:^BOOL{ return web.recordedRequest != nil; }];
    FixtureNavigationAction *action = [FixtureNavigationAction new];
    action.fixtureRequest = [NSURLRequest requestWithURL:[NSURL URLWithString:@"http://localhost/?oauth_callback=localhost&oauth_token=rt&oauth_verifier=fixture-verifier"]];
    [browser webView:web decidePolicyForNavigationAction:action decisionHandler:^(WKNavigationActionPolicy policy) { XCTAssertEqual(policy, WKNavigationActionPolicyCancel); }];
    XCTAssertEqual(transport.requests.count, 2u);
    NSError *policyError = [NSError errorWithDomain:@"WebKitErrorDomain" code:102 userInfo:nil];
    if (provisional.boolValue) [browser webView:web didFailProvisionalNavigation:nil withError:policyError];
    else [browser webView:web didFailNavigation:nil withError:policyError];
    XCTAssertFalse(transport.handles[1].cancelled, @"Navigation ended, but access exchange must remain active.");
    XCTAssertEqual(calls, 0u, @"Consumer must await identity/registration, not receive navigation error102.");
    // Avoid fixture out-of-bounds after the intentionally failing pre-fix assertions.
    if (transport.handles[1].cancelled || calls) { [service logout]; [transport.callbacks removeAllObjects]; continue; }
    [transport respond:1 text:@"oauth_token=at&oauth_token_secret=as" status:200 error:nil];
    [self until:^BOOL{ return transport.requests.count == 3; }];
    [transport respond:2 text:@"{\"wsuserid\":\"fixture-wsuserid\",\"nomeUsuario\":\"Fixture\"}" status:200 error:nil];
    XCTAssertEqual(transport.requests.count, 4u);
    NSDictionary *body = [NSJSONSerialization JSONObjectWithData:transport.requests[3].HTTPBody options:0 error:nil];
    XCTAssertEqualObjects(body[@"token"], @"fixture-wsuserid");
    [transport respond:3 text:@"" status:200 error:nil];
    XCTAssertEqual(calls, 1u); XCTAssertEqualObjects(consumerUser.wsuserid, @"fixture-wsuserid");
    XCTAssertEqualObjects(service.currentWSUserId, consumerUser.wsuserid); XCTAssertTrue(service.isLoggedIn);
    [service logout]; [transport.callbacks removeAllObjects];
  }
}

- (void)testBrowserFailureBeforeCallbackStillFailsAuthenticationIncludingError102 {
  RecordingWebView *web = [RecordingWebView new]; USPWKAuthBrowser *browser = [[USPWKAuthBrowser alloc] initWithWebView:web];
  __block NSUInteger callbacks = 0;
  [browser begin:^{} cancellation:^(NSError *error) { XCTFail(@"Expected navigation error result, not explicit cancellation."); }];
  [browser openURL:[NSURL URLWithString:@"https://example.invalid/authorize"] matching:^BOOL(NSURL *url) { return [url.host isEqual:@"localhost"]; } completion:^(NSURL *url, NSError *error) { callbacks++; XCTAssertNil(url); XCTAssertEqual(error.code, 102); }];
  [browser webView:web didFailNavigation:nil withError:[NSError errorWithDomain:@"WebKitErrorDomain" code:102 userInfo:nil]];
  XCTAssertEqual(callbacks, 1u); [browser finish:^{}];
}

- (void)testInvalidCallbackThroughWKBrowserRemainsTerminalDespiteLaterNavigationFailure {
  NSArray<NSString *> *callbacks = @[
    @"http://localhost/?oauth_token=other-token&oauth_verifier=v",
    @"http://localhost/?oauth_token=rt&oauth_verifier=",
    @"https://foreign.example.invalid/?oauth_token=rt&oauth_verifier=v"];
  for (NSString *callback in callbacks) {
    NSUInteger start = self.transport.requests.count; RecordingWebView *web = [RecordingWebView new];
    __block NSUInteger completions = 0;
    [self.provider loginInWebView:web completion:^(BOOL success, NSError *error) { completions++; XCTAssertFalse(success); XCTAssertEqual(error.code, 101); }];
    [self.transport respond:start text:@"oauth_token=rt&oauth_token_secret=rs" status:200 error:nil];
    [self until:^BOOL{ return web.recordedRequest != nil; }];
    id<WKNavigationDelegate> delegate = web.navigationDelegate;
    FixtureNavigationAction *action = [FixtureNavigationAction new]; action.fixtureRequest = [NSURLRequest requestWithURL:[NSURL URLWithString:callback]];
    [delegate webView:web decidePolicyForNavigationAction:action decisionHandler:^(WKNavigationActionPolicy policy) { XCTAssertEqual(policy, WKNavigationActionPolicyCancel); }];
    [delegate webView:web didFailNavigation:nil withError:[NSError errorWithDomain:@"WebKitErrorDomain" code:102 userInfo:nil]];
    XCTAssertEqual(completions, 1u); XCTAssertEqual(self.transport.requests.count, start + 1);
    XCTAssertNil(self.provider.legacyToken); XCTAssertNil(self.provider.legacySecret);
  }
}
@end
