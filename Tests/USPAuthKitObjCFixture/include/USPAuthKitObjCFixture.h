#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Test-only, synchronous scope. Never run concurrently with defaults consumers
/// in the same process. Restores the original implementation even on exception.
FOUNDATION_EXPORT void USPAuthWithIsolatedStandardDefaults(NSUserDefaults *defaults,
                                                           void (^body)(void));

/// A real Objective-C consumer of exported SDK selectors; no login or network.
FOUNDATION_EXPORT NSDictionary<NSString *, NSNumber *> *USPAuthExerciseObjectiveCConsumer(NSUserDefaults *defaults);

/// Observes the two public invalidation entry points without replacing transport.
FOUNDATION_EXPORT NSDictionary<NSString *, NSNumber *> *USPAuthObserveLegacyLocalLogout(NSUserDefaults *defaults);

NS_ASSUME_NONNULL_END
