//
//  USPAuthUser.m
//  USPAuthKit
//
//  Created by Vagner Machado on 23/05/25.
//

#import "USPAuthUser.h"
#import "USPAuthVinculo.h"

// JSON `null` deserializes to NSNull, not nil, so a plain `?:` does not
// catch it. Treat anything that isn't an NSString as absent to avoid
// storing NSNull in a property the header declares as nonnull NSString.
static NSString *USPAuthStringOrEmpty(id value) {
    return [value isKindOfClass:[NSString class]] ? value : @"";
}

@implementation USPAuthUser

- (instancetype)initWithDictionary:(NSDictionary<NSString*,id>*)dict {
  self = [super init];
  if (!self) return nil;

  // Para cada campo, tenta extrair do dict; se não houver, armazena string vazia
  _loginUsuario             = [USPAuthStringOrEmpty(dict[@"loginUsuario"])             copy];
  _nomeUsuario              = [USPAuthStringOrEmpty(dict[@"nomeUsuario"])              copy];
  _emailPrincipalUsuario    = [USPAuthStringOrEmpty(dict[@"emailPrincipalUsuario"])    copy];
  _emailAlternativoUsuario  = [USPAuthStringOrEmpty(dict[@"emailAlternativoUsuario"])  copy];
  _emailUspUsuario          = [USPAuthStringOrEmpty(dict[@"emailUspUsuario"])          copy];
  _numeroTelefoneFormatado  = [USPAuthStringOrEmpty(dict[@"numeroTelefoneFormatado"])  copy];
  _tipoUsuario              = [USPAuthStringOrEmpty(dict[@"tipoUsuario"])              copy];
  _wsuserid                 = [USPAuthStringOrEmpty(dict[@"wsuserid"])                 copy];
  
  // Parse dos vínculos
  id raw = dict[@"vinculo"];
  if ([raw isKindOfClass:[NSArray class]]) {
    NSMutableArray<USPAuthVinculo*> *arr = [NSMutableArray array];
    for (id item in raw) {
      if ([item isKindOfClass:[NSDictionary class]]) {
        USPAuthVinculo *v = [[USPAuthVinculo alloc] initWithDictionary:item];
        [arr addObject:v];
      }
    }
    _vinculos = [arr copy];
  } else {
    _vinculos = @[];
  }
  
  return self;
}

- (NSString *)description {
    NSMutableString *s = [NSMutableString stringWithFormat:
        @"<User: %@ (%@)>", self.nomeUsuario, self.wsuserid
    ];
    [s appendString:@"\nVínculos:"];
    for (USPAuthVinculo *v in self.vinculos) {
        [s appendFormat:@"\n  %@", v];
    }
    return s;
}

@end
