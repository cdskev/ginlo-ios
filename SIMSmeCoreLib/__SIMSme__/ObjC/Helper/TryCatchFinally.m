//
//  TryCatchFinally.m
//  SIMSme
//
//  Created by RBU on 27/01/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

#import "TryCatchFinally.h"

void tryCatchFinally(void(^tryBlock)(void), void(^catchBlock)(NSException *e), void(^finallyBlock)(void)) {
    @try {
        tryBlock();
    }
    @catch (NSException *exception) {
        catchBlock(exception);
    }
    @finally {
        finallyBlock();
    }
}
