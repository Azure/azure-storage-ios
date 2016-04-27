// -----------------------------------------------------------------------------------------
// <copyright file="AZSCloudBlockBlob.h" company="Microsoft">
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

@class AZSCopyState;
@class AZSBlobProperties;
@class AZSCloudBlobContainer;
@class AZSCloudBlobClient;
@class AZSBlobOutputStream;

AZS_ASSUME_NONNULL_BEGIN

/** The AZSCloudBlockBlob represents a block blob in Azure Storage.
 
 The AZSCloudBlockBlob is used to perform blob-level operations on block blobs, including uploading, retrieving, and deleting.
 */
@interface AZSCloudBlockBlob : AZSCloudBlob

/** Uploades a blob from given source stream.
 
 This operation will schedule the input sourceStream on a runloop (created in a new thread), and read in all data as long as it is able.  This will
 chunk the data into blocks, and upload each of those blocks to the service.  Finally, when the stream is finished, it will upload a block list
 consisting of all read data.
 
 No more than one block's worth of data will be uploaded at a time.  Block size is configurable in the AZSBlobRequestOptions (see – uploadFromStream:accessCondition:requestOptions:operationContext:completionHandler:).  Maximum
 number of outstanding downloads is also configurable in the AZSBlobRequestOptions.
 
 @param sourceStream The stream containing the data that the blob should contain.
 @param completionHandler The block of code to execute when the upload call completes.
 
 | Parameter name | Description |
 |----------------|-------------|
 |NSError * | Nil if the operation succeeded without error, error with details about the failure otherwise.|
 */
-(void)uploadFromStream:(NSInputStream *)sourceStream completionHandler:(void (^)(NSError* __AZSNullable))completionHandler;

/** Uploades a blob from given source stream.
 
 This operation will schedule the input sourceStream on a runloop (created in a new thread), and read in all data as long as it is able.  This will
 chunk the data into blocks, and upload each of those blocks to the service.  Finally, when the stream is finished, it will upload a block list
 consisting of all read data.
 
 No more than one block's worth of data will be uploaded at a time.  Block size is configurable in the AZSBlobRequestOptions.  Maximum
 number of outstanding downloads is also configurable in the AZSBlobRequestOptions.
 
 @param sourceStream The stream containing the data that the blob should contain.
 @param accessCondition The access condition for the request.
 @param requestOptions The options to use for the request.
 @param operationContext The operation context to use for the call.
 @param completionHandler The block of code to execute when the upload call completes.
 
 | Parameter name | Description |
 |----------------|-------------|
 |NSError * | Nil if the operation succeeded without error, error with details about the failure otherwise.|
 */
-(void)uploadFromStream:(NSInputStream *)sourceStream accessCondition:(AZSNullable AZSAccessCondition *)accessCondition requestOptions:(AZSNullable AZSBlobRequestOptions *)requestOptions operationContext:(AZSNullable AZSOperationContext *)operationContext completionHandler:(void (^)(NSError* __AZSNullable))completionHandler;

/** Initializes a newly allocated AZSCloudBlockBlob object
 
 @param blobAbsoluteUrl The absolute URL to the blob.
 @param error A pointer to a NSError*, to be set in the event of failure.
 @return The newly allocated instance.
 */
- (instancetype)initWithUrl:(NSURL *)blobAbsoluteUrl error:(NSError **)error;

/** Initializes a newly allocated AZSCloudBlockBlob object
 
 @param blobAbsoluteUrl The absolute URL to the blob.
 @param credentials The AZSStorageCredentials used to authenticate to the blob
 @param snapshotTime The timestamp of the intended snapshot. If nil, this AZSCloudBlockBlob object refers to the actual blob, not a snapshot.
 @param error A pointer to a NSError*, to be set in the event of failure.
 @return The newly allocated instance.
 */
- (instancetype)initWithUrl:(NSURL *)blobAbsoluteUrl credentials:(AZSNullable AZSStorageCredentials *)credentials snapshotTime:(AZSNullable NSString *)snapshotTime error:(NSError **)error;

/** Initializes a newly allocated AZSCloudBlockBlob object
 
 @param blobAbsoluteUri The absolute URL to the blob.
 @param error A pointer to a NSError*, to be set in the event of failure.
 @return The newly allocated instance.
 */
- (instancetype)initWithStorageUri:(AZSStorageUri *)blobAbsoluteUri error:(NSError **)error;

/** Initializes a newly allocated AZSCloudBlockBlob object
 
 @param blobAbsoluteUri The absolute URL to the blob.
 @param credentials The AZSStorageCredentials used to authenticate to the blob
 @param snapshotTime The timestamp of the intended snapshot. If nil, this AZSCloudBlockBlob object refers to the actual blob, not a snapshot.
 @param error A pointer to a NSError*, to be set in the event of failure.
 @return The newly allocated instance.
 */
- (instancetype)initWithStorageUri:(AZSStorageUri *)blobAbsoluteUri credentials:(AZSNullable AZSStorageCredentials *)credentials snapshotTime:(AZSNullable NSString *)snapshotTime error:(NSError **)error AZS_DESIGNATED_INITIALIZER;

/** Initializes a newly allocated AZSCloudBlockBlob object
 
 @param blobContainer The AZSCloudBlobContainer in which the blob exists or should be created.
 @param blobName The name of the blob.
 @return The newly allocated instance.
 */
-(instancetype)initWithContainer:(AZSCloudBlobContainer *)blobContainer name:(NSString *)blobName;

/** Initializes a newly allocated AZSCloudBlockBlob object
 
 @param blobContainer The AZSCloudBlobContainer in which the blob exists or should be created.
 @param blobName The name of the blob.
 @param snapshotTime The timestamp of the intended snapshot.  If nil, this AZSCloudBlockBlob object refers to the actual blob, not a snapshot.
 @return The newly allocated instance.
 */
-(instancetype)initWithContainer:(AZSCloudBlobContainer *)blobContainer name:(NSString *)blobName snapshotTime:(AZSNullable NSString *)snapshotTime AZS_DESIGNATED_INITIALIZER;

/** Uploads a blob from given source data.
 
 UploadFromData uploads all data in the input NSData to the blob on the service.  This operation will overwrite any data
 already in the blob on the service, unless protected with an appropriate AZSAccessCondition.
 
 @param sourceData The data that the blob should contain.
 @param completionHandler The block of code to execute when the upload call completes.
 
 | Parameter name | Description |
 |----------------|-------------|
 |NSError * | Nil if the operation succeeded without error, error with details about the failure otherwise.|
 */
-(void)uploadFromData:(NSData *)sourceData completionHandler:(void (^)(NSError* AZSNullable))completionHandler;

/** Uploads a blob from given source data.
 
 UploadFromData uploads all data in the input NSData to the blob on the service.  This operation will overwrite any data
 already in the blob on the service, unless protected with an appropriate AZSAccessCondition.
 
 @param sourceData The data that the blob should contain.
 @param accessCondition The access condition for the request.
 @param requestOptions The options to use for the request.
 @param operationContext The operation context to use for the call.
 @param completionHandler The block of code to execute when the upload call completes.
 
 | Parameter name | Description |
 |----------------|-------------|
 |NSError * | Nil if the operation succeeded without error, error with details about the failure otherwise.|
 */
-(void)uploadFromData:(NSData *)sourceData accessCondition:(AZSNullable AZSAccessCondition *)accessCondition requestOptions:(AZSNullable AZSBlobRequestOptions *)requestOptions operationContext:(AZSNullable AZSOperationContext *)operationContext completionHandler:(void (^)(NSError* __AZSNullable))completionHandler;

/** Uploads a single block from given source data.
 
 This operation uploads one block of data to the blob in the Storage Service.  The block will remain uncommitted (meaning the data will not
 be considered part of the blob) until a corresponding uploadBlockList call.
 
 Note that all blocks in a given blob must have the same length Block ID.
 
 @param sourceData The data that the blob should contain.
 @param blockID The base64-encoded string identifying the block.
 @param completionHandler The block of code to execute when the upload call completes.
 
 | Parameter name | Description |
 |----------------|-------------|
 |NSError * | Nil if the operation succeeded without error, error with details about the failure otherwise.|
 */
-(void)uploadBlockFromData:(NSData *)sourceData blockID:(NSString *)blockID completionHandler:(void (^)(NSError* __AZSNullable))completionHandler;


/** Uploads a single block from given source data.
 
 This operation uploads one block of data to the blob in the Storage Service.  The block will remain uncommitted (meaning the data will not 
 be considered part of the blob) until a corresponding uploadBlockList call.
 
 Note that all blocks in a given blob must have the same length Block ID.
 
 @param sourceData The data that the blob should contain.
 @param blockID The base64-encoded string identifying the block.
 @param contentMD5 Optional.  The content-MD5 to use for transactional integrety for the uploadBlock request. 
 If contentMD5 is nil, and requestOptions.useTransactionalMD5 is set to YES, the library will calculate the MD5 of the block for you.
 This value is not stored on the service.
 @param accessCondition The access condition for the request.
 @param requestOptions The options to use for the request.
 @param operationContext The operation context to use for the call.
 @param completionHandler The block of code to execute when the upload call completes.
 
 | Parameter name | Description |
 |----------------|-------------|
 |NSError * | Nil if the operation succeeded without error, error with details about the failure otherwise.|
 */
-(void)uploadBlockFromData:(NSData *)sourceData blockID:(NSString *)blockID contentMD5:(AZSNullable NSString *)contentMD5 accessCondition:(AZSNullable AZSAccessCondition *)accessCondition requestOptions:(AZSNullable AZSBlobRequestOptions *)requestOptions operationContext:(AZSNullable AZSOperationContext *)operationContext completionHandler:(void (^)(NSError* __AZSNullable))completionHandler;

/** Uploads a block list, committing the blocks in the list to the blob.
 
 This operation commits a block list to the blob, which causes the blob to be committed.  The blocks included in the list will be
 the data in the blob, in order.
 
 @param blockList The blocks that the blob should contain.  Each item in this array must be an instance of the AZSBlockListItem class.
 @param completionHandler The block of code to execute when the upload call completes.
 
 | Parameter name | Description |
 |----------------|-------------|
 |NSError * | Nil if the operation succeeded without error, error with details about the failure otherwise.|
 */
-(void)uploadBlockListFromArray:(NSArray *)blockList completionHandler:(void (^)(NSError * __AZSNullable))completionHandler;


/** Uploads a block list, committing the blocks in the list to the blob.
 
 This operation commits a block list to the blob, which causes the blob to be committed.  The blocks included in the list will be
 the data in the blob, in order.
 
 @param blockList The blocks that the blob should contain.  Each item in this array must be an instance of the AZSBlockListItem class.
 @param accessCondition The access condition for the request.
 @param requestOptions The options to use for the request.
 @param operationContext The operation context to use for the call.
 @param completionHandler The block of code to execute when the upload call completes.
 
 | Parameter name | Description |
 |----------------|-------------|
 |NSError * | Nil if the operation succeeded without error, error with details about the failure otherwise.|
 */
-(void)uploadBlockListFromArray:(NSArray *)blockList accessCondition:(AZSNullable AZSAccessCondition *)accessCondition requestOptions:(AZSNullable AZSBlobRequestOptions *)requestOptions operationContext:(AZSNullable AZSOperationContext *)operationContext completionHandler:(void (^)(NSError * __AZSNullable))completionHandler;

/** Downloads the block list for a blob.
 
 This operation fetches the current block list from the service.
 
 Note that this data is not streamed, all data is in memory at once.  This may use a significant amount of memory for blobs with
 many blocks.
 
 @param blockListFilter Whether we want to fetch only uncommitted blocks, only committed blocks, or all blocks.
 @param completionHandler The block of code to execute when the download call completes.
 
 | Parameter name | Description |
 |----------------|-------------|
 |NSError * | Nil if the operation succeeded without error, error with details about the failure otherwise.|
 |NSArray * | The list of blocks in the blob.  Each item in the array will be an instance of AZSBlockListItem.|
 */
-(void)downloadBlockListFromFilter:(AZSBlockListFilter)blockListFilter completionHandler:(void (^)(NSError * __AZSNullable, NSArray * __AZSNullable))completionHandler;

/** Downloads the block list for a blob.
 
 This operation fetches the current block list from the service.
 
 Note that this data is not streamed, all data is in memory at once.  This may use a significant amount of memory for blobs with
 many blocks.
 
 @param blockListFilter Whether we want to fetch only uncommitted blocks, only committed blocks, or all blocks.
 @param accessCondition The access condition for the request.
 @param requestOptions The options to use for the request.
 @param operationContext The operation context to use for the call.
 @param completionHandler The block of code to execute when the download call completes.
 
 | Parameter name | Description |
 |----------------|-------------|
 |NSError * | Nil if the operation succeeded without error, error with details about the failure otherwise.|
 |NSArray * | The list of blocks in the blob.  Each item in the array will be an instance of AZSBlockListItem.|
 */
-(void)downloadBlockListFromFilter:(AZSBlockListFilter)blockListFilter accessCondition:(AZSNullable AZSAccessCondition *)accessCondition requestOptions:(AZSNullable AZSBlobRequestOptions *)requestOptions operationContext:(AZSNullable AZSOperationContext *)operationContext completionHandler:(void (^)(NSError * __AZSNullable, NSArray * __AZSNullable))completionHandler;

/** Creates an output stream that is capable of writing to the blob.
 
 This method returns an instance of AZSBlobOutputStream.  The caller can then assign a delegate and schedule the stream in a runloop 
 (similar to any other NSOutputStream.)  See AZSBlobOutputStream documentation for details.
 
 @returns The created AZSBlobOutputStream, capable of writing to this blob.
 */
- (AZSBlobOutputStream *)createOutputStream;

/** Creates an output stream that is capable of writing to the blob.
 
 This method returns an instance of AZSBlobOutputStream.  The caller can then assign a delegate and schedule the stream in a runloop
 (similar to any other NSOutputStream.)  See AZSBlobOutputStream documentation for details.
 
 @param accessCondition The access condition for the request.
 @param requestOptions The options to use for the request.
 @param operationContext The operation context to use for the call.
 
 @returns The created AZSBlobOutputStream, capable of writing to this blob.
 */
- (AZSBlobOutputStream *)createOutputStreamWithAccessCondition:(AZSNullable AZSAccessCondition *)accessCondition requestOptions:(AZSNullable AZSBlobRequestOptions *)requestOptions operationContext:(AZSNullable AZSOperationContext *)operationContext;

/** Uploads a blob from given source text.
 
 UploadFromText encodes the input text as UTF-8 and then uploads it to the blob on the service.  This operation will overwrite any data
 already in the blob on the service, unless protected with an appropriate AZSAccessCondition.
 
 @param textToUpload The text that the blob should contain.
 @param completionHandler The block of code to execute when the upload call completes.
 
 | Parameter name | Description |
 |----------------|-------------|
 |NSError * | Nil if the operation succeeded without error, error with details about the failure otherwise.|
 */
-(void)uploadFromText:(NSString *)textToUpload completionHandler:(void (^)(NSError * __AZSNullable))completionHandler;

/** Uploads a blob from given source text.
 
 UploadFromText encodes the input text as UTF-8 and then uploads it to the blob on the service.  This operation will overwrite any data
 already in the blob on the service, unless protected with an appropriate AZSAccessCondition.
 
 @param textToUpload The text that the blob should contain.
 @param accessCondition The access condition for the request.
 @param requestOptions The options to use for the request.
 @param operationContext The operation context to use for the call.
 @param completionHandler The block of code to execute when the upload call completes.
 
 | Parameter name | Description |
 |----------------|-------------|
 |NSError * | Nil if the operation succeeded without error, error with details about the failure otherwise.|
 */
-(void)uploadFromText:(NSString *)textToUpload accessCondition:(AZSNullable AZSAccessCondition *)accessCondition requestOptions:(AZSNullable AZSBlobRequestOptions *)requestOptions operationContext:(AZSNullable AZSOperationContext *)operationContext completionHandler:(void (^)(NSError * __AZSNullable))completionHandler;

/** Uploads a blob from given source file.
 
 UploadFromText loads an the input file and uploads the contents of that file to the service.  Contents will not be
 read all at once, but instead in a streaming fashion.  This operation will overwrite any data
 already in the blob on the service, unless protected with an appropriate AZSAccessCondition.
 
 @param filePath The path to the file containing the data that the blob should contain.
 @param completionHandler The block of code to execute when the upload call completes.
 
 | Parameter name | Description |
 |----------------|-------------|
 |NSError * | Nil if the operation succeeded without error, error with details about the failure otherwise.|
 */
-(void)uploadFromFileWithPath:(NSString *)filePath completionHandler:(void (^)(NSError * __AZSNullable))completionHandler;

/** Uploads a blob from given source file.
 
 UploadFromText loads an the input file and uploads the contents of that file to the service.  Contents will not be
 read all at once, but instead in a streaming fashion.  This operation will overwrite any data
 already in the blob on the service, unless protected with an appropriate AZSAccessCondition.
 
 @param filePath The path to the file containing the data that the blob should contain.
 @param accessCondition The access condition for the request.
 @param requestOptions The options to use for the request.
 @param operationContext The operation context to use for the call.
 @param completionHandler The block of code to execute when the upload call completes.
 
 | Parameter name | Description |
 |----------------|-------------|
 |NSError * | Nil if the operation succeeded without error, error with details about the failure otherwise.|
 */
-(void)uploadFromFileWithPath:(NSString *)filePath accessCondition:(AZSNullable AZSAccessCondition *)accessCondition requestOptions:(AZSNullable AZSBlobRequestOptions *)requestOptions operationContext:(AZSNullable AZSOperationContext *)operationContext completionHandler:(void (^)(NSError * __AZSNullable))completionHandler;

/** Uploads a blob from given source file.
 
 UploadFromText loads an the input file and uploads the contents of that file to the service.  Contents will not be
 read all at once, but instead in a streaming fashion.  This operation will overwrite any data
 already in the blob on the service, unless protected with an appropriate AZSAccessCondition.
 
 @param fileURL The URL to the file containing the data that the blob should contain.
 @param completionHandler The block of code to execute when the upload call completes.
 
 | Parameter name | Description |
 |----------------|-------------|
 |NSError * | Nil if the operation succeeded without error, error with details about the failure otherwise.|
 */
-(void)uploadFromFileWithURL:(NSURL *)fileURL completionHandler:(void (^)(NSError * __AZSNullable))completionHandler;

/** Uploads a blob from given source file.
 
 UploadFromText loads an the input file and uploads the contents of that file to the service.  Contents will not be
 read all at once, but instead in a streaming fashion.  This operation will overwrite any data
 already in the blob on the service, unless protected with an appropriate AZSAccessCondition.
 
 @param fileURL The URL to the file containing the data that the blob should contain.
 @param accessCondition The access condition for the request.
 @param requestOptions The options to use for the request.
 @param operationContext The operation context to use for the call.
 @param completionHandler The block of code to execute when the upload call completes.
 
 | Parameter name | Description |
 |----------------|-------------|
 |NSError * | Nil if the operation succeeded without error, error with details about the failure otherwise.|
 */
-(void)uploadFromFileWithURL:(NSURL *)fileURL accessCondition:(AZSNullable AZSAccessCondition *)accessCondition requestOptions:(AZSNullable AZSBlobRequestOptions *)requestOptions operationContext:(AZSNullable AZSOperationContext *)operationContext completionHandler:(void (^)(NSError * __AZSNullable))completionHandler;

@end

AZS_ASSUME_NONNULL_END