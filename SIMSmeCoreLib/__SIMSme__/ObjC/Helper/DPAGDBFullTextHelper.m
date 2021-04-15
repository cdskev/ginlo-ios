//
//  DPAGDBFullTextHelper.m
//  SIMSmeCore
//
//  Created by Robert Burchert on 22.11.18.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

#import "DPAGDBFullTextHelper.h"

#import <sqlite3.h>

#define SECRET_KEY @"HalloYves!!!250675"

typedef void (^OpenDBExecutionBlock)(sqlite3 * db);

struct FtsDatabaseHelperStruct {
    NSString * const FTS_CONTACTS_TABLE;
    NSString * const COLUMN_ACCOUNT_GUID;
    NSString * const COLUMN_SORT_ATTRIBUTES_BY_FIRST_NAME;
    NSString * const COLUMN_SORT_ATTRIBUTES_BY_LAST_NAME;
    NSString * const COLUMN_DISPLAY_ATTRIBUTES;
    NSString * const COLUMN_SEARCH_ATTRIBUTES;
};

extern const struct FtsDatabaseHelperStruct FtsDatabaseHelper;

const struct FtsDatabaseHelperStruct FtsDatabaseHelper = {
    .FTS_CONTACTS_TABLE = @"CONTACTS",
    .COLUMN_ACCOUNT_GUID = @"ACCOUNT_GUID",
    .COLUMN_SORT_ATTRIBUTES_BY_FIRST_NAME = @"SORT_ATTRIBUTES_FN",
    .COLUMN_SORT_ATTRIBUTES_BY_LAST_NAME = @"SORT_ATTRIBUTES_LN",
    .COLUMN_DISPLAY_ATTRIBUTES = @"DISPLAY_ATTRIBUTES",
    .COLUMN_SEARCH_ATTRIBUTES = @"COLUMN_SEARCH_ATTRIBUTES"
};

@interface FtsDatabaseContact()

@property (nonatomic) NSString * _Nonnull accountGuid;
@property (nonatomic) NSString * _Nonnull sortStringFirstName;
@property (nonatomic) NSString * _Nonnull sortStringLastName;
@property (nonatomic) NSString * _Nonnull displayAttributes;
@property (nonatomic) NSString * _Nonnull searchAttributes;
@property (nonatomic) BOOL deleted;

@end

@implementation FtsDatabaseContact

- (instancetype) initWithAccountGuid:(NSString *)accountGuid sortStringFirstName:(NSString *)sortStringFirstName sortStringLastName:(NSString *)sortStringLastName displayAttributes:(NSString *)displayAttributes searchAttributes:(NSString *)searchAttributes deleted:(BOOL)deleted {
    if (self = [super init]) {
        self.accountGuid = accountGuid;
        self.sortStringFirstName = sortStringFirstName;
        self.sortStringLastName = sortStringLastName;
        self.displayAttributes = displayAttributes;
        self.searchAttributes = searchAttributes;
        self.deleted = deleted;

        return self;
    }

    return nil;
}

@end

@implementation DPAGDBFullTextHelper

+ (DPAGDBFullTextHelper *)sharedInstance {
    static DPAGDBFullTextHelper *sharedInstance = nil;
    static dispatch_once_t pred;

    dispatch_once(&pred, ^{
        sharedInstance = [[self alloc] init];
    });

    return sharedInstance;
}

// private
+ (NSString * _Nullable)openDBWithGroupId:(NSString *) groupId andExecute: (OpenDBExecutionBlock) execute {
    NSURL *databaseURL = [[[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:groupId] URLByAppendingPathComponent: @"fts_database.db"];
    //    NSString *databasePath = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingPathComponent: @"sqlcipher.db"];

    sqlite3 *db;

    if (sqlite3_open([databaseURL.path UTF8String], &db) == SQLITE_OK) {
        const char* key = [SECRET_KEY UTF8String];
        sqlite3_key(db, key, (int)strlen(key));
//        migration
        sqlite3_exec(db, "PRAGMA cipher_migrate;", 0, 0, 0);
//        fallback to version 3
//        sqlite3_exec(db, "PRAGMA cipher_page_size = 1024; PRAGMA kdf_iter = 64000; PRAGMA cipher_hmac_algorithm = HMAC_SHA1; PRAGMA cipher_kdf_algorithm = PBKDF2_HMAC_SHA1;", 0, 0, 0);
        execute(db);

        sqlite3_close(db);

        return nil;
    } else {
        const char *errMsg = sqlite3_errmsg(db);

        if (errMsg != nil) {
            return [NSString stringWithCString:errMsg encoding: NSUTF8StringEncoding];
        }
    }
    return nil;
}

+ (NSInteger) checkDBConnectionWithGroupId:(NSString *) groupId {
    __block NSInteger retVal = -1;

    [self openDBWithGroupId:groupId andExecute:^(sqlite3 *db) {

        if (sqlite3_exec(db, "SELECT count(*) FROM sqlite_master;", NULL, NULL, NULL) != SQLITE_OK) {
            return;
        }

        sqlite3_stmt *stmt;
        if (sqlite3_prepare_v2(db, "PRAGMA cipher_version;", -1, &stmt, NULL) == SQLITE_OK) {
            if (sqlite3_step(stmt) == SQLITE_ROW) {
                const unsigned char *ver = sqlite3_column_text(stmt, 0);
                if (ver != NULL) {
                    // password is correct (or database initialize), and verified to be using sqlcipher
                    retVal = 0;
                }
            }
            sqlite3_finalize(stmt);
        }

        int versionRetVal = sqlite3_prepare_v2(db, "SELECT version FROM fts_version;", -1, &stmt, NULL);

        if (versionRetVal != SQLITE_OK) {
            return;
        }

        if (sqlite3_step(stmt) == SQLITE_ROW) {
            int version = sqlite3_column_int(stmt, 0);

            if (version != 0) {
                retVal = (NSInteger)version;
            }
        }
        sqlite3_finalize(stmt);
    }];

    return retVal;
}

+ (void) upgradeDBWithGroupId:(NSString *) groupId fromVersion:(NSInteger) versionOld {
    // create table
    NSString* FTS_TABLE_CREATE =
    [[[[[[[[[[[[[@"CREATE VIRTUAL TABLE " stringByAppendingString:FtsDatabaseHelper.FTS_CONTACTS_TABLE] stringByAppendingString:@" USING FTS3("] stringByAppendingString:FtsDatabaseHelper.COLUMN_ACCOUNT_GUID] stringByAppendingString:@", "] stringByAppendingString:FtsDatabaseHelper.COLUMN_SORT_ATTRIBUTES_BY_FIRST_NAME] stringByAppendingString:@", "] stringByAppendingString:FtsDatabaseHelper.COLUMN_SORT_ATTRIBUTES_BY_LAST_NAME] stringByAppendingString:@", "] stringByAppendingString:@", "] stringByAppendingString:FtsDatabaseHelper.COLUMN_DISPLAY_ATTRIBUTES] stringByAppendingString:@", "] stringByAppendingString:FtsDatabaseHelper.COLUMN_SEARCH_ATTRIBUTES] stringByAppendingString:@");"];

    [self openDBWithGroupId:groupId andExecute:^(sqlite3 *db) {

        if (versionOld > 0) {
            return;
        }

        char *errMsg;

        if (sqlite3_exec(db, "CREATE TABLE fts_version(version)", NULL, NULL, &errMsg) != SQLITE_OK && [self isMsgAlreadyExists:errMsg] == false) {
            return;
        }

        if (sqlite3_exec(db, [FTS_TABLE_CREATE cStringUsingEncoding:NSUTF8StringEncoding], NULL, NULL, &errMsg) != SQLITE_OK && [self isMsgAlreadyExists:errMsg] == false) {
            return;
        }

        if (sqlite3_exec(db, "REPLACE INTO fts_version (version) VALUES (1)", NULL, NULL, &errMsg) != SQLITE_OK) {
            return;
        }
    }];
}

+ (BOOL) isMsgAlreadyExists:(char *)msg {
    if (msg == nil) {
        return false;
    }

    const char *strAlreadyExists = "already exists";

    size_t len = strlen(msg);
    size_t lenAlEx = strlen(strAlreadyExists);

    if (len > lenAlEx && strcmp(msg + len - lenAlEx, strAlreadyExists) == 0) {
        return true;
    }
    
    return false;
}

+ (void) insertOrUpdateContactsWithGroupId:(NSString *) groupId contactInfos:(NSArray<FtsDatabaseContact *> *) contactInfos {
    if (contactInfos.count == 0) {
        return;
    }

    [self openDBWithGroupId:groupId andExecute:^(sqlite3 *db) {

        NSString* FTS_TABLE_SELECT_FORMAT =
        [[[[@"SELECT COUNT(*) FROM " stringByAppendingString:FtsDatabaseHelper.FTS_CONTACTS_TABLE] stringByAppendingString:@" WHERE "] stringByAppendingString:FtsDatabaseHelper.COLUMN_ACCOUNT_GUID] stringByAppendingString:@" = ?;"];

        NSString* FTS_TABLE_DELETE_FORMAT =
        [[[[@"DELETE FROM " stringByAppendingString:FtsDatabaseHelper.FTS_CONTACTS_TABLE] stringByAppendingString:@" WHERE "] stringByAppendingString:FtsDatabaseHelper.COLUMN_ACCOUNT_GUID] stringByAppendingString:@" = ?;"];

        NSString* FTS_TABLE_INSERT_FORMAT =
        [[[[[[[[[[[[@"INSERT INTO " stringByAppendingString:FtsDatabaseHelper.FTS_CONTACTS_TABLE] stringByAppendingString:@" ("] stringByAppendingString:FtsDatabaseHelper.COLUMN_ACCOUNT_GUID] stringByAppendingString:@", "] stringByAppendingString:FtsDatabaseHelper.COLUMN_SORT_ATTRIBUTES_BY_FIRST_NAME] stringByAppendingString:@", "] stringByAppendingString:FtsDatabaseHelper.COLUMN_SORT_ATTRIBUTES_BY_LAST_NAME] stringByAppendingString:@", "] stringByAppendingString:FtsDatabaseHelper.COLUMN_DISPLAY_ATTRIBUTES] stringByAppendingString:@", "] stringByAppendingString:FtsDatabaseHelper.COLUMN_SEARCH_ATTRIBUTES] stringByAppendingString:@") VALUES (?, ?, ?, ?, ?);"];

        NSString* FTS_TABLE_UPDATE_FORMAT =
        [[[[[[[[[[[[@"UPDATE " stringByAppendingString:FtsDatabaseHelper.FTS_CONTACTS_TABLE] stringByAppendingString:@" SET "] stringByAppendingString:FtsDatabaseHelper.COLUMN_SORT_ATTRIBUTES_BY_FIRST_NAME] stringByAppendingString:@" = ?, "] stringByAppendingString:FtsDatabaseHelper.COLUMN_SORT_ATTRIBUTES_BY_LAST_NAME] stringByAppendingString:@" = ?, "] stringByAppendingString:FtsDatabaseHelper.COLUMN_DISPLAY_ATTRIBUTES] stringByAppendingString:@" = ?, "] stringByAppendingString:FtsDatabaseHelper.COLUMN_SEARCH_ATTRIBUTES] stringByAppendingString:@" = ? WHERE "] stringByAppendingString:FtsDatabaseHelper.COLUMN_ACCOUNT_GUID] stringByAppendingString:@" = ?;"];

        for (FtsDatabaseContact *contactInfo in contactInfos) {
//            char *errMsg;
            sqlite3_stmt *stmt;

            if (contactInfo.deleted) {
                if (sqlite3_prepare_v2(db, [FTS_TABLE_DELETE_FORMAT cStringUsingEncoding:NSUTF8StringEncoding], -1, &stmt, NULL) == SQLITE_OK) {
                    if (sqlite3_bind_text(stmt, 1, [contactInfo.accountGuid cStringUsingEncoding:NSUTF8StringEncoding], -1, NULL) != SQLITE_OK) {
                        sqlite3_finalize(stmt);
                        break;
                    }

                    sqlite3_step(stmt);
                    sqlite3_finalize(stmt);
                }
                continue;
            }

            if (sqlite3_prepare_v2(db, [FTS_TABLE_SELECT_FORMAT cStringUsingEncoding:NSUTF8StringEncoding], -1, &stmt, NULL) == SQLITE_OK) {
                int count = 0;

                if (sqlite3_bind_text(stmt, 1, [contactInfo.accountGuid cStringUsingEncoding:NSUTF8StringEncoding], -1, NULL) != SQLITE_OK) {
                    sqlite3_finalize(stmt);
                    break;
                }

                if (sqlite3_step(stmt) == SQLITE_ROW) {
                    count = sqlite3_column_int(stmt, 0);
                }
                sqlite3_finalize(stmt);

                if (count != 0) {
                    if (sqlite3_prepare_v2(db, [FTS_TABLE_UPDATE_FORMAT cStringUsingEncoding:NSUTF8StringEncoding], -1, &stmt, NULL) == SQLITE_OK) {
                        if (sqlite3_bind_text(stmt, 1, [contactInfo.sortStringFirstName cStringUsingEncoding:NSUTF8StringEncoding], -1, NULL) != SQLITE_OK) {
                            sqlite3_finalize(stmt);
                            break;
                        }
                        if (sqlite3_bind_text(stmt, 2, [contactInfo.sortStringLastName cStringUsingEncoding:NSUTF8StringEncoding], -1, NULL) != SQLITE_OK) {
                            sqlite3_finalize(stmt);
                            break;
                        }
                        if (sqlite3_bind_text(stmt, 3, [contactInfo.displayAttributes cStringUsingEncoding:NSUTF8StringEncoding], -1, NULL) != SQLITE_OK) {
                            sqlite3_finalize(stmt);
                            break;
                        }
                        if (sqlite3_bind_text(stmt, 4, [contactInfo.searchAttributes cStringUsingEncoding:NSUTF8StringEncoding], -1, NULL) != SQLITE_OK) {
                            sqlite3_finalize(stmt);
                            break;
                        }
                        if (sqlite3_bind_text(stmt, 5, [contactInfo.accountGuid cStringUsingEncoding:NSUTF8StringEncoding], -1, NULL) != SQLITE_OK) {
                            sqlite3_finalize(stmt);
                            break;
                        }

                        if (sqlite3_step(stmt) != SQLITE_DONE) {
                        }
                        sqlite3_finalize(stmt);
                    }
                } else {
                    if (sqlite3_prepare_v2(db, [FTS_TABLE_INSERT_FORMAT cStringUsingEncoding:NSUTF8StringEncoding], -1, &stmt, NULL) == SQLITE_OK) {
                        if (sqlite3_bind_text(stmt, 1, [contactInfo.accountGuid cStringUsingEncoding:NSUTF8StringEncoding], -1, NULL) != SQLITE_OK) {
                            sqlite3_finalize(stmt);
                            break;
                        }
                        if (sqlite3_bind_text(stmt, 2, [contactInfo.sortStringFirstName cStringUsingEncoding:NSUTF8StringEncoding], -1, NULL) != SQLITE_OK) {
                            sqlite3_finalize(stmt);
                            break;
                        }
                        if (sqlite3_bind_text(stmt, 3, [contactInfo.sortStringLastName cStringUsingEncoding:NSUTF8StringEncoding], -1, NULL) != SQLITE_OK) {
                            sqlite3_finalize(stmt);
                            break;
                        }
                        if (sqlite3_bind_text(stmt, 4, [contactInfo.displayAttributes cStringUsingEncoding:NSUTF8StringEncoding], -1, NULL) != SQLITE_OK) {
                            sqlite3_finalize(stmt);
                            break;
                        }
                        if (sqlite3_bind_text(stmt, 5, [contactInfo.searchAttributes cStringUsingEncoding:NSUTF8StringEncoding], -1, NULL) != SQLITE_OK) {
                            sqlite3_finalize(stmt);
                            break;
                        }

                        if (sqlite3_step(stmt) != SQLITE_DONE) {
                        }
                        sqlite3_finalize(stmt);
                    }
                }
            }
        }
    }];
}

+ (NSArray<NSString *> *) searchContactsWithGroupId:(NSString *) groupId searchText:(NSString *) searchText orderByFirstName:(BOOL)orderByFirstName {
    __block NSMutableArray<NSString *> *contactsFound = [NSMutableArray array];

    [self openDBWithGroupId:groupId andExecute:^(sqlite3 *db) {

        NSString* FTS_TABLE_SEARCH = (orderByFirstName) ? @"SELECT DISPLAY_ATTRIBUTES FROM CONTACTS WHERE COLUMN_SEARCH_ATTRIBUTES MATCH ? ORDER BY SORT_ATTRIBUTES_FN, ACCOUNT_GUID" : @"SELECT DISPLAY_ATTRIBUTES FROM CONTACTS WHERE COLUMN_SEARCH_ATTRIBUTES MATCH ? ORDER BY SORT_ATTRIBUTES_LN, ACCOUNT_GUID";
        
        sqlite3_stmt *stmt;

        if (sqlite3_prepare_v2(db, [FTS_TABLE_SEARCH cStringUsingEncoding:NSUTF8StringEncoding], -1, &stmt, NULL) == SQLITE_OK) {
            if (sqlite3_bind_text(stmt, 1, [[searchText stringByAppendingString:@"*"] cStringUsingEncoding:NSUTF8StringEncoding], -1, NULL) != SQLITE_OK) {
                sqlite3_finalize(stmt);
                return;
            }
            while (sqlite3_step(stmt) == SQLITE_ROW) {
                const char *attributesJSONC = (char *)sqlite3_column_text(stmt, 0);

                if (attributesJSONC != NULL) {
                    NSString *attributesJSON = [NSString stringWithCString:attributesJSONC encoding:NSUTF8StringEncoding];
                    
                    [contactsFound addObject:attributesJSON];
                }
            }
            sqlite3_finalize(stmt);
        } else {
            const char* lastErr = sqlite3_errmsg(db);
            NSLog(@"%s", lastErr);
        }
    }];

    return contactsFound;
}

+ (void) deleteAllObjectsWithGroupId:(NSString *) groupId {
    [self openDBWithGroupId:groupId andExecute:^(sqlite3 *db) {

        NSString* FTS_TABLE_DELETE =
        [[@"DELETE FROM " stringByAppendingString:FtsDatabaseHelper.FTS_CONTACTS_TABLE] stringByAppendingString:@";"];

        char *errMsg;

        if (sqlite3_exec(db, [FTS_TABLE_DELETE cStringUsingEncoding:NSUTF8StringEncoding], NULL, NULL, &errMsg) != SQLITE_OK) {
            NSLog(@"%s", errMsg);
        }
    }];
}

@end
