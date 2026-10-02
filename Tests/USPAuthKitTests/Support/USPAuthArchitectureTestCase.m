#import "USPAuthArchitectureTestCase.h"
#import "USPOAuth1AuthenticationProvider.h"
#import "NSString+URLEncoding.h"
@implementation TestHandle
- (void)cancel { self.cancelled = YES; }
@end
@implementation FakeTransport
- (instancetype)init { if ((self = [super init])) { _requests = [NSMutableArray new]; _callbacks = [NSMutableArray new]; _handles = [NSMutableArray new]; } return self; }
- (id<USPCancellable>)executeRequest:(NSURLRequest *)request completion:(USPHTTPCompletion)completion {
  [self.requests addObject:request]; [self.callbacks addObject:[completion copy]];
  TestHandle *handle = [TestHandle new]; [self.handles addObject:handle]; return handle;
}
- (void)respond:(NSUInteger)index text:(NSString *)text status:(NSInteger)status error:(NSError *)error {
  NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:self.requests[index].URL statusCode:status HTTPVersion:@"HTTP/1.1" headerFields:nil];
  self.callbacks[index]([text dataUsingEncoding:NSUTF8StringEncoding], response, error);
}
@end
@implementation FakeBrowser
- (void)begin:(dispatch_block_t)ready cancellation:(void (^)(NSError *))cancellation { self.begins++; self.cancellation = cancellation; ready(); }
- (void)openURL:(NSURL *)url matching:(BOOL (^)(NSURL *))matches completion:(void (^)(NSURL *, NSError *))completion { self.url = url; self.matches = matches; self.callback = completion; }
- (void)finish:(dispatch_block_t)completion { self.finished = YES; completion(); }
- (void)cancel { self.cancelled = YES; if (self.cancellation) self.cancellation([NSError errorWithDomain:@"fixture" code:NSUserCancelledError userInfo:nil]); }
@end
/// Provider-independent store: deliberately no OAuth1 fields or UserDefaults.
@implementation MemoryStore
- (instancetype)init { if ((self = [super init])) { _session = [USPAuthSession new]; _notificationPlatform = @"F"; } return self; }
- (USPAuthSession *)loadSession { return self.session; }
- (void)saveSession:(USPAuthSession *)session { self.session = session; }
- (void)updateProviderState:(NSDictionary *)state forProvider:(NSString *)identifier { self.session.providerState = state; self.session.providerIdentifier = identifier; }
- (void)updateIdentity:(USPIdentity *)identity { self.session.identity = identity; }
- (void)clearSession { self.session = [USPAuthSession new]; self.isRegistered = NO; }
- (void)clearAll { [self clearSession]; self.notificationToken = nil; self.notificationPlatform = @"F"; }
@end
@implementation FakeAuthenticationProvider
- (NSString *)identifier { return @"alternative-test-mechanism"; }
- (BOOL)hasCachedCredential { return self.available; }
- (BOOL)recognizesSession:(USPAuthSession *)session { return [session.providerIdentifier isEqual:self.identifier] && [session.providerState[@"opaque-envelope"] isEqual:@"fixture"]; }
- (void)authenticateFromViewController:(UIViewController *)presenter completion:(void (^)(USPIdentity *, NSError *))completion { self.calls++; self.result = completion; }
- (void)cancel { self.cancelled = YES; }
- (void)clearCredential { self.available = NO; }
- (void)resolveUser:(USPAuthUser *)user { self.available = YES; self.result([[USPIdentity alloc] initWithUser:user], nil); }
@end

NSInteger StubStatus;
BOOL StubWait;
NSError *StubError;
@implementation StubURLProtocol
+ (BOOL)canInitWithRequest:(NSURLRequest *)request { return YES; }
+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request { return request; }
- (void)startLoading {
  if (StubWait) return;
  if (StubError) { [self.client URLProtocol:self didFailWithError:StubError]; return; }
  NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:self.request.URL statusCode:StubStatus HTTPVersion:@"HTTP/1.1" headerFields:nil];
  [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
  [self.client URLProtocol:self didLoadData:[@"fixture-bytes" dataUsingEncoding:NSUTF8StringEncoding]];
  [self.client URLProtocolDidFinishLoading:self];
}
- (void)stopLoading {}
@end
@implementation RecordingWebView
- (WKNavigation *)loadRequest:(NSURLRequest *)request { self.recordedRequest = request; return nil; }
@end
@implementation FixtureNavigationAction
- (NSURLRequest *)request { return self.fixtureRequest; }
@end

@implementation USPAuthArchitectureTests
@synthesize provider = _provider;
- (void)setUp {
  [super setUp];
  self.suite = [@"USPAuthArchitectureTests." stringByAppendingString:NSUUID.UUID.UUIDString];
  self.defaults = [[NSUserDefaults alloc] initWithSuiteName:self.suite];
  [self.defaults removePersistentDomainForName:self.suite];
  self.store = [[USPAuthSessionStore alloc] initWithDefaults:self.defaults];
  self.transport = [FakeTransport new]; self.browser = [FakeBrowser new]; self.presenter = [UIViewController new];
}
// Construct protocol-specific fixtures only for tests that actually request OAuth1.
- (USPOAuth1AuthenticationProvider *)provider {
  if (!_provider) {
    FakeBrowser *browser = self.browser;
    _provider = [[USPOAuth1AuthenticationProvider alloc] initWithStore:self.store transport:self.transport browserFactory:^id<USPAuthBrowser>(UIViewController *presenter) { return browser; } clock:^{ return [NSDate dateWithTimeIntervalSince1970:1700000000.9]; } nonce:^{ return @"abcdef123"; }];
    _provider.config = [USPAuthConfig customWithBaseURL:@"https://example.invalid" consumerKey:@"ck" consumerSecret:@"cs" appKey:@"fixture-app"];
  }
  return _provider;
}
- (void)tearDown {
  [_provider cancel];
  [self.transport.callbacks removeAllObjects];
  self.browser.callback = nil; self.browser.cancellation = nil;
  [self.defaults removePersistentDomainForName:self.suite];
  [super tearDown];
}
- (void)until:(BOOL (^)(void))condition {
  NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:2];
  while (!condition() && deadline.timeIntervalSinceNow > 0) [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.002]];
  XCTAssertTrue(condition());
}
- (USPMobileBackendClient *)mobile {
  USPMobileBackendClient *client = [[USPMobileBackendClient alloc] initWithTransport:self.transport];
  client.baseURL = @"https://example.invalid"; client.appKey = @"fixture-app"; client.headerValue = @"fixture-header";
  return client;
}
- (void)advanceToAuthorization {
  [self.transport respond:0 text:@"oauth_token=rt&oauth_token_secret=rs" status:200 error:nil];
  [self until:^BOOL { return self.browser.url != nil; }];
}
- (void)advanceToProfile {
  [self advanceToAuthorization];
  self.browser.callback([NSURL URLWithString:@"http://localhost/?oauth_token=rt&oauth_verifier=verify"], nil);
  XCTAssertEqual(self.transport.requests.count, 2u);
  [self.transport respond:1 text:@"oauth_token=at&oauth_token_secret=as" status:200 error:nil];
  [self until:^BOOL { return self.transport.requests.count == 3; }];
}
- (NSDictionary *)bodyAt:(NSUInteger)index {
  return [NSJSONSerialization JSONObjectWithData:self.transport.requests[index].HTTPBody options:0 error:nil];
}

- (NSDictionary *)authorizationFields:(NSUInteger)index {
  NSString *header = [self.transport.requests[index] valueForHTTPHeaderField:@"Authorization"];
  XCTAssertTrue([header hasPrefix:@"OAuth "]);
  NSMutableDictionary *fields = [NSMutableDictionary new];
  for (NSString *pair in [[header substringFromIndex:6] componentsSeparatedByString:@", "]) {
    NSRange split = [pair rangeOfString:@"=\""];
    if (split.location != NSNotFound) {
      NSString *key = [pair substringToIndex:split.location];
      NSString *value = [pair substringFromIndex:split.location+2];
      fields[key] = [[value substringToIndex:value.length-1] stringByRemovingPercentEncoding];
    }
  }
  return fields;
}

- (USPAuthUser *)standardFixtureUser {
  // Synthetic model fixture; not a protocol response and never parsed by the consumer.
  return [[USPAuthUser alloc] initWithDictionary:@{
    @"loginUsuario":@"fixture-login", @"nomeUsuario":@"Fixture User",
    @"emailPrincipalUsuario":@"primary@example.invalid", @"emailAlternativoUsuario":@"alternative@example.invalid",
    @"emailUspUsuario":@"usp@example.invalid", @"numeroTelefoneFormatado":@"fixture-phone",
    @"tipoUsuario":@"fixture-type", @"wsuserid":@"usp-operational-id",
    @"vinculo":@[@{@"codigoSetor":@12, @"codigoUnidade":@34, @"nomeUnidade":@"Fixture Unit",
      @"nomeVinculo":@"Fixture Link", @"siglaUnidade":@"FU", @"tipoVinculo":@"fixture-link-type"}]}];
}
- (void)assertStandardProfile:(USPAuthUser *)user {
  XCTAssertEqualObjects(user.loginUsuario, @"fixture-login"); XCTAssertEqualObjects(user.nomeUsuario, @"Fixture User");
  XCTAssertEqualObjects(user.emailPrincipalUsuario, @"primary@example.invalid"); XCTAssertEqualObjects(user.emailAlternativoUsuario, @"alternative@example.invalid");
  XCTAssertEqualObjects(user.emailUspUsuario, @"usp@example.invalid"); XCTAssertEqualObjects(user.numeroTelefoneFormatado, @"fixture-phone");
  XCTAssertEqualObjects(user.tipoUsuario, @"fixture-type"); XCTAssertEqualObjects(user.wsuserid, @"usp-operational-id");
  XCTAssertEqual(user.vinculos.count, 1u); USPAuthVinculo *link = user.vinculos.firstObject;
  XCTAssertEqual(link.codigoSetor, 12); XCTAssertEqual(link.codigoUnidade, 34);
  XCTAssertEqualObjects(link.nomeUnidade, @"Fixture Unit"); XCTAssertEqualObjects(link.nomeVinculo, @"Fixture Link");
  XCTAssertEqualObjects(link.siglaUnidade, @"FU"); XCTAssertEqualObjects(link.tipoVinculo, @"fixture-link-type");
}

@end
