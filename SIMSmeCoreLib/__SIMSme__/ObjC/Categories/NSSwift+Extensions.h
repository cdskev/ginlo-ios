//
//  NSSwift+Extensions.h
//  SIMSmeLib
//
//  Created by RBU on 27/05/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

#ifndef SIMSmeLib_nsswift_extensions_h
#define SIMSmeLib_nsswift_extensions_h

#import <UIKit/UIKit.h>

@interface DPAGHelper: NSObject

+ (NSString * _Nullable) mimeTypeForExtension: (NSString * _Nonnull) fileExtension;

+ (NSData * _Nullable) gzipData: (NSData * _Nonnull)pUncompressedData;
+ (NSData * _Nullable) gzipFile: (NSURL * _Nonnull)pFileUrl length:(long)length;
+ (unsigned long long) deviceMemory;
+ (bool) canPerformRAMBasedJSONOfSize:(unsigned long)jsonSize;
@end

// Implement a custom appearance property via a UILabel category
@interface UILabel (PickerLabelTextColor)

@property (nonatomic) UIColor * _Nonnull textColorWorkaround UI_APPEARANCE_SELECTOR;

@end

#endif
