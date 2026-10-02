//
//  MyMutableURLRequest.m
//  e-Card USP
//
//  Created by Vagner Machado on 10/08/22.
//  Copyright © 2022 USP. All rights reserved.
//

#if __has_include(<UIKit/UIKit.h>)

#import "USPAuthKitMutableURLRequest.h"

@implementation USPAuthKitMutableURLRequest

+ (NSMutableURLRequest *)requestWithURL:(NSURL *)URL {
  USPAuthKitMutableURLRequest *urlRequest = (USPAuthKitMutableURLRequest *)[NSMutableURLRequest requestWithURL:URL];
  [urlRequest setValue:@"820ecd52-849f-4815-8eb3-bbf9f4440ac5" forHTTPHeaderField:@"DEV-USP-MOBILE"];
  [urlRequest setValue:@"PostmanRuntime/7.43.0" forHTTPHeaderField:@"User-Agent"];
  
  return urlRequest;
}

@end

#endif
