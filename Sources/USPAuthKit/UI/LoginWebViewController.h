//
//  LoginWebViewController.h
//  NuAuthKit
//
//  Created by Vagner Machado on 22/05/25.
//

#if __has_include(<UIKit/UIKit.h>)

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// VC que apresenta o fluxo de OAuth 1.0 em WKWebView
@interface LoginWebViewController : UIViewController

/// Bloco chamado ao concluir o login OAuth no webview.
@property (nonatomic, copy) void (^loginCompletion)(BOOL success, NSError * _Nullable error);

/// Descarta a webview e limpa delegates
- (void)disposeWebView;


@end

NS_ASSUME_NONNULL_END

#endif
