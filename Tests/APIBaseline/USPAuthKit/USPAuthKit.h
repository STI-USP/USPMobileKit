//
//  USPAuthKit.h
//  USPAuthKit
//
//  Created by Vagner Machado on 22/05/25.
//  Umbrella header for the USPAuthKit Swift package.
//  Exports all public headers for ObjC/Swift clients.
//

#import <Foundation/Foundation.h>
#if __has_include(<WebKit/WebKit.h>)
#import <WebKit/WebKit.h>
#endif
#if __has_include(<UIKit/UIKit.h>)
#import <UIKit/UIKit.h>
#endif

// Public interfaces
#import "USPAuthService.h"
#import "USPAuthUser.h"
#import "USPAuthVinculo.h"
#import "USPAuthConfig.h"

//! Project version number for USPAuthKit.
FOUNDATION_EXPORT double USPAuthKitVersionNumber;

//! Project version string for USPAuthKit.
FOUNDATION_EXPORT const unsigned char USPAuthKitVersionString[];
