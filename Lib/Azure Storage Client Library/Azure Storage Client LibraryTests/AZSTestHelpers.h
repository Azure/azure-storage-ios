// -----------------------------------------------------------------------------------------
// <copyright file="AZSTestHelpers.h" company="Microsoft">
//    Copyright 2015 Microsoft Corporation
//
//    Licensed under the MIT License;
//    you may not use this file except in compliance with the License.
//    You may obtain a copy of the License at
//      http://spdx.org/licenses/MIT
//
//    Unless required by applicable law or agreed to in writing, software
//    distributed under the License is distributed on an "AS IS" BASIS,
//    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//    See the License for the specific language governing permissions and
//    limitations under the License.
// </copyright>
// -----------------------------------------------------------------------------------------

#import <XCTest/XCTest.h>
#import "AZSTestBase.h"
#import "AZSEnums.h"

@class AZSContinuationToken;

@interface AZSTestHelpers : AZSTestBase

+(NSString *)uniqueName;

+(NSMutableData *)generateSampleDataWithSeed:(unsigned int *)seed length:(unsigned int)length;
+(void)listAllInDirectoryOrContainer:(NSObject *)objectToList useFlatBlobListing:(BOOL)useFlatBlobListing blobArrayToPopulate:(NSMutableArray *)blobArrayToPopulate directoryArrayToPopulate:(NSMutableArray *)directoryArrayToPopulate continuationToken:(AZSContinuationToken *)continuationToken prefix:(NSString *)prefix blobListingDetails:(AZSBlobListingDetails)blobListingDetails maxResults:(NSUInteger)maxResults completionHandler:(void (^)(NSError *))completionHandler;

@end

@interface AZSUIntegerHolder : NSObject
{
@public
    unsigned int number;
}

-(instancetype)initWithNumber:(unsigned int)number;

@end


@interface AZSByteValidationStream : NSStream <NSStreamDelegate>

@property BOOL dataCorrupt;
@property BOOL streamFailed;
@property BOOL downloadComplete;
@property NSUInteger totalBytes;
@property NSUInteger errorCount;
@property long bytesRead;
@property long bytesWritten;
@property NSMutableString *errors;
@property(strong) void(^failBlock)(NSString *);

// NSStream methods and properties:
@property(assign) id<NSStreamDelegate> delegate;
@property(readonly) NSStreamStatus streamStatus;
@property(readonly, copy) NSError *streamError;
@property(strong) void(^errorBlock)();

-(void)open;

// Potential problem - this method will *block* until all blocks have successfully been uploaded, and the block list is successfully uploaded.
-(void)close;

-(void)scheduleInRunLoop:(NSRunLoop *)runLoop forMode:(NSString *)mode;
-(void)removeFromRunLoop:(NSRunLoop *)runLoop forMode:(NSString *)mode;

-(id)propertyForKey:(NSString *)key;
-(BOOL)setProperty:(id)property forKey:(NSString *)key;

// NSOutputStream methods and properties:
@property(readonly) BOOL hasSpaceAvailable;

-(NSInteger)write:(const uint8_t *)buffer maxLength:(NSUInteger)length;

// NSInputStream methods and properties:
@property(readonly) BOOL hasBytesAvailable;

-(NSInteger)read:(uint8_t *)buffer maxLength:(NSUInteger)length;
-(BOOL)getBuffer:(uint8_t **)buffer length:(NSUInteger *)len;

-(instancetype)initWithRandomSeed:(unsigned int)seed totalBlobSize:(NSUInteger)totalBlobSize isUpload:(BOOL)isUpload failBlock:(void(^)())failBlock;
-(instancetype)init;

@end