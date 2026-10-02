#if __has_include(<UIKit/UIKit.h>)
#import <UIKit/UIKit.h>
#import "USPAuthSession.h"
NS_ASSUME_NONNULL_BEGIN
/// Internal authentication contract. No protocol credentials or browser type cross it.
@protocol USPAuthenticationProvider <NSObject>
@property (nonatomic, copy, readonly) NSString *identifier;
- (BOOL)hasCachedCredential;
- (BOOL)recognizesSession:(USPAuthSession *)session;
- (void)authenticateFromViewController:(UIViewController *)presenter completion:(void (^)(USPIdentity * _Nullable, NSError * _Nullable))completion;
- (void)cancel;
- (void)clearCredential;
@end
NS_ASSUME_NONNULL_END
#endif
