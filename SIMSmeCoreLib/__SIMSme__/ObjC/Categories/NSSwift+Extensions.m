//
//  NSSwift+Extensions.m
//  SIMSmeLib
//
//  Created by RBU on 27/05/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

#import "NSSwift+Extensions.h"

#import <zlib.h>
#import <stdlib.h>
#import <MobileCoreServices/MobileCoreServices.h>

// https://zlib.net/zlib_how.html
#define CHUNK 256 * 1024

@implementation DPAGHelper

+ (NSString *) mimeTypeForExtension: (NSString *) fileExtension
{
    NSString *UTI = (__bridge_transfer NSString *)UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (__bridge CFStringRef)fileExtension, NULL);
    NSString *contentMimeType = (__bridge_transfer NSString *)UTTypeCopyPreferredTagWithClass((__bridge CFStringRef)UTI, kUTTagClassMIMEType);

    return contentMimeType;
}

/*******************************************************************************
 See header for documentation.
 */
+ (NSData*) gzipData: (NSData*)pUncompressedData
{
    /*
     Special thanks to Robbie Hanson of Deusty Designs for sharing sample code
     showing how deflateInit2() can be used to make zlib generate a compressed
     file with gzip headers:

     http://deusty.blogspot.com/2007/07/gzip-compressiondecompression.html

     */

    if (!pUncompressedData || [pUncompressedData length] == 0)
    {
        #if DEBUG
        NSLog(@"%s: Error: Can't compress an empty or null NSData object.", __func__);
        #endif
        return nil;
    }

    /* Before we can begin compressing (aka "deflating") data using the zlib
     functions, we must initialize zlib. Normally this is done by calling the
     deflateInit() function; in this case, however, we'll use deflateInit2() so
     that the compressed data will have gzip headers. This will make it easy to
     decompress the data later using a tool like gunzip, WinZip, etc.

     deflateInit2() accepts many parameters, the first of which is a C struct of
     type "z_stream" defined in zlib.h. The properties of this struct are used to
     control how the compression algorithms work. z_stream is also used to
     maintain pointers to the "input" and "output" byte buffers (next_in/out) as
     well as information about how many bytes have been processed, how many are
     left to process, etc. */
    z_stream zlibStreamStruct;
    zlibStreamStruct.zalloc    = Z_NULL; // Set zalloc, zfree, and opaque to Z_NULL so
    zlibStreamStruct.zfree     = Z_NULL; // that when we call deflateInit2 they will be
    zlibStreamStruct.opaque    = Z_NULL; // updated to use default allocation functions.
    zlibStreamStruct.total_out = 0; // Total number of output bytes produced so far
    zlibStreamStruct.next_in   = (Bytef*)[pUncompressedData bytes]; // Pointer to input bytes
    zlibStreamStruct.avail_in  = (unsigned int)[pUncompressedData length]; // Number of input bytes left to process

    /* Initialize the zlib deflation (i.e. compression) internals with deflateInit2().
     The parameters are as follows:

     z_streamp strm - Pointer to a zstream struct
     int level      - Compression level. Must be Z_DEFAULT_COMPRESSION, or between
     0 and 9: 1 gives best speed, 9 gives best compression, 0 gives
     no compression.
     int method     - Compression method. Only method supported is "Z_DEFLATED".
     int windowBits - Base two logarithm of the maximum window size (the size of
     the history buffer). It should be in the range 8..15. Add
     16 to windowBits to write a simple gzip header and trailer
     around the compressed data instead of a zlib wrapper. The
     gzip header will have no file name, no extra data, no comment,
     no modification time (set to zero), no header crc, and the
     operating system will be set to 255 (unknown).
     int memLevel   - Amount of memory allocated for internal compression state.
     1 uses minimum memory but is slow and reduces compression
     ratio; 9 uses maximum memory for optimal speed. Default value
     is 8.
     int strategy   - Used to tune the compression algorithm. Use the value
     Z_DEFAULT_STRATEGY for normal data, Z_FILTERED for data
     produced by a filter (or predictor), or Z_HUFFMAN_ONLY to
     force Huffman encoding only (no string match) */
    int initError = deflateInit2(&zlibStreamStruct, Z_DEFAULT_COMPRESSION, Z_DEFLATED, (15+16), 8, Z_DEFAULT_STRATEGY);
    if (initError != Z_OK)
    {
        NSString *errorMsg = nil;
        switch (initError)
        {
            case Z_STREAM_ERROR:
                errorMsg = @"Invalid parameter passed in to function.";
                break;
            case Z_MEM_ERROR:
                errorMsg = @"Insufficient memory.";
                break;
            case Z_VERSION_ERROR:
                errorMsg = @"The version of zlib.h and the version of the library linked do not match.";
                break;
            default:
                errorMsg = @"Unknown error code.";
                break;
        }
        #if DEBUG
        NSLog(@"%s: deflateInit2() Error: \"%@\" Message: \"%s\"", __func__, errorMsg, zlibStreamStruct.msg);
        #endif
        return nil;
    }

    // Create output memory buffer for compressed data. The zlib documentation states that
    // destination buffer size must be at least 0.1% larger than avail_in plus 12 bytes.
    NSMutableData *compressedData = [NSMutableData dataWithLength:[pUncompressedData length] * 1.01 + 12];

    int deflateStatus;
    do
    {
        // Store location where next byte should be put in next_out
        zlibStreamStruct.next_out = [compressedData mutableBytes] + zlibStreamStruct.total_out;

        // Calculate the amount of remaining free space in the output buffer
        // by subtracting the number of bytes that have been written so far
        // from the buffer's total capacity
        zlibStreamStruct.avail_out = ((uint)[compressedData length]) - (uint)zlibStreamStruct.total_out;

        /* deflate() compresses as much data as possible, and stops/returns when
         the input buffer becomes empty or the output buffer becomes full. If
         deflate() returns Z_OK, it means that there are more bytes left to
         compress in the input buffer but the output buffer is full; the output
         buffer should be expanded and deflate should be called again (i.e., the
         loop should continue to rune). If deflate() returns Z_STREAM_END, the
         end of the input stream was reached (i.e.g, all of the data has been
         compressed) and the loop should stop. */
        deflateStatus = deflate(&zlibStreamStruct, Z_FINISH);

    } while ( deflateStatus == Z_OK );

    // Check for zlib error and convert code to usable error message if appropriate
    if (deflateStatus != Z_STREAM_END)
    {
        NSString *errorMsg = nil;
        switch (deflateStatus)
        {
            case Z_ERRNO:
                errorMsg = @"Error occured while reading file.";
                break;
            case Z_STREAM_ERROR:
                errorMsg = @"The stream state was inconsistent (e.g., next_in or next_out was NULL).";
                break;
            case Z_DATA_ERROR:
                errorMsg = @"The deflate data was invalid or incomplete.";
                break;
            case Z_MEM_ERROR:
                errorMsg = @"Memory could not be allocated for processing.";
                break;
            case Z_BUF_ERROR:
                errorMsg = @"Ran out of output buffer for writing compressed bytes.";
                break;
            case Z_VERSION_ERROR:
                errorMsg = @"The version of zlib.h and the version of the library linked do not match.";
                break;
            default:
                errorMsg = @"Unknown error code.";
                break;
        }
        #if DEBUG
        NSLog(@"%s: zlib error while attempting compression: \"%@\" Message: \"%s\"", __func__, errorMsg, zlibStreamStruct.msg);
        #endif

        // Free data structures that were dynamically created for the stream.
        deflateEnd(&zlibStreamStruct);

        return nil;
    }
    // Free data structures that were dynamically created for the stream.
    deflateEnd(&zlibStreamStruct);
    [compressedData setLength: zlibStreamStruct.total_out];

    return compressedData;
}

+ (int) deflateFileToFile:(FILE *)source dest:(FILE *)dest
{
    int ret, flush;
    unsigned have;
    z_stream strm;
    unsigned char *inB = malloc(CHUNK);
    unsigned char *outB = malloc(CHUNK);

    /* allocate deflate state */
    strm.zalloc = Z_NULL;
    strm.zfree = Z_NULL;
    strm.opaque = Z_NULL;
    ret = deflateInit2(&strm, Z_DEFAULT_COMPRESSION, Z_DEFLATED, (15+16), 8, Z_DEFAULT_STRATEGY);
    if (ret != Z_OK) {
        free(inB);
        free(outB);
        return ret;
    }

    /* compress until end of file */
    do {
        strm.avail_in = fread(inB, 1, CHUNK, source);
        if (ferror(source)) {
            (void)deflateEnd(&strm);
            free(inB);
            free(outB);
            return Z_ERRNO;
        }
        flush = feof(source) ? Z_FINISH : Z_NO_FLUSH;
        strm.next_in = inB;

        /* run deflate() on input until output buffer not full, finish
           compression if all of source has been read in */
        do {
            strm.avail_out = CHUNK;
            strm.next_out = outB;
            ret = deflate(&strm, flush);    /* no bad return value */
            assert(ret != Z_STREAM_ERROR);  /* state not clobbered */
            have = CHUNK - strm.avail_out;
            if (fwrite(outB, 1, have, dest) != have || ferror(dest)) {
                (void)deflateEnd(&strm);
                free(inB);
                free(outB);
                return Z_ERRNO;
            }
        } while (strm.avail_out == 0);
        assert(strm.avail_in == 0);     /* all input will be used */

        /* done when last data in file processed */
    } while (flush != Z_FINISH);
    assert(ret == Z_STREAM_END);        /* stream will be complete */

    /* clean up and return */
    (void)deflateEnd(&strm);
    free(inB);
    free(outB);
    return Z_OK;
}

+ (NSData*) gzipFile: (NSURL*)pFileUrl length:(long)length
{
    if (!pFileUrl || length == 0)
    {
        #if DEBUG
        NSLog(@"%s: Error: Can't compress an empty or null NSData object.", __func__);
        #endif
        return nil;
    }
    
    char *inFilename;
    char *outFilename;
    FILE *inFile;
    FILE *outFile;
    unsigned long fnl = [pFileUrl.path lengthOfBytesUsingEncoding:NSUTF8StringEncoding]  + 1;
    int deflateResult = 0;
    NSData *compressedData = nil;

    inFilename = malloc(fnl);
    outFilename = malloc(fnl + 32);
    bzero(inFilename, fnl);
    strcpy(inFilename, [pFileUrl.path cStringUsingEncoding:NSUTF8StringEncoding]);
    bzero(outFilename, fnl+32);
    strcpy(outFilename, inFilename);
    strcat(outFilename, ".out");
    
    inFile = fopen(inFilename, "r");
    outFile = fopen(outFilename, "wb");
    deflateResult = [DPAGHelper deflateFileToFile:inFile dest:outFile];
    fclose(outFile);
    fclose(inFile);

    if (deflateResult == Z_OK) {
        compressedData = [NSData dataWithContentsOfFile:[NSString stringWithCString:outFilename encoding:NSUTF8StringEncoding]];
        NSLog(@"CompressedData Length = %d", (unsigned long)[compressedData length]);
    }
    unlink(inFilename);
    unlink(outFilename);
    return compressedData;
}

@end

@implementation UILabel (PickerLabelTextColor)

- (UIColor *)textColorWorkaround {
    return self.textColor;
}

- (void)setTextColorWorkaround:(UIColor *)textColor {
    self.textColor = textColor;
}

@end
