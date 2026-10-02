#import "USPAuthArchitectureTestCase.h"

@implementation USPAuthArchitectureTests (USPAuthSessionStoreTests)
- (void)testStoreSaveLoadPartialClearAndUnknownValidity {
  USPAuthSession *session = [USPAuthSession new]; session.providerIdentifier = @"oauth1"; session.providerState = @{@"token":@"fixture"}; session.identity = [[USPIdentity alloc] initWithMetadata:@{@"wsuserid":@"mobile"}];
  [self.store saveSession:session];
  XCTAssertFalse(self.store.loadSession.validityKnown);
  XCTAssertFalse([self.store hasValidSession]); XCTAssertEqualObjects(self.store.loadSession.identity.user.wsuserid, @"mobile");
  [self.store updateProviderState:@{@"token":@"fixture", @"secret":@"fixture-secret"} forProvider:@"oauth1"];
  XCTAssertTrue([self.store hasValidSession]);
  self.store.notificationToken = @"push"; self.store.isRegistered = YES;
  [self.store clearSession]; XCTAssertNil(self.store.loadSession.identity); XCTAssertFalse(self.store.isRegistered); XCTAssertEqualObjects(self.store.notificationToken, @"push");
  [self.store clearAll]; XCTAssertNil(self.store.notificationToken); XCTAssertEqualObjects(self.store.notificationPlatform, @"F");
}

- (void)testStoreCorruptPayloadIsNotDeletedAndSuitesAreIsolated {
  NSData *corrupt = [@"not-json" dataUsingEncoding:NSUTF8StringEncoding]; [self.defaults setObject:corrupt forKey:@"userData"];
  XCTAssertNil(self.store.loadSession.identity); XCTAssertEqualObjects([self.defaults dataForKey:@"userData"], corrupt);
  NSString *otherSuite = [self.suite stringByAppendingString:@".other"]; NSUserDefaults *other = [[NSUserDefaults alloc] initWithSuiteName:otherSuite];
  [other removePersistentDomainForName:otherSuite]; USPAuthSessionStore *otherStore = [[USPAuthSessionStore alloc] initWithDefaults:other];
  self.store.oauthToken = @"only-here"; XCTAssertNil(otherStore.oauthToken); [other removePersistentDomainForName:otherSuite];
}

- (void)testTypedProfileRoundTripsThroughLegacyStoreWithoutSeparateUserIdentifierState {
  USPIdentity *identity = [[USPIdentity alloc] initWithUser:[self standardFixtureUser]];
  [self.store updateIdentity:identity];
  [self assertStandardProfile:self.store.loadSession.identity.user];
  XCTAssertNil(self.store.oauthToken); XCTAssertNil(self.store.oauthTokenSecret);
  XCTAssertEqualObjects(self.store.userData[@"wsuserid"], @"usp-operational-id");
  XCTAssertEqualObjects(self.store.userData[@"vinculo"][0][@"siglaUnidade"], @"FU");
}
@end
