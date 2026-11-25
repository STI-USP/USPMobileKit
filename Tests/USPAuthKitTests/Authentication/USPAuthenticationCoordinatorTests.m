#import "USPAuthArchitectureTestCase.h"

@implementation USPAuthArchitectureTests (USPAuthenticationCoordinatorTests)
- (void)testCoordinatorAlternativeProviderSuccessProfileRegistrationAndCache {
  MemoryStore *store = [MemoryStore new]; FakeAuthenticationProvider *provider = [FakeAuthenticationProvider new]; USPAuthenticationCoordinator *coordinator = [[USPAuthenticationCoordinator alloc] initWithProvider:provider store:store mobileClient:[self mobile]];
  __block USPAuthUser *result; [coordinator ensureFromViewController:self.presenter completion:^(USPAuthUser *user, NSError *error) { XCTAssertNil(error); result = user; }];
  [store updateProviderState:@{@"opaque-envelope":@"fixture"} forProvider:provider.identifier]; provider.available = YES;
  provider.result([[USPIdentity alloc] initWithMetadata:@{@"wsuserid":@"mobile", @"nomeUsuario":@"Fixture"}], nil);
  XCTAssertNotNil(store.session.identity); XCTAssertNil(result); [self.transport respond:0 text:@"" status:200 error:nil];
  XCTAssertTrue(store.isRegistered); XCTAssertEqualObjects(result.nomeUsuario, @"Fixture"); XCTAssertTrue(coordinator.isLoggedIn);
  __block BOOL cachedCompleted = NO;
  [coordinator ensureFromViewController:self.presenter completion:^(USPAuthUser *user, NSError *error) { XCTAssertNotNil(user); XCTAssertNil(error); cachedCompleted = YES; }];
  XCTAssertFalse(cachedCompleted); XCTAssertEqual(provider.calls, 1u); XCTAssertEqual(self.transport.requests.count, 2u);
  [self.transport respond:1 text:@"" status:200 error:nil]; XCTAssertTrue(cachedCompleted);
}

- (void)testCoordinatorRetriesFailedRegistrationBeforeReturningCachedUser {
  MemoryStore *store = [MemoryStore new]; FakeAuthenticationProvider *provider = [FakeAuthenticationProvider new]; USPAuthenticationCoordinator *coordinator = [[USPAuthenticationCoordinator alloc] initWithProvider:provider store:store mobileClient:[self mobile]];
  __block NSInteger code = 0; [coordinator ensureFromViewController:self.presenter completion:^(USPAuthUser *user, NSError *error) { XCTAssertNil(user); code = error.code; }];
  provider.available = YES; provider.result([[USPIdentity alloc] initWithMetadata:@{@"wsuserid":@"mobile"}], nil);
  [self.transport respond:0 text:@"" status:503 error:nil]; XCTAssertEqual(code, 503); XCTAssertNotNil(store.session.identity); XCTAssertFalse(store.isRegistered);
  __block BOOL completed = NO;
  [coordinator ensureFromViewController:self.presenter completion:^(USPAuthUser *user, NSError *error) { XCTAssertNotNil(user); XCTAssertNil(error); completed = YES; }];
  XCTAssertFalse(completed); XCTAssertEqual(self.transport.requests.count, 2u); XCTAssertEqual(provider.calls, 1u);
  [self.transport respond:1 text:@"" status:200 error:nil]; XCTAssertTrue(completed); XCTAssertTrue(store.isRegistered);
}

- (void)testCachedRegistrationFailureDoesNotReturnUser {
  MemoryStore *store = [MemoryStore new]; FakeAuthenticationProvider *provider = [FakeAuthenticationProvider new]; provider.available = YES;
  [store updateIdentity:[[USPIdentity alloc] initWithMetadata:@{@"wsuserid":@"mobile"}]];
  USPAuthenticationCoordinator *coordinator = [[USPAuthenticationCoordinator alloc] initWithProvider:provider store:store mobileClient:[self mobile]];
  __block NSInteger code = 0;
  [coordinator ensureFromViewController:self.presenter completion:^(USPAuthUser *user, NSError *error) { XCTAssertNil(user); code = error.code; }];
  [self.transport respond:0 text:@"" status:503 error:nil]; XCTAssertEqual(code, 503); XCTAssertFalse(store.isRegistered); XCTAssertNotNil(store.session.identity);
}

- (void)testCachedRegistrationUsesCurrentIdentityEvenWhenPreviouslyRegistered {
  MemoryStore *store = [MemoryStore new]; FakeAuthenticationProvider *provider = [FakeAuthenticationProvider new]; provider.available = YES; store.isRegistered = YES;
  [store updateIdentity:[[USPIdentity alloc] initWithMetadata:@{@"wsuserid":@"other-user"}]];
  USPAuthenticationCoordinator *coordinator = [[USPAuthenticationCoordinator alloc] initWithProvider:provider store:store mobileClient:[self mobile]];
  __block BOOL completed = NO;
  [coordinator ensureFromViewController:self.presenter completion:^(USPAuthUser *user, NSError *error) { XCTAssertNil(error); XCTAssertEqualObjects(user.wsuserid, @"other-user"); completed = YES; }];
  XCTAssertEqualObjects([self bodyAt:0][@"token"], @"other-user"); XCTAssertFalse(completed);
  [self.transport respond:0 text:@"" status:200 error:nil]; XCTAssertTrue(completed);
}

- (void)testLogoutCancelsCachedRegistrationAndIgnoresLateResult {
  MemoryStore *store = [MemoryStore new]; FakeAuthenticationProvider *provider = [FakeAuthenticationProvider new]; provider.available = YES;
  [store updateIdentity:[[USPIdentity alloc] initWithMetadata:@{@"wsuserid":@"mobile"}]];
  USPAuthenticationCoordinator *coordinator = [[USPAuthenticationCoordinator alloc] initWithProvider:provider store:store mobileClient:[self mobile]];
  __block NSUInteger calls = 0;
  [coordinator ensureFromViewController:self.presenter completion:^(USPAuthUser *user, NSError *error) { calls++; XCTAssertNil(user); XCTAssertEqual(error.code, NSUserCancelledError); }];
  [coordinator logout]; XCTAssertTrue(self.transport.handles[0].cancelled);
  [self.transport respond:0 text:@"" status:200 error:nil];
  XCTAssertEqual(calls, 1u); XCTAssertFalse(store.isRegistered); XCTAssertNil(store.session.identity);
}

- (void)testTokenArrivingDuringLoginIsRegisteredAfterLogin {
  MemoryStore *store = [MemoryStore new]; FakeAuthenticationProvider *provider = [FakeAuthenticationProvider new];
  [store updateProviderState:@{@"opaque-envelope":@"fixture"} forProvider:provider.identifier];
  USPAuthenticationCoordinator *coordinator = [[USPAuthenticationCoordinator alloc] initWithProvider:provider store:store mobileClient:[self mobile]];
  [coordinator ensureFromViewController:self.presenter completion:^(__unused USPAuthUser *user, NSError *error) { XCTAssertNil(error); }];
  provider.available = YES; provider.result([[USPIdentity alloc] initWithMetadata:@{@"wsuserid":@"mobile"}], nil);
  [coordinator updateNotificationToken:@"new-push"]; XCTAssertEqual(self.transport.requests.count, 1u);
  [self.transport respond:0 text:@"" status:200 error:nil]; XCTAssertEqual(self.transport.requests.count, 2u);
  XCTAssertEqualObjects([self bodyAt:1][@"tokenNotificacao"], @"new-push");
  [self.transport respond:1 text:@"" status:200 error:nil];
}

- (void)testFailedPushRegistrationCanRetrySameToken {
  MemoryStore *store = [MemoryStore new]; FakeAuthenticationProvider *provider = [FakeAuthenticationProvider new]; provider.available = YES;
  [store updateProviderState:@{@"opaque-envelope":@"fixture"} forProvider:provider.identifier];
  [store updateIdentity:[[USPIdentity alloc] initWithMetadata:@{@"wsuserid":@"mobile"}]];
  USPAuthenticationCoordinator *coordinator = [[USPAuthenticationCoordinator alloc] initWithProvider:provider store:store mobileClient:[self mobile]];
  [coordinator updateNotificationToken:@"push"]; [self.transport respond:0 text:@"" status:503 error:nil];
  [coordinator updateNotificationToken:@"push"]; XCTAssertEqual(self.transport.requests.count, 2u);
  [self.transport respond:1 text:@"" status:200 error:nil];
}

- (void)testCoordinatorConcurrentAttemptErrorAndProviderFailure {
  MemoryStore *store = [MemoryStore new]; FakeAuthenticationProvider *provider = [FakeAuthenticationProvider new]; USPAuthenticationCoordinator *coordinator = [[USPAuthenticationCoordinator alloc] initWithProvider:provider store:store mobileClient:[self mobile]];
  __block NSInteger first = 0, second = 0;
  [coordinator ensureFromViewController:self.presenter completion:^(USPAuthUser *user, NSError *error) { first = error.code; }];
  [coordinator ensureFromViewController:self.presenter completion:^(USPAuthUser *user, NSError *error) { second = error.code; }]; XCTAssertEqual(second, 1001);
  provider.result(nil, USPAuthError(1000, @"fixture")); XCTAssertEqual(first, 1000); XCTAssertEqual(self.transport.requests.count, 0u);
}

- (void)testCoordinatorLogoutDiscardsLateProviderAndRegistrationResults {
  for (NSNumber *stage in @[@0, @1]) {
    MemoryStore *store = [MemoryStore new]; FakeAuthenticationProvider *provider = [FakeAuthenticationProvider new]; USPAuthenticationCoordinator *coordinator = [[USPAuthenticationCoordinator alloc] initWithProvider:provider store:store mobileClient:[self mobile]];
    __block NSUInteger calls = 0; [coordinator ensureFromViewController:self.presenter completion:^(USPAuthUser *user, NSError *error) { calls++; XCTAssertEqual(error.code, NSUserCancelledError); }];
    if (stage.boolValue) provider.result([[USPIdentity alloc] initWithMetadata:@{@"wsuserid":@"mobile"}], nil);
    [coordinator logout]; XCTAssertTrue(provider.cancelled); XCTAssertNil(store.session.identity); XCTAssertFalse(store.isRegistered);
    if (stage.boolValue) { NSUInteger index = self.transport.requests.count-1; XCTAssertTrue(self.transport.handles[index].cancelled); [self.transport respond:index text:@"" status:200 error:nil]; }
    else provider.result([[USPIdentity alloc] initWithMetadata:@{@"wsuserid":@"late"}], nil);
    XCTAssertEqual(calls, 1u); XCTAssertNil(store.session.identity); XCTAssertFalse(store.isRegistered);
  }
}

- (void)testCoordinatorPushUpdateAndLogoutAreLocal {
  MemoryStore *store = [MemoryStore new]; FakeAuthenticationProvider *provider = [FakeAuthenticationProvider new]; provider.available = YES; [store updateProviderState:@{@"opaque-envelope":@"fixture"} forProvider:provider.identifier];
  [store updateIdentity:[[USPIdentity alloc] initWithMetadata:@{@"wsuserid":@"mobile"}]];
  USPAuthenticationCoordinator *coordinator = [[USPAuthenticationCoordinator alloc] initWithProvider:provider store:store mobileClient:[self mobile]];
  [coordinator updateNotificationToken:@"push"]; XCTAssertEqual(self.transport.requests.count, 1u); XCTAssertEqualObjects([self bodyAt:0][@"tokenNotificacao"], @"push");
  [self.transport respond:0 text:@"" status:200 error:nil]; [coordinator updateNotificationToken:@"push"]; XCTAssertEqual(self.transport.requests.count, 1u);
  [coordinator logout]; XCTAssertEqual(self.transport.requests.count, 1u); XCTAssertNil(coordinator.notificationToken); XCTAssertFalse(coordinator.isLoggedIn);
}
@end
