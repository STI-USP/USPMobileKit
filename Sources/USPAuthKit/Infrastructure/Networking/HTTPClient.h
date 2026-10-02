//
//  HTTPClient.h
//  NuAuthKit
//
//  Created by Vagner Machado on 22/05/25.
//

#import <Foundation/Foundation.h>
#import "USPHTTPTransport.h"

NS_ASSUME_NONNULL_BEGIN

@interface HTTPClient : NSObject

/// Singleton
+ (instancetype)sharedClient;

- (instancetype)initWithSession:(NSURLSession *)session;
- (instancetype)init;

- (instancetype)initWithTransport:(id<USPHTTPTransport>)transport NS_DESIGNATED_INITIALIZER;

/// Envia um dicionário como JSON via POST
- (id<USPCancellable> _Nullable)postJSON:(NSDictionary *)body
            toURL:(NSURL *)url
       completion:(void (^)(NSData * _Nullable data,
                            NSHTTPURLResponse * _Nullable response,
                            NSError * _Nullable error))handler;

/// Envia um dicionário como JSON via POST com cabeçalhos adicionais.
- (id<USPCancellable> _Nullable)postJSON:(NSDictionary *)body
           toURL:(NSURL *)url
         headers:(nullable NSDictionary<NSString *, NSString *> *)headers
      completion:(void (^)(NSData * _Nullable data,
                           NSHTTPURLResponse * _Nullable response,
                           NSError * _Nullable error))handler;

@end

NS_ASSUME_NONNULL_END
