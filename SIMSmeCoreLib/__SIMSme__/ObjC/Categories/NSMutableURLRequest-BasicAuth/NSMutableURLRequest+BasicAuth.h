//
//  NSMutableURLRequest+BasicAuth.h
//  ID.me Scan
//
//  Created by Arthur Sabintsev on 9/9/13.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSMutableURLRequest (BasicAuth)

+ (void)basicAuthForRequest:(NSMutableURLRequest *)request withUsername:(NSString *)username andPassword:(NSString *)password;

@end
