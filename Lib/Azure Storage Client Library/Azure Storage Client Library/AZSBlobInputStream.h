// -----------------------------------------------------------------------------------------
// <copyright file="AZSBlobInputStream.h" company="Microsoft">
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

@class AZSCloudBlob;
@class AZSAccessCondition;
@class AZSBlobRequestOptions;
@class AZSStreamDownloadBuffer;
@class AZSOperationContext;

/** An AZSBlobInputStream is used to read data from a blob on the service.
 
 The AZSBlobInputStream class inherits from NSInputStream, and is designed to be used similarly.
 To create an AZSBlobInputStream instance, call the createInputStream method on an instance of AZSCloudBlob.
 Just like a regular Input stream, you can set a delegate to be called on stream events, and then schedule the stream in a runloop.
 See https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/Streams/Streams.html for more details about how to use streams.
 */
@interface AZSBlobInputStream : NSInputStream <NSStreamDelegate>

-(instancetype)initWithBlob:(AZSCloudBlob *)blob accessCondition:(AZSAccessCondition *)accessCondition requestOptions:(AZSNullable AZSBlobRequestOptions *)requestOptions operationContext:(AZSOperationContext *)operationContext AZS_DESIGNATED_INITIALIZER;

// NSStream methods and properties:
@property (readonly) NSStreamStatus streamStatus;
@property (readonly, copy, AZSNullable) NSError *streamError;
@property (assign, AZSNullable) id<NSStreamDelegate> delegate;
@property (strong, readonly) AZSStreamDownloadBuffer *downloadBuffer;

-(void)open;
-(void)close;

-(AZSNullable id)propertyForKey:(NSString *)key;
-(BOOL)setProperty:(AZSNullable id)property forKey:(NSString *)key;

-(void)scheduleInRunLoop:(NSRunLoop *)runLoop forMode:(NSString *)mode;
-(void)removeFromRunLoop:(NSRunLoop *)runLoop forMode:(NSString *)mode;

// NSInputStream methods and properties:
@property (readonly) BOOL hasBytesAvailable;

-(NSInteger)read:(uint8_t *)buffer maxLength:(NSUInteger)length;
-(BOOL)getBuffer:(uint8_t * __AZSNullable * __nonnull)buffer length:(NSUInteger *)length;

@end

AZS_ASSUME_NONNULL_END