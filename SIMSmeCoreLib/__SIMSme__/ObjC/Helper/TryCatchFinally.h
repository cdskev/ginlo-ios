//
//  TryCatchFinally.h
// ginlo
//
//  Created by RBU on 27/01/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>

void tryCatchFinally(void(^ _Nonnull tryBlock)(void), void(^ _Nonnull catchBlock)(NSException * _Nonnull e), void(^ _Nonnull finallyBlock)(void));
