#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Encapsula persistência da sessão OAuth e dados do usuário.
@interface USPAuthSessionStore : NSObject

- (instancetype)initWithDefaults:(NSUserDefaults *)defaults NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@property (nonatomic, copy, nullable) NSString *oauthToken;
@property (nonatomic, copy, nullable) NSString *oauthTokenSecret;
@property (nonatomic, copy, nullable) NSString *notificationToken;
@property (nonatomic, copy) NSString *notificationPlatform;
@property (nonatomic, assign) BOOL isRegistered;

/// Dicionário JSON do usuário cacheado (ou nil).
@property (nonatomic, copy, nullable) NSDictionary<NSString *, id> *userData;

/// Indica se há sessão válida em cache.
- (BOOL)hasValidSession;

/// Limpa tokens + userData + status de registro.
- (void)clearSession;

/// Limpa todos os dados persistidos do kit.
- (void)clearAll;

@end

NS_ASSUME_NONNULL_END
