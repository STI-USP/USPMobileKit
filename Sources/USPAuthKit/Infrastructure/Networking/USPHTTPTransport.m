#import "USPHTTPTransport.h"
@interface NSURLSessionTask (USPCancellation) <USPCancellable>
@end
@interface USPURLSessionTransport ()
@property (nonatomic, strong) NSURLSession *session;
@end
@implementation USPURLSessionTransport
- (instancetype)initWithSession:(NSURLSession *)session {
  NSParameterAssert(session);
  if ((self = [super init])) _session = session;
  return self;
}
- (id<USPCancellable>)executeRequest:(NSURLRequest *)request completion:(USPHTTPCompletion)completion {
  NSURLSessionDataTask *task = [self.session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
    NSHTTPURLResponse *http = [response isKindOfClass:NSHTTPURLResponse.class] ? (id)response : nil;
    completion(data, http, error);
  }];
  [task resume];
  return task;
}
@end
void USPAuthOnMain(dispatch_block_t block) {
  if (NSThread.isMainThread) block(); else dispatch_async(dispatch_get_main_queue(), block);
}
NSError *USPAuthError(NSInteger code, NSString *message) {
  return [NSError errorWithDomain:@"USPAuthService" code:code userInfo:@{NSLocalizedDescriptionKey:message}];
}
