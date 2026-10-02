#import <Foundation/Foundation.h>
#import "USPIdentity.h"
NS_ASSUME_NONNULL_BEGIN
/// Provider-owned payload. Only that provider and its storage adapter interpret it.
@interface USPAuthSession : NSObject
@property (nonatomic, copy) NSString *providerIdentifier;
@property (nonatomic, copy) NSDictionary *providerState;
@property (nonatomic, strong, nullable) USPIdentity *identity;
@property (nonatomic, readonly) BOOL validityKnown;
@end
@protocol USPAuthSessionStoring <NSObject>
- (USPAuthSession *)loadSession;
- (void)saveSession:(USPAuthSession *)session;
- (void)updateProviderState:(NSDictionary *)state forProvider:(NSString *)identifier;
- (void)updateIdentity:(nullable USPIdentity *)identity;
- (void)clearSession;
- (void)clearAll;
@property (nonatomic, copy, nullable) NSString *notificationToken;
@property (nonatomic, copy) NSString *notificationPlatform;
@property (nonatomic) BOOL isRegistered;
@end
NS_ASSUME_NONNULL_END
