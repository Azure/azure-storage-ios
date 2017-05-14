// -----------------------------------------------------------------------------------------
// <copyright file="AZSStreamDownloadBuffer.h" company="Microsoft">
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

#import <CommonCrypto/CommonDigest.h>
@class AZSOperationContext;

@interface AZSStreamDownloadBuffer : NSObject <NSStreamDelegate>

@property BOOL calculateMD5;
@property NSUInteger currentLength;
@property (strong, readonly) NSCondition *dataDownloadCondition;
@property (strong, readonly) AZSOperationContext *operationContext;
@property (strong) NSError *streamError;
@property BOOL streamClosed;
@property (readonly) uint64_t totalSizeStreamed;
@property BOOL downloadComplete;

-(instancetype)initWithInputStream:(NSInputStream *)stream maxSizeToBuffer:(NSUInteger)maxSizeToBuffer calculateMD5:(BOOL)calculateMD5 runLoopForDownload:(NSRunLoop *)runLoop operationContext:(AZSOperationContext *)operationContext fireEventBlock:(void(^)())fireEventBlock;
-(instancetype)initWithOutputStream:(NSOutputStream *)stream maxSizeToBuffer:(NSUInteger)maxSizeToBuffer calculateMD5:(BOOL)calculateMD5 runLoopForDownload:(NSRunLoop *)runLoop operationContext:(AZSOperationContext *)operationContext;
-(void)stream:(NSStream *)stream handleEvent:(NSStreamEvent)eventCode;
-(void)processDataWithProcess:(long(^)(uint8_t *, long))process;
-(void)writeData:(NSData *)data;
-(void)createAndSpinRunloop;
-(void)removeFromRunLoop;
-(NSString *)checkMD5;

@end