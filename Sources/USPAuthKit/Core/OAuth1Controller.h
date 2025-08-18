// OAuth1Controller.h
// USPAuthKit
//
// Adapted by Vagner Machado on 22/05/25.
//

#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>

NS_ASSUME_NONNULL_BEGIN

@class USPAuthConfig;

@interface OAuth1Controller : NSObject <WKNavigationDelegate>

- (instancetype)initWithConfig:(USPAuthConfig *)config NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

/// Passo único de login (request token → authorize → access token).
- (void)loginWithWebView:(WKWebView *)webView
              completion:(void (^)(NSDictionary<NSString*,NSString*> * _Nullable accessParams,
                                   NSError * _Nullable error))completion;

/// Constrói uma request assinada para um endpoint OAuth 1.0a (HMAC-SHA1).
+ (NSURLRequest * _Nullable)preparedRequestForPath:(NSString *)path
                                        parameters:(nullable NSDictionary *)queryParameters
                                        HTTPmethod:(NSString *)HTTPmethod
                                        oauthToken:(NSString *)oauth_token
                                       oauthSecret:(NSString *)oauth_token_secret
                                            config:(USPAuthConfig *)config;

@end

NS_ASSUME_NONNULL_END
