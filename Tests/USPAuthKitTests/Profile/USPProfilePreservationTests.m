#import "USPAuthArchitectureTestCase.h"
#import "USPOAuth1AuthenticationProvider.h"

@implementation USPAuthArchitectureTests (USPProfilePreservationTests)
- (void)testOriginalProfileRelationshipsSurviveProviderIdentityLegacyUserDataAndRestoration {
  // Synthetic singular-array shape confirmed in the real DEV/PROD integration.
  // Aliases/extra fields exercise raw-payload compatibility, without real profile data.
  NSDictionary *raw = @{@"wsuserid":@"fixture-id", @"nomeUsuario":@"Fixture",
    @"vinculo":@[@{@"nomeVinculo":@"Fixture Role A", @"nomeUnidade":@"Fixture Unit A", @"extraAlias":@[@"fixture"]},
                  @{@"tipoVinculo":@"Fixture Role B", @"siglaUnidade":@"Fixture Unit B"}],
    @"vinculos":@[@{@"unmodeled":@YES}], @"unmodeledProfileField":@{@"preserved":@YES}};
  USPMobileBackendClient *mobile = [self mobile];
  USPAuthService *service = [[USPAuthService alloc] initWithCoordinator:[[USPAuthenticationCoordinator alloc] initWithProvider:self.provider store:self.store mobileClient:mobile] legacyProvider:self.provider];
  service.config = self.provider.config;
  __block NSUInteger calls = 0;
  [service ensureLoggedInFromViewController:self.presenter completion:^(USPAuthUser *user, NSError *error) {
    calls++; XCTAssertNil(error); XCTAssertEqual(user.vinculos.count, 2u);
  }];
  [self advanceToProfile];
  NSData *json = [NSJSONSerialization dataWithJSONObject:raw options:0 error:nil];
  [self.transport respond:2 text:[[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding] status:200 error:nil];
  XCTAssertEqual(self.transport.requests.count, 4u);
  USPIdentity *identity = self.store.loadSession.identity;
  XCTAssertEqual(identity.user.vinculos.count, 2u); XCTAssertEqualObjects(identity.metadata, raw);
  XCTAssertEqualObjects(service.userData, raw); XCTAssertEqualObjects(self.store.userData, raw);
  [self.transport respond:3 text:@"" status:200 error:nil]; XCTAssertEqual(calls, 1u);
  USPAuthService *restored = [[USPAuthService alloc] initWithUserDefaults:self.defaults];
  XCTAssertEqual(restored.currentUser.vinculos.count, 2u); XCTAssertEqualObjects(restored.userData, raw);
  XCTAssertEqualObjects(restored.currentUser.vinculos.firstObject.nomeVinculo, @"Fixture Role A");
  XCTAssertEqualObjects(restored.currentUser.vinculos.lastObject.siglaUnidade, @"Fixture Unit B");
}

- (void)testLegacyBaselinePluralOnlyRelationshipsRemainRawEvenWhenTypedParserIgnoresThem {
  // Existing parser accepts only singular array. Do not silently normalize legacy JSON.
  for (id field in @[@[@{@"nomeVinculo":@"Fixture Role", @"nomeUnidade":@"Fixture Unit"}],
                     @{@"nomeVinculo":@"Fixture Role"}, NSNull.null]) {
    NSDictionary *raw = @{@"vinculos":field, @"wsuserid":@"fixture-id"};
    USPIdentity *identity = [[USPIdentity alloc] initWithMetadata:raw];
    XCTAssertEqual(identity.user.vinculos.count, 0u); XCTAssertEqualObjects(identity.metadata, raw);
    [self.store updateIdentity:identity];
    USPAuthService *restored = [[USPAuthService alloc] initWithUserDefaults:self.defaults];
    XCTAssertEqualObjects(restored.userData, raw); XCTAssertEqual(restored.currentUser.vinculos.count, 0u);
    XCTAssertNil(restored.userData[@"vinculo"]);
  }
}
@end
