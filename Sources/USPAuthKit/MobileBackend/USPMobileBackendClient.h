#import "USPHTTPTransport.h"
#import "USPAuthSession.h"
NS_ASSUME_NONNULL_BEGIN
FOUNDATION_EXPORT NSString *USPDefaultMobileHeaderValue(void);
@interface USPMobileBackendClient : NSObject
@property (nonatomic, copy) NSString *baseURL;
@property (nonatomic, copy) NSString *appKey;
@property (nonatomic, copy) NSString *headerValue;
- (instancetype)initWithTransport:(id<USPHTTPTransport>)transport;
- (id<USPCancellable> _Nullable)registerUserIdentifier:(nullable NSString *)userIdentifier notificationToken:(nullable NSString *)token platform:(NSString *)platform completion:(void (^)(NSError * _Nullable))completion;
- (id<USPCancellable> _Nullable)invalidateUserIdentifier:(nullable NSString *)userIdentifier completion:(void (^)(NSError * _Nullable))completion;
- (id<USPCancellable> _Nullable)checkUserIdentifier:(nullable NSString *)userIdentifier completion:(void (^)(NSDictionary * _Nullable, NSError * _Nullable))completion;
@end
NS_ASSUME_NONNULL_END
