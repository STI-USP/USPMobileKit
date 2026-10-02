#if __has_include(<UIKit/UIKit.h>)
#import "USPAuthenticationProvider.h"
#import "USPAuthBrowser.h"
#import "USPHTTPTransport.h"
@class USPAuthConfig;
NS_ASSUME_NONNULL_BEGIN
@interface USPOAuth1AuthenticationProvider : NSObject <USPAuthenticationProvider>
- (instancetype)initWithStore:(id<USPAuthSessionStoring>)store transport:(id<USPHTTPTransport>)transport browserFactory:(id<USPAuthBrowser>(^)(UIViewController *))factory clock:(NSDate *(^)(void))clock nonce:(NSString *(^)(void))nonce;
@property (nonatomic, strong, nullable) USPAuthConfig *config;
/// Legacy OAuth1 Compatibility API: never added to the neutral provider protocol.
@property (nonatomic, copy, nullable) NSString *legacyToken;
@property (nonatomic, copy, nullable) NSString *legacySecret;
- (void)loginInWebView:(WKWebView *)webView completion:(void (^)(BOOL, NSError * _Nullable))completion;
@end
NS_ASSUME_NONNULL_END
#endif
