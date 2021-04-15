//
//  TouchIDKeyProvider.m
//  SIMSme
//
//  Created by Florin Pop on 19/01/15.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

#import "TouchIDKeyProvider.h"

#import "KeychainWrapper.h"
#import "DPAGConstants.h"

@interface TouchIDKeyProvider()

@property (nonatomic, strong) KeychainWrapper* kcWrapper;

@end

@implementation TouchIDKeyProvider

- (void) reset
{
    if( self.kcWrapper != nil )
    {
        [self.kcWrapper resetKeychainItem];
        self.kcWrapper = nil;
    }
}

- (BOOL) hasKeyForTouchID
{
    return self.kcWrapper.password.length > 0;
}

- (NSString*)keyForTouchID
{
    return self.kcWrapper.password;
}

- (void) setKeyForTouchID:(NSString*)key
{
    if (key == nil)
    {
        [self reset];
        return;
    }
    [self.kcWrapper setPassword:key];
}

#pragma mark - properties

- (KeychainWrapper *)kcWrapper
{
    if( _kcWrapper == nil )
    {
        self.kcWrapper = [[KeychainWrapper alloc] initWithIdentifier:KEY_ACCESS_PRIVATE_KEY_TOUCH_ID accessGroup:KEY_ACCESS_DOQ_LOC_ACCESS_GROUP isThisDeviceOnly:YES];
    }
    
    return _kcWrapper;
}

+ (TouchIDKeyProvider*)sharedInstance
{
    // Keine wirkliche Shared Instanz mehr, um das LoginProblem zu fixen
    TouchIDKeyProvider *sharedInstance = [[self alloc] init];

    return sharedInstance;
}

@end


