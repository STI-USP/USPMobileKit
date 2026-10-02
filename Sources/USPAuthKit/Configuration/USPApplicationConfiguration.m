#import "USPApplicationConfiguration.h"
@implementation USPApplicationConfiguration
- (instancetype)initWithBaseURL:(NSString *)baseURL appKey:(NSString *)appKey backendHeaderValue:(NSString *)header {
  if ((self = [super init])) { _baseURL = [baseURL copy]; _appKey = [appKey copy]; _backendHeaderValue = [header copy]; }
  return self;
}
@end
