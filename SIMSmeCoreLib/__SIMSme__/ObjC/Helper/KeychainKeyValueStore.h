//
//  KeychainKeyValueStore.h
// ginlo
//
//  Created by Florin Pop on 06/11/14.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 This class can be used to store properties as passwords in the keychain.
 It should only be used to store properties when the encrypted account attributes are not available.
 */
@interface KeychainKeyValueStore: NSObject

+ (KeychainKeyValueStore *)sharedInstance;

/**
 Use shortest possible keys.
 The shorter the key, the fastest the keychain store.
 */
- (void)storeValue:(id)value forKey:(NSString *)key;
- (id)storedValueForKey:(NSString *)key;

- (void)storeBoolValue:(BOOL)value forKey:(NSString *)key;
- (BOOL)storedBoolValueForKey:(NSString *)key;

- (void)clear;

@end
