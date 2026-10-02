// OAuth1Controller.h
// USPAuthKit
//
// Adapted by Vagner Machado on 22/05/25.
//

#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>
#import "USPHTTPTransport.h"
#import "USPAuthBrowser.h"

NS_ASSUME_NONNULL_BEGIN

@class USPAuthConfig;

@interface OAuth1Controller : NSObject

- (instancetype)initWithConfig:(USPAuthConfig *)config;
- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithConfig:(USPAuthConfig *)config transport:(id<USPHTTPTransport>)transport clock:(NSDate *(^)(void))clock nonce:(NSString *(^)(void))nonce;
- (void)loginWithBrowser:(id<USPAuthBrowser>)browser completion:(void (^)(NSDictionary * _Nullable, NSError * _Nullable))completion;
- (void)cancel;
- (NSURLRequest * _Nullable)identityRequestWithToken:(NSString *)token secret:(NSString *)secret;
+ (NSMutableDictionary *)standardParametersWithConsumerKey:(NSString *)key date:(NSDate *)date nonce:(NSString *)nonce;
+ (NSString *)baseStringWithMethod:(NSString *)method url:(NSString *)url parameters:(NSDictionary *)params;
+ (NSString *)authorizationHeaderFromParams:(NSDictionary *)params;
+ (NSString *)signClearText:(NSString *)text withSecret:(NSString *)secret;
/// Correlated callback validation; keeps the legacy localhost destination forms.
+ (NSString * _Nullable)callbackRejectionReason:(NSURL *)url requestToken:(NSString *)token;
+ (NSDictionary * _Nullable)validatedCallbackURL:(NSURL *)url requestToken:(NSString *)token;

#if __has_include(<UIKit/UIKit.h>)
/// Passo único de login (request token → authorize → access token).
- (void)loginWithWebView:(WKWebView *)webView
              completion:(void (^)(NSDictionary<NSString*,NSString*> * _Nullable accessParams,
                                   NSError * _Nullable error))completion;
#endif

/// Constrói uma request assinada para um endpoint OAuth 1.0a (HMAC-SHA1).
+ (NSURLRequest * _Nullable)preparedRequestForPath:(NSString *)path
                                        parameters:(nullable NSDictionary *)queryParameters
                                        HTTPmethod:(NSString *)HTTPmethod
                                        oauthToken:(NSString *)oauth_token
                                       oauthSecret:(NSString *)oauth_token_secret
                                            config:(USPAuthConfig *)config;

/// Parser defensivo para query strings OAuth (ignora pares inválidos).
+ (NSDictionary<NSString *, NSString *> *)parametersFromQueryString:(nullable NSString *)queryString;

@end

NS_ASSUME_NONNULL_END
