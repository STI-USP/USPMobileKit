//
//  USPAuthConfig.h
//  USPAuthKit
//
//  Created by Vagner Machado on 18/08/25.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, USPAuthEnvironment) {
  USPAuthEnvironmentDev = 0,
  USPAuthEnvironmentProd = 1,
  USPAuthEnvironmentCustom = 2
};

@interface USPAuthConfig : NSObject
@property (nonatomic, assign, readonly) USPAuthEnvironment environment;
@property (nonatomic, copy, readonly) NSString *baseURL; // ex: https://dev.uspdigital.usp.br
@property (nonatomic, copy, readonly) NSString *consumerKey;
@property (nonatomic, copy, readonly) NSString *consumerSecret;
@property (nonatomic, copy, readonly) NSString *appKey;

+ (instancetype)devWithConsumerKey:(NSString*)ck consumerSecret:(NSString*)cs appKey:(NSString*)appKey;

+ (instancetype)prodWithConsumerKey:(NSString*)ck consumerSecret:(NSString*)cs appKey:(NSString*)appKey;

+ (instancetype)customWithBaseURL:(NSString*)baseURL consumerKey:(NSString*)ck consumerSecret:(NSString*)cs appKey:(NSString*)appKey;

@end

NS_ASSUME_NONNULL_END
