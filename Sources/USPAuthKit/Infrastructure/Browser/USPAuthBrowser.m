#if __has_include(<UIKit/UIKit.h>)
#import "USPAuthBrowser.h"
#import "USPHTTPTransport.h"
#import "LoginWebViewController.h"
@interface USPWKAuthBrowser ()
@property (nonatomic, weak) UIViewController *presenter;
@property (nonatomic, strong) UINavigationController *navigation;
@property (nonatomic, strong) LoginWebViewController *controller;
@property (nonatomic, strong) WKWebView *webView;
@property (nonatomic, copy) BOOL (^matches)(NSURL *);
@property (nonatomic, copy) void (^callback)(NSURL *, NSError *);
@property (nonatomic, copy) void (^cancellation)(NSError *);
@property (nonatomic) BOOL finished;
@property (nonatomic) BOOL callbackConsumed;
@end
@implementation USPWKAuthBrowser
- (instancetype)initWithPresenter:(UIViewController *)presenter {
  if ((self = [super init])) _presenter = presenter;
  return self;
}
- (instancetype)initWithWebView:(WKWebView *)webView {
  if ((self = [super init])) _webView = webView;
  return self;
}
- (void)begin:(dispatch_block_t)ready cancellation:(void (^)(NSError *))cancellation {
  self.cancellation = cancellation;
  if (self.webView) { ready(); return; }
  self.controller = [LoginWebViewController new];
  __weak typeof(self) weakSelf = self;
  self.controller.ready = ^(WKWebView *webView) {
    if (weakSelf.finished) { return; }

    weakSelf.webView = webView;
    ready();
  };
  self.controller.cancellation = ^{ [weakSelf cancel]; };
  self.navigation = [[UINavigationController alloc] initWithRootViewController:self.controller];
  if (self.presenter.traitCollection.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
    self.navigation.modalPresentationStyle = UIModalPresentationPageSheet;
    if (@available(iOS 15.0, *)) {
      self.navigation.sheetPresentationController.detents = @[UISheetPresentationControllerDetent.largeDetent];
      self.navigation.sheetPresentationController.prefersGrabberVisible = YES;
    }
  } else self.navigation.modalPresentationStyle = UIModalPresentationFullScreen;
  self.navigation.presentationController.delegate = self;
  dispatch_async(dispatch_get_main_queue(), ^{
    if (!self.finished) { [self.presenter presentViewController:self.navigation animated:YES completion:nil]; }
  });
}
- (void)openURL:(NSURL *)url matching:(BOOL (^)(NSURL *))matches completion:(void (^)(NSURL *, NSError *))completion {
  if (self.finished) return;

  self.matches = matches;
  self.callback = completion;
  self.webView.navigationDelegate = self;
  [self.webView loadRequest:[NSURLRequest requestWithURL:url]];
}
- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)action decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
  NSURL *url = action.request.URL;

  if (!self.finished && url && self.matches && self.matches(url)) {
    void (^callback)(NSURL *, NSError *) = self.callback;
    self.callback = nil;
    self.matches = nil;
    // Transfer responsibility before cancelling navigation: WK may report failure
    // synchronously or later, while the provider is exchanging the access token.
    self.callbackConsumed = YES;
    decisionHandler(WKNavigationActionPolicyCancel);
    if (callback) callback(url, nil);
  } else decisionHandler(WKNavigationActionPolicyAllow);
}
- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error { [self fail:error]; }
- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error { [self fail:error]; }
- (void)fail:(NSError *)error {
  if (self.callbackConsumed) return;
  if (error.code == NSURLErrorCancelled || self.finished) return;
  void (^callback)(NSURL *, NSError *) = self.callback;
  self.callback = nil; self.matches = nil;
  if (callback) callback(nil, error); else if (self.cancellation) self.cancellation(error);
}
- (void)presentationControllerDidDismiss:(UIPresentationController *)presentationController { [self cancel]; }
- (void)cancel {
  if (self.finished) return;
  void (^cancellation)(NSError *) = self.cancellation;
  [self finish:^{}];
  if (cancellation) cancellation([NSError errorWithDomain:@"LoginWebViewController" code:NSUserCancelledError userInfo:@{NSLocalizedDescriptionKey:@"Login cancelado pelo usuário."}]);
}
- (void)finish:(dispatch_block_t)completion {
  self.finished = YES;
  self.callback = nil; self.matches = nil; self.cancellation = nil;
  [self.webView stopLoading];
  if (self.webView.navigationDelegate == self) self.webView.navigationDelegate = nil;
  [self.controller disposeWebView];
  if (self.navigation && self.presenter.presentedViewController == self.navigation) {
    [self.presenter dismissViewControllerAnimated:YES completion:^{ completion(); }];
  } else { completion(); }
}
@end
#endif
