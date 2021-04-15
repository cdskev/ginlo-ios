/*
 File: KeychainItemWrapper.m
 Abstract:
 Objective-C wrapper for accessing a single keychain item.
 
 Version: 1.2 - ARCified
 
 Disclaimer: IMPORTANT:  This Apple software is supplied to you by Apple
 Inc. ("Apple") in consideration of your agreement to the following
 terms, and your use, installation, modification or redistribution of
 this Apple software constitutes acceptance of these terms.  If you do
 not agree with these terms, please do not use, install, modify or
 redistribute this Apple software.
 
 In consideration of your agreement to abide by the following terms, and
 subject to these terms, Apple grants you a personal, non-exclusive
 license, under Apple's copyrights in this original Apple software (the
 "Apple Software"), to use, reproduce, modify and redistribute the Apple
 Software, with or without modifications, in source and/or binary forms;
 provided that if you redistribute the Apple Software in its entirety and
 without modifications, you must retain this notice and the following
 text and disclaimers in all such redistributions of the Apple Software.
 Neither the name, trademarks, service marks or logos of Apple Inc. may
 be used to endorse or promote products derived from the Apple Software
 without specific prior written permission from Apple.  Except as
 expressly stated in this notice, no other rights or licenses, express or
 implied, are granted by Apple herein, including but not limited to any
 patent rights that may be infringed by your derivative works or by other
 works in which the Apple Software may be incorporated.
 
 The Apple Software is provided by Apple on an "AS IS" basis.  APPLE
 MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
 THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS
 FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND
 OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.
 
 IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL
 OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION,
 MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED
 AND WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE),
 STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE
 POSSIBILITY OF SUCH DAMAGE.
 
 Copyright (C) 2010 Apple Inc. All Rights Reserved.
 
 */

#import "KeychainWrapper.h"

#import <Security/Security.h>
#import "DPAGConstants.h"
#import <UIKit/UIKit.h>

#if ! __has_feature(objc_arc)
#error THIS CODE MUST BE COMPILED WITH ARC ENABLED!
#endif

/*
 
 These are the default constants and their respective types,
 available for the kSecClassGenericPassword Keychain Item class:
 
 kSecAttrAccessGroup         -       CFStringRef
 kSecAttrCreationDate        -       CFDateRef
 kSecAttrModificationDate    -       CFDateRef
 kSecAttrDescription         -       CFStringRef
 kSecAttrComment             -       CFStringRef
 kSecAttrCreator             -       CFNumberRef
 kSecAttrType                -       CFNumberRef
 kSecAttrLabel               -       CFStringRef
 kSecAttrIsInvisible         -       CFBooleanRef
 kSecAttrIsNegative          -       CFBooleanRef
 kSecAttrAccount             -       CFStringRef
 kSecAttrService             -       CFStringRef
 kSecAttrGeneric             -       CFDataRef
 
 See the header file Security/SecItem.h for more details.
 
 */

NSString *const KEYCHAIN_IDENTIFIER_PUBLIC_KEY = @"public_keyDL";
NSString *const KEYCHAIN_IDENTIFIER_PRIVATE_KEY = @"private_keyDL";
NSString *const KEYCHAIN_IDENTIFIER_PRIVATE_KEY_ENCODED = @"private_key_enc_DL";
NSString *const KEYCHAIN_BACKUP_FILENAME = @"f1b70958-5c98-4ac0-a844-2f5d9f7389a9.kc";
NSString *const KEYCHAIN_BACKUP_KEY_TOUCH_ID = @"touchID";
NSString *const KEYCHAIN_BACKUP_KEY_PREFERENCES = @"preferences";
NSString *const KEYCHAIN_BACKUP_KEY_PUBLIC_KEY = @"publicKey";
NSString *const KEYCHAIN_BACKUP_KEY_PRIVATE_KEY = @"privateKey";
NSString *const KEYCHAIN_BACKUP_KEY_PRIVATE_KEY_ENCODED = @"privateKeyEncoded";
NSString *const KEYCHAIN_BACKUP_KEY_PRIVATE_KEY_ENCODED_SALT = @"privateKeyEncodedSalt";

@interface KeychainWrapper ()

@property (nonatomic) NSMutableDictionary *keychainItemData;		// The actual keychain item data backing store.
@property (nonatomic) NSMutableDictionary *genericPasswordQuery;	// A placeholder for the generic keychain item query used to locate the item.

@property (nonatomic) NSString* keychainIdentifier;
@property (nonatomic) NSString* service;

@end

@interface KeychainWrapper (PrivateMethods)
/*
 The decision behind the following two methods (secItemFormatToDictionary and dictionaryToSecItemFormat) was
 to encapsulate the transition between what the detail view controller was expecting (NSString *) and what the
 Keychain API expects as a validly constructed container class.
 */

- (NSMutableDictionary *)secItemFormatToDictionary:(NSDictionary *)dictionaryToConvert;
- (NSMutableDictionary *)dictionaryToSecItemFormat:(NSDictionary *)dictionaryToConvert;

// Updates the item in the keychain, or adds it if it doesn't exist.
- (void)writeToKeychain;

- (void)setObject:(id)inObject forKey:(id)key;
- (id)objectForKey:(id)key;

//

@end

@implementation KeychainWrapper

+(NSMutableDictionary*)cachedData
{
    @synchronized(self)
    {
        static NSMutableDictionary* _cachedData = nil;
        if (_cachedData == nil)
        {
            _cachedData = [NSMutableDictionary new];
        }
        return _cachedData;
    }
    
}


- (id)initWithIdentifier: (NSString *)identifier accessGroup:(NSString *) accessGroup isThisDeviceOnly:(BOOL)flag
{
    @synchronized([self class])
    {
        DPAGLog(@"KeychainWrapper: init: %@",identifier);

        self = [super init];
        
        if (!self)
        {
            return nil;
        }
        
        self.keychainIdentifier = identifier;
        self.service = [[NSBundle mainBundle] infoDictionary][@"CFBundleIdentifier"];
        
        // Begin Keychain search setup. The genericPasswordQuery leverages the special user
        // defined attribute kSecAttrGeneric to distinguish itself between other generic Keychain
        // items which may be included by the same application.
        self.genericPasswordQuery = [[NSMutableDictionary alloc] init];
        
        self.genericPasswordQuery[(__bridge id)kSecClass] = (__bridge id)kSecClassGenericPassword;
        self.genericPasswordQuery[(__bridge id)kSecAttrGeneric] = identifier;
        
        if(flag)
        {
            self.genericPasswordQuery[(__bridge id)kSecAttrAccessible] = (__bridge id)kSecAttrAccessibleWhenUnlockedThisDeviceOnly;
        }
        else
        {
            self.genericPasswordQuery[(__bridge id)kSecAttrAccessible] = (__bridge id)kSecAttrAccessibleWhenUnlocked;
        }
        
        
        self.genericPasswordQuery[(__bridge id)kSecAttrAccount] = identifier;
        self.genericPasswordQuery[(__bridge id)kSecAttrService] = self.service;
        
        // The keychain access group attribute determines if this item can be shared
        // amongst multiple apps whose code signing entitlements contain the same keychain access group.
        if (accessGroup != nil)
        {
#if TARGET_IPHONE_SIMULATOR
            // Ignore the access group if running on the iPhone simulator.
            //
            // Apps that are built for the simulator aren't signed, so there's no keychain access group
            // for the simulator to check. This means that all apps can see all keychain items when run
            // on the simulator.
            //
            // If a SecItem contains an access group attribute, SecItemAdd and SecItemUpdate on the
            // simulator will return -25243 (errSecNoAccessForItem).
            ;
#else
            
            self.genericPasswordQuery[(__bridge id)kSecAttrAccessGroup] = accessGroup;
            
#endif
        }
        
        // Use the proper search constants, return only the attributes of the first match.
        self.genericPasswordQuery[(__bridge id)kSecMatchLimit] = (__bridge id)kSecMatchLimitOne;
        self.genericPasswordQuery[(__bridge id)kSecReturnAttributes] = (__bridge id)kCFBooleanTrue;

        
        // use global cache
        if ([[KeychainWrapper cachedData] objectForKey:identifier] != nil)
        {
            DPAGLog(@"KeychainWrapper: init return cachedData: %@",self.keychainIdentifier);
            //cache Laden
            NSMutableDictionary* copy = [[KeychainWrapper cachedData] objectForKey:identifier];
            
            // und auf dieser arbeiten
            self.keychainItemData = copy;
            
            return self;
        }
        
        NSDictionary *tempQuery = [NSDictionary dictionaryWithDictionary:self.genericPasswordQuery];
        
        CFMutableDictionaryRef outDictionary = NULL;
        
        OSStatus statusLoading = SecItemCopyMatching((__bridge CFDictionaryRef)tempQuery, (CFTypeRef *)&outDictionary);
        
        if (statusLoading != noErr)
        {
            DPAGLog(@"KeychainWrapper: init error loading data: %@ %i",self.keychainIdentifier, (int)statusLoading);
            // Aktuell kein Zugriff auf die Daten
            if (statusLoading == errSecInteractionNotAllowed)
            {
                return nil;
            }
            // Stick these default values into keychain item if nothing found.
            [self resetKeychainItem];
            
            // Add the generic attribute and the keychain access group.
            self.keychainItemData[(__bridge id)kSecAttrGeneric] = identifier;
            self.keychainItemData[(__bridge id)kSecAttrAccount] = identifier;
            self.keychainItemData[(__bridge id)kSecAttrService] = self.service;
            
            if(flag)
            {
                self.keychainItemData[(__bridge id)kSecAttrAccessible] = (__bridge id)kSecAttrAccessibleWhenUnlockedThisDeviceOnly;
            }
            else
            {
                self.keychainItemData[(__bridge id)kSecAttrAccessible] = (__bridge id)kSecAttrAccessibleWhenUnlocked;
            }
            
            if (accessGroup != nil)
            {
#if TARGET_IPHONE_SIMULATOR
                // Ignore the access group if running on the iPhone simulator.
                //
                // Apps that are built for the simulator aren't signed, so there's no keychain access group
                // for the simulator to check. This means that all apps can see all keychain items when run
                // on the simulator.
                //
                // If a SecItem contains an access group attribute, SecItemAdd and SecItemUpdate on the
                // simulator will return -25243 (errSecNoAccessForItem).
                ;
#else
                self.keychainItemData[(__bridge id)kSecAttrAccessGroup] = accessGroup;
#endif
            }
        }
        else
        {
            DPAGLog(@"KeychainWrapper: init loading data: %@",self.keychainIdentifier);
            // load the saved data from Keychain.
            self.keychainItemData = [self secItemFormatToDictionary:(__bridge NSDictionary *)outDictionary];
            
        }
        // Kopie erstellen
        NSMutableDictionary* copy = [self.keychainItemData mutableCopy];
        [[KeychainWrapper cachedData] setObject:copy forKey:self.keychainIdentifier];
        
        // und auf dieser arbeiten
        self.keychainItemData = copy;
        if (outDictionary) CFRelease(outDictionary);
        
        return self;
    }
}

- (void)setObject:(id)inObject forKey:(id)key
{
    @synchronized([self class])
    {
    if (inObject == nil) return;
    id currentObject = [self.keychainItemData objectForKey:key];
    if (![currentObject isEqual:inObject])
    {
        self.keychainItemData[key] = inObject;
        [self writeToKeychain];
    }
    }
}

- (id)objectForKey:(id)key
{
    @synchronized([self class])
    {
        return [self.keychainItemData objectForKey:key];
    }
}

- (void)resetKeychainItem
{
    @synchronized([self class])
    {
        DPAGLog(@"KeychainWrapper: resetKeyChainItemData: %@",self.keychainIdentifier);
        
        OSStatus junk = noErr;
        
        if ( self.keychainItemData == nil )
        {
            self.keychainItemData = [[NSMutableDictionary alloc] init];
        }
        else
        {
            //[[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_SECURITY_PRIVATE_KEY_WILL_BE_DELETED object:nil];
            
            NSMutableDictionary *tempDictionary = [self dictionaryToSecItemFormat:self.keychainItemData];
            junk = SecItemDelete((__bridge CFDictionaryRef)tempDictionary);
            
            if (junk == noErr || junk == errSecItemNotFound)
            {
                DPAGLog(@"Problem deleting current dictionary.");
            }
            DPAGLog(@"resetKeychainItem delete OSStatus: %ld", junk);
            
            if (junk == noErr)
            {
                //[[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_SECURITY_PRIVATE_KEY_HAS_BEEN_DELETED object:nil];
            }
            else
            {
                // Mit alten Einstellungen löschen
                NSMutableDictionary* delDict = [[NSMutableDictionary alloc] init];
                
                delDict[(__bridge id)kSecClass] = (__bridge id)kSecClassGenericPassword;
                delDict[(__bridge id)kSecAttrAccessible] = (__bridge id)kSecAttrAccessibleWhenUnlocked;
                delDict[(__bridge id)kSecAttrAccount] = self.genericPasswordQuery[(__bridge id)kSecAttrAccount];
                
                if (self.genericPasswordQuery[(__bridge id)kSecAttrAccessGroup] != nil)
                {
                    delDict[(__bridge id)kSecAttrAccessGroup] = self.genericPasswordQuery[(__bridge id)kSecAttrAccessGroup];
                }
                
                NSDictionary *tempQuery = [NSDictionary dictionaryWithDictionary:delDict];
                
                junk = SecItemDelete((__bridge CFDictionaryRef)tempQuery);
                
                if (junk == noErr)
                {
                    //[[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_SECURITY_PRIVATE_KEY_HAS_BEEN_DELETED object:nil];
                }
                else
                {
                    DPAGLog(@"KeychainItem can not be deleted. Error: %ld", junk);
                }
            }
        }
        
        // Default attributes for keychain item.
        //[keychainItemData setObject:@"" forKey:(__bridge id)kSecAttrAccount];
        self.keychainItemData[(__bridge id)kSecAttrLabel] = @"";
        self.keychainItemData[(__bridge id)kSecAttrDescription] = @"";
        
        // Default data for keychain item.
        self.keychainItemData[(__bridge id)kSecValueData] = @"";
        // Kopie erstellen
        NSMutableDictionary* copy = [self.keychainItemData mutableCopy];
        [[KeychainWrapper cachedData] setObject:copy forKey:self.keychainIdentifier];
        
        // und auf dieser arbeiten
        self.keychainItemData = copy;

        dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0ul);

        dispatch_async(queue, ^{
            [KeychainWrapper backup];
        });
    }
}

- (NSMutableDictionary *)dictionaryToSecItemFormat:(NSDictionary *)dictionaryToConvert
{
    @synchronized([self class])
    {
        // The assumption is that this method will be called with a properly populated dictionary
        // containing all the right key/value pairs for a SecItem.

        // Create a dictionary to return populated with the attributes and data.
        NSMutableDictionary *returnDictionary = [NSMutableDictionary dictionaryWithDictionary:dictionaryToConvert];

        // Add the Generic Password keychain item class attribute.
        returnDictionary[(__bridge id)kSecClass] = (__bridge id)kSecClassGenericPassword;

        // Convert the NSString to NSData to meet the requirements for the value type kSecValueData.
        // This is where to store sensitive data that should be encrypted.
        NSString *passwordString = dictionaryToConvert[(__bridge id)kSecValueData];

        returnDictionary[(__bridge id)kSecValueData] = [passwordString dataUsingEncoding:NSUTF8StringEncoding];

        return returnDictionary;
    }
}

- (NSMutableDictionary *)secItemFormatToDictionary:(NSDictionary *)dictionaryToConvert
{
    @synchronized([self class])
    {
    // The assumption is that this method will be called with a properly populated dictionary
    // containing all the right key/value pairs for the UI element.
    
    // Create a dictionary to return populated with the attributes and data.
    NSMutableDictionary *returnDictionary = [NSMutableDictionary dictionaryWithDictionary:dictionaryToConvert];
    
    // Add the proper search key and class attribute.
    returnDictionary[(__bridge id)kSecReturnData] = (__bridge id)kCFBooleanTrue;
    returnDictionary[(__bridge id)kSecClass] = (__bridge id)kSecClassGenericPassword;
    
    // Acquire the password data from the attributes.
    CFDataRef passwordData = NULL;
    if (SecItemCopyMatching((__bridge CFDictionaryRef)returnDictionary, (CFTypeRef *)&passwordData) == noErr)
    {
        // Remove the search, class, and identifier key/value, we don't need them anymore.
        [returnDictionary removeObjectForKey:(__bridge id)kSecReturnData];
        
        // Add the password to the dictionary, converting from NSData to NSString.
        NSString *password = [[NSString alloc] initWithBytes:[(__bridge NSData *)passwordData bytes] length:[(__bridge NSData *)passwordData length] encoding:NSUTF8StringEncoding];
        NSMutableString* realCopy = [NSMutableString new];
        [realCopy appendString:password];
        returnDictionary[(__bridge id)kSecValueData] = realCopy;
    }
    else
    {
        // Don't do anything if nothing is found.
        NSAssert(NO, @"Serious error, no matching item found in the keychain.\n");
    }
    if(passwordData) CFRelease(passwordData);
    
    return returnDictionary;
    }
}

- (void)writeToKeychain
{
    @synchronized([self class])
    {
    CFDictionaryRef attributes = NULL;
    NSMutableDictionary *updateItem = nil;
    OSStatus result;
    
    if (SecItemCopyMatching((__bridge CFDictionaryRef)self.genericPasswordQuery, (CFTypeRef *)&attributes) == noErr)
    {
        // First we need the attributes from the Keychain.
        updateItem = [NSMutableDictionary dictionaryWithDictionary:(__bridge NSDictionary *)attributes];
        // Second we need to add the appropriate search key/values.
        updateItem[(__bridge id)kSecClass] = self.genericPasswordQuery[(__bridge id)kSecClass];
        
        // Lastly, we need to set up the updated attribute list being careful to remove the class.
        NSMutableDictionary *tempCheck = [self dictionaryToSecItemFormat:self.keychainItemData];
        [tempCheck removeObjectForKey:(__bridge id)kSecClass];
        
#if TARGET_IPHONE_SIMULATOR
        // Remove the access group if running on the iPhone simulator.
        //
        // Apps that are built for the simulator aren't signed, so there's no keychain access group
        // for the simulator to check. This means that all apps can see all keychain items when run
        // on the simulator.
        //
        // If a SecItem contains an access group attribute, SecItemAdd and SecItemUpdate on the
        // simulator will return -25243 (errSecNoAccessForItem).
        //
        // The access group attribute will be included in items returned by SecItemCopyMatching,
        // which is why we need to remove it before updating the item.
        [tempCheck removeObjectForKey:(__bridge id)kSecAttrAccessGroup];
#endif
        
        // An implicit assumption is that you can only update a single item at a time.
        
        result = SecItemUpdate((__bridge CFDictionaryRef)updateItem, (__bridge CFDictionaryRef)tempCheck);
        NSAssert( result == noErr, @"Couldn't update the Keychain Item." );
    }
    else
    {
        // No previous item found; add the new one.
        result = SecItemAdd((__bridge CFDictionaryRef)[self dictionaryToSecItemFormat:self.keychainItemData], NULL);
        if (result != noErr)
        {
            NSError *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:result userInfo:nil];
            if (error != nil)
            {
                DPAGLog(@"Error : %@",error);
            };
        }
        NSAssert( result == noErr, @"Couldn't add the Keychain Item." );
    }
    
    if(attributes) CFRelease(attributes);

        dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0ul);

        dispatch_async(queue, ^{
            [KeychainWrapper backup];
        });
    }
}

- (void)setPassword:(NSString*)password
{
    @synchronized([self class])
    {
        if (password == nil) return;
        id currentObject = [self.keychainItemData objectForKey:(__bridge id)kSecValueData];
        if (![currentObject isEqual:password])
        {
            self.keychainItemData[(__bridge id)kSecValueData] = password;
            [self writeToKeychain];
        }
    }
}

- (NSString*)password
{
    @synchronized([self class])
    {
        return [self.keychainItemData objectForKey:(__bridge id)kSecValueData];
    }
}

- (void)setUser:(NSString*)user
{
    @synchronized([self class])
    {
        if (user == nil) return;
        id currentObject = [self.keychainItemData objectForKey:(__bridge id)kSecAttrLabel];
        if (![currentObject isEqual:user])
        {
            self.keychainItemData[(__bridge id)kSecAttrLabel] = user;
            [self writeToKeychain];
        }
    }
}

- (NSString*)user
{
    @synchronized([self class])
    {
        return [self.keychainItemData objectForKey:(__bridge id)(kSecAttrLabel)];
    }
}

+ (void) backup {
    @try {
        NSMutableDictionary *dictAllKCEntries = [NSMutableDictionary dictionary];

        [dictAllKCEntries addEntriesFromDictionary:[self backupKeychainWrapperValueWithIdentifier:KEY_ACCESS_PRIVATE_KEY_TOUCH_ID passwordKey:KEYCHAIN_BACKUP_KEY_TOUCH_ID userKey:nil]];

        [dictAllKCEntries addEntriesFromDictionary:[self backupKeychainWrapperValueWithIdentifier:KEY_ACCESS_PRIVATE_PREFERENCES passwordKey:KEYCHAIN_BACKUP_KEY_PREFERENCES userKey:nil]];

        [dictAllKCEntries addEntriesFromDictionary:[self backupKeychainWrapperValueWithIdentifier:KEYCHAIN_IDENTIFIER_PUBLIC_KEY passwordKey:KEYCHAIN_BACKUP_KEY_PUBLIC_KEY userKey:nil]];
        [dictAllKCEntries addEntriesFromDictionary:[self backupKeychainWrapperValueWithIdentifier:KEYCHAIN_IDENTIFIER_PRIVATE_KEY passwordKey:KEYCHAIN_BACKUP_KEY_PRIVATE_KEY userKey:nil]];

        [dictAllKCEntries addEntriesFromDictionary:[self backupKeychainWrapperValueWithIdentifier:KEYCHAIN_IDENTIFIER_PRIVATE_KEY_ENCODED passwordKey:KEYCHAIN_BACKUP_KEY_PRIVATE_KEY_ENCODED userKey:KEYCHAIN_BACKUP_KEY_PRIVATE_KEY_ENCODED_SALT]];

        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *documentsDirectory = [paths objectAtIndex:0];
        NSString *path = [documentsDirectory stringByAppendingPathComponent:KEYCHAIN_BACKUP_FILENAME];

        [dictAllKCEntries writeToFile:path atomically:YES];
    } @catch (NSException *exception) {
        // do nothing
    }
}

+ (NSDictionary *) backupKeychainWrapperValueWithIdentifier:(NSString *)identifier passwordKey:(NSString *)passwordKey userKey:(NSString * )userKey {
    KeychainWrapper *kcWrapper = [[KeychainWrapper alloc] initWithIdentifier:identifier accessGroup:KEY_ACCESS_DOQ_LOC_ACCESS_GROUP isThisDeviceOnly:YES];

    NSMutableDictionary *dictKCEntries = [NSMutableDictionary dictionary];

    if ([passwordKey length] > 0 && [kcWrapper.password length] > 0) {
        dictKCEntries[passwordKey] = kcWrapper.password;
    }

    if ([userKey length] > 0 && [kcWrapper.user length] > 0) {
        dictKCEntries[userKey] = kcWrapper.user;
    }

    return dictKCEntries;
}

@end
