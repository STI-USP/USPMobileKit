#if __has_include(<UIKit/UIKit.h>)
#import "USPAuthenticationCoordinator.h"
// An operation owns exactly one completion, including synchronous failures and logout.
@interface USPMobileOperation : NSObject <USPCancellable>
@property (nonatomic, strong) id<USPCancellable> handle;
@property (nonatomic, copy) void (^result)(NSDictionary *, NSError *);
@property (nonatomic) BOOL finished;
- (void)complete:(NSDictionary *)payload error:(NSError *)error;
@end
@implementation USPMobileOperation
- (void)complete:(NSDictionary *)payload error:(NSError *)error {
  if (self.finished) return;
  self.finished = YES;
  void (^result)(NSDictionary *, NSError *) = self.result;
  self.result = nil;
  self.handle = nil;
  if (result) result(payload, error);
}
- (void)cancel {
  id<USPCancellable> handle = self.handle;
  [self complete:nil error:USPAuthError(NSUserCancelledError, @"Operação cancelada.")];
  [handle cancel];
}
@end
@interface USPAuthenticationCoordinator ()
@property (nonatomic) NSUInteger generation;
@property (nonatomic, copy) void (^pending)(USPAuthUser *, NSError *);
@property (nonatomic, strong) NSMutableArray<id<USPCancellable>> *tasks;
@end
@implementation USPAuthenticationCoordinator
- (instancetype)initWithProvider:(id<USPAuthenticationProvider>)provider store:(id<USPAuthSessionStoring>)store mobileClient:(USPMobileBackendClient *)mobile {
  if ((self = [super init])) {
    _provider = provider; _store = store; _mobile = mobile; _tasks = [NSMutableArray new];
    _notificationToken = [store.notificationToken copy]; _notificationPlatform = [store.notificationPlatform copy];
  }
  return self;
}
- (USPAuthSession *)session { return [self.store loadSession]; }
- (BOOL)isLoggedIn { USPAuthSession *session = self.session; return session.identity != nil && [self.provider recognizesSession:session]; }
- (void)setNotificationToken:(NSString *)token { _notificationToken = [token copy]; self.store.notificationToken = token; }
- (void)setNotificationPlatform:(NSString *)platform { _notificationPlatform = platform.length ? [platform copy] : @"F"; self.store.notificationPlatform = _notificationPlatform; }
- (void)ensureFromViewController:(UIViewController *)presenter completion:(void (^)(USPAuthUser *, NSError *))completion {
  USPAuthOnMain(^{
    if (self.pending) { completion(nil, USPAuthError(1001, @"Login já em andamento.")); return; }
    USPIdentity *cached = self.session.identity;
    if (cached && [self.provider hasCachedCredential]) {  completion(cached.user, nil); return; }
    NSUInteger generation = ++self.generation;
    self.pending = completion;
    __block BOOL authenticationHandled = NO;
    [self.provider authenticateFromViewController:presenter completion:^(USPIdentity *identity, NSError *error) {
      USPAuthOnMain(^{
        if (generation != self.generation || !self.pending || authenticationHandled) { return; }

        authenticationHandled = YES;
        if (error || !identity) { [self finish:nil error:error ?: USPAuthError(1005, @"Dados do usuário não encontrados.")]; return; }
        [self.store updateIdentity:identity];
        [self registerWithCompletion:^(NSError *error) {
          if (generation == self.generation && self.pending) [self finish:error ? nil : identity.user error:error];
        }];
      });
    }];
  });
}
- (void)finish:(USPAuthUser *)user error:(NSError *)error {
  void (^pending)(USPAuthUser *, NSError *) = self.pending;
  self.pending = nil;

  if (pending) pending(user, error);
}
- (void)performMobile:(id<USPCancellable> (^)(void (^)(NSDictionary *, NSError *)))start completion:(void (^)(NSDictionary *, NSError *))completion {
  USPAuthOnMain(^{
    USPMobileOperation *operation = [USPMobileOperation new];
    __weak USPAuthenticationCoordinator *owner = self;
    __weak USPMobileOperation *weakOperation = operation;
    operation.result = ^(NSDictionary *payload, NSError *error) {
      [owner.tasks removeObject:weakOperation];
      completion(payload, error);
    };
    [self.tasks addObject:operation];
    id<USPCancellable> handle = start(^(NSDictionary *payload, NSError *error) {
      USPAuthOnMain(^{ [operation complete:payload error:error]; });
    });
    if (!operation.finished) operation.handle = handle;
  });
}
- (void)registerWithCompletion:(void (^)(NSError *))completion {
  [self performMobile:^id<USPCancellable>(void (^result)(NSDictionary *, NSError *)) {
    return [self.mobile registerUserIdentifier:self.session.identity.user.wsuserid notificationToken:self.notificationToken platform:self.notificationPlatform completion:^(NSError *error) { result(nil, error); }];
  } completion:^(NSDictionary *payload, NSError *error) {
    if (!error) self.store.isRegistered = YES;
    completion(error);
  }];
}
- (void)invalidateWithCompletion:(void (^)(NSError *))completion {
  [self performMobile:^id<USPCancellable>(void (^result)(NSDictionary *, NSError *)) {
    return [self.mobile invalidateUserIdentifier:self.session.identity.user.wsuserid completion:^(NSError *error) { result(nil, error); }];
  } completion:^(NSDictionary *payload, NSError *error) { completion(error); }];
}
- (void)checkWithCompletion:(void (^)(NSDictionary *, NSError *))completion {
  [self performMobile:^id<USPCancellable>(void (^result)(NSDictionary *, NSError *)) {
    return [self.mobile checkUserIdentifier:self.session.identity.user.wsuserid completion:result];
  } completion:completion];
}
- (void)updateNotificationToken:(NSString *)token {
  USPAuthOnMain(^{
    if ([(token ?: @"") isEqual:(self.notificationToken ?: @"")]) return;
    self.notificationToken = token;
    if (self.isLoggedIn) [self registerWithCompletion:^(NSError *error) { if (error) NSLog(@"[USPAuth] Falha ao registrar token de push após update: %@", error.localizedDescription); }];
  });
}
- (void)logout {
  dispatch_block_t clear = ^{
    ++self.generation;
    void (^pending)(USPAuthUser *, NSError *) = self.pending;
    self.pending = nil;
    [self.provider cancel]; [self.provider clearCredential];
    NSArray *tasks = [self.tasks copy];
    [self.tasks removeAllObjects];
    _notificationToken = nil; _notificationPlatform = @"F";
    [self.store clearAll];
    for (id<USPCancellable> task in tasks) [task cancel];
    if (pending) pending(nil, [NSError errorWithDomain:@"LoginWebViewController" code:NSUserCancelledError userInfo:@{NSLocalizedDescriptionKey:@"Login cancelado pelo usuário."}]);
  };
  if (NSThread.isMainThread) clear(); else dispatch_sync(dispatch_get_main_queue(), clear);
}
@end
#endif
