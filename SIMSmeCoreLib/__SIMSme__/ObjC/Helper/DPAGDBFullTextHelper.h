//
//  DPAGDBFullTextHelper.h
//  SIMSmeCore
//
//  Created by Robert Burchert on 22.11.18.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>

//NS_ASSUME_NONNULL_BEGIN

@interface FtsDatabaseContact: NSObject

@property (nonatomic, readonly) NSString * _Nonnull accountGuid;
@property (nonatomic, readonly) NSString * _Nonnull sortStringFirstName;
@property (nonatomic, readonly) NSString * _Nonnull sortStringLastName;
@property (nonatomic, readonly) NSString * _Nonnull displayAttributes;
@property (nonatomic, readonly) NSString * _Nonnull searchAttributes;
@property (nonatomic, readonly) BOOL deleted;

- (instancetype _Nullable) initWithAccountGuid:(NSString * _Nonnull)accountGuid sortStringFirstName:(NSString * _Nonnull)sortStringFirstName sortStringLastName:(NSString * _Nonnull)sortStringLastName displayAttributes:(NSString * _Nonnull)displayAttributes searchAttributes:(NSString * _Nonnull)searchAttributes deleted:(BOOL)deleted;

@end

@interface DPAGDBFullTextHelper: NSObject

+ (NSInteger) checkDBConnectionWithGroupId:(NSString * _Nonnull) groupId;

+ (void) upgradeDBWithGroupId:(NSString * _Nonnull) groupId fromVersion:(NSInteger) versionOld;

+ (void) insertOrUpdateContactsWithGroupId:(NSString * _Nonnull) groupId contactInfos:(NSArray<FtsDatabaseContact *> * _Nonnull) contactInfos;

+ (NSArray<NSString *> * _Nonnull) searchContactsWithGroupId:(NSString * _Nonnull) groupId searchText:(NSString * _Nonnull) searchText orderByFirstName:(BOOL)orderByFirstName;

+ (void) deleteAllObjectsWithGroupId:(NSString * _Nonnull) groupId;

+ (DPAGDBFullTextHelper * _Nonnull)sharedInstance;

@end

//NS_ASSUME_NONNULL_END
