#if __has_include(<UIKit/UIKit.h>)
#import "USPAuthServiceInternal.h"
#import "USPAuthConfig.h"
#import "USPApplicationConfiguration.h"
#import "USPAuthSessionStore.h"
#import "USPOAuth1AuthenticationProvider.h"
#import "USPAuthenticationCoordinator.h"
#import "NSString+URLEncoding.h"
@interface USPAuthService ()
@property (nonatomic, strong) USPAuthenticationCoordinator *coordinator;
@property (nonatomic, strong) USPOAuth1AuthenticationProvider *legacyProvider;
@property (nonatomic, strong) USPApplicationConfiguration *applicationConfiguration;
@property (nonatomic, copy) NSString *legacyConfiguredAppKey;
@end
@implementation USPAuthService
+ (instancetype)sharedService {
  static USPAuthService *svc;
  static dispatch_once_t once;
  dispatch_once(&once, ^{
    svc = [[self alloc] init];
  });
  return svc;
}


- (instancetype)init { return [self initWithUserDefaults:NSUserDefaults.standardUserDefaults]; }
- (instancetype)initWithUserDefaults:(NSUserDefaults *)defaults {
  NSParameterAssert(defaults);
  if ((self = [super init])) {
    id<USPAuthSessionStoring> store = [[USPAuthSessionStore alloc] initWithDefaults:defaults];
    id<USPHTTPTransport> authTransport = [[USPURLSessionTransport alloc] initWithSession:NSURLSession.sharedSession];
    NSURLSession *mobileSession = [NSURLSession sessionWithConfiguration:NSURLSessionConfiguration.defaultSessionConfiguration delegate:nil delegateQueue:NSOperationQueue.mainQueue];
    id<USPHTTPTransport> mobileTransport = [[USPURLSessionTransport alloc] initWithSession:mobileSession];
    _legacyProvider = [[USPOAuth1AuthenticationProvider alloc] initWithStore:store transport:authTransport browserFactory:^id<USPAuthBrowser>(UIViewController *presenter) { return [[USPWKAuthBrowser alloc] initWithPresenter:presenter]; } clock:^{ return NSDate.date; } nonce:^{ return [NSString getNonce]; }];
    _coordinator = [[USPAuthenticationCoordinator alloc] initWithProvider:_legacyProvider store:store mobileClient:[[USPMobileBackendClient alloc] initWithTransport:mobileTransport]];
    _appKey = @""; _backendHeaderValue = USPDefaultMobileHeaderValue();
    _applicationConfiguration = [[USPApplicationConfiguration alloc] initWithBaseURL:@"" appKey:_appKey backendHeaderValue:_backendHeaderValue];
  }
  return self;
}
- (instancetype)initWithCoordinator:(USPAuthenticationCoordinator *)coordinator legacyProvider:(USPOAuth1AuthenticationProvider *)provider {
  NSParameterAssert(coordinator);
  if ((self = [super init])) {
    _coordinator = coordinator; _legacyProvider = provider;
    _appKey = @""; _backendHeaderValue = USPDefaultMobileHeaderValue();
    _applicationConfiguration = [[USPApplicationConfiguration alloc] initWithBaseURL:@"" appKey:_appKey backendHeaderValue:_backendHeaderValue];
  }
  return self;
}
+ (void)configureWithEnvironment:(USPAuthEnvironment)env
                     consumerKey:(NSString *)consumerKey
                  consumerSecret:(NSString *)consumerSecret
                          appKey:(NSString *)appKey {
  USPAuthConfig *cfg = nil;

  switch (env) {
    case USPAuthEnvironmentDev:
      cfg = [USPAuthConfig devWithConsumerKey:consumerKey consumerSecret:consumerSecret appKey:appKey];
      break;

    case USPAuthEnvironmentProd:
      cfg = [USPAuthConfig prodWithConsumerKey:consumerKey consumerSecret:consumerSecret appKey:appKey];
      break;

    case USPAuthEnvironmentCustom:
    default:
      NSAssert(NO, @"Use +configureWithConfig: para USPAuthEnvironmentCustom com baseURL explícita.");
      return;
  }

  [self configureWithConfig:cfg];
}

+ (void)configureWithConfig:(USPAuthConfig *)config {
  NSParameterAssert(config);
  USPAuthService *service = [USPAuthService sharedService];
  service.config = config;
  service.appKey = config.appKey ?: @"";
}


- (void)syncMobileConfiguration {
  self.coordinator.mobile.baseURL = self.applicationConfiguration.baseURL;
  self.coordinator.mobile.appKey = self.applicationConfiguration.appKey;
  self.coordinator.mobile.headerValue = self.applicationConfiguration.backendHeaderValue;
}
- (void)applyApplicationConfiguration:(USPApplicationConfiguration *)configuration {
  NSParameterAssert(configuration);
  _applicationConfiguration = [[USPApplicationConfiguration alloc] initWithBaseURL:configuration.baseURL appKey:configuration.appKey backendHeaderValue:configuration.backendHeaderValue];
  _appKey = [configuration.appKey copy]; _backendHeaderValue = [configuration.backendHeaderValue copy];
  self.legacyConfiguredAppKey = nil;
  [self syncMobileConfiguration];
}
// Legacy combined configuration adapter. Protocol-specific fields never enter the coordinator.
- (void)setConfig:(USPAuthConfig *)config {
  _config = config; self.legacyProvider.config = config;
  self.legacyConfiguredAppKey = config.appKey ?: @"";
  self.applicationConfiguration.baseURL = config.baseURL ?: @"";
  self.applicationConfiguration.appKey = self.legacyConfiguredAppKey.length ? self.legacyConfiguredAppKey : self.appKey ?: @"";
  [self syncMobileConfiguration];
}
- (void)setAppKey:(NSString *)appKey {
  _appKey = [appKey copy];
  self.applicationConfiguration.appKey = self.legacyConfiguredAppKey.length ? self.legacyConfiguredAppKey : appKey ?: @"";
  [self syncMobileConfiguration];
}
- (void)setBackendHeaderValue:(NSString *)value {
  _backendHeaderValue = [value copy]; self.applicationConfiguration.backendHeaderValue = value ?: @"";
  [self syncMobileConfiguration];
}
- (NSDictionary *)userData { return self.coordinator.session.identity.metadata ?: @{}; }
- (USPAuthUser *)currentUser { return self.coordinator.session.identity.user; }
- (NSString *)currentWSUserId {
  USPIdentity *identity = self.coordinator.session.identity;
  // Legacy nullable selector preserves R02; typed profile normalizes missing/null to "".
  return [identity.metadata[@"wsuserid"] isKindOfClass:NSString.class] ? identity.user.wsuserid : nil;
}
- (BOOL)isLoggedIn { return self.coordinator.isLoggedIn; }
- (void)ensureLoggedInFromViewController:(UIViewController *)presenter completion:(void (^)(USPAuthUser *, NSError *))completion {
  NSParameterAssert(presenter); NSParameterAssert(completion);
  [self syncMobileConfiguration];
  [self.coordinator ensureFromViewController:presenter completion:^(USPAuthUser *user, NSError *error) {
    completion(user, error);
  }];
}
- (void)logout { [self.coordinator logout]; }
- (NSString *)notificationToken { return self.coordinator.notificationToken; }
- (void)setNotificationToken:(NSString *)token { self.coordinator.notificationToken = token; }
- (NSString *)notificationPlatform { return self.coordinator.notificationPlatform; }
- (void)setNotificationPlatform:(NSString *)platform { self.coordinator.notificationPlatform = platform; }
- (void)updateNotificationToken:(NSString *)token { [self syncMobileConfiguration]; [self.coordinator updateNotificationToken:token]; }
- (void)registerTokenWithCompletion:(void (^)(NSError *))completion { NSParameterAssert(completion); [self syncMobileConfiguration]; [self.coordinator registerWithCompletion:completion]; }
- (void)invalidateTokenWithCompletion:(void (^)(NSError *))completion { NSParameterAssert(completion); [self syncMobileConfiguration]; [self.coordinator invalidateWithCompletion:completion]; }
- (void)checkTokenWithCompletion:(void (^)(NSDictionary<NSString *,id> *, NSError *))completion { NSParameterAssert(completion); [self syncMobileConfiguration]; [self.coordinator checkWithCompletion:completion]; }
- (void)registerToken { [self registerTokenWithCompletion:^(NSError *error) { if (error) NSLog(@"[USPAuth] Falha ao registrar token: %@", error.localizedDescription); }]; }
- (void)invalidateToken { [self invalidateTokenWithCompletion:^(NSError *error) { if (error) NSLog(@"[USPAuth] Falha ao invalidar token: %@", error.localizedDescription); }]; }
- (void)checkToken { [self checkTokenWithCompletion:^(NSDictionary *payload, NSError *error) { if (error) NSLog(@"[USPAuth] Falha ao consultar token: %@", error.localizedDescription); }]; }

#pragma mark - Legacy OAuth1 Compatibility API
// These selectors are adapters. They must never be required of another provider.
- (NSString *)oauthToken { return self.legacyProvider.legacyToken; }
- (void)setOauthToken:(NSString *)token { self.legacyProvider.legacyToken = token; }
- (NSString *)oauthTokenSecret { return self.legacyProvider.legacySecret; }
- (void)setOauthTokenSecret:(NSString *)secret { self.legacyProvider.legacySecret = secret; }
- (void)loginInWebView:(WKWebView *)webView completion:(void (^)(BOOL, NSError *))completion {
  NSParameterAssert(webView); NSParameterAssert(completion);
  USPAuthOnMain(^{
    if (!self.legacyProvider) { completion(NO, USPAuthError(1000, @"API legada disponível somente com OAuth1.")); return; }
    [self.legacyProvider loginInWebView:webView completion:completion];
  });
}
@end
#endif
