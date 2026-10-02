#if __has_include(<UIKit/UIKit.h>)
#import "USPAuthenticationProvider.h"
#import "USPMobileBackendClient.h"
NS_ASSUME_NONNULL_BEGIN
@interface USPAuthenticationCoordinator : NSObject
- (instancetype)initWithProvider:(id<USPAuthenticationProvider>)provider store:(id<USPAuthSessionStoring>)store mobileClient:(USPMobileBackendClient *)mobile;
@property (nonatomic, strong, readonly) id<USPAuthenticationProvider> provider;
@property (nonatomic, strong, readonly) id<USPAuthSessionStoring> store;
@property (nonatomic, strong, readonly) USPMobileBackendClient *mobile;
@property (nonatomic, copy, nullable) NSString *notificationToken;
@property (nonatomic, copy) NSString *notificationPlatform;
- (USPAuthSession *)session;
- (BOOL)isLoggedIn;
- (void)ensureFromViewController:(UIViewController *)presenter completion:(void (^)(USPAuthUser * _Nullable, NSError * _Nullable))completion;
- (void)registerWithCompletion:(void (^)(NSError * _Nullable))completion;
- (void)invalidateWithCompletion:(void (^)(NSError * _Nullable))completion;
- (void)checkWithCompletion:(void (^)(NSDictionary * _Nullable, NSError * _Nullable))completion;
- (void)updateNotificationToken:(nullable NSString *)token;
- (void)logout;
@end
NS_ASSUME_NONNULL_END
#endif
