#if __has_include(<UIKit/UIKit.h>)
#import "USPAuthService.h"
#import "USPAuthenticationCoordinator.h"
@class USPOAuth1AuthenticationProvider, USPApplicationConfiguration;
NS_ASSUME_NONNULL_BEGIN
// Composition entry point for SDK internals/tests, never exported to consumers.
@interface USPAuthService ()
- (instancetype)initWithCoordinator:(USPAuthenticationCoordinator *)coordinator legacyProvider:(nullable USPOAuth1AuthenticationProvider *)provider NS_DESIGNATED_INITIALIZER;
- (void)applyApplicationConfiguration:(USPApplicationConfiguration *)configuration;
@end
NS_ASSUME_NONNULL_END
#endif
