#import "USPAuthSession.h"
@implementation USPAuthSession
- (instancetype)init {
  if ((self = [super init])) { _providerIdentifier = @""; _providerState = @{}; }
  return self;
}
- (BOOL)validityKnown { return NO; }
@end
