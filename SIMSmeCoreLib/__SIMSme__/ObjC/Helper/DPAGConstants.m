//
// Created by mg on 02.10.13.
// Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

#import "DPAGConstants.h"

#import <execinfo.h>

@implementation DPAGConstants

+ (void) PrintBacktrace
{
#if DEBUG
    NSArray<NSString *> *callStackSymbols = [NSThread callStackSymbols];

    for (NSString *callStackSymbol in callStackSymbols)
    {
        NSLog(@"%@\n", callStackSymbol);
    }
#endif
}

+ (void) ReleaseNoLog: (NSString *) format, ...
{

}

+ (void) DebugTruncLog: (NSString *) format, ...
{
    NSString *messageFormatted;

    va_list args;
    va_start(args,format);
    //loop, get every next arg by calling va_arg(args,<type>)
    // e.g. NSString *arg=va_arg(args,NSString*) or int arg=(args,int)
    messageFormatted = [[NSString alloc] initWithFormat:format arguments:args];

    va_end(args);

    if ([messageFormatted length] > 512)
    {
        NSLog(@"%@ ... (truncated) ... %@", [messageFormatted substringToIndex:256], [messageFormatted substringFromIndex:[messageFormatted length]-256]);
        return;
    }
    NSLog(@"%@", messageFormatted);
}

NSString *const KEY_ACCESS_PRIVATE_KEY_TOUCH_ID = @"private_key_touchID";
NSString *const KEY_ACCESS_DOQ_LOC_ACCESS_GROUP = nil;
NSString *const KEY_ACCESS_PRIVATE_PREFERENCES = @"private_preferences";

@end
