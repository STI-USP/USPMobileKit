//  LoginWebViewController.m
//  NuAuthKit
//
//  Created by Vagner Machado on 22/05/25.
//

#if __has_include(<UIKit/UIKit.h>)

#import "LoginWebViewController.h"

#import <WebKit/WebKit.h>


static UIColor *USPAuthLoadingColor(void) {
  return [UIColor colorWithRed:(100.0 / 255.0)
                         green:(196.0 / 255.0)
                          blue:(210.0 / 255.0)
                         alpha:1.0];
}

@interface LoginWebViewController ()
@property (nonatomic, strong) WKWebView *webView;
@property (nonatomic, strong) UIProgressView *progressView;
@property (nonatomic) BOOL started;
@property (nonatomic) BOOL observing;
@end

@implementation LoginWebViewController

- (void)dealloc { [self disposeWebView]; }
- (void)disposeWebView {
  if (self.observing) {
    [self.webView removeObserver:self forKeyPath:@"estimatedProgress"];
    self.observing = NO;
  }
  [self.webView stopLoading];
  self.webView.navigationDelegate = nil;
  self.ready = nil;
  self.cancellation = nil;
}

#pragma mark - View Lifecycle

- (void)loadView {
  UIView *root = [[UIView alloc] initWithFrame:[UIScreen mainScreen].bounds];
  root.backgroundColor = UIColor.systemBackgroundColor;
  self.view = root;

  // Barra de progresso fina logo abaixo do nav-bar
  self.progressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleBar];
  self.progressView.translatesAutoresizingMaskIntoConstraints = NO;
  self.progressView.tintColor = USPAuthLoadingColor();
  [root addSubview:self.progressView];

  // WebView
  WKWebViewConfiguration *cfg = [[WKWebViewConfiguration alloc] init];
  self.webView = [[WKWebView alloc] initWithFrame:CGRectZero configuration:cfg];
  self.webView.translatesAutoresizingMaskIntoConstraints = NO;
  [root addSubview:self.webView];

  [NSLayoutConstraint activateConstraints:@[
    [self.progressView.topAnchor constraintEqualToAnchor:root.safeAreaLayoutGuide.topAnchor],
    [self.progressView.leadingAnchor constraintEqualToAnchor:root.leadingAnchor],
    [self.progressView.trailingAnchor constraintEqualToAnchor:root.trailingAnchor],

    [self.webView.topAnchor constraintEqualToAnchor:self.progressView.bottomAnchor],
    [self.webView.leadingAnchor constraintEqualToAnchor:root.leadingAnchor],
    [self.webView.trailingAnchor constraintEqualToAnchor:root.trailingAnchor],
    [self.webView.bottomAnchor constraintEqualToAnchor:root.bottomAnchor],
  ]];
}

- (void)viewDidLoad {
  [super viewDidLoad];

  // Título + botão Cancelar
  //self.title = @"Entrar";
  UIBarButtonItem *cancelBtn = [[UIBarButtonItem alloc] initWithTitle:@"Cancelar" style:UIBarButtonItemStylePlain target:self action:@selector(cancel)];
  self.navigationItem.rightBarButtonItem = cancelBtn;

  // Observa progresso
  self.observing = YES;
  [self.webView addObserver:self forKeyPath:@"estimatedProgress" options:NSKeyValueObservingOptionNew context:nil];
}

- (void)viewDidAppear:(BOOL)animated {
  [super viewDidAppear:animated];
  if (!self.started) {
    self.started = YES;
    if (self.ready) self.ready(self.webView);
  }
}

#pragma mark - Cancel & Progress
- (void)cancel { if (self.cancellation) self.cancellation(); }

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)contex {
  if ([keyPath isEqualToString:@"estimatedProgress"]) {
    self.progressView.progress = self.webView.estimatedProgress;
    self.progressView.hidden = self.progressView.progress >= 1.0;
  }
}

@end
#endif
