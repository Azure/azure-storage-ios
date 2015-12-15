// -----------------------------------------------------------------------------------------
// <copyright file="AZSCloudAppendBlob.h" company="Microsoft">
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
#import "AZSCloudBlob.h"

AZS_ASSUME_NONNULL_BEGIN

@interface AZSCloudAppendBlob : AZSCloudBlob

/** Initializes a newly allocated AZSCloudAppendBlob object
 
 @param blobAbsoluteUrl The absolute URL to the blob.
 @return The newly allocated instance.
 */
- (instancetype)initWithUrl:(NSURL *)blobAbsoluteUrl error:(NSError **)error;

/** Initializes a newly allocated AZSCloudAppendBlob object
 
 @param blobAbsoluteUrl The absolute URL to the blob.
 @param credentials The AZSStorageCredentials used to authenticate to the blob
 @param snapshotTime The timestamp of the intended snapshot.  If nil, this AZSCloudAppendBlob object refers to the actual blob, not a snapshot.
 @return The newly allocated instance.
 */
- (instancetype)initWithUrl:(NSURL *)blobAbsoluteUrl credentials:(AZSNullable AZSStorageCredentials *)credentials snapshotTime:(AZSNullable NSString *)snapshotTime error:(NSError **)error;

/** Initializes a newly allocated AZSCloudAppendBlob object
 
 @param blobAbsoluteUri An AZSStorageUri representing the absolute URL to the blob.
 @return The newly allocated instance.
 */
- (instancetype)initWithStorageUri:(AZSStorageUri *)blobAbsoluteUri error:(NSError **)error;

/** Initializes a newly allocated AZSCloudAppendBlob object
 
 @param blobAbsoluteUri An AZSStorageUri representing the absolute URL to the blob.
 @param credentials The AZSStorageCredentials used to authenticate to the blob
 @param snapshotTime The timestamp of the intended snapshot.  If nil, this AZSCloudAppendBlob object refers to the actual blob, not a snapshot.
 @return The newly allocated instance.
 */
- (instancetype)initWithStorageUri:(AZSStorageUri *)blobAbsoluteUri credentials:(AZSNullable AZSStorageCredentials *)credentials snapshotTime:(AZSNullable NSString *)snapshotTime error:(NSError **)error AZS_DESIGNATED_INITIALIZER;

/** Initializes a newly allocated AZSCloudAppendBlob object
 
 @param blobContainer The AZSCloudBlobContainer in which the blob exists or should be created.
 @param blobName The name of the blob.
 @return The newly allocated instance.
 */
-(instancetype)initWithContainer:(AZSCloudBlobContainer *)blobContainer name:(NSString *)blobName;

/** Initializes a newly allocated AZSCloudAppendBlob object
 
 @param blobContainer The AZSCloudBlobContainer in which the blob exists or should be created.
 @param blobName The name of the blob.
 @param snapshotTime The timestamp of the intended snapshot.  If nil, this AZSCloudAppendBlob object refers to the actual blob, not a snapshot.
 @return The newly allocated instance.
 */
-(instancetype)initWithContainer:(AZSCloudBlobContainer *)blobContainer name:(NSString *)blobName snapshotTime:(AZSNullable NSString *)snapshotTime AZS_DESIGNATED_INITIALIZER;

/** Creates the append blob on the service.
 
 Unlike block blobs, append blobs must be explicitly created on the service before data can be written.
 This method does the creation.
 
 @param completionHandler The block of code to execute when the delete call completes.
 | Parameter name | Description |
 |----------------|-------------|
 |NSError * | Nil if the operation succeeded without error, error with details about the failure otherwise.|
 */
-(void)createWithCompletionHandler:(void (^)(NSError * __AZSNullable))completionHandler;

/** Creates the append blob on the service.
 
 Unlike block blobs, append blobs must be explicitly created on the service before data can be written.
 This method does the creation.
 
 @param accessCondition The access condition for the request.
 @param requestOptions The options to use for the request.
 @param operationContext The operation context to use for the call.
 @param completionHandler The block of code to execute when the delete call completes.
 | Parameter name | Description |
 |----------------|-------------|
 |NSError * | Nil if the operation succeeded without error, error with details about the failure otherwise.|
 */
-(void)createWithAccessCondition:(AZSNullable AZSAccessCondition *)accessCondition requestOptions:(AZSNullable AZSBlobRequestOptions *)requestOptions operationContext:(AZSNullable AZSOperationContext *)operationContext completionHandler:(void (^)(NSError * __AZSNullable))completionHandler;

/** Creates the append blob on the service if it does not already exist.
 
 Unlike block blobs, append blobs must be explicitly created on the service before data can be written.
 This method does the creation.
 
 @param completionHandler The block of code to execute when the delete call completes.
 | Parameter name | Description |
 |----------------|-------------|
 |NSError * | Nil if the operation succeeded without error, error with details about the failure otherwise.|
 |BOOL | YES if the blob was successfully created with this call.  NO if the blob already existed.|
 */
-(void)createIfNotExistsWithCompletionHandler:(void (^)(NSError * __AZSNullable, BOOL))completionHandler;

/** Creates the append blob on the service if it does not already exist.
 
 Unlike block blobs, append blobs must be explicitly created on the service before data can be written.
 This method does the creation.
 
 @param accessCondition The access condition for the request.
 @param requestOptions The options to use for the request.
 @param operationContext The operation context to use for the call.
 @param completionHandler The block of code to execute when the delete call completes.
 | Parameter name | Description |
 |----------------|-------------|
 |NSError * | Nil if the operation succeeded without error, error with details about the failure otherwise.|
 |BOOL | YES if the blob was successfully created with this call.  NO if the blob already existed.|
 */
-(void)createIfNotExistsWithAccessCondition:(AZSNullable AZSAccessCondition *)accessCondition requestOptions:(AZSNullable AZSBlobRequestOptions *)requestOptions operationContext:(AZSNullable AZSOperationContext *)operationContext completionHandler:(void (^)(NSError * __AZSNullable, BOOL))completionHandler;

/** Appends a block of data to the append blob.
 
 @param blockData The data to append.  Must be less than 4 MB.
 @param contentMD5 Optional.  The content-MD5 to use for transactional integrety for the appendBlock request.
 If contentMD5 is nil, and requestOptions.useTransactionalMD5 is set to YES, the library will calculate the MD5 of the block for you.
 This value is not stored on the service.
 @param completionHandler The block of code to execute when the append call completes.
 | Parameter name | Description |
 |----------------|-------------|
 |NSError * | Nil if the operation succeeded without error, error with details about the failure otherwise.|
 |NSNumber * | The append offset for this append operation - the offset where this block was committed|
 */
-(void)appendBlockWithData:(NSData *)blockData contentMD5:(AZSNullable NSString *)contentMD5 completionHandler:(void (^)(NSError * __AZSNullable, NSNumber *appendOffset))completionHandler;

/** Appends a block of data to the append blob.
 
 @param blockData The data to append.  Must be less than 4 MB.
 @param contentMD5 Optional.  The content-MD5 to use for transactional integrety for the appendBlock request.
 If contentMD5 is nil, and requestOptions.useTransactionalMD5 is set to YES, the library will calculate the MD5 of the block for you.
 This value is not stored on the service.
 @param accessCondition The access condition for the request.
 @param requestOptions The options to use for the request.
 @param operationContext The operation context to use for the call.
 @param completionHandler The block of code to execute when the append call completes.
 | Parameter name | Description |
 |----------------|-------------|
 |NSError * | Nil if the operation succeeded without error, error with details about the failure otherwise.|
 |NSNumber * | The append offset for this append operation - the offset where this block was committed|
 */
-(void)appendBlockWithData:(NSData *)blockData contentMD5:(AZSNullable NSString *)contentMD5 accessCondition:(AZSNullable AZSAccessCondition *)accessCondition requestOptions:(AZSNullable AZSBlobRequestOptions *)requestOptions operationContext:(AZSNullable AZSOperationContext *)operationContext completionHandler:(void (^)(NSError * __AZSNullable, NSNumber *appendOffset))completionHandler;

@end

AZS_ASSUME_NONNULL_END