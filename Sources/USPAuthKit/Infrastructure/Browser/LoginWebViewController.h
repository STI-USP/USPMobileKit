//
//  LoginWebViewController.h
//  NuAuthKit
//
//  Created by Vagner Machado on 22/05/25.
//

#if __has_include(<UIKit/UIKit.h>)

#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>

NS_ASSUME_NONNULL_BEGIN

/// VC de apresentação WKWebView controlado pela operação de browser
@interface LoginWebViewController : UIViewController

/// The browser operation owns the flow; no singleton or service access from UI.
@property (nonatomic, copy, nullable) void (^ready)(WKWebView *webView);
@property (nonatomic, copy, nullable) dispatch_block_t cancellation;
/// Descarta a webview e limpa delegates
- (void)disposeWebView;


@end

NS_ASSUME_NONNULL_END

#endif
