#pragma once
#import <XCTest/XCTest.h>
#import "USPHTTPTransport.h"
#import "USPAuthBrowser.h"
#import "USPAuthServiceInternal.h"
#import "USPApplicationConfiguration.h"
#import "USPAuthVinculo.h"
#import "HTTPClient.h"
#import "USPAuthSessionStore.h"
#import "USPAuthenticationCoordinator.h"
#import "USPAuthConfig.h"
#import "LoginWebViewController.h"


@class USPOAuth1AuthenticationProvider;
@interface TestHandle : NSObject <USPCancellable>
@property BOOL cancelled;
@end
@interface FakeTransport : NSObject <USPHTTPTransport>
- (void)respond:(NSUInteger)index text:(NSString *)text status:(NSInteger)status error:(NSError *)error;
@property NSMutableArray<NSURLRequest *> *requests;
@property NSMutableArray<USPHTTPCompletion> *callbacks;
@property NSMutableArray<TestHandle *> *handles;
@end
@interface FakeBrowser : NSObject <USPAuthBrowser>
@property NSURL *url;
@property BOOL finished;
@property BOOL cancelled;
@property NSUInteger begins;
@property (copy) BOOL (^matches)(NSURL *);
@property (copy) void (^callback)(NSURL *, NSError *);
@property (copy) void (^cancellation)(NSError *);
@end
@interface MemoryStore : NSObject <USPAuthSessionStoring>
@property USPAuthSession *session;
@property (nonatomic, copy) NSString *notificationToken;
@property (nonatomic, copy) NSString *notificationPlatform;
@property (nonatomic) BOOL isRegistered;
@end
@interface FakeAuthenticationProvider : NSObject <USPAuthenticationProvider>
@property BOOL available;
@property BOOL cancelled;
@property NSUInteger calls;
@property (copy) void (^result)(USPIdentity *, NSError *);
- (void)resolveUser:(USPAuthUser *)user;
@end
@interface StubURLProtocol : NSURLProtocol
@end
@interface RecordingWebView : WKWebView
@property NSURLRequest *recordedRequest;
@end
@interface FixtureNavigationAction : WKNavigationAction
@property NSURLRequest *fixtureRequest;
@end
@interface USPAuthArchitectureTests : XCTestCase {
@protected
  USPOAuth1AuthenticationProvider *_provider;
}
@property NSString *suite;
@property NSUserDefaults *defaults;
@property USPAuthSessionStore *store;
@property FakeTransport *transport;
@property FakeBrowser *browser;
@property (nonatomic, strong) USPOAuth1AuthenticationProvider *provider;
@property UIViewController *presenter;
- (void)until:(BOOL (^)(void))condition;
- (USPMobileBackendClient *)mobile;
- (void)advanceToAuthorization;
- (void)advanceToProfile;
- (NSDictionary *)bodyAt:(NSUInteger)index;
- (NSDictionary *)authorizationFields:(NSUInteger)index;
- (USPAuthUser *)standardFixtureUser;
- (void)assertStandardProfile:(USPAuthUser *)user;
@end

extern NSInteger StubStatus;
extern BOOL StubWait;
extern NSError *StubError;
