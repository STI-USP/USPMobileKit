//
//  USPAuthVinculo.m
//  USPAuthKit
//
//  Created by Vagner Machado on 23/05/25.
//

#import "USPAuthVinculo.h"

// JSON `null` deserializes to NSNull, not nil, so a plain `?:` does not
// catch it. Treat anything that isn't an NSString as absent to avoid
// storing NSNull in a property the header declares as nonnull NSString.
static NSString *USPAuthStringOrEmpty(id value) {
    return [value isKindOfClass:[NSString class]] ? value : @"";
}

@implementation USPAuthVinculo

- (instancetype)initWithDictionary:(NSDictionary<NSString*, id>*)dict {
    self = [super init];
    if (!self) return nil;

    _codigoSetor    = [dict[@"codigoSetor"]    integerValue];
    _codigoUnidade  = [dict[@"codigoUnidade"]  integerValue];
    _nomeUnidade    = [USPAuthStringOrEmpty(dict[@"nomeUnidade"])   copy];
    _nomeVinculo    = [USPAuthStringOrEmpty(dict[@"nomeVinculo"])   copy];
    _siglaUnidade   = [USPAuthStringOrEmpty(dict[@"siglaUnidade"])  copy];
    _tipoVinculo    = [USPAuthStringOrEmpty(dict[@"tipoVinculo"])   copy];

    return self;
}

- (NSString *)description {
    return [NSString stringWithFormat:
      @"<Vínculo: %@ (%@) — setor %ld/%ld>",
      self.nomeVinculo,
      self.siglaUnidade,
      (long)self.codigoUnidade,
      (long)self.codigoSetor
    ];
}

@end
