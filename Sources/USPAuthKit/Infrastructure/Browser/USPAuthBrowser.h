#import <Foundation/Foundation.h>
#if __has_include(<UIKit/UIKit.h>)
#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
#endif
NS_ASSUME_NONNULL_BEGIN
@protocol USPAuthBrowser <NSObject>
- (void)begin:(dispatch_block_t)ready cancellation:(void (^)(NSError *))cancellation;
- (void)openURL:(NSURL *)url matching:(BOOL (^)(NSURL *))matches completion:(void (^)(NSURL * _Nullable, NSError * _Nullable))completion;
- (void)finish:(dispatch_block_t)completion;
- (void)cancel;
@end
#if __has_include(<UIKit/UIKit.h>)
@interface USPWKAuthBrowser : NSObject <USPAuthBrowser, WKNavigationDelegate, UIAdaptivePresentationControllerDelegate>
- (instancetype)initWithPresenter:(UIViewController *)presenter;
/// Legacy direct-WK entry point; never part of the provider-neutral domain.
- (instancetype)initWithWebView:(WKWebView *)webView;
@end
#endif
NS_ASSUME_NONNULL_END
