//
//  HTTPClient.m
//  NuAuthKit
//
//  Created by Vagner Machado on 22/05/25.
//

#import "HTTPClient.h"

@interface HTTPClient ()
@property (nonatomic, strong) id<USPHTTPTransport> transport;
@end

@implementation HTTPClient

+ (instancetype)sharedClient {
  static HTTPClient *client;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    client = [[HTTPClient alloc] init];
  });
  return client;
}

- (instancetype)init {
  NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
  NSURLSession *session = [NSURLSession sessionWithConfiguration:config delegate:nil delegateQueue:[NSOperationQueue mainQueue]];
  return [self initWithSession:session];
}

- (instancetype)initWithSession:(NSURLSession *)session {
  return [self initWithTransport:[[USPURLSessionTransport alloc] initWithSession:session]];
}
- (instancetype)initWithTransport:(id<USPHTTPTransport>)transport {
  NSParameterAssert(transport);
  if ((self = [super init])) _transport = transport;
  return self;
}

- (id<USPCancellable>)postJSON:(NSDictionary *)body toURL:(NSURL *)url completion:(void (^)(NSData * _Nullable data, NSHTTPURLResponse * _Nullable response, NSError * _Nullable error))handler {
  return [self postJSON:body toURL:url headers:nil completion:handler];
}

- (id<USPCancellable>)postJSON:(NSDictionary *)body
           toURL:(NSURL *)url
         headers:(NSDictionary<NSString *,NSString *> *)headers
      completion:(void (^)(NSData * _Nullable, NSHTTPURLResponse * _Nullable, NSError * _Nullable))handler {
  NSError *jsonErr;
  NSData *jsonData = [NSJSONSerialization dataWithJSONObject:body options:0 error:&jsonErr];
  if (!jsonData) {
    if (handler) handler(nil, nil, jsonErr);
    return nil;
  }

  NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
  req.HTTPMethod = @"POST";
  [req setValue:@"application/json; charset=UTF-8" forHTTPHeaderField:@"Content-Type"];
  for (NSString *headerName in headers) {
    NSString *headerValue = headers[headerName];
    if (headerValue.length > 0) {
      [req setValue:headerValue forHTTPHeaderField:headerName];
    }
  }

  req.HTTPBody = jsonData;

  return [self.transport executeRequest:req completion:handler];
}

@end
