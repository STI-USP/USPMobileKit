#import "USPAuthArchitectureTestCase.h"

@implementation USPAuthArchitectureTests (USPAuthBrowserTests)
- (void)testWKBrowserUsesNavigationActionURLAndConsumesCallbackOnce {
  WKWebView *web = [RecordingWebView new]; USPWKAuthBrowser *browser = [[USPWKAuthBrowser alloc] initWithWebView:web];
  __block NSUInteger calls = 0; [browser begin:^{} cancellation:^(NSError *error) {}];
  [browser openURL:[NSURL URLWithString:@"https://example.invalid"] matching:^BOOL(NSURL *url) { return [url.host isEqual:@"localhost"]; } completion:^(NSURL *url, NSError *error) { calls++; XCTAssertEqualObjects(url.host, @"localhost"); }];
  FixtureNavigationAction *action = [FixtureNavigationAction new]; action.fixtureRequest = [NSURLRequest requestWithURL:[NSURL URLWithString:@"http://localhost/?fixture=1"]];
  [browser webView:web decidePolicyForNavigationAction:action decisionHandler:^(WKNavigationActionPolicy policy) { XCTAssertEqual(policy, WKNavigationActionPolicyCancel); }];
  [browser webView:web decidePolicyForNavigationAction:action decisionHandler:^(WKNavigationActionPolicy policy) { XCTAssertEqual(policy, WKNavigationActionPolicyAllow); }];
  XCTAssertEqual(calls, 1u); [browser finish:^{}]; XCTAssertNil(web.navigationDelegate);
}

- (void)testLoginUIStartsInjectedOperationOnceWithoutSingleton {
  LoginWebViewController *controller = [LoginWebViewController new]; __block NSUInteger calls = 0; controller.ready = ^(WKWebView *web) { calls++; XCTAssertNotNil(web); };
  [controller loadViewIfNeeded]; [controller viewDidAppear:NO]; [controller viewDidAppear:NO]; XCTAssertEqual(calls, 1u); [controller disposeWebView];
}

- (void)testCallbackHandoffSurvivesReentrantPolicyFailureButExplicitCancelStillWorks {
  RecordingWebView *web = [RecordingWebView new]; USPWKAuthBrowser *browser = [[USPWKAuthBrowser alloc] initWithWebView:web];
  __block NSUInteger callbacks = 0, cancellations = 0;
  [browser begin:^{} cancellation:^(NSError *error) { cancellations++; XCTAssertEqual(error.code, NSUserCancelledError); }];
  [browser openURL:[NSURL URLWithString:@"https://example.invalid/authorize"] matching:^BOOL(NSURL *url) { return [url.host isEqual:@"localhost"]; } completion:^(NSURL *url, NSError *error) { callbacks++; XCTAssertNotNil(url); XCTAssertNil(error); }];
  FixtureNavigationAction *action = [FixtureNavigationAction new]; action.fixtureRequest = [NSURLRequest requestWithURL:[NSURL URLWithString:@"http://localhost/?oauth_token=rt&oauth_verifier=v"]];
  [browser webView:web decidePolicyForNavigationAction:action decisionHandler:^(WKNavigationActionPolicy policy) {
    XCTAssertEqual(policy, WKNavigationActionPolicyCancel);
    [browser webView:web didFailProvisionalNavigation:nil withError:[NSError errorWithDomain:@"WebKitErrorDomain" code:102 userInfo:nil]];
  }];
  XCTAssertEqual(callbacks, 1u); XCTAssertEqual(cancellations, 0u);
  [browser cancel]; [browser cancel]; XCTAssertEqual(cancellations, 1u); XCTAssertEqual(callbacks, 1u);
}
@end
