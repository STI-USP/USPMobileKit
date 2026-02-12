// USPAuthService.m
// NuAuthKit
//
// Created by Vagner Machado on 22/05/25.
//

#if __has_include(<UIKit/UIKit.h>)

#import "USPAuthService.h"
#import "HTTPClient.h"
#import "OAuth1Controller.h"
#import "LoginWebViewController.h"
#import "USPAuthUser.h"
#import "USPAuthConfig.h"
#import "USPAuthSessionStore.h"

static NSString * const kUSPAuthServiceErrorDomain = @"USPAuthService";
static NSString * const kUserInfoPath = @"/wsusuario/oauth/usuariousp";
static NSString * const kRegisterPath = @"/mobile/servicos/oauth/registrar";
static NSString * const kInvalidatePath = @"/mobile/servicos/oauth/invalidar";
static NSString * const kCheckPath = @"/mobile/servicos/oauth/consultar";
static NSString * const kBackendHeaderName = @"DEV-USP-MOBILE";
static NSString * const kDefaultBackendHeaderValue = @"820ecd52-849f-4815-8eb3-bbf9f4440ac5";

typedef NS_ENUM(NSInteger, USPAuthServiceErrorCode) {
  USPAuthServiceErrorCodeMissingConfig = 1000,
  USPAuthServiceErrorCodeLoginInProgress = 1001,
  USPAuthServiceErrorCodeMissingOAuthTokens = 1002,
  USPAuthServiceErrorCodeInvalidRequest = 1003,
  USPAuthServiceErrorCodeEmptyResponse = 1004,
  USPAuthServiceErrorCodeInvalidResponse = 1005,
  USPAuthServiceErrorCodeMissingWSUserId = 1006,
  USPAuthServiceErrorCodeInvalidURL = 1007,
};

@interface USPAuthService ()

@property (nonatomic, strong) USPAuthSessionStore *sessionStore;
@property (nonatomic, strong) HTTPClient *httpClient;
@property (nonatomic, strong) NSURLSession *urlSession;
@property (nonatomic, strong, nullable) OAuth1Controller *activeOAuthController;
@property (nonatomic, assign) BOOL isLoginPresentationInProgress;

@end

@implementation USPAuthService

#pragma mark - Lifecycle

+ (instancetype)sharedService {
  static USPAuthService *svc;
  static dispatch_once_t once;
  dispatch_once(&once, ^{
    svc = [[self alloc] init];
  });
  return svc;
}

- (instancetype)init {
  return [self initWithUserDefaults:[NSUserDefaults standardUserDefaults]];
}

- (instancetype)initWithUserDefaults:(NSUserDefaults *)defaults {
  NSParameterAssert(defaults);
  if (self = [super init]) {
    _sessionStore = [[USPAuthSessionStore alloc] initWithDefaults:defaults];
    _httpClient = [HTTPClient sharedClient];
    _urlSession = [NSURLSession sharedSession];
    _appKey = @"";
    _backendHeaderValue = kDefaultBackendHeaderValue;
    _oauthToken = [_sessionStore.oauthToken copy];
    _oauthTokenSecret = [_sessionStore.oauthTokenSecret copy];
    _notificationToken = [_sessionStore.notificationToken copy];
    _notificationPlatform = [_sessionStore.notificationPlatform copy];
    _isLoginPresentationInProgress = NO;
  }
  return self;
}

#pragma mark - Configuration

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

#pragma mark - State

- (NSDictionary<NSString *,id> *)userData {
  return self.sessionStore.userData ?: @{};
}

- (BOOL)isLoggedIn {
  return [self.sessionStore hasValidSession];
}

- (nullable USPAuthUser *)currentUser {
  NSDictionary *data = self.sessionStore.userData;
  if (data.count == 0) return nil;
  return [[USPAuthUser alloc] initWithDictionary:data];
}

- (nullable NSString *)currentWSUserId {
  id value = self.userData[@"wsuserid"];
  return [value isKindOfClass:[NSString class]] ? value : nil;
}

#pragma mark - Login Flow

- (void)ensureLoggedInFromViewController:(UIViewController *)fromVC
                              completion:(void (^)(USPAuthUser * _Nullable, NSError * _Nullable))completion {
  NSParameterAssert(fromVC);
  NSParameterAssert(completion);

  if (self.isLoginPresentationInProgress) {
    NSError *error = [NSError errorWithDomain:kUSPAuthServiceErrorDomain
                                         code:USPAuthServiceErrorCodeLoginInProgress
                                     userInfo:@{NSLocalizedDescriptionKey: @"Login já em andamento."}];
    [self dispatchCompletionOnMain:^{ completion(nil, error); }];
    return;
  }

  USPAuthUser *cached = [self currentUser];
  if (self.oauthToken.length > 0 && self.oauthTokenSecret.length > 0 && cached) {
    [self dispatchCompletionOnMain:^{ completion(cached, nil); }];
    return;
  }

  if (!self.config) {
    NSError *error = [NSError errorWithDomain:kUSPAuthServiceErrorDomain
                                         code:USPAuthServiceErrorCodeMissingConfig
                                     userInfo:@{NSLocalizedDescriptionKey: @"USPAuthService.config não foi configurado."}];
    [self dispatchCompletionOnMain:^{ completion(nil, error); }];
    return;
  }

  self.isLoginPresentationInProgress = YES;

  LoginWebViewController *loginVC = [[LoginWebViewController alloc] init];
  __weak typeof(self) weakSelf = self;
  loginVC.loginCompletion = ^(BOOL success, NSError * _Nullable loginErr) {
    [fromVC dismissViewControllerAnimated:YES completion:^{
      __strong typeof(weakSelf) self = weakSelf;
      self.isLoginPresentationInProgress = NO;

      if (!success) {
        completion(nil, loginErr);
        return;
      }

      [self fetchUserDataWithCompletion:^(NSDictionary<NSString *,id> * _Nullable user, NSError * _Nullable fetchErr) {
        if (fetchErr || user.count == 0) {
          NSError *effectiveError = fetchErr ?: [NSError errorWithDomain:kUSPAuthServiceErrorDomain
                                                                     code:USPAuthServiceErrorCodeInvalidResponse
                                                                 userInfo:@{NSLocalizedDescriptionKey: @"Dados do usuário não encontrados."}];
          completion(nil, effectiveError);
          return;
        }

        [self registerTokenWithCompletion:^(NSError * _Nullable registerError) {
          completion(registerError ? nil : [[USPAuthUser alloc] initWithDictionary:user], registerError);
        }];
      }];
    }];
  };

  UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:loginVC];
  if (@available(iOS 13.0, *)) {
    UINavigationBarAppearance *appearance = [UINavigationBarAppearance new];
    [appearance configureWithOpaqueBackground];
    appearance.backgroundColor = [UIColor colorNamed:@"BrandPrimary"] ?: UIColor.systemBlueColor;
    appearance.titleTextAttributes = @{ NSForegroundColorAttributeName : UIColor.whiteColor };

    nav.navigationBar.standardAppearance = appearance;
    nav.navigationBar.scrollEdgeAppearance = appearance;
    nav.navigationBar.compactAppearance = appearance;
    nav.navigationBar.tintColor = UIColor.whiteColor;
  }

  if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
    nav.modalPresentationStyle = UIModalPresentationPageSheet;
    if (@available(iOS 15.0, *)) {
      nav.sheetPresentationController.detents = @[UISheetPresentationControllerDetent.largeDetent];
      nav.sheetPresentationController.prefersGrabberVisible = YES;
    }
  } else {
    nav.modalPresentationStyle = UIModalPresentationFullScreen;
  }

  dispatch_async(dispatch_get_main_queue(), ^{
    [fromVC presentViewController:nav animated:YES completion:nil];
  });
}

- (void)loginInWebView:(WKWebView *)webView
            completion:(void (^)(BOOL, NSError * _Nullable))completion {
  NSParameterAssert(webView);
  NSParameterAssert(completion);

  if (!self.config) {
    NSError *error = [NSError errorWithDomain:kUSPAuthServiceErrorDomain
                                         code:USPAuthServiceErrorCodeMissingConfig
                                     userInfo:@{NSLocalizedDescriptionKey: @"USPAuthService.config não foi configurado."}];
    [self dispatchCompletionOnMain:^{ completion(NO, error); }];
    return;
  }

  self.activeOAuthController = [[OAuth1Controller alloc] initWithConfig:self.config];
  __weak typeof(self) weakSelf = self;
  [self.activeOAuthController loginWithWebView:webView completion:^(NSDictionary<NSString *,NSString *> * _Nullable accessParams, NSError * _Nullable error) {
    __strong typeof(weakSelf) self = weakSelf;
    self.activeOAuthController = nil;

    if (error || accessParams.count == 0) {
      completion(NO, error);
      return;
    }

    self.oauthToken = accessParams[@"oauth_token"];
    self.oauthTokenSecret = accessParams[@"oauth_token_secret"];
    completion(YES, nil);
  }];
}

#pragma mark - Push Token

- (void)updateNotificationToken:(nullable NSString *)token {
  NSString *newToken = token ?: @"";
  NSString *currentToken = self.notificationToken ?: @"";
  if ([newToken isEqualToString:currentToken]) {
    return;
  }

  self.notificationToken = token;

  if ([self isLoggedIn]) {
    [self registerTokenWithCompletion:^(NSError * _Nullable error) {
      if (error) {
        NSLog(@"[USPAuth] Falha ao registrar token de push após update: %@", error.localizedDescription);
      }
    }];
  }
}

#pragma mark - Backend Operations

- (void)registerToken {
  [self registerTokenWithCompletion:^(NSError * _Nullable error) {
    if (error) {
      NSLog(@"[USPAuth] Falha ao registrar token: %@", error.localizedDescription);
    }
  }];
}

- (void)registerTokenWithCompletion:(void (^)(NSError * _Nullable))completion {
  NSParameterAssert(completion);

  NSString *wsUserId = [self currentWSUserId];
  if (wsUserId.length == 0) {
    NSError *error = [NSError errorWithDomain:kUSPAuthServiceErrorDomain
                                         code:USPAuthServiceErrorCodeMissingWSUserId
                                     userInfo:@{NSLocalizedDescriptionKey: @"ID do usuário (wsuserid) não encontrado."}];
    [self dispatchCompletionOnMain:^{ completion(error); }];
    return;
  }

  NSDictionary *body = [self registrationPayloadWithWSUserId:wsUserId];
  [self postBody:body
       toAPIPath:kRegisterPath
      completion:^(NSData * _Nullable data, NSHTTPURLResponse * _Nullable response, NSError * _Nullable error) {
    if (error) {
      completion(error);
      return;
    }

    self.sessionStore.isRegistered = YES;
    completion(nil);
  }];
}

- (void)invalidateToken {
  [self invalidateTokenWithCompletion:^(NSError * _Nullable error) {
    if (error) {
      NSLog(@"[USPAuth] Falha ao invalidar token: %@", error.localizedDescription);
    }
  }];
}

- (void)invalidateTokenWithCompletion:(void (^)(NSError * _Nullable))completion {
  NSParameterAssert(completion);

  NSString *wsUserId = [self currentWSUserId];
  if (wsUserId.length == 0) {
    NSError *error = [NSError errorWithDomain:kUSPAuthServiceErrorDomain
                                         code:USPAuthServiceErrorCodeMissingWSUserId
                                     userInfo:@{NSLocalizedDescriptionKey: @"ID do usuário (wsuserid) não encontrado."}];
    [self dispatchCompletionOnMain:^{ completion(error); }];
    return;
  }

  NSDictionary *body = @{ @"token": wsUserId, @"app": [self effectiveAppKey] };
  [self postBody:body
       toAPIPath:kInvalidatePath
      completion:^(NSData * _Nullable data, NSHTTPURLResponse * _Nullable response, NSError * _Nullable error) {
    completion(error);
  }];
}

- (void)checkToken {
  [self checkTokenWithCompletion:^(NSDictionary<NSString *,id> * _Nullable payload, NSError * _Nullable error) {
    if (error) {
      NSLog(@"[USPAuth] Falha ao consultar token: %@", error.localizedDescription);
    }
  }];
}

- (void)checkTokenWithCompletion:(void (^)(NSDictionary<NSString *,id> * _Nullable, NSError * _Nullable))completion {
  NSParameterAssert(completion);

  NSString *wsUserId = [self currentWSUserId];
  if (wsUserId.length == 0) {
    NSError *error = [NSError errorWithDomain:kUSPAuthServiceErrorDomain
                                         code:USPAuthServiceErrorCodeMissingWSUserId
                                     userInfo:@{NSLocalizedDescriptionKey: @"ID do usuário (wsuserid) não encontrado."}];
    [self dispatchCompletionOnMain:^{ completion(nil, error); }];
    return;
  }

  NSDictionary *body = @{ @"token": wsUserId, @"app": [self effectiveAppKey] };
  [self postBody:body
       toAPIPath:kCheckPath
      completion:^(NSData * _Nullable data, NSHTTPURLResponse * _Nullable response, NSError * _Nullable error) {
    if (error) {
      completion(nil, error);
      return;
    }

    if (data.length == 0) {
      completion(@{}, nil);
      return;
    }

    NSError *jsonError = nil;
    NSDictionary *payload = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
    if (jsonError || ![payload isKindOfClass:[NSDictionary class]]) {
      NSError *invalidError = [NSError errorWithDomain:kUSPAuthServiceErrorDomain
                                                  code:USPAuthServiceErrorCodeInvalidResponse
                                              userInfo:@{NSLocalizedDescriptionKey: @"Resposta inválida ao consultar token."}];
      completion(nil, invalidError);
      return;
    }

    completion(payload, nil);
  }];
}

- (void)logout {
  self.oauthToken = nil;
  self.oauthTokenSecret = nil;
  self.notificationToken = nil;
  self.notificationPlatform = @"F";
  [self.sessionStore clearAll];
}

#pragma mark - OAuth Tokens

- (void)setOauthToken:(NSString *)oauthToken {
  _oauthToken = [oauthToken copy];
  self.sessionStore.oauthToken = oauthToken;
}

- (NSString *)oauthToken {
  if (_oauthToken.length == 0) {
    _oauthToken = [self.sessionStore.oauthToken copy];
  }
  return _oauthToken;
}

- (void)setOauthTokenSecret:(NSString *)oauthTokenSecret {
  _oauthTokenSecret = [oauthTokenSecret copy];
  self.sessionStore.oauthTokenSecret = oauthTokenSecret;
}

- (NSString *)oauthTokenSecret {
  if (_oauthTokenSecret.length == 0) {
    _oauthTokenSecret = [self.sessionStore.oauthTokenSecret copy];
  }
  return _oauthTokenSecret;
}

- (void)setNotificationToken:(NSString *)notificationToken {
  _notificationToken = [notificationToken copy];
  self.sessionStore.notificationToken = notificationToken;
}

- (void)setNotificationPlatform:(NSString *)notificationPlatform {
  _notificationPlatform = notificationPlatform.length > 0 ? [notificationPlatform copy] : @"F";
  self.sessionStore.notificationPlatform = _notificationPlatform;
}

#pragma mark - Helpers

- (void)fetchUserDataWithCompletion:(void (^)(NSDictionary<NSString *,id> * _Nullable, NSError * _Nullable))completion {
  NSParameterAssert(completion);

  if (!self.config) {
    NSError *error = [NSError errorWithDomain:kUSPAuthServiceErrorDomain
                                         code:USPAuthServiceErrorCodeMissingConfig
                                     userInfo:@{NSLocalizedDescriptionKey: @"USPAuthService.config não foi configurado."}];
    [self dispatchCompletionOnMain:^{ completion(nil, error); }];
    return;
  }

  if (self.oauthToken.length == 0 || self.oauthTokenSecret.length == 0) {
    NSError *error = [NSError errorWithDomain:kUSPAuthServiceErrorDomain
                                         code:USPAuthServiceErrorCodeMissingOAuthTokens
                                     userInfo:@{NSLocalizedDescriptionKey: @"Tokens OAuth não disponíveis para buscar dados do usuário."}];
    [self dispatchCompletionOnMain:^{ completion(nil, error); }];
    return;
  }

  NSURLRequest *request = [OAuth1Controller preparedRequestForPath:kUserInfoPath
                                                        parameters:nil
                                                        HTTPmethod:@"POST"
                                                        oauthToken:self.oauthToken
                                                       oauthSecret:self.oauthTokenSecret
                                                            config:self.config];
  if (!request) {
    NSError *error = [NSError errorWithDomain:kUSPAuthServiceErrorDomain
                                         code:USPAuthServiceErrorCodeInvalidRequest
                                     userInfo:@{NSLocalizedDescriptionKey: @"Não foi possível montar a requisição de dados do usuário."}];
    [self dispatchCompletionOnMain:^{ completion(nil, error); }];
    return;
  }

  [[self.urlSession dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
    [self dispatchCompletionOnMain:^{
      if (error) {
        completion(nil, error);
        return;
      }

      if (data.length == 0) {
        NSError *emptyError = [NSError errorWithDomain:kUSPAuthServiceErrorDomain
                                                  code:USPAuthServiceErrorCodeEmptyResponse
                                              userInfo:@{NSLocalizedDescriptionKey: @"Nenhum dado recebido do servidor."}];
        completion(nil, emptyError);
        return;
      }

      NSError *jsonError = nil;
      NSDictionary *user = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
      if (jsonError || ![user isKindOfClass:[NSDictionary class]] || user.count == 0) {
        NSError *invalidError = [NSError errorWithDomain:kUSPAuthServiceErrorDomain
                                                    code:USPAuthServiceErrorCodeInvalidResponse
                                                userInfo:@{NSLocalizedDescriptionKey: @"Resposta inválida ao buscar dados do usuário."}];
        completion(nil, invalidError);
        return;
      }

      self.sessionStore.userData = user;
      completion(user, nil);
    }];
  }] resume];
}

- (NSDictionary<NSString *, id> *)registrationPayloadWithWSUserId:(NSString *)wsUserId {
  return @{
    @"token": wsUserId,
    @"tokenNotificacao": self.notificationToken ?: @"",
    @"app": [self effectiveAppKey],
    @"ambiente": @"I",
    @"plataformaNotificacao": self.notificationPlatform.length > 0 ? self.notificationPlatform : @"F"
  };
}

- (NSString *)effectiveAppKey {
  NSString *value = self.config.appKey.length > 0 ? self.config.appKey : self.appKey;
  return value ?: @"";
}

- (void)postBody:(NSDictionary *)body
       toAPIPath:(NSString *)path
      completion:(void (^)(NSData * _Nullable data,
                           NSHTTPURLResponse * _Nullable response,
                           NSError * _Nullable error))completion {
  NSURL *url = [self URLWithAPIPath:path];
  if (!url) {
    NSError *error = [NSError errorWithDomain:kUSPAuthServiceErrorDomain
                                         code:USPAuthServiceErrorCodeInvalidURL
                                     userInfo:@{NSLocalizedDescriptionKey: @"Base URL inválida na configuração."}];
    [self dispatchCompletionOnMain:^{ completion(nil, nil, error); }];
    return;
  }

  NSDictionary *headers = self.backendHeaderValue.length > 0
  ? @{ kBackendHeaderName: self.backendHeaderValue }
  : @{};
  [self.httpClient postJSON:body toURL:url headers:headers completion:^(NSData * _Nullable data, NSHTTPURLResponse * _Nullable response, NSError * _Nullable error) {
    [self dispatchCompletionOnMain:^{
      if (error) {
        completion(data, response, error);
        return;
      }

      NSInteger statusCode = response.statusCode;
      if (statusCode < 200 || statusCode >= 300) {
        NSError *statusError = [NSError errorWithDomain:kUSPAuthServiceErrorDomain
                                                   code:statusCode
                                               userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Falha na chamada %@ (status %ld).", path, (long)statusCode]}];
        completion(data, response, statusError);
        return;
      }

      completion(data, response, nil);
    }];
  }];
}

- (NSURL *)URLWithAPIPath:(NSString *)path {
  if (self.config.baseURL.length == 0 || path.length == 0) {
    return nil;
  }

  NSString *fullPath = [self.config.baseURL stringByAppendingString:path];
  return [NSURL URLWithString:fullPath];
}

- (void)dispatchCompletionOnMain:(dispatch_block_t)block {
  if (!block) return;
  if ([NSThread isMainThread]) {
    block();
  } else {
    dispatch_async(dispatch_get_main_queue(), block);
  }
}

@end

#endif
