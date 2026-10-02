#import <Foundation/Foundation.h>
#import "USPAuthUser.h"
NS_ASSUME_NONNULL_BEGIN
@interface USPIdentity : NSObject
@property (nonatomic, copy, readonly) NSDictionary *metadata;
@property (nonatomic, strong, readonly) USPAuthUser *user;
// Typed profile is canonical; metadata remains a legacy persistence/API adapter.
- (instancetype)initWithUser:(USPAuthUser *)user;
- (instancetype)initWithMetadata:(NSDictionary *)metadata;
@end
NS_ASSUME_NONNULL_END
