//
//  TouchIDKeyProvider.h
// ginlo
//
//  Created by Florin Pop on 19/01/15.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface TouchIDKeyProvider: NSObject

+ (TouchIDKeyProvider *)sharedInstance;

- (NSString*)keyForTouchID;
- (void) setKeyForTouchID:(NSString*)key;
- (void) reset;
- (BOOL) hasKeyForTouchID;

@end


