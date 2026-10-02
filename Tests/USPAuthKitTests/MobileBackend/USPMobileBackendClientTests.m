#import "USPAuthArchitectureTestCase.h"

@implementation USPAuthArchitectureTests (USPMobileBackendClientTests)
- (void)testMobileWirePayloadAndHeaderAreIndependentOfProvider {
  __block BOOL done = NO;
  [[self mobile] registerUserIdentifier:@"mobile-opaque" notificationToken:@"push" platform:@"F" completion:^(NSError *error) { XCTAssertNil(error); done = YES; }];
  XCTAssertEqualObjects(self.transport.requests[0].URL.path, @"/mobile/servicos/oauth/registrar");
  XCTAssertEqualObjects([self bodyAt:0], (@{@"token":@"mobile-opaque", @"tokenNotificacao":@"push", @"app":@"fixture-app", @"ambiente":@"I", @"plataformaNotificacao":@"F"}));
  XCTAssertEqualObjects([self.transport.requests[0] valueForHTTPHeaderField:@"DEV-USP-MOBILE"], @"fixture-header");
  XCTAssertNil([self.transport.requests[0] valueForHTTPHeaderField:@"Authorization"]);
  [self.transport respond:0 text:@"ignored" status:201 error:nil]; XCTAssertTrue(done);
}

- (void)testMobileStatusFailureAndMissingCredential {
  __block NSInteger code = 0;
  [[self mobile] registerUserIdentifier:@"mobile" notificationToken:nil platform:@"F" completion:^(NSError *error) { code = error.code; }];
  [self.transport respond:0 text:@"{}" status:401 error:nil]; XCTAssertEqual(code, 401);
  [[self mobile] registerUserIdentifier:nil notificationToken:nil platform:@"F" completion:^(NSError *error) { code = error.code; }]; XCTAssertEqual(code, 1006); XCTAssertEqual(self.transport.requests.count, 1u);
}

- (void)testMobileCheckEmptyInvalidAndDictionaryResponses {
  for (NSString *body in @[@"", @"[]", @"{\"valid\":true}"]) {
    NSUInteger index = self.transport.requests.count;
    __block NSDictionary *payload; __block NSError *failure;
    [[self mobile] checkUserIdentifier:@"mobile" completion:^(NSDictionary *result, NSError *error) { payload = result; failure = error; }];
    XCTAssertEqualObjects(self.transport.requests[index].URL.path, @"/mobile/servicos/oauth/consultar");
    [self.transport respond:index text:body status:200 error:nil];
    if ([body isEqual:@"[]"]) { XCTAssertEqual(failure.code, 1005); XCTAssertNil(payload); } else { XCTAssertNil(failure); XCTAssertNotNil(payload); }
  }
}

- (void)testMobileInvalidateUsesMobileCredentialAndDoesNotClearStore {
  [self.store updateIdentity:[[USPIdentity alloc] initWithMetadata:@{@"wsuserid":@"mobile"}]];
  [[self mobile] invalidateUserIdentifier:self.store.loadSession.identity.user.wsuserid completion:^(NSError *error) { XCTAssertNil(error); }];
  XCTAssertEqualObjects(self.transport.requests[0].URL.path, @"/mobile/servicos/oauth/invalidar"); XCTAssertEqualObjects([self bodyAt:0], (@{@"token":@"mobile", @"app":@"fixture-app"}));
  [self.transport respond:0 text:@"" status:204 error:nil]; XCTAssertNotNil(self.store.loadSession.identity);
}

- (void)testMobileOperationsCancelOnceOnLogoutAndIgnoreLateResponses {
  MemoryStore *store = [MemoryStore new];
  [store updateIdentity:[[USPIdentity alloc] initWithMetadata:@{@"wsuserid":@"mobile"}]];
  USPAuthenticationCoordinator *coordinator = [[USPAuthenticationCoordinator alloc] initWithProvider:[FakeAuthenticationProvider new] store:store mobileClient:[self mobile]];
  __block NSUInteger checks = 0, invalidations = 0;
  [coordinator checkWithCompletion:^(NSDictionary *payload, NSError *error) { checks++; XCTAssertNil(payload); XCTAssertEqual(error.code, NSUserCancelledError); XCTAssertNil(coordinator.session.identity); }];
  [coordinator invalidateWithCompletion:^(NSError *error) { invalidations++; XCTAssertEqual(error.code, NSUserCancelledError); }];
  [coordinator logout]; XCTAssertEqual(checks, 1u); XCTAssertEqual(invalidations, 1u);
  [self.transport respond:0 text:@"{}" status:200 error:nil]; [self.transport respond:1 text:@"" status:200 error:nil];
  XCTAssertEqual(checks, 1u); XCTAssertEqual(invalidations, 1u);
  XCTAssertTrue(self.transport.handles[0].cancelled); XCTAssertTrue(self.transport.handles[1].cancelled);
}
@end
