// -----------------------------------------------------------------------------------------
// <copyright file="AZSCloudPageBlob.h" company="Microsoft">
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

@interface AZSCloudPageBlob : AZSCloudBlob

/** Initializes a newly allocated AZSCloudPageBlob object
 
 @param blobAbsoluteUrl The absolute URL to the blob.
 @return The newly allocated instance.
 */
- (instancetype)initWithUrl:(NSURL *)blobAbsoluteUrl error:(NSError **)error;

/** Initializes a newly allocated AZSCloudPageBlob object
 
 @param blobAbsoluteUrl The absolute URL to the blob.
 @param credentials The AZSStorageCredentials used to authenticate to the blob
 @param snapshotTime The timestamp of the intended snapshot.  If nil, this AZSCloudPageBlob object refers to the actual blob, not a snapshot.
 @return The newly allocated instance.
 */
- (instancetype)initWithUrl:(NSURL *)blobAbsoluteUrl credentials:(AZSNullable AZSStorageCredentials *)credentials snapshotTime:(AZSNullable NSString *)snapshotTime error:(NSError **)error;

/** Initializes a newly allocated AZSCloudPageBlob object
 
 @param blobAbsoluteUri The absolute URL to the blob.
 @return The newly allocated instance.
 */
- (instancetype)initWithStorageUri:(AZSStorageUri *)blobAbsoluteUri error:(NSError **)error;

/** Initializes a newly allocated AZSCloudPageBlob object
 
 @param blobAbsoluteUri The absolute URL to the blob.
 @param credentials The AZSStorageCredentials used to authenticate to the blob
 @param snapshotTime The timestamp of the intended snapshot.  If nil, this AZSCloudPageBlob object refers to the actual blob, not a snapshot.
 @return The newly allocated instance.
 */
- (instancetype)initWithStorageUri:(AZSStorageUri *)blobAbsoluteUri credentials:(AZSNullable AZSStorageCredentials *)credentials snapshotTime:(AZSNullable NSString *)snapshotTime error:(NSError **)error AZS_DESIGNATED_INITIALIZER;

/** Initializes a newly allocated AZSCloudPageBlob object
 
 @param blobContainer The AZSCloudBlobContainer in which the blob exists or should be created.
 @param blobName The name of the blob.
 @return The newly allocated instance.
 */
-(instancetype)initWithContainer:(AZSCloudBlobContainer *)blobContainer name:(NSString *)blobName;

/** Initializes a newly allocated AZSCloudPageBlob object
 
 @param blobContainer The AZSCloudBlobContainer in which the blob exists or should be created.
 @param blobName The name of the blob.
 @param snapshotTime The timestamp of the intended snapshot.  If nil, this AZSCloudPageBlob object refers to the actual blob, not a snapshot.
 @return The newly allocated instance.
 */
-(instancetype)initWithContainer:(AZSCloudBlobContainer *)blobContainer name:(NSString *)blobName snapshotTime:(AZSNullable NSString *)snapshotTime AZS_DESIGNATED_INITIALIZER;

/** Clears a set of bytes from the page blob.
 
 @param range The range of bytes to clear (set to all 0) from the page blob.  Note that this must be 512-byte aligned.
 Can be up to the full size of the blob.
 @param completionHandler The block of code to execute when the clear call completes.
 | Parameter name | Description |
 |----------------|-------------|
 |NSError * | Nil if the operation succeeded without error, error with details about the failure otherwise.|
*/
-(void)clearPagesWithRange:(NSRange)range completionHandler:(void (^)(NSError * __AZSNullable))completionHandler;

/** Clears a set of bytes from the page blob.
 
 @param range The range of bytes to clear (set to all 0) from the page blob.  Note that this must be 512-byte aligned.
 Can be up to the full size of the blob.
 @param accessCondition The access condition for the request.
 @param requestOptions The options to use for the request.
 @param operationContext The operation context to use for the call.
 @param completionHandler The block of code to execute when the clear call completes.
 | Parameter name | Description |
 |----------------|-------------|
 |NSError * | Nil if the operation succeeded without error, error with details about the failure otherwise.|
 */
-(void)clearPagesWithRange:(NSRange)range accessCondition:(AZSNullable AZSAccessCondition *)accessCondition requestOptions:(AZSNullable AZSBlobRequestOptions *)requestOptions operationContext:(AZSNullable AZSOperationContext *)operationContext completionHandler:(void (^)(NSError * __AZSNullable))completionHandler;

/** Downloads the non-clear page ranges from the blob.
 
 This method will query the page blob on the service, and download all page ranges that are non-zero (non-clear).
 If this method times out, consider breaking up the query into smaller ranges.
 
 @param completionHandler The block of code to execute when the query page ranges call completes.
 | Parameter name | Description |
 |----------------|-------------|
 |NSError * | Nil if the operation succeeded without error, error with details about the failure otherwise.|
 |NSArray * | The page ranges queried.  Each item in this array is of type NSValue*, which contains an NSRange.|
 */
-(void)downloadPageRangesWithCompletionHandler:(void (^)(NSError * __AZSNullable, NSArray *))completionHandler;

/** Downloads the non-clear page ranges from the blob.
  
 This method will query the page blob on the service, and download all page ranges in the input range that are non-zero (non-clear).
 If this method times out, consider breaking up the query into smaller ranges.
  
 @param range The range of the blob to query.
 @param completionHandler The block of code to execute when the query page ranges call completes.
 | Parameter name | Description |
 |----------------|-------------|
 |NSError * | Nil if the operation succeeded without error, error with details about the failure otherwise.|
 |NSArray * | The page ranges queried.  Each item in this array is of type NSValue*, which contains an NSRange.|
 */
-(void)downloadPageRangesWithRange:(NSRange)range completionHandler:(void (^)(NSError * __AZSNullable, NSArray *))completionHandler;

/** Downloads the non-clear page ranges from the blob.
 
 This method will query the page blob on the service, and download all page ranges in the input range that are non-zero (non-clear).
 If this method times out, consider breaking up the query into smaller ranges.
 
 @param range The range of the blob to query.
 @param accessCondition The access condition for the request.
 @param requestOptions The options to use for the request.
 @param operationContext The operation context to use for the call.
 @param completionHandler The block of code to execute when the query page ranges call completes.
 | Parameter name | Description |
 |----------------|-------------|
 |NSError * | Nil if the operation succeeded without error, error with details about the failure otherwise.|
 |NSArray * | The page ranges queried.  Each item in this array is of type NSValue*, which contains an NSRange.|
 */
-(void)downloadPageRangesWithRange:(NSRange)range accessCondition:(AZSNullable AZSAccessCondition *)accessCondition requestOptions:(AZSNullable AZSBlobRequestOptions *)requestOptions operationContext:(AZSNullable AZSOperationContext *)operationContext completionHandler:(void (^)(NSError * __AZSNullable, NSArray *))completionHandler;

/* Upload data to the page blob.
 
 @param data The data to upload.  Size must be less than 4MB, and a multiple of 512 bytes.
 @param startOffset The start offset at which to upload the data.  Must be a multiple of 512.
 @param contentMD5 Optional.  The content-MD5 to use for transactional integrety for the upload pages request.
 If contentMD5 is nil, and requestOptions.useTransactionalMD5 is set to YES, the library will calculate the MD5 of the block for you.
 This value is not stored on the service.
 @param completionHandler The block of code to execute when the upload pages call completes.
 | Parameter name | Description |
 |----------------|-------------|
 |NSError * | Nil if the operation succeeded without error, error with details about the failure otherwise.|
 */
-(void)uploadPagesWithData:(NSData *)data startOffset:(NSNumber *)startOffset contentMD5:(AZSNullable NSString  *)contentMD5 completionHandler:(void (^)(NSError * __AZSNullable))completionHandler;

/* Upload data to the page blob.
 
 @param data The data to upload.  Size must be less than 4MB, and a multiple of 512 bytes.
 @param startOffset The start offset at which to upload the data.  Must be a multiple of 512.
 @param contentMD5 Optional.  The content-MD5 to use for transactional integrety for the upload pages request.
 If contentMD5 is nil, and requestOptions.useTransactionalMD5 is set to YES, the library will calculate the MD5 of the block for you.
 This value is not stored on the service.
 @param accessCondition The access condition for the request.
 @param requestOptions The options to use for the request.
 @param operationContext The operation context to use for the call.
 @param completionHandler The block of code to execute when the upload pages call completes.
 | Parameter name | Description |
 |----------------|-------------|
 |NSError * | Nil if the operation succeeded without error, error with details about the failure otherwise.|
 */
-(void)uploadPagesWithData:(NSData *)data startOffset:(NSNumber *)startOffset contentMD5:(AZSNullable NSString *)contentMD5 accessCondition:(AZSNullable AZSAccessCondition *)accessCondition requestOptions:(AZSNullable AZSBlobRequestOptions *)requestOptions operationContext:(AZSNullable AZSOperationContext *)operationContext completionHandler:(void (^)(NSError * __AZSNullable))completionHandler;

/** Creates the page blob on the service.
 
 Unlike block blobs, page and append blobs must be explicitly created on the service before data can be written.
 This method does the creation.
 
 @param totalBlobSize The total size of the blob.  This must be known at creation time for page blobs.
 @param completionHandler The block of code to execute when the create call completes.
 | Parameter name | Description |
 |----------------|-------------|
 |NSError * | Nil if the operation succeeded without error, error with details about the failure otherwise.|
 */
-(void)createWithSize:(NSNumber *)totalBlobSize completionHandler:(void (^)(NSError * __AZSNullable))completionHandler;

/** Creates the page blob on the service.
 
 Unlike block blobs, page and append blobs must be explicitly created on the service before data can be written.
 This method does the creation.
 
 @param totalBlobSize The total size of the blob.  This must be known at creation time for page blobs.
 @param sequenceNumber The intiial sequence number for the blob.  If nil, a default value will be used.
 @param completionHandler The block of code to execute when the create call completes.
 | Parameter name | Description |
 |----------------|-------------|
 |NSError * | Nil if the operation succeeded without error, error with details about the failure otherwise.|
 */
-(void)createWithSize:(NSNumber *)totalBlobSize sequenceNumber:(AZSNullable NSNumber *)sequenceNumber completionHandler:(void (^)(NSError * __AZSNullable))completionHandler;

/** Creates the page blob on the service.
 
 Unlike block blobs, page and append blobs must be explicitly created on the service before data can be written.
 This method does the creation.
 
 @param totalBlobSize The total size of the blob.  This must be known at creation time for page blobs.
 @param sequenceNumber The intiial sequence number for the blob.  If nil, a default value will be used.
 @param accessCondition The access condition for the request.
 @param requestOptions The options to use for the request.
 @param operationContext The operation context to use for the call.
 @param completionHandler The block of code to execute when the create call completes.
 | Parameter name | Description |
 |----------------|-------------|
 |NSError * | Nil if the operation succeeded without error, error with details about the failure otherwise.|
 */
-(void)createWithSize:(NSNumber *)totalBlobSize sequenceNumber:(AZSNullable NSNumber *)sequenceNumber accessCondition:(AZSNullable AZSAccessCondition *)accessCondition requestOptions:(AZSNullable AZSBlobRequestOptions *)requestOptions operationContext:(AZSNullable AZSOperationContext *)operationContext completionHandler:(void (^)(NSError * __AZSNullable))completionHandler;

/** Creates the page blob on the service if it does not already exist.
 
 Unlike block blobs, page and append blobs must be explicitly created on the service before data can be written.
 This method does the creation.
 
 @param totalBlobSize The total size of the blob.  This must be known at creation time for page blobs.
 @param completionHandler The block of code to execute when the create call completes.
 | Parameter name | Description |
 |----------------|-------------|
 |NSError * | Nil if the operation succeeded without error, error with details about the failure otherwise.|
 |BOOL | YES if the blob was successfully created with this call.  NO if the blob already existed.|
 */
-(void)createIfNotExistsWithSize:(NSNumber *)totalBlobSize completionHandler:(void (^)(NSError * __AZSNullable, BOOL))completionHandler;

/** Creates the page blob on the service if it does not already exist.
 
 Unlike block blobs, page and append blobs must be explicitly created on the service before data can be written.
 This method does the creation.
 
 @param totalBlobSize The total size of the blob.  This must be known at creation time for page blobs.
 @param sequenceNumber The intiial sequence number for the blob.  If nil, a default value will be used.
 @param completionHandler The block of code to execute when the create call completes.
 | Parameter name | Description |
 |----------------|-------------|
 |NSError * | Nil if the operation succeeded without error, error with details about the failure otherwise.|
 |BOOL | YES if the blob was successfully created with this call.  NO if the blob already existed.|
 */
-(void)createIfNotExistsWithSize:(NSNumber *)totalBlobSize sequenceNumber:(AZSNullable NSNumber *)sequenceNumber completionHandler:(void (^)(NSError * __AZSNullable, BOOL))completionHandler;

/** Creates the page blob on the service if it does not already exist.
 
 Unlike block blobs, page and append blobs must be explicitly created on the service before data can be written.
 This method does the creation.
 
 @param totalBlobSize The total size of the blob.  This must be known at creation time for page blobs.
 @param sequenceNumber The intiial sequence number for the blob.  If nil, a default value will be used.
 @param accessCondition The access condition for the request.
 @param requestOptions The options to use for the request.
 @param operationContext The operation context to use for the call.
 @param completionHandler The block of code to execute when the create call completes.
 | Parameter name | Description |
 |----------------|-------------|
 |NSError * | Nil if the operation succeeded without error, error with details about the failure otherwise.|
 |BOOL | YES if the blob was successfully created with this call.  NO if the blob already existed.|
 */
-(void)createIfNotExistsWithSize:(NSNumber *)totalBlobSize sequenceNumber:(AZSNullable NSNumber *)sequenceNumber accessCondition:(AZSNullable AZSAccessCondition *)accessCondition requestOptions:(AZSNullable AZSBlobRequestOptions *)requestOptions operationContext:(AZSNullable AZSOperationContext *)operationContext completionHandler:(void (^)(NSError * __AZSNullable, BOOL))completionHandler;

/** Sets the total blob size.
 
 If the new size is less than the old size, the blob will be truncated.
 
 @param totalBlobSize The new blob size.
 @param completionHandler The block of code to execute when the resize call completes.
 | Parameter name | Description |
 |----------------|-------------|
 |NSError * | Nil if the operation succeeded without error, error with details about the failure otherwise.|
 */
-(void)resizeWithSize:(NSNumber *)totalBlobSize completionHandler:(void (^)(NSError * __AZSNullable))completionHandler;

/** Sets the total blob size.
 
 If the new size is less than the old size, the blob will be truncated.
 
 @param totalBlobSize The new blob size.
 @param accessCondition The access condition for the request.
 @param requestOptions The options to use for the request.
 @param operationContext The operation context to use for the call.
 @param completionHandler The block of code to execute when the resize call completes.
 | Parameter name | Description |
 |----------------|-------------|
 |NSError * | Nil if the operation succeeded without error, error with details about the failure otherwise.|
 */
-(void)resizeWithSize:(NSNumber *)totalBlobSize accessCondition:(AZSNullable AZSAccessCondition *)accessCondition requestOptions:(AZSNullable AZSBlobRequestOptions *)requestOptions operationContext:(AZSNullable AZSOperationContext *)operationContext completionHandler:(void (^)(NSError * __AZSNullable))completionHandler;

/** Increments the sequence number of the page blob on the service.
 
 @param completionHandler The block of code to execute when the increment call completes.
 | Parameter name | Description |
 |----------------|-------------|
 |NSError * | Nil if the operation succeeded without error, error with details about the failure otherwise.|
 */
-(void)incrementSequenceNumberWithCompletionHandler:(void (^)(NSError * __AZSNullable))completionHandler;

/** Increments the sequence number of the page blob on the service.
 
 @param completionHandler The block of code to execute when the increment call completes.
 @param accessCondition The access condition for the request.
 @param requestOptions The options to use for the request.
 @param operationContext The operation context to use for the call.
 @param completionHandler The block of code to execute when the increment call completes.
 | Parameter name | Description |
 |----------------|-------------|
 |NSError * | Nil if the operation succeeded without error, error with details about the failure otherwise.|
 */
-(void)incrementSequenceNumberWithAccessCondition:(AZSNullable AZSAccessCondition *)accessCondition requestOptions:(AZSNullable AZSBlobRequestOptions *)requestOptions operationContext:(AZSNullable AZSOperationContext *)operationContext completionHandler:(void (^)(NSError * __AZSNullable))completionHandler;

/** Sets the sequence number of the page blob on the service.
 
 @param newSequenceNumber The sequence number to set the blob to.
 @param useMaximum If YES, this method will set the sequence number to the larger of its existing value, and the input value.  If NO, the blob will get the new value, regardless of existing value.
 @param operationContext The operation context to use for the call.
 @param completionHandler The block of code to execute when the set sequence number call completes.
 | Parameter name | Description |
 |----------------|-------------|
 |NSError * | Nil if the operation succeeded without error, error with details about the failure otherwise.|
*/
-(void)setSequenceNumberWithNumber:(NSNumber *)newSequenceNumber useMaximum:(BOOL)useMaximum completionHandler:(void (^)(NSError * __AZSNullable))completionHandler;

/** Sets the sequence number of the page blob on the service.
 
 @param newSequenceNumber The sequence number to set the blob to.
 @param useMaximum If YES, this method will set the sequence number to the larger of its existing value, and the input value.  If NO, the blob will get the new value, regardless of existing value.
 @param operationContext The operation context to use for the call.
 @param completionHandler The block of code to execute when the set sequence number call completes.
 | Parameter name | Description |
 |----------------|-------------|
 |NSError * | Nil if the operation succeeded without error, error with details about the failure otherwise.|
 */
-(void)setSequenceNumberWithNumber:(NSNumber *)newSequenceNumber useMaximum:(BOOL)useMaximum accessCondition:(AZSNullable AZSAccessCondition *)accessCondition requestOptions:(AZSNullable AZSBlobRequestOptions *)requestOptions operationContext:(AZSNullable AZSOperationContext *)operationContext completionHandler:(void (^)(NSError * __AZSNullable))completionHandler;

@end

AZS_ASSUME_NONNULL_END