//
//  KeychainKeyValueStore.m
//  SIMSme
//
//  Created by Florin Pop on 06/11/14.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

#import "KeychainKeyValueStore.h"

#import "KeychainWrapper.h"
#import "DPAGConstants.h"

@interface KeychainKeyValueStore()

@property(nonatomic, strong) KeychainWrapper *prefWrapper;

@end

@implementation KeychainKeyValueStore

+ (KeychainKeyValueStore *)sharedInstance {
    static KeychainKeyValueStore *sharedInstance = nil;
    static dispatch_once_t pred;
    
    dispatch_once(&pred, ^{
        sharedInstance = [[self alloc] init];
    });
    
    return sharedInstance;
}

- (KeychainWrapper *)prefWrapper {
    if ([NSThread isMainThread])
    {
        [self loadData];
        return _prefWrapper;
    }
    [self performSelectorOnMainThread:@selector(loadData) withObject:self waitUntilDone:YES];
    return _prefWrapper;
}

-(void)loadData
{
    if (_prefWrapper == nil) {
        self.prefWrapper = [[KeychainWrapper alloc] initWithIdentifier:KEY_ACCESS_PRIVATE_PREFERENCES accessGroup:KEY_ACCESS_DOQ_LOC_ACCESS_GROUP isThisDeviceOnly:YES];
    }
    
}

- (NSDictionary*)preferencesDictionary
{
    NSDictionary *prefDictionary = nil;
    
    if (self.prefWrapper.password.length > 0)
    {
        /*
        prefDictionary = (NSDictionary*) [NSKeyedUnarchiver unarchiveObjectWithData:[[NSData alloc] initWithBase64EncodedString:self.prefWrapper.getPassword options:0]];
        */
        NSData* data =[self.prefWrapper.password dataUsingEncoding:NSUTF8StringEncoding];
        if (data != nil)
        {
            @try
            {
                prefDictionary = (NSDictionary*) [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            }
            @catch (NSException *exception)
            {
                DPAGLog(@"Could not parse the keychain properties. Reson: %@", exception);
            }
        }
    }
    if (prefDictionary == nil)
    {
        prefDictionary = [[NSDictionary alloc] init];
    }
    return prefDictionary;
}

- (void)storeValue:(id)value forKey:(NSString *)key
{
    NSMutableDictionary *prefDictionary = [[self preferencesDictionary] mutableCopy];
    prefDictionary[key] = value;
    /*
    NSData *archivedDictionary = [NSKeyedArchiver archivedDataWithRootObject:prefDictionary];
    [self.prefWrapper setPassword:[archivedDictionary base64EncodedStringWithOptions:0]];
     */
    
    //Serialization is nicer, but JSON is shorter
    
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:prefDictionary
                                                       options:0
                                                         error:nil];
    NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    [self.prefWrapper setPassword:jsonString];
}

- (id)storedValueForKey:(NSString *)key
{
    return [self preferencesDictionary][key];
}

- (void)storeBoolValue:(BOOL)value forKey:(NSString *)key
{
    [self storeValue:@(value) forKey:key];
}

- (BOOL)storedBoolValueForKey:(NSString *)key
{
    id storedValue = [self storedValueForKey:key];
    return storedValue ? [storedValue boolValue] : NO;
}

- (void)clear
{
    [self.prefWrapper resetKeychainItem];
}

@end
