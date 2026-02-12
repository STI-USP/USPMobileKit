#import "USPAuthSessionStore.h"

static NSString * const kUSPAuthDefaultsOAuthTokenKey = @"oauthToken";
static NSString * const kUSPAuthDefaultsOAuthTokenSecretKey = @"oauthTokenSecret";
static NSString * const kUSPAuthDefaultsNotificationTokenKey = @"notificationToken";
static NSString * const kUSPAuthDefaultsNotificationPlatformKey = @"notificationPlatform";
static NSString * const kUSPAuthDefaultsUserDataKey = @"userData";
static NSString * const kUSPAuthDefaultsIsRegisteredKey = @"isRegistered";

@interface USPAuthSessionStore ()
@property (nonatomic, strong) NSUserDefaults *defaults;
@end

@implementation USPAuthSessionStore

- (instancetype)initWithDefaults:(NSUserDefaults *)defaults {
  NSParameterAssert(defaults);
  if (self = [super init]) {
    _defaults = defaults;
  }
  return self;
}

- (NSString *)oauthToken {
  return [self.defaults stringForKey:kUSPAuthDefaultsOAuthTokenKey];
}

- (void)setOauthToken:(NSString *)oauthToken {
  [self setNullableString:oauthToken forKey:kUSPAuthDefaultsOAuthTokenKey];
}

- (NSString *)oauthTokenSecret {
  return [self.defaults stringForKey:kUSPAuthDefaultsOAuthTokenSecretKey];
}

- (void)setOauthTokenSecret:(NSString *)oauthTokenSecret {
  [self setNullableString:oauthTokenSecret forKey:kUSPAuthDefaultsOAuthTokenSecretKey];
}

- (NSString *)notificationToken {
  return [self.defaults stringForKey:kUSPAuthDefaultsNotificationTokenKey];
}

- (void)setNotificationToken:(NSString *)notificationToken {
  [self setNullableString:notificationToken forKey:kUSPAuthDefaultsNotificationTokenKey];
}

- (NSString *)notificationPlatform {
  NSString *platform = [self.defaults stringForKey:kUSPAuthDefaultsNotificationPlatformKey];
  return platform.length > 0 ? platform : @"F";
}

- (void)setNotificationPlatform:(NSString *)notificationPlatform {
  NSString *value = notificationPlatform.length > 0 ? notificationPlatform : @"F";
  [self.defaults setObject:value forKey:kUSPAuthDefaultsNotificationPlatformKey];
}

- (BOOL)isRegistered {
  return [self.defaults boolForKey:kUSPAuthDefaultsIsRegisteredKey];
}

- (void)setIsRegistered:(BOOL)isRegistered {
  [self.defaults setBool:isRegistered forKey:kUSPAuthDefaultsIsRegisteredKey];
}

- (NSDictionary<NSString *,id> *)userData {
  NSData *data = [self.defaults objectForKey:kUSPAuthDefaultsUserDataKey];
  if (![data isKindOfClass:[NSData class]] || data.length == 0) {
    return nil;
  }

  NSError *jsonError = nil;
  NSDictionary *parsed = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
  if (jsonError || ![parsed isKindOfClass:NSDictionary.class]) {
    return nil;
  }
  return parsed;
}

- (void)setUserData:(NSDictionary<NSString *,id> *)userData {
  if (userData.count == 0) {
    [self.defaults removeObjectForKey:kUSPAuthDefaultsUserDataKey];
    return;
  }

  NSError *error = nil;
  NSData *data = [NSJSONSerialization dataWithJSONObject:userData options:0 error:&error];
  if (!error && data.length > 0) {
    [self.defaults setObject:data forKey:kUSPAuthDefaultsUserDataKey];
  }
}

- (BOOL)hasValidSession {
  NSDictionary *cachedUser = self.userData;
  return self.oauthToken.length > 0 && self.oauthTokenSecret.length > 0 && cachedUser.count > 0;
}

- (void)clearSession {
  [self.defaults removeObjectForKey:kUSPAuthDefaultsOAuthTokenKey];
  [self.defaults removeObjectForKey:kUSPAuthDefaultsOAuthTokenSecretKey];
  [self.defaults removeObjectForKey:kUSPAuthDefaultsUserDataKey];
  [self.defaults removeObjectForKey:kUSPAuthDefaultsIsRegisteredKey];
}

- (void)clearAll {
  [self clearSession];
  [self.defaults removeObjectForKey:kUSPAuthDefaultsNotificationTokenKey];
  [self.defaults removeObjectForKey:kUSPAuthDefaultsNotificationPlatformKey];
}

- (void)setNullableString:(NSString *)value forKey:(NSString *)key {
  if (value.length > 0) {
    [self.defaults setObject:value forKey:key];
  } else {
    [self.defaults removeObjectForKey:key];
  }
}

@end
