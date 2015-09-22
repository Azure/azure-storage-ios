// -----------------------------------------------------------------------------------------
// <copyright file="AZSBlobUploadHelper.h" company="Microsoft">
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

// This class is reserved for internal use.
@interface AZSBlobUploadHelper : NSObject <NSStreamDelegate>

@property (strong) AZSOperationContext *operationContext;
@property (strong) NSError *streamingError;

-(instancetype)initToBlockBlob:(AZSCloudBlockBlob *)blockBlob accessCondition:(AZSNullable AZSAccessCondition *)accessCondition requestOptions:(AZSNullable AZSBlobRequestOptions *)requestOptions operationContext:(AZSNullable AZSOperationContext *)operationContext completionHandler:(void (^)(NSError* __AZSNullable))completionHandler AZS_DESIGNATED_INITIALIZER;
-(NSInteger)write:(const uint8_t *)buffer maxLength:(NSUInteger)length completionHandler:(void(^)())completionHandler;
-(BOOL)closeWithCompletionHandler:(void(^)())completionHandler;
-(BOOL)hasSpaceAvailable;
-(BOOL)allBlocksUploaded;
-(void)stream:(NSStream *)stream handleEvent:(NSStreamEvent)eventCode;

@end

AZS_ASSUME_NONNULL_END