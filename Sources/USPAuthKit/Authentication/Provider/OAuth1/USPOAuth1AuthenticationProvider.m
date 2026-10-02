#if __has_include(<UIKit/UIKit.h>)
#import "USPOAuth1AuthenticationProvider.h"
#import "OAuth1Controller.h"
#import "USPAuthConfig.h"
@interface USPOAuth1AuthenticationProvider ()
@property (nonatomic, strong) id<USPAuthSessionStoring> store;
@property (nonatomic, strong) id<USPHTTPTransport> transport;
@property (nonatomic, copy) id<USPAuthBrowser>(^browserFactory)(UIViewController *);
@property (nonatomic, copy) NSDate *(^clock)(void);
@property (nonatomic, copy) NSString *(^nonce)(void);
@property (nonatomic, strong) OAuth1Controller *controller;
@property (nonatomic, strong) id<USPAuthBrowser> browser;
@property (nonatomic, strong) id<USPCancellable> profileTask;
@property (nonatomic, copy) void (^pending)(USPIdentity *, NSError *);
@property (nonatomic) NSUInteger generation;
@end
@implementation USPOAuth1AuthenticationProvider
@synthesize legacyToken = _legacyToken, legacySecret = _legacySecret;
- (instancetype)initWithStore:(id<USPAuthSessionStoring>)store transport:(id<USPHTTPTransport>)transport browserFactory:(id<USPAuthBrowser>(^)(UIViewController *))factory clock:(NSDate *(^)(void))clock nonce:(NSString *(^)(void))nonce {
  if ((self = [super init])) {
    _store = store; _transport = transport; _browserFactory = [factory copy]; _clock = [clock copy]; _nonce = [nonce copy];
    NSDictionary *state = [store loadSession].providerState;
    _legacyToken = [state[@"token"] copy]; _legacySecret = [state[@"secret"] copy];
  }
  return self;
}
- (NSString *)identifier { return @"oauth1"; }
- (NSString *)legacyToken {
  if (!_legacyToken.length) _legacyToken = [[self.store loadSession].providerState[@"token"] copy];
  return _legacyToken;
}
- (NSString *)legacySecret {
  if (!_legacySecret.length) _legacySecret = [[self.store loadSession].providerState[@"secret"] copy];
  return _legacySecret;
}
- (void)persistCredential {
  NSMutableDictionary *state = [NSMutableDictionary new];
  if (_legacyToken) state[@"token"] = _legacyToken;
  if (_legacySecret) state[@"secret"] = _legacySecret;
  [self.store updateProviderState:state forProvider:self.identifier];
}
- (void)setLegacyToken:(NSString *)token { _legacyToken = [token copy]; [self persistCredential]; }
- (void)setLegacySecret:(NSString *)secret { _legacySecret = [secret copy]; [self persistCredential]; }
- (BOOL)hasCachedCredential { return self.legacyToken.length && self.legacySecret.length; }
- (BOOL)recognizesSession:(USPAuthSession *)session {
  return [session.providerIdentifier isEqual:self.identifier] && [session.providerState[@"token"] length] && [session.providerState[@"secret"] length];
}
- (void)clearCredential { _legacyToken = nil; _legacySecret = nil; }
- (void)authenticateFromViewController:(UIViewController *)presenter completion:(void (^)(USPIdentity *, NSError *))completion {
  [self startBrowser:self.browserFactory(presenter) fetchIdentity:YES completion:completion];
}
- (void)loginInWebView:(WKWebView *)webView completion:(void (^)(BOOL, NSError *))completion {
  [self startBrowser:[[USPWKAuthBrowser alloc] initWithWebView:webView] fetchIdentity:NO completion:^(USPIdentity *identity, NSError *error) { completion(!error, error); }];
}
- (void)startBrowser:(id<USPAuthBrowser>)browser fetchIdentity:(BOOL)fetch completion:(void (^)(USPIdentity *, NSError *))completion {
  if (self.pending) { completion(nil, USPAuthError(1001, @"Login já em andamento.")); return; }
  if (!self.config) { completion(nil, USPAuthError(1000, @"USPAuthService.config não foi configurado.")); return; }

  self.pending = completion;
  self.browser = browser;
  self.controller = [[OAuth1Controller alloc] initWithConfig:self.config transport:self.transport clock:self.clock nonce:self.nonce];
  NSUInteger generation = ++self.generation;
  __weak typeof(self) weakSelf = self;
  [browser begin:^{
    __strong typeof(weakSelf) self = weakSelf;
    if (!self || generation != self.generation) { return; }
    [self.controller loginWithBrowser:browser completion:^(NSDictionary *params, NSError *error) {
      if (generation != self.generation || !self.pending) { return; }
      if (error || !params.count) {
        [browser finish:^{ if (generation == self.generation) [self finish:nil error:error ?: USPAuthError(1005, @"Retorno de autorização inválido.")]; }];
        return;
      }
      // Partial access response remains a characterized legacy behavior (R13).

      self.legacyToken = params[@"oauth_token"];
      self.legacySecret = params[@"oauth_token_secret"];
      [browser finish:^{
        if (generation != self.generation || !self.pending) { return; }
        if (fetch) [self fetchIdentityForGeneration:generation]; else [self finish:nil error:nil];
      }];
    }];
  } cancellation:^(NSError *error) {
    if (generation == weakSelf.generation) [weakSelf abort:error];
  }];
}
- (void)fetchIdentityForGeneration:(NSUInteger)generation {
  if (![self hasCachedCredential]) { [self finish:nil error:USPAuthError(1002, @"Tokens OAuth não disponíveis para buscar dados do usuário.")]; return; }
  NSURLRequest *request = [self.controller identityRequestWithToken:self.legacyToken secret:self.legacySecret];
  if (!request) { [self finish:nil error:USPAuthError(1003, @"Não foi possível montar a requisição de dados do usuário.")]; return; }

  self.profileTask = [self.transport executeRequest:request completion:^(NSData *data, NSHTTPURLResponse *response, NSError *error) {
    USPAuthOnMain(^{
      if (generation != self.generation || !self.pending) { return; }
      if (error) { [self finish:nil error:error]; return; }
      if (!data.length) { [self finish:nil error:USPAuthError(1004, @"Nenhum dado recebido do servidor.")]; return; }
      NSError *jsonError = nil;
      id metadata = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];

      if (jsonError || ![metadata isKindOfClass:NSDictionary.class] || ![metadata count]) {
        [self finish:nil error:USPAuthError(1005, @"Resposta inválida ao buscar dados do usuário.")]; return;
      }
      // HTTP status handling is intentionally unchanged here; R13 owns that policy.
      USPIdentity *identity = [[USPIdentity alloc] initWithMetadata:metadata];


      [self finish:identity error:nil];
    });
  }];
}
- (void)finish:(USPIdentity *)identity error:(NSError *)error {
  void (^pending)(USPIdentity *, NSError *) = self.pending;
  self.pending = nil; self.profileTask = nil; self.controller = nil; self.browser = nil;

  if (pending) pending(identity, error);
}
- (void)abort:(NSError *)error {
  ++self.generation;
  void (^pending)(USPIdentity *, NSError *) = self.pending;
  self.pending = nil;
  [self.controller cancel]; [self.profileTask cancel]; [self.browser finish:^{}];
  self.controller = nil; self.profileTask = nil; self.browser = nil;
  if (pending) pending(nil, error);
}
- (void)cancel { [self abort:[NSError errorWithDomain:@"LoginWebViewController" code:NSUserCancelledError userInfo:@{NSLocalizedDescriptionKey:@"Login cancelado pelo usuário."}]]; }
@end
#endif
