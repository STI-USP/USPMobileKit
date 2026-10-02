#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
/// Resolved application/environment settings, with no authentication-protocol fields.
/// Provider-specific configuration is composed separately by the legacy facade adapter.
@interface USPApplicationConfiguration : NSObject
@property (nonatomic, copy) NSString *baseURL;
@property (nonatomic, copy) NSString *appKey;
@property (nonatomic, copy) NSString *backendHeaderValue;
- (instancetype)initWithBaseURL:(NSString *)baseURL appKey:(NSString *)appKey backendHeaderValue:(NSString *)header;
@end
NS_ASSUME_NONNULL_END
