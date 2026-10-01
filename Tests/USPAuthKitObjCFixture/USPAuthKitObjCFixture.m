#import "USPAuthKitObjCFixture.h"
@import USPAuthKit;
#import <objc/runtime.h>

void USPAuthWithIsolatedStandardDefaults(NSUserDefaults *defaults, void (^body)(void)) {
    NSCParameterAssert(defaults);
    NSCParameterAssert(body);
    // Required only for the public init/shared/configure entry points, which
    // otherwise read real standard defaults. No SDK method is swizzled.
    @synchronized ([NSUserDefaults class]) {
        Method method = class_getClassMethod([NSUserDefaults class], @selector(standardUserDefaults));
        IMP original = method_getImplementation(method);
        IMP replacement = imp_implementationWithBlock(^NSUserDefaults *(id receiver) {
            return defaults;
        });
        method_setImplementation(method, replacement);
        @try {
            body();
        } @finally {
            method_setImplementation(method, original);
            imp_removeBlock(replacement);
        }
    }
}

NSDictionary<NSString *, NSNumber *> *USPAuthExerciseObjectiveCConsumer(NSUserDefaults *defaults) {
    USPAuthService *service = [[USPAuthService alloc] initWithUserDefaults:defaults];
    USPAuthService *shared = [USPAuthService sharedService];
    USPAuthConfig *config = [USPAuthConfig customWithBaseURL:@"https://example.invalid"
                                              consumerKey:@"fixture-consumer-key"
                                           consumerSecret:@"fixture-consumer-secret"
                                                   appKey:@"fixture-app"];
    [USPAuthService configureWithConfig:config];
    BOOL configured = shared.config == config && [shared.appKey isEqualToString:@"fixture-app"];
    [USPAuthService configureWithEnvironment:USPAuthEnvironmentDev
                                consumerKey:@"fixture-key"
                             consumerSecret:@"fixture-secret"
                                     appKey:@"fixture-dev-app"];
    BOOL environmentConfigured = shared.config.environment == USPAuthEnvironmentDev
        && [shared.appKey isEqualToString:@"fixture-dev-app"];

    service.config = config;
    service.appKey = @"fixture-instance-app";
    service.backendHeaderValue = @"fixture-header";
    service.oauthToken = @"fixture-oauth-token";
    service.oauthTokenSecret = @"fixture-oauth-secret";
    service.notificationToken = @"fixture-push";
    service.notificationPlatform = @"A";
    BOOL properties = service.config == config
        && [service.appKey isEqualToString:@"fixture-instance-app"]
        && [service.backendHeaderValue isEqualToString:@"fixture-header"]
        && [service.oauthToken isEqualToString:@"fixture-oauth-token"]
        && [service.oauthTokenSecret isEqualToString:@"fixture-oauth-secret"]
        && [service.notificationToken isEqualToString:@"fixture-push"]
        && [service.notificationPlatform isEqualToString:@"A"];

    [defaults setObject:[NSJSONSerialization dataWithJSONObject:@{@"wsuserid": @"fixture-mobile-credential"}
                                                            options:0 error:NULL] forKey:@"userData"];
    BOOL state = [service isLoggedIn] && [service currentUser] != nil
        && [[service currentWSUserId] isEqualToString:@"fixture-mobile-credential"]
        && [service.userData[@"wsuserid"] isEqual:@"fixture-mobile-credential"];
    [service logout];
    BOOL cleared = ![service isLoggedIn] && [service currentUser] == nil
        && [service currentWSUserId] == nil && service.userData.count == 0
        && service.oauthToken == nil && service.oauthTokenSecret == nil
        && service.notificationToken == nil && [service.notificationPlatform isEqualToString:@"F"];
    return @{@"sharedIdentity": @([USPAuthService sharedService] == shared),
             @"configured": @(configured), @"environmentConfigured": @(environmentConfigured),
             @"properties": @(properties), @"state": @(state), @"logout": @(cleared)};
}

@interface USPAuthLogoutObservationService : USPAuthService
@property (nonatomic) NSUInteger invalidationCalls;
@end

@implementation USPAuthLogoutObservationService
- (void)invalidateToken { self.invalidationCalls += 1; }
- (void)invalidateTokenWithCompletion:(void (^)(NSError * _Nullable))completion {
    self.invalidationCalls += 1;
    completion(nil);
}
@end

NSDictionary<NSString *, NSNumber *> *USPAuthObserveLegacyLocalLogout(NSUserDefaults *defaults) {
    USPAuthLogoutObservationService *service = [[USPAuthLogoutObservationService alloc] initWithUserDefaults:defaults];
    service.config = [USPAuthConfig customWithBaseURL:@"https://example.invalid"
                                        consumerKey:@"fixture-key" consumerSecret:@"fixture-secret" appKey:@"fixture-app"];
    service.oauthToken = @"fixture-token";
    service.oauthTokenSecret = @"fixture-secret";
    [defaults setObject:[NSJSONSerialization dataWithJSONObject:@{@"wsuserid": @"fixture-mobile"}
                                                            options:0 error:NULL] forKey:@"userData"];
    [service logout];
    return @{@"invalidationCalls": @(service.invalidationCalls),
             @"clearedSynchronously": @(![service isLoggedIn] && service.userData.count == 0)};
}
