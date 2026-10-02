#import "USPMobileBackendClient.h"
#import "HTTPClient.h"
static NSString * const kDefaultBackendHeaderValue = @"820ecd52-849f-4815-8eb3-bbf9f4440ac5";
NSString *USPDefaultMobileHeaderValue(void) { return kDefaultBackendHeaderValue; }
@interface USPMobileBackendClient ()
@property (nonatomic, strong) HTTPClient *httpClient;
@end
@implementation USPMobileBackendClient
- (instancetype)initWithTransport:(id<USPHTTPTransport>)transport {
  if ((self = [super init])) { _httpClient = [[HTTPClient alloc] initWithTransport:transport]; _baseURL = @""; _appKey = @""; _headerValue = USPDefaultMobileHeaderValue(); }
  return self;
}
- (NSError *)missingUserIdentifier { return USPAuthError(1006, @"ID do usuário (wsuserid) não encontrado."); }
- (id<USPCancellable>)registerUserIdentifier:(NSString *)userIdentifier notificationToken:(NSString *)token platform:(NSString *)platform completion:(void (^)(NSError *))completion {
  if (!userIdentifier.length) { completion([self missingUserIdentifier]); return nil; }
  NSDictionary *body = @{@"token":userIdentifier, @"tokenNotificacao":token ?: @"", @"app":self.appKey ?: @"", @"ambiente":@"I", @"plataformaNotificacao":platform.length ? platform : @"F"};
  return [self postBody:body toAPIPath:@"/mobile/servicos/oauth/registrar" completion:^(NSData *data, NSHTTPURLResponse *response, NSError *error) {  completion(error); }];
}
- (id<USPCancellable>)invalidateUserIdentifier:(NSString *)userIdentifier completion:(void (^)(NSError *))completion {
  if (!userIdentifier.length) { completion([self missingUserIdentifier]); return nil; }
  return [self postBody:@{@"token":userIdentifier, @"app":self.appKey ?: @""} toAPIPath:@"/mobile/servicos/oauth/invalidar" completion:^(NSData *data, NSHTTPURLResponse *response, NSError *error) { completion(error); }];
}
- (id<USPCancellable>)checkUserIdentifier:(NSString *)userIdentifier completion:(void (^)(NSDictionary *, NSError *))completion {
  if (!userIdentifier.length) { completion(nil, [self missingUserIdentifier]); return nil; }
  return [self postBody:@{@"token":userIdentifier, @"app":self.appKey ?: @""} toAPIPath:@"/mobile/servicos/oauth/consultar" completion:^(NSData *data, NSHTTPURLResponse *response, NSError *error) {
    if (error) { completion(nil, error); return; }
    if (!data.length) { completion(@{}, nil); return; }
    NSError *jsonError = nil;
    id payload = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
    if (jsonError || ![payload isKindOfClass:NSDictionary.class]) { completion(nil, USPAuthError(1005, @"Resposta inválida ao consultar token.")); return; }
    completion(payload, nil);
  }];
}
- (id<USPCancellable>)postBody:(NSDictionary *)body
       toAPIPath:(NSString *)path
      completion:(void (^)(NSData * _Nullable data,
                           NSHTTPURLResponse * _Nullable response,
                           NSError * _Nullable error))completion {
  NSURL *url = [self URLWithAPIPath:path];
  if (!url) {
    NSError *error = [NSError errorWithDomain:@"USPAuthService"
                                         code:1007
                                     userInfo:@{NSLocalizedDescriptionKey: @"Base URL inválida na configuração."}];
    USPAuthOnMain(^{ completion(nil, nil, error); });
    return nil;
  }

  NSDictionary *headers = self.headerValue.length > 0
  ? @{ @"DEV-USP-MOBILE": self.headerValue }
  : @{};
  return [self.httpClient postJSON:body toURL:url headers:headers completion:^(NSData * _Nullable data, NSHTTPURLResponse * _Nullable response, NSError * _Nullable error) {
    USPAuthOnMain(^{
      if (error) {
        completion(data, response, error);
        return;
      }

      NSInteger statusCode = response.statusCode;
      if (statusCode < 200 || statusCode >= 300) {
        NSError *statusError = [NSError errorWithDomain:@"USPAuthService"
                                                   code:statusCode
                                               userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Falha na chamada %@ (status %ld).", path, (long)statusCode]}];
        completion(data, response, statusError);
        return;
      }

      completion(data, response, nil);
    });
  }];
}

- (NSURL *)URLWithAPIPath:(NSString *)path {
  if (self.baseURL.length == 0 || path.length == 0) {
    return nil;
  }

  NSString *fullPath = [self.baseURL stringByAppendingString:path];
  return [NSURL URLWithString:fullPath];
}

@end
