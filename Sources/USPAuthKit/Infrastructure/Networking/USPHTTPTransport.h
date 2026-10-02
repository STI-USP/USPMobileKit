#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
@protocol USPCancellable <NSObject>
- (void)cancel;
@end
typedef void (^USPHTTPCompletion)(NSData * _Nullable, NSHTTPURLResponse * _Nullable, NSError * _Nullable);
/// Internal byte transport. Status/payload policy belongs to its caller.
@protocol USPHTTPTransport <NSObject>
- (id<USPCancellable>)executeRequest:(NSURLRequest *)request completion:(USPHTTPCompletion)completion;
@end
@interface USPURLSessionTransport : NSObject <USPHTTPTransport>
- (instancetype)initWithSession:(NSURLSession *)session;
@end
FOUNDATION_EXPORT void USPAuthOnMain(dispatch_block_t block);
FOUNDATION_EXPORT NSError *USPAuthError(NSInteger code, NSString *message);
NS_ASSUME_NONNULL_END
