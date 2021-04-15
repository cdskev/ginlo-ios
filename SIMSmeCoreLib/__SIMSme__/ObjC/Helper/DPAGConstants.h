//
// Created by mg on 02.10.13.
// Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface DPAGConstants: NSObject

+ (void) PrintBacktrace;
+ (void) ReleaseNoLog: (NSString *) format, ...;
+ (void) DebugTruncLog: (NSString *) format, ...;

#ifdef DEBUG
#define DPAGLog(message, ...) { \
[DPAGConstants DebugTruncLog: [NSString stringWithFormat:@"%s [%i]: %@", __PRETTY_FUNCTION__, __LINE__, message], ##__VA_ARGS__]; \
}
#else
#define DPAGLog(message, ...) { \
}
#endif

#define CHECK_MAIN_THREAD if (![NSThread isMainThread]) { DPAGLog(@"%@ should be called on the main thread",[NSString stringWithUTF8String:__func__]); [DPAGConstants PrintBacktrace];}
#define CHECK_BACKGROUND_THREAD if ([NSThread isMainThread]) { DPAGLog(@"%@ should be called in a background thread",[NSString stringWithUTF8String:__func__]); [DPAGConstants PrintBacktrace];}

FOUNDATION_EXPORT NSString *const KEY_ACCESS_PRIVATE_KEY_TOUCH_ID;
FOUNDATION_EXPORT NSString *const KEY_ACCESS_PRIVATE_PREFERENCES;
FOUNDATION_EXPORT NSString *const KEY_ACCESS_DOQ_LOC_ACCESS_GROUP;

@end
