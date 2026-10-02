//
//  USPAuthConfig.m
//  USPAuthKit
//
//  Created by Vagner Machado on 18/08/25.
//

#import "USPAuthConfig.h"

@implementation USPAuthConfig
- (instancetype)initWithEnv:(USPAuthEnvironment)env baseURL:(NSString*)baseURL consumerKey:(NSString*)ck consumerSecret:(NSString*)cs appKey:(NSString*)appKey {
  if (self = [super init]) {
    _environment = env;
    _baseURL = [baseURL copy];
    _consumerKey = [ck copy];
    _consumerSecret = [cs copy];
    _appKey = [appKey copy];
  }
  return self;
}

+ (instancetype)devWithConsumerKey:(NSString*)ck consumerSecret:(NSString*)cs appKey:(NSString*)appKey {
  return [[self alloc] initWithEnv:USPAuthEnvironmentDev
                           baseURL:@"https://dev.uspdigital.usp.br"
                       consumerKey:ck
                    consumerSecret:cs
                            appKey:appKey];
}

+ (instancetype)prodWithConsumerKey:(NSString*)ck consumerSecret:(NSString*)cs appKey:(NSString*)appKey {
  return [[self alloc] initWithEnv:USPAuthEnvironmentProd
                           baseURL:@"https://uspdigital.usp.br"
                       consumerKey:ck
                    consumerSecret:cs
                            appKey:appKey];
}

+ (instancetype)customWithBaseURL:(NSString*)baseURL consumerKey:(NSString*)ck consumerSecret:(NSString*)cs appKey:(NSString*)appKey {
  return [[self alloc] initWithEnv:USPAuthEnvironmentCustom
                           baseURL:baseURL
                       consumerKey:ck
                    consumerSecret:cs
                            appKey:appKey];
}
@end
