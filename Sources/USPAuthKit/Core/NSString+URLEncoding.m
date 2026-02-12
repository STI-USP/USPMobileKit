//
//  NSString+URLEncoding.m
//  NuAuthKit
//
//  Created by Vagner Machado on 22/05/25.
//

#import "NSString+URLEncoding.h"

@implementation NSString (URLEncoding)

- (NSString *)utf8AndURLEncode {
    NSMutableCharacterSet *allowed = [[NSCharacterSet URLQueryAllowedCharacterSet] mutableCopy];
    [allowed removeCharactersInString:@"!*'\"();:@&=+$,/?%#[]% "];
    return [self stringByAddingPercentEncodingWithAllowedCharacters:allowed] ?: @"";
}

+ (NSString *)getNonce {
    NSString *uuid = [[NSUUID UUID].UUIDString lowercaseString];
    return [[uuid substringToIndex:10] stringByReplacingOccurrencesOfString:@"-" withString:@""];
}

@end
