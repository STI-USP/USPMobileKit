//
//  USPAuthService.h
//  NuAuthKit
//
//  Created by Vagner Machado on 22/05/25.
//

#import <Foundation/Foundation.h>
#if __has_include(<UIKit/UIKit.h>)
#import <UIKit/UIKit.h>
#else
@class UIViewController;
#endif
#if __has_include(<WebKit/WebKit.h>)
#import <WebKit/WebKit.h>
#else
@class WKWebView;
#endif
#import "USPAuthConfig.h"
@class USPAuthUser;
@class USPAuthConfig;

NS_ASSUME_NONNULL_BEGIN

/// Gerencia login/logout via OAuth1 e registro/invalidação/consulta de token no backend USP
@interface USPAuthService : NSObject

/// Tokens do OAuth1
@property (nonatomic, copy, nullable) NSString  *oauthToken;
@property (nonatomic, copy, nullable) NSString  *oauthTokenSecret;

/// Chave da sua aplicação a ser enviada no registro de token.
@property (nonatomic, copy) NSString *appKey;
/// Valor enviado no header `DEV-USP-MOBILE` nas chamadas ao backend mobile.
@property (nonatomic, copy) NSString *backendHeaderValue;
@property (nonatomic, strong) USPAuthConfig *config;

/// Token de push do dispositivo (APNs ou FCM). Se setado, será enviado no /registrar.
@property (nonatomic, copy, nullable) NSString *notificationToken;
@property (nonatomic, copy) NSString *notificationPlatform;

/// Dados do usuário retornados pela API (JSON desserializado)
@property (nonatomic, readonly) NSDictionary<NSString*, id> *userData;

/// Singleton
+ (instancetype)sharedService;

/// Config
+ (void)configureWithEnvironment:(USPAuthEnvironment)env consumerKey:(NSString *)consumerKey consumerSecret:(NSString *)consumerSecret appKey:(NSString *)appKey;
/// Configuração explícita (recomendado para ambiente custom).
+ (void)configureWithConfig:(USPAuthConfig *)config;

/// Permite injetar um NSUserDefaults dedicado (ex.: testes com suite isolada).
- (instancetype)initWithUserDefaults:(NSUserDefaults *)defaults NS_DESIGNATED_INITIALIZER;
- (instancetype)init;

/// Atualiza o token de push em memória + persiste em NSUserDefaults
- (void)updateNotificationToken:(nullable NSString *)token;


/// Garante que o user esteja logado:
/// • se já houver cache, devolve imediatamente
/// • senão, apresenta o LoginWebViewController e, ao final, devolve o user
- (void)ensureLoggedInFromViewController:(UIViewController*)fromVC
                              completion:(void(^)(USPAuthUser * _Nullable user,
                                                  NSError * _Nullable error))completion;
/// Garante que o usuário está logado (cache válido + tokens presentes)
- (BOOL)isLoggedIn;

/// Retorna o usuário atual (ou nil se não estiver logado)
- (nullable USPAuthUser*)currentUser;
/// Retorna o token usado pelos apps clientes nas requisições internas (wsuserid).
- (nullable NSString *)currentWSUserId;

/// Apresenta o fluxo de login num WKWebView. Chama completion com sucesso ou erro.
- (void)loginInWebView:(WKWebView*)webView
           completion:(void (^)(BOOL success, NSError * _Nullable error))completion;

/// Logout: invalida no servidor e limpa credenciais locais
- (void)logout;

/// Registro do token no backend USP
- (void)registerToken;
- (void)registerTokenWithCompletion:(void(^)(NSError * _Nullable error))completion;

/// Invalidação do token no backend USP
- (void)invalidateToken;
- (void)invalidateTokenWithCompletion:(void(^)(NSError * _Nullable error))completion;

/// Consulta status do token no backend USP
- (void)checkToken;
- (void)checkTokenWithCompletion:(void(^)(NSDictionary<NSString *, id> * _Nullable payload,
                                          NSError * _Nullable error))completion;

@end

NS_ASSUME_NONNULL_END
