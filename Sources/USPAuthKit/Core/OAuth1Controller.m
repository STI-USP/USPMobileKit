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

static inline NSDictionary * CHParametersFromQueryString(NSString *qs) {
  NSMutableDictionary *params = [NSMutableDictionary dictionary];
  NSScanner *scanner = [NSScanner scannerWithString:qs];
  NSString *name, *value;
  while (![scanner isAtEnd]) {
    name = nil; [scanner scanUpToString:@"=" intoString:&name];
    [scanner scanString:@"=" intoString:NULL];
    value = nil; [scanner scanUpToString:@"&" intoString:&value];
    [scanner scanString:@"&" intoString:NULL];
    if (name && value) {
      NSString *decodedName  = [name stringByRemovingPercentEncoding];
      NSString *decodedValue = [value stringByRemovingPercentEncoding];
      if (decodedName && decodedValue) params[decodedName] = decodedValue;
    }
  }
  return params;
}

// -----------------------------------------------------------------------------
// Interface privada
// -----------------------------------------------------------------------------

typedef void (^WebViewHandler)(NSDictionary *oauthParams);

@interface OAuth1Controller ()
@property (nonatomic, weak)   WKWebView *webView;
@property (nonatomic, copy)   WebViewHandler delegateHandler;
@property (nonatomic, strong, readonly) USPAuthConfig *config;
@end

// -----------------------------------------------------------------------------
// Implementação
// -----------------------------------------------------------------------------

@implementation OAuth1Controller

- (instancetype)initWithConfig:(USPAuthConfig *)config {
  NSParameterAssert(config);
  if (self = [super init]) {
    _config = config;
  }
  return self;
}

- (void)loginWithWebView:(WKWebView*)webView
              completion:(void (^)(NSDictionary<NSString*,NSString*>*,NSError*))completion
{
  NSParameterAssert(webView);
  NSParameterAssert(completion);
  
  self.webView = webView;
  webView.navigationDelegate = self;
  
  // Step 1: request token
  __weak typeof(self) wself = self;
  [self obtainRequestTokenWithCompletion:^(NSError *err, NSDictionary *respParams) {
    if (err) { completion(nil, err); return; }
    
    NSString *tok = respParams[@"oauth_token"];
    NSString *sec = respParams[@"oauth_token_secret"];
    if (tok.length == 0 || sec.length == 0) {
      NSError *e = [NSError errorWithDomain:@"oauth"
                                       code:100
                                   userInfo:@{NSLocalizedDescriptionKey:@"Parâmetros do request token inválidos."}];
      completion(nil, e);
      return;
    }
    
    // Step 2: authorize
    [wself authenticateToken:tok withCompletion:^(NSError *err2, NSDictionary *authParams) {
      if (err2) { completion(nil, err2); return; }
      
      NSString *verifier = authParams[@"oauth_verifier"];
      NSString *authTok  = authParams[@"oauth_token"];
      if (verifier.length == 0 || authTok.length == 0) {
        NSError *e = [NSError errorWithDomain:@"oauth"
                                         code:101
                                     userInfo:@{NSLocalizedDescriptionKey:@"Retorno de autorização inválido."}];
        completion(nil, e);
        return;
      }
      
      // Step 3: access token
      [wself requestAccessToken:sec
                     oauthToken:authTok
                  oauthVerifier:verifier
                     completion:^(NSError *err3, NSDictionary *accessParams) {
        completion(err3 ? nil : accessParams, err3);
      }];
    }];
  }];
}

// — Step 1
- (void)obtainRequestTokenWithCompletion:(void (^)(NSError * _Nullable, NSDictionary * _Nullable))completion {
  NSString *urlStr = [self.config.baseURL stringByAppendingString:REQUEST_TOKEN_URL];
  
  NSMutableDictionary *params = [self.class standardOauthParametersWithConsumerKey:self.config.consumerKey];
  NSString *baseStr = [self.class baseStringWithMethod:REQUEST_TOKEN_METHOD
                                                   url:urlStr
                                            parameters:params];
  NSString *sig = [self.class signClearText:baseStr
                                 withSecret:[NSString stringWithFormat:@"%@&", self.config.consumerSecret.utf8AndURLEncode]];
  params[@"oauth_signature"] = sig;
  
  NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlStr]];
  req.HTTPMethod = REQUEST_TOKEN_METHOD;
  [req setValue:[self.class authorizationHeaderFromParams:params] forHTTPHeaderField:@"Authorization"];
  
  [[[NSURLSession sharedSession]
    dataTaskWithRequest:req
    completionHandler:^(NSData *data, NSURLResponse *r, NSError *err) {
    if (err) { dispatch_async(dispatch_get_main_queue(), ^{ completion(err, nil); }); return; }
    NSString *resp = data ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : @"";
    NSDictionary *parsed = CHParametersFromQueryString(resp ?: @"");
    dispatch_async(dispatch_get_main_queue(), ^{ completion(nil, parsed); });
  }] resume];
}

// — Step 2
- (void)authenticateToken:(NSString*)oauthToken
           withCompletion:(void (^)(NSError * _Nullable, NSDictionary * _Nullable))completion
{
  NSString *cb  = OAUTH_CALLBACK.utf8AndURLEncode;
  NSString *url = [NSString stringWithFormat:@"%@%@?oauth_token=%@&oauth_callback=%@",
                   self.config.baseURL, AUTHENTICATE_URL, oauthToken, cb];
  
  self.delegateHandler = ^(NSDictionary *params) {
    if (!params[@"oauth_verifier"]) {
      NSError *e = [NSError errorWithDomain:@"oauth"
                                      code:0
                                   userInfo:@{NSLocalizedDescriptionKey:@"Verifier ausente."}];
      completion(e, params);
    } else {
      completion(nil, params);
    }
  };
  
  dispatch_async(dispatch_get_main_queue(), ^{
    [self.webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:url]]];
  });
}

// — Step 3
- (void)requestAccessToken:(NSString*)tokenSecret
                oauthToken:(NSString*)oauthToken
             oauthVerifier:(NSString*)oauthVerifier
                completion:(void (^)(NSError * _Nullable, NSDictionary * _Nullable))completion
{
  NSString *urlStr = [self.config.baseURL stringByAppendingString:ACCESS_TOKEN_URL];
  
  NSMutableDictionary *params = [self.class standardOauthParametersWithConsumerKey:self.config.consumerKey];
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
  
  [[[NSURLSession sharedSession]
    dataTaskWithRequest:req
    completionHandler:^(NSData *data, NSURLResponse *r, NSError *err) {
    if (err) { dispatch_async(dispatch_get_main_queue(), ^{ completion(err, nil); }); return; }
    NSString *resp = data ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : @"";
    NSDictionary *parsed = CHParametersFromQueryString(resp ?: @"");
    dispatch_async(dispatch_get_main_queue(), ^{ completion(nil, parsed); });
  }] resume];
}

+ (NSURLRequest *)preparedRequestForPath:(NSString *)path
                              parameters:(NSDictionary *)queryParameters
                              HTTPmethod:(NSString *)HTTPmethod
                              oauthToken:(NSString *)oauth_token
                             oauthSecret:(NSString *)oauth_token_secret
                                  config:(USPAuthConfig *)config
{
  if (!HTTPmethod.length || !oauth_token.length || !config) return nil;
  
  NSMutableDictionary *allParams = [self standardOauthParametersWithConsumerKey:config.consumerKey];
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
// WKNavigationDelegate
// -----------------------------------------------------------------------------

- (void)webView:(WKWebView*)webView
decidePolicyForNavigationAction:(WKNavigationAction*)navigationAction
decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler
{
  NSString *url = webView.URL.absoluteString ?: @"";
  NSRange range = [url rangeOfString:@"oauth_verifier="];
  if (range.location != NSNotFound) {
    NSString *query = [[url componentsSeparatedByString:@"?"] lastObject] ?: @"";
    NSDictionary *paramsIn = CHParametersFromQueryString(query);
    
    // Remove sufixo "#_=_"
    NSMutableDictionary *params = [paramsIn mutableCopy];
    NSString *verifier = params[@"oauth_verifier"];
    if ([verifier hasSuffix:@"#_=_"]) {
      params[@"oauth_verifier"] = [verifier stringByReplacingOccurrencesOfString:@"#_=_" withString:@""];
    }
    
    if (self.delegateHandler) {
      self.delegateHandler(params);
      self.delegateHandler = nil;
    }
    decisionHandler(WKNavigationActionPolicyCancel);
    return;
  }
  
  decisionHandler(WKNavigationActionPolicyAllow);
}

- (void)webView:(WKWebView*)webView didFinishNavigation:(WKNavigation*)nav {
  (void)webView;
  (void)nav;
}

// -----------------------------------------------------------------------------
// Helpers OAuth
// -----------------------------------------------------------------------------

+ (NSMutableDictionary*)standardOauthParametersWithConsumerKey:(NSString*)consumerKey {
  return [@{
    @"oauth_consumer_key":     consumerKey ?: @"",
    @"oauth_nonce":            [NSString getNonce],
    @"oauth_signature_method": @"HMAC-SHA1",
    @"oauth_timestamp":        [NSString stringWithFormat:@"%lu",(unsigned long)[[NSDate date] timeIntervalSince1970]],
    @"oauth_version":          @"1.0"
  } mutableCopy];
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
  hmac_sha1((unsigned char*)msgData.bytes, (unsigned int)msgData.length,
            (unsigned char*)keyData.bytes, (unsigned int)keyData.length, result);
  char base64Buff[32];
  size_t outLen = sizeof(base64Buff);
  Base64EncodeData(result, 20, base64Buff, &outLen);
  return [[NSString alloc] initWithBytes:base64Buff length:outLen encoding:NSUTF8StringEncoding];
}

@end
