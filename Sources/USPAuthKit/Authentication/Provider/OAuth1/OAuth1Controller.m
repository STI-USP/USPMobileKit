// OAuth1Controller.m
// USPAuthKit
//
// Adapted by Vagner Machado on 22/05/25.
//

@import WebKit;

#import "OAuth1Controller.h"
#import "NSString+URLEncoding.h"
#import "USPAuthConfig.h"
#include "hmac.h"
#include "Base64Transcoder.h"

// -----------------------------------------------------------------------------
// Endpoints relativos (concatenados com baseURL da config)
// -----------------------------------------------------------------------------
#define OAUTH_CALLBACK       @"localhost"
#define REQUEST_TOKEN_URL    @"/wsusuario/oauth/request_token"
#define AUTHENTICATE_URL     @"/wsusuario/oauth/authorize"
#define ACCESS_TOKEN_URL     @"/wsusuario/oauth/access_token"

#define REQUEST_TOKEN_METHOD @"POST"
#define ACCESS_TOKEN_METHOD  @"POST"

// -----------------------------------------------------------------------------
// Query helpers (percent-escape, parse, join)
// -----------------------------------------------------------------------------

static NSString * CHPercentEscapedQueryStringPairMemberFromStringWithEncoding(NSString *string, NSStringEncoding encoding) {
  (void)encoding;
  if (string.length == 0) return @"";
  static NSCharacterSet *allowedCharacterSet;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    NSMutableCharacterSet *mutableSet = [[NSCharacterSet URLQueryAllowedCharacterSet] mutableCopy];
    [mutableSet removeCharactersInString:@":/?&=;+!@#$()~"];
    allowedCharacterSet = [mutableSet copy];
  });
  return [string stringByAddingPercentEncodingWithAllowedCharacters:allowedCharacterSet] ?: @"";
}

@interface CHQueryStringPair : NSObject
@property (nonatomic,strong) id field;
@property (nonatomic,strong) id value;
- (instancetype)initWithField:(id)field value:(id)value;
- (NSString *)URLEncodedStringValueWithEncoding:(NSStringEncoding)stringEncoding;
@end

@implementation CHQueryStringPair
- (instancetype)initWithField:(id)field value:(id)value {
  if (!(self = [super init])) return nil;
  _field = field; _value = value;
  return self;
}
- (NSString *)URLEncodedStringValueWithEncoding:(NSStringEncoding)encoding {
  if (!_value || [_value isEqual:[NSNull null]]) {
    return CHPercentEscapedQueryStringPairMemberFromStringWithEncoding([_field description], encoding);
  } else {
    return [NSString stringWithFormat:@"%@=%@",
            CHPercentEscapedQueryStringPairMemberFromStringWithEncoding([_field description], encoding),
            CHPercentEscapedQueryStringPairMemberFromStringWithEncoding([_value description], encoding)
    ];
  }
}
@end

static NSArray<CHQueryStringPair*> * CHQueryStringPairsFromKeyAndValue(NSString *key, id value);

static NSArray<CHQueryStringPair*> * CHQueryStringPairsFromDictionary(NSDictionary *dict) {
  return CHQueryStringPairsFromKeyAndValue(nil, dict);
}

static NSArray<CHQueryStringPair*> * CHQueryStringPairsFromKeyAndValue(NSString *key, id value) {
  NSMutableArray *components = [NSMutableArray array];
  if ([value isKindOfClass:[NSDictionary class]]) {
    for (NSString *nestedKey in [[value allKeys] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)]) {
      [components addObjectsFromArray:
         CHQueryStringPairsFromKeyAndValue(
                                           key ? [NSString stringWithFormat:@"%@[%@]", key, nestedKey] : nestedKey,
                                           value[nestedKey]
                                           )
      ];
    }
  } else if ([value isKindOfClass:[NSArray class]]) {
    for (id v in value) {
      [components addObjectsFromArray:
         CHQueryStringPairsFromKeyAndValue([NSString stringWithFormat:@"%@[]", key], v)
      ];
    }
  } else {
    [components addObject:[[CHQueryStringPair alloc] initWithField:key value:value]];
  }
  return components;
}

static NSString * CHQueryStringFromParametersWithEncoding(NSDictionary *parameters, NSStringEncoding encoding) {
  NSMutableArray *pairs = [NSMutableArray array];
  for (CHQueryStringPair *p in CHQueryStringPairsFromDictionary(parameters)) {
    [pairs addObject:[p URLEncodedStringValueWithEncoding:encoding]];
  }
  return [pairs componentsJoinedByString:@"&"];
}

// -----------------------------------------------------------------------------
// Interface privada
// -----------------------------------------------------------------------------

@interface OAuth1Controller ()
@property (nonatomic, strong) USPAuthConfig *config;
@property (nonatomic, strong) id<USPHTTPTransport> transport;
@property (nonatomic, copy) NSDate *(^clock)(void);
@property (nonatomic, copy) NSString *(^nonce)(void);
@property (nonatomic, strong) NSMutableArray<id<USPCancellable>> *tasks;
@property (nonatomic, strong) id<USPAuthBrowser> browser;
@property (nonatomic, copy) void (^completion)(NSDictionary *, NSError *);
@property (nonatomic) NSUInteger generation;
@end

@implementation OAuth1Controller
- (instancetype)initWithConfig:(USPAuthConfig *)config {
  return [self initWithConfig:config transport:[[USPURLSessionTransport alloc] initWithSession:NSURLSession.sharedSession] clock:^{ return NSDate.date; } nonce:^{ return [NSString getNonce]; }];
}
- (instancetype)initWithConfig:(USPAuthConfig *)config transport:(id<USPHTTPTransport>)transport clock:(NSDate *(^)(void))clock nonce:(NSString *(^)(void))nonce {
  NSParameterAssert(config); NSParameterAssert(transport);
  if ((self = [super init])) { _config = config; _transport = transport; _clock = [clock copy]; _nonce = [nonce copy]; _tasks = [NSMutableArray new]; }
  return self;
}
- (NSMutableDictionary *)standardParameters {
  return [self.class standardParametersWithConsumerKey:self.config.consumerKey date:self.clock() nonce:self.nonce()];
}
#if __has_include(<UIKit/UIKit.h>)
- (void)loginWithWebView:(WKWebView *)webView completion:(void (^)(NSDictionary<NSString *,NSString *> *, NSError *))completion {
  id<USPAuthBrowser> browser = [[USPWKAuthBrowser alloc] initWithWebView:webView];
  [browser begin:^{ [self loginWithBrowser:browser completion:completion]; } cancellation:^(NSError *error) { [self cancel]; }];
}
#endif
- (void)loginWithBrowser:(id<USPAuthBrowser>)browser completion:(void (^)(NSDictionary *, NSError *))completion {
  [self cancel];
  self.browser = browser;
  self.completion = completion;
  NSUInteger generation = ++self.generation;
  __block BOOL requestHandled = NO;
  __block BOOL authorizationHandled = NO;
  [self obtainRequestTokenWithCompletion:^(NSError *error, NSDictionary *params) {
    if (generation != self.generation || !self.completion || requestHandled) { return; }
    requestHandled = YES;
    NSString *token = params[@"oauth_token"], *secret = params[@"oauth_token_secret"];
    if (error) { [self complete:nil error:error]; return; }
    if (!token.length || !secret.length) { [self complete:nil error:[NSError errorWithDomain:@"oauth" code:100 userInfo:@{NSLocalizedDescriptionKey:@"Parâmetros do request token inválidos."}]]; return; }
    NSString *urlString = [NSString stringWithFormat:@"%@%@?oauth_token=%@&oauth_callback=%@", self.config.baseURL, AUTHENTICATE_URL, token, OAUTH_CALLBACK.utf8AndURLEncode];
    [browser openURL:[NSURL URLWithString:urlString] matching:^BOOL(NSURL *url) {
      return [url.absoluteString rangeOfString:@"oauth_verifier="].location != NSNotFound;
    } completion:^(NSURL *url, NSError *browserError) {
      if (generation != self.generation || !self.completion || authorizationHandled) { return; }
      authorizationHandled = YES;

      NSDictionary *callback = url ? [self.class validatedCallbackURL:url requestToken:token] : nil;
      if (browserError || !callback) {
        [self complete:nil error:browserError ?: [NSError errorWithDomain:@"oauth" code:101 userInfo:@{NSLocalizedDescriptionKey:@"Retorno de autorização inválido."}]];
        return;
      }

      [self requestAccessToken:secret oauthToken:token oauthVerifier:callback[@"oauth_verifier"] completion:^(NSError *error, NSDictionary *accessParams) {
        if (generation == self.generation && self.completion) [self complete:error ? nil : accessParams error:error];
      }];
    }];
  }];
}
- (void)complete:(NSDictionary *)params error:(NSError *)error {
  void (^completion)(NSDictionary *, NSError *) = self.completion;
  self.completion = nil;
  self.browser = nil;
  [self.tasks removeAllObjects];
  if (completion) completion(params, error);
}
- (void)cancel {
  ++self.generation;
  for (id<USPCancellable> task in self.tasks) [task cancel];
  [self.tasks removeAllObjects];
  [self complete:nil error:[NSError errorWithDomain:@"LoginWebViewController" code:NSUserCancelledError userInfo:@{NSLocalizedDescriptionKey:@"Login cancelado pelo usuário."}]];
}

// — Step 1
- (void)obtainRequestTokenWithCompletion:(void (^)(NSError * _Nullable, NSDictionary * _Nullable))completion {
  NSString *urlStr = [self.config.baseURL stringByAppendingString:REQUEST_TOKEN_URL];

  NSMutableDictionary *params = [self standardParameters];
  NSString *baseStr = [self.class baseStringWithMethod:REQUEST_TOKEN_METHOD
                                                   url:urlStr
                                            parameters:params];
  NSString *sig = [self.class signClearText:baseStr
                                 withSecret:[NSString stringWithFormat:@"%@&", self.config.consumerSecret.utf8AndURLEncode]];
  params[@"oauth_signature"] = sig;

  NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlStr]];
  req.HTTPMethod = REQUEST_TOKEN_METHOD;
  [req setValue:[self.class authorizationHeaderFromParams:params] forHTTPHeaderField:@"Authorization"];


  id<USPCancellable> task = [self.transport executeRequest:req completion:^(NSData *data, NSHTTPURLResponse *r, NSError *err) {
    if (err) { dispatch_async(dispatch_get_main_queue(), ^{ completion(err, nil); }); return; }
    NSString *resp = data ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : @"";
    NSDictionary *parsed = [self.class parametersFromQueryString:resp ?: @""];

    dispatch_async(dispatch_get_main_queue(), ^{ completion(nil, parsed); });
  }];
  [self.tasks addObject:task];
}

// — Step 3
- (void)requestAccessToken:(NSString*)tokenSecret
                oauthToken:(NSString*)oauthToken
             oauthVerifier:(NSString*)oauthVerifier
                completion:(void (^)(NSError * _Nullable, NSDictionary * _Nullable))completion
{
  NSString *urlStr = [self.config.baseURL stringByAppendingString:ACCESS_TOKEN_URL];

  NSMutableDictionary *params = [self standardParameters];
  params[@"oauth_token"]    = oauthToken ?: @"";
  params[@"oauth_verifier"] = oauthVerifier ?: @"";

  NSString *baseStr = [self.class baseStringWithMethod:ACCESS_TOKEN_METHOD url:urlStr parameters:params];
  NSString *secret  = [NSString stringWithFormat:@"%@&%@",
                       self.config.consumerSecret.utf8AndURLEncode,
                       (tokenSecret ?: @"").utf8AndURLEncode];
  params[@"oauth_signature"] = [self.class signClearText:baseStr withSecret:secret];

  NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlStr]];
  req.HTTPMethod = ACCESS_TOKEN_METHOD;
  [req setValue:[self.class authorizationHeaderFromParams:params] forHTTPHeaderField:@"Authorization"];


  id<USPCancellable> task = [self.transport executeRequest:req completion:^(NSData *data, NSHTTPURLResponse *r, NSError *err) {
    if (err) { dispatch_async(dispatch_get_main_queue(), ^{ completion(err, nil); }); return; }
    NSString *resp = data ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : @"";
    NSDictionary *parsed = [self.class parametersFromQueryString:resp ?: @""];

    dispatch_async(dispatch_get_main_queue(), ^{ completion(nil, parsed); });
  }];
  [self.tasks addObject:task];
}

+ (NSURLRequest *)preparedRequestForPath:(NSString *)path
                              parameters:(NSDictionary *)queryParameters
                              HTTPmethod:(NSString *)HTTPmethod
                              oauthToken:(NSString *)oauth_token
                             oauthSecret:(NSString *)oauth_token_secret
                                  config:(USPAuthConfig *)config
{
  return [self preparedRequestForPath:path parameters:queryParameters HTTPmethod:HTTPmethod oauthToken:oauth_token oauthSecret:oauth_token_secret config:config standardParameters:[self standardOauthParametersWithConsumerKey:config.consumerKey]];
}
- (NSURLRequest *)identityRequestWithToken:(NSString *)token secret:(NSString *)secret {
  return [self.class preparedRequestForPath:@"/wsusuario/oauth/usuariousp" parameters:nil HTTPmethod:@"POST" oauthToken:token oauthSecret:secret config:self.config standardParameters:[self standardParameters]];
}
+ (NSURLRequest *)preparedRequestForPath:(NSString *)path parameters:(NSDictionary *)queryParameters HTTPmethod:(NSString *)HTTPmethod oauthToken:(NSString *)oauth_token oauthSecret:(NSString *)oauth_token_secret config:(USPAuthConfig *)config standardParameters:(NSMutableDictionary *)allParams {
  if (!HTTPmethod.length || !oauth_token.length || !config) return nil;

  allParams[@"oauth_token"] = oauth_token;
  if (queryParameters) [allParams addEntriesFromDictionary:queryParameters];

  NSString *urlString   = [config.baseURL stringByAppendingString:path ?: @""];
  NSString *paramString = CHQueryStringFromParametersWithEncoding(allParams, NSUTF8StringEncoding);
  NSString *baseString  = [NSString stringWithFormat:@"%@&%@&%@",
                           HTTPmethod,
                           [urlString utf8AndURLEncode],
                           [paramString utf8AndURLEncode]];

  NSString *secretString = [NSString stringWithFormat:@"%@&%@",
                            config.consumerSecret.utf8AndURLEncode,
                            (oauth_token_secret ?: @"").utf8AndURLEncode];
  NSString *signature = [self signClearText:baseString withSecret:secretString];
  allParams[@"oauth_signature"] = signature;

  NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
  request.HTTPMethod = HTTPmethod;

  // Header Authorization
  NSMutableArray *pairs = [NSMutableArray array];
  for (NSString *k in allParams) {
    NSString *v = [allParams[k] description] ?: @"";
    [pairs addObject:[NSString stringWithFormat:@"%@=\"%@\"", [k utf8AndURLEncode], [v utf8AndURLEncode]]];
  }
  NSString *authHeader = [@"OAuth " stringByAppendingString:[pairs componentsJoinedByString:@", "]];
  [request setValue:authHeader forHTTPHeaderField:@"Authorization"];

  // Body se POST e houver params (não OAuth)
  if ([HTTPmethod isEqualToString:@"POST"] && queryParameters.count > 0) {
    NSString *bodyString = CHQueryStringFromParametersWithEncoding(queryParameters, NSUTF8StringEncoding);
    request.HTTPBody = [bodyString dataUsingEncoding:NSUTF8StringEncoding];
  }

  return request;
}

// -----------------------------------------------------------------------------
// Helpers OAuth
// -----------------------------------------------------------------------------

+ (NSDictionary<NSString *, NSString *> *)parametersFromQueryString:(NSString *)queryString {
  if (queryString.length == 0) return @{};

  NSString *normalizedQuery = [queryString hasPrefix:@"?"] ? [queryString substringFromIndex:1] : queryString;
  NSURLComponents *components = [NSURLComponents componentsWithString:[NSString stringWithFormat:@"https://localhost/?%@", normalizedQuery]];
  if (!components) return @{};

  NSMutableDictionary<NSString *, NSString *> *params = [NSMutableDictionary dictionary];
  for (NSURLQueryItem *item in components.queryItems) {
    if (item.name.length == 0 || item.value == nil) {
      continue;
    }
    params[item.name] = item.value;
  }
  return params;
}

+ (NSMutableDictionary*)standardOauthParametersWithConsumerKey:(NSString*)consumerKey {
  return [self standardParametersWithConsumerKey:consumerKey date:NSDate.date nonce:[NSString getNonce]];
}
+ (NSMutableDictionary *)standardParametersWithConsumerKey:(NSString *)key date:(NSDate *)date nonce:(NSString *)nonce {
  return [@{ @"oauth_consumer_key":key ?: @"", @"oauth_nonce":nonce ?: @"", @"oauth_signature_method":@"HMAC-SHA1", @"oauth_timestamp":[NSString stringWithFormat:@"%lu", (unsigned long)date.timeIntervalSince1970], @"oauth_version":@"1.0" } mutableCopy];
}
+ (NSString *)callbackRejectionReason:(NSURL *)url requestToken:(NSString *)token {
  NSURLComponents *parts = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
  BOOL localHTTP = ([parts.scheme.lowercaseString isEqual:@"http"] || [parts.scheme.lowercaseString isEqual:@"https"]) && [parts.host.lowercaseString isEqual:@"localhost"] && (!parts.port || (parts.port.integerValue >= 1 && parts.port.integerValue <= 65535)) && !parts.user && !parts.password && (!parts.path.length || [parts.path isEqual:@"/"] || [parts.path isEqual:@"/login.aspx"]);
  BOOL literalLocal = !parts.scheme && !parts.host && [parts.path isEqual:@"localhost"];
  if (!localHTTP && !literalLocal) return @"destination";
  if (parts.fragment.length && ![parts.fragment isEqual:@"_=_"]) return @"fragment";
  NSMutableSet *seen = [NSMutableSet new];
  for (NSURLQueryItem *item in parts.queryItems) {
    if ([seen containsObject:item.name]) return @"duplicate_query";
    [seen addObject:item.name];
  }
  NSDictionary *params = [self parametersFromQueryString:parts.percentEncodedQuery];
  if (![params[@"oauth_token"] length]) return @"missing_token";
  if (![params[@"oauth_token"] isEqual:token]) return @"token_mismatch";
  if (![params[@"oauth_verifier"] length]) return @"missing_verifier";
  return nil;
}

+ (NSDictionary *)validatedCallbackURL:(NSURL *)url requestToken:(NSString *)token {
  if ([self callbackRejectionReason:url requestToken:token]) return nil;
  NSURLComponents *parts = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
  return [self parametersFromQueryString:parts.percentEncodedQuery];
}

+ (NSString*)baseStringWithMethod:(NSString*)method
                              url:(NSString*)url
                       parameters:(NSDictionary*)params
{
  NSArray *ks = [[params allKeys] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
  NSMutableArray *parts = [NSMutableArray arrayWithCapacity:ks.count];
  for (NSString *k in ks) {
    [parts addObject:[NSString stringWithFormat:@"%@=%@",
                      CHPercentEscapedQueryStringPairMemberFromStringWithEncoding(k,NSUTF8StringEncoding),
                      CHPercentEscapedQueryStringPairMemberFromStringWithEncoding([params[k] description],NSUTF8StringEncoding)]];
  }
  NSString *paramString = [parts componentsJoinedByString:@"&"];
  return [@[method ?: @"POST", url.utf8AndURLEncode, paramString.utf8AndURLEncode] componentsJoinedByString:@"&"];
}

+ (NSString*)authorizationHeaderFromParams:(NSDictionary*)params {
  NSMutableArray *pairs = [NSMutableArray arrayWithCapacity:params.count];
  for (NSString *k in params) {
    NSString *v = [[params objectForKey:k] description] ?: @"";
    NSString *ek = CHPercentEscapedQueryStringPairMemberFromStringWithEncoding(k, NSUTF8StringEncoding);
    NSString *ev = CHPercentEscapedQueryStringPairMemberFromStringWithEncoding(v, NSUTF8StringEncoding);
    [pairs addObject:[NSString stringWithFormat:@"%@=\"%@\"", ek, ev]];
  }
  return [@"OAuth " stringByAppendingString:[pairs componentsJoinedByString:@", "]];
}

+ (NSString*)signClearText:(NSString*)text withSecret:(NSString*)secret {
  NSData *keyData = [secret dataUsingEncoding:NSUTF8StringEncoding];
  NSData *msgData = [text dataUsingEncoding:NSUTF8StringEncoding];
  unsigned char result[20];
  hmac_sha1(msgData.bytes, (unsigned int)msgData.length,
            keyData.bytes, (unsigned int)keyData.length, result);
  char base64Buff[32];
  size_t outLen = sizeof(base64Buff);
  Base64EncodeData(result, 20, base64Buff, &outLen);
  return [[NSString alloc] initWithBytes:base64Buff length:outLen encoding:NSUTF8StringEncoding];
}

@end
