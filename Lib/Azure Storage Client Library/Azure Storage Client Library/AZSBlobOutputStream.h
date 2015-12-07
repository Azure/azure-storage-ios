// -----------------------------------------------------------------------------------------
// <copyright file="AZSBlobOutputStream.h" company="Microsoft">
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

#import <Foundation/Foundation.h>
#import "AZSMacros.h"

AZS_ASSUME_NONNULL_BEGIN

@class AZSCloudBlockBlob;
@class AZSAccessCondition;
@class AZSBlobRequestOptions;
@class AZSOperationContext;

/** An AZSBlobOutputStream is used to write data to a blob on the service.
 
 The AZSBlobOutputStream class inherits from NSOutputStream, and is designed to be used similarly.
 To create an AZSBlobOutputStream instance, call the createOutputStream method on an instance of 
 AZSCloudBlockBlob.  Just like a regular output stream, you can set a delegate to be called on stream 
 events, and then schedule the stream in a runloop.  See https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/Streams/Streams.html
 for more details about how to use streams.
 
 Internally, the AZSBlobOutputStream will buffer data that's written to it until it has buffered one
 block's worth of data.  (Currently, block size is hard-coded to 4 MB; this will soon be configurable.)
 That block will then be asynchronously committed to the service while more data is being buffered.
 To protect against usign too much network bandwidth at a time, there is a hard-coded maximum to 
 how many uploads are outstanding at once (currently 3, this will soon be configurable.)
 
 When close is called on the stream, the stream will commit any remaining data, and then commit the block list
 it has been building.
 
 @warning Using a AZSBlobOutputStream will overwrite any existing data in the blob.
 @warning The call to close the stream will block until all uploads are complete and the block list has been committed.  As
 network operations, this make take a significant amount of time.  Do not call close on a critical thread.
 @bug Currently, if there are too many outstanding block uploads, a call to write will block.  This is a known
 issue.
 */
@interface AZSBlobOutputStream : NSOutputStream <NSStreamDelegate>

// NSStream methods and properties:
@property (assign, AZSNullable) id<NSStreamDelegate> delegate;
@property (readonly) NSStreamStatus streamStatus;
@property (readonly, copy, AZSNullable) NSError *streamError;

-(void)open;

// Potential problem - this method will *block* until all blocks have successfully been uploaded, and the block list is successfully uploaded.
-(void)close;

-(void)scheduleInRunLoop:(NSRunLoop *)runLoop forMode:(NSString *)mode;
-(void)removeFromRunLoop:(NSRunLoop *)runLoop forMode:(NSString *)mode;

-(AZSNullable id)propertyForKey:(NSString *)key;
-(BOOL)setProperty:(AZSNullable id)property forKey:(NSString *)key;

// NSOutputStream methods and properties:
@property(readonly) BOOL hasSpaceAvailable;

-(NSInteger)write:(const uint8_t *)buffer maxLength:(NSUInteger)length;

// NSStreamDelegate:
- (void)stream:(NSStream *)stream handleEvent:(NSStreamEvent)eventCode;

// Specific blob methods:
-(instancetype)initToBlockBlob:(AZSCloudBlockBlob *)blockBlob accessCondition:(AZSNullable AZSAccessCondition *)accessCondition requestOptions:(AZSNullable AZSBlobRequestOptions *)requestOptions operationContext:(AZSNullable AZSOperationContext *)operationContext AZS_DESIGNATED_INITIALIZER;

@end

AZS_ASSUME_NONNULL_END
