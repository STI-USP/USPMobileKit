#import "USPIdentity.h"
#import "USPAuthVinculo.h"
@implementation USPIdentity
- (instancetype)initWithMetadata:(NSDictionary *)metadata {
  if ((self = [super init])) {
    _metadata = [metadata copy];
    _user = [[USPAuthUser alloc] initWithDictionary:metadata];
  }
  return self;
}
- (instancetype)initWithUser:(USPAuthUser *)user {
  NSParameterAssert(user);
  if ((self = [super init])) {
    _user = user;
    // This serialization is solely the existing defaults/userData compatibility format.
    NSMutableArray *links = [NSMutableArray new];
    for (USPAuthVinculo *link in user.vinculos) {
      [links addObject:@{@"codigoSetor":@(link.codigoSetor), @"codigoUnidade":@(link.codigoUnidade),
        @"nomeUnidade":link.nomeUnidade, @"nomeVinculo":link.nomeVinculo,
        @"siglaUnidade":link.siglaUnidade, @"tipoVinculo":link.tipoVinculo}];
    }
    _metadata = @{@"loginUsuario":user.loginUsuario, @"nomeUsuario":user.nomeUsuario,
      @"emailPrincipalUsuario":user.emailPrincipalUsuario, @"emailAlternativoUsuario":user.emailAlternativoUsuario,
      @"emailUspUsuario":user.emailUspUsuario, @"numeroTelefoneFormatado":user.numeroTelefoneFormatado,
      @"tipoUsuario":user.tipoUsuario, @"wsuserid":user.wsuserid, @"vinculo":links};
  }
  return self;
}
@end
