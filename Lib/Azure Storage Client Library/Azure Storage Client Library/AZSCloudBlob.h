// -----------------------------------------------------------------------------------------
// <copyright file="AZSCloudBlob.h" company="Microsoft">
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
#import "AZSEnums.h"
#import "AZSMacros.h"

AZS_ASSUME_NONNULL_BEGIN

@class AZSCloudBlobContainer;
@class AZSAccessCondition;
@class AZSBlobRequestOptions;
@class AZSOperationContext;
@class AZSStorageUri;
@class AZSCloudBlobClient;
@class AZSCopyState;
@class AZSBlobProperties;
@class AZSStorageCredentials;
@class AZSSharedAccessBlobParameters;
@class AZSSharedAccessHeaders;

/** The AZSCloudBlob represents a blob in Azure Storage.
 
 The AZSCloudBlob is used to perform blob-level operations on all blobs, including retrieving, and deleting.
 */
@interface AZSCloudBlob : NSObject

/** The name of the blob.  This is the full path to the blob, not including the container name.*/
@property (copy) NSString *blobName;

/** The container in which this blob exists.*/
@property (strong) AZSCloudBlobContainer *blobContainer;

/** The full StorageURI to this blob.*/
@property (strong) AZSStorageUri *storageUri;

/** The blob client representing the blob service for this blob.*/
@property (strong) AZSCloudBlobClient *client;

/** The snapshot time of this snapshot of the blob.  If nil, this AZSCloudBlob object does not represent a snapshot.*/
@property (copy, AZSNullable) NSString *snapshotTime;

//@property (nonatomic, strong) AZSCloudBlobDirectory *parent;

/** The metadata on this blob.*/
@property (strong) NSMutableDictionary *metadata;

/** The properties on this blob.*/
@property (strong) AZSBlobProperties *properties;

/** The current copy state of this blob.*/
@property (strong) AZSCopyState *blobCopyState;

// TODO: snapshotqualifieduri, issnapshot, etc.

// Initializers are not commented because callers shouldn't be creating AZSCloudBlob objects directly.
- (instancetype)initWithUrl:(NSURL *)blobAbsoluteUrl;
- (instancetype)initWithUrl:(NSURL *)blobAbsoluteUrl credentials:(AZSNullable AZSStorageCredentials *)credentials snapshotTime:(AZSNullable NSString *)snapshotTime;
- (instancetype)initWithStorageUri:(AZSStorageUri *)blobAbsoluteUri;
- (instancetype)initWithStorageUri:(AZSStorageUri *)blobAbsoluteUri credentials:(AZSNullable AZSStorageCredentials *)credentials snapshotTime:(AZSNullable NSString *)snapshotTime AZS_DESIGNATED_INITIALIZER;
- (instancetype)initWithContainer:(AZSCloudBlobContainer *)blobContainer name:(NSString *)blobName;
- (instancetype)initWithContainer:(AZSCloudBlobContainer *)blobContainer name:(NSString *)blobName snapshotTime:(AZSNullable NSString *)snapshotTime AZS_DESIGNATED_INITIALIZER;

/** Downloads the contents of the blob to a stream.
 
 This method streams the contents of a blob down from the service.
 
 This method is currently unstable, it does not use accepted patterns for Objective-C streams.  A solution is forthcoming.
 
 @param targetStream The destination stream.  The stream should already be opened.
 @param completionHandler The block of code to execute when the download call completes.  Note that this will only be called after the entire
 blob has been downloaded.
 
 | Parameter name | Description |
 |----------------|-------------|
 |NSError * | Nil if the operation succeeded without error, error with details about the failure otherwise.|
 */
-(void)downloadToStream:(NSOutputStream *)targetStream completionHandler:(void (^)(NSError* __AZSNullable))completionHandler;

/** Downloads the contents of the blob to a stream.
 
 This method streams the contents of a blob down from the service.
 
 This method is currently unstable, it does not use accepted patterns for Objective-C streams.  A solution is forthcoming.
 
 @param targetStream The destination stream.  The stream should already be opened.
 @param accessCondition The access condition for the request.
 @param requestOptions The options to use for the request.
 @param operationContext The operation context to use for the call.
 @param completionHandler The block of code to execute when the download call completes.  Note that this will only be called after the entire
 blob has been downloaded.
 
 | Parameter name | Description |
 |----------------|-------------|
 |NSError * | Nil if the operation succeeded without error, error with details about the failure otherwise.|
 */
-(void)downloadToStream:(NSOutputStream *)targetStream accessCondition:(AZSNullable AZSAccessCondition *)accessCondition requestOptions:(AZSNullable AZSBlobRequestOptions *)requestOptions operationContext:(AZSNullable AZSOperationContext *)operationContext completionHandler:(void (^)(NSError* __AZSNullable))completionHandler;

/** Downloads the contents of the blob to a stream.
 
 This method streams the contents of a blob down from the service.
 
 This method is currently unstable, it does not use accepted patterns for Objective-C streams.  A solution is forthcoming.
 
 @param targetStream The destination stream.  The stream should already be opened.
 @param range The range of bytes to download.  If the length is 0, download the entire blob.
 @param accessCondition The access condition for the request.
 @param requestOptions The options to use for the request.
 @param operationContext The operation context to use for the call.
 @param completionHandler The block of code to execute when the download call completes.  Note that this will only be called after the entire 
 blob has been downloaded.
 
 | Parameter name | Description |
 |----------------|-------------|
 |NSError * | Nil if the operation succeeded without error, error with details about the failure otherwise.|
 */
-(void)downloadToStream:(NSOutputStream *)targetStream range:(NSRange)range accessCondition:(AZSNullable AZSAccessCondition *)accessCondition requestOptions:(AZSNullable AZSBlobRequestOptions *)requestOptions operationContext:(AZSNullable AZSOperationContext *)operationContext completionHandler:(void (^)(NSError* __AZSNullable))completionHandler;

/** Deletes the blob.
 
 This method deletes the blob on the service.  It will fail if the blob does not exist.
 
 @param completionHandler The block of code to execute when the delete call completes.
 
 | Parameter name | Description |
 |----------------|-------------|
 |NSError * | Nil if the operation succeeded without error, error with details about the failure otherwise.|
 
 */
-(void)deleteWithCompletionHandler:(void (^)(NSError* __AZSNullable))completionHandler;

/** Deletes the blob.
 
 This method deletes the blob on the service.  It will fail if the blob does not exist.
 
 @param snapshotsOption If snapshots should be deleted.  See AZSDeleteSnapshotsOption for more information.
 @param completionHandler The block of code to execute when the delete call completes.
 
 | Parameter name | Description |
 |----------------|-------------|
 |NSError * | Nil if the operation succeeded without error, error with details about the failure otherwise.|
 
 */
-(void)deleteWithSnapshotsOption:(AZSDeleteSnapshotsOption)snapshotsOption completionHandler:(void (^)(NSError* __AZSNullable))completionHandler;

/** Deletes the blob.
 
 This method deletes the blob on the service.  It will fail if the blob does not exist.
 
 @param snapshotsOption If snapshots should be deleted.  See AZSDeleteSnapshotsOption for more information.
 @param accessCondition The access condition for the request.
 @param requestOptions The options to use for the request.
 @param operationContext The operation context to use for the call.
 @param completionHandler The block of code to execute when the delete call completes.
 
 | Parameter name | Description |
 |----------------|-------------|
 |NSError * | Nil if the operation succeeded without error, error with details about the failure otherwise.|

 */
-(void)deleteWithSnapshotsOption:(AZSDeleteSnapshotsOption)snapshotsOption accessCondition:(AZSNullable AZSAccessCondition *)accessCondition requestOptions:(AZSNullable AZSBlobRequestOptions *)requestOptions operationContext:(AZSNullable AZSOperationContext *)operationContext completionHandler:(void (^)(NSError* __AZSNullable))completionHandler;

/** Updates the blob's properties.
 
 @param completionHandler The block of code to execute when the Upload Properties call completes.
 
 | Parameter name | Description |
 |----------------|-------------|
 |NSError * | Nil if the operation succeeded without error, error with details about the failure otherwise.|
 */
- (void)uploadPropertiesWithCompletionHandler:(void (^)(NSError* __AZSNullable))completionHandler;

/** Updates the blob's properties.

 @param accessCondition The access condition for the request.
 @param requestOptions The options to use for the request.
 @param operationContext The operation context to use for the call.
 @param completionHandler The block of code to execute when the Upload Properties call completes.
 
 | Parameter name | Description |
 |----------------|-------------|
 |NSError * | Nil if the operation succeeded without error, error with details about the failure otherwise.|
 */
- (void)uploadPropertiesWithAccessCondition:(AZSNullable AZSAccessCondition *)accessCondition requestOptions:(AZSNullable AZSBlobRequestOptions *)requestOptions operationContext:(AZSNullable AZSOperationContext *)operationContext completionHandler:(void (^)(NSError* __AZSNullable))completionHandler;

/** Updates the blob's user defined metadata.
 
 @param completionHandler The block of code to execute when the Upload Metadata call completes.
 
 | Parameter name | Description |
 |----------------|-------------|
 |NSError * | Nil if the operation succeeded without error, error with details about the failure otherwise.|
 */
- (void)uploadMetadataWithCompletionHandler:(void (^)(NSError* __AZSNullable))completionHandler;

/** Updates the blob's user defined metadata.
 
 @param accessCondition The access condition for the request.
 @param requestOptions The options to use for the request.
 @param operationContext The operation context to use for the call.
 @param completionHandler The block of code to execute when the Upload Metadata call completes.
 
 | Parameter name | Description |
 |----------------|-------------|
 |NSError * | Nil if the operation succeeded without error, error with details about the failure otherwise.|
 */
- (void)uploadMetadataWithAccessCondition:(AZSNullable AZSAccessCondition *)accessCondition requestOptions:(AZSNullable AZSBlobRequestOptions *)requestOptions operationContext:(AZSNullable AZSOperationContext *)operationContext completionHandler:(void (^)(NSError* __AZSNullable))completionHandler;

/** Retrieves the blob's attributes.
 
 @param completionHandler The block of code to execute when the Fetch Attributes call completes.
 
 | Parameter name | Description |
 |----------------|-------------|
 |NSError * | Nil if the operation succeeded without error, error with details about the failure otherwise.|
 */
- (void)downloadAttributesWithCompletionHandler:(void (^)(NSError* __AZSNullable))completionHandler;

/** Retrieves the blob's attributes.
 
 @param accessCondition The access condition for the request.
 @param requestOptions The options to use for the request.
 @param operationContext The operation context to use for the call.
 @param completionHandler The block of code to execute when the Fetch Attributes call completes.
 
 | Parameter name | Description |
 |----------------|-------------|
 |NSError * | Nil if the operation succeeded without error, error with details about the failure otherwise.|
 */
- (void)downloadAttributesWithAccessCondition:(AZSNullable AZSAccessCondition *)accessCondition requestOptions:(AZSNullable AZSBlobRequestOptions *)requestOptions operationContext:(AZSNullable AZSOperationContext *)operationContext completionHandler:(void (^)(NSError* __AZSNullable))completionHandler;

/** Snapshots the blob.
 
 This method creates a snapshot of the blob on the service.
 
 @param metadata The metadata to set on the blob snapshot.  If nil, the snapshot will copy the metadata of the base blob.
 @param completionHandler The block of code to execute when the snapshot call completes.
 
 | Parameter name | Description |
 |----------------|-------------|
 |NSError * | Nil if the operation succeeded without error, error with details about the failure otherwise.|
 |AZSCloudBlob * | The blob object that represents the snapshot.  It will have the snapshotTime property set.|
 
 */
-(void)snapshotBlobWithMetadata:(AZSNullable NSDictionary *)metadata completionHandler:(void (^)(NSError* __AZSNullable, AZSCloudBlob * __AZSNullable))completionHandler;

/** Snapshots the blob.
 
 This method creates a snapshot of the blob on the service.
 
 @param metadata The metadata to set on the blob snapshot.  If nil, the snapshot will copy the metadata of the base blob.
 @param accessCondition The access condition for the request.
 @param requestOptions The options to use for the request.
 @param operationContext The operation context to use for the call.
 @param completionHandler The block of code to execute when the snapshot call completes.
 
 | Parameter name | Description |
 |----------------|-------------|
 |NSError * | Nil if the operation succeeded without error, error with details about the failure otherwise.|
 |AZSCloudBlob * | The blob object that represents the snapshot.  It will have the snapshotTime property set.|
 
 */
-(void)snapshotBlobWithMetadata:(AZSNullable NSDictionary *)metadata accessCondition:(AZSNullable AZSAccessCondition *)accessCondition requestOptions:(AZSNullable AZSBlobRequestOptions *)requestOptions operationContext:(AZSNullable AZSOperationContext *)operationContext completionHandler:(void (^)(NSError* __AZSNullable, AZSCloudBlob * __AZSNullable))completionHandler;

/** Checks to see if the blob exists.
 
 This method queries the service to determine if the blob exists.
 
 @param completionHandler The block of code to execute when the snapshot call completes.
 
 | Parameter name | Description |
 |----------------|-------------|
 |NSError * | Nil if the operation succeeded without error, error with details about the failure otherwise.|
 |BOOL | YES if the blob object exists on the service, NO else.|
 */
-(void)existsWithCompletionHandler:(void (^)(NSError* __AZSNullable, BOOL))completionHandler;

/** Checks to see if the blob exists.
 
 This method queries the service to determine if the blob exists.
 
 @param accessCondition The access condition for the request.
 @param requestOptions The options to use for the request.
 @param operationContext The operation context to use for the call.
 @param completionHandler The block of code to execute when the snapshot call completes.
 
 | Parameter name | Description |
 |----------------|-------------|
 |NSError * | Nil if the operation succeeded without error, error with details about the failure otherwise.|
 |BOOL | YES if the blob object exists on the service, NO else.|
 */
-(void)existsWithAccessCondition:(AZSNullable AZSAccessCondition *)accessCondition requestOptions:(AZSNullable AZSBlobRequestOptions *)requestOptions operationContext:(AZSNullable AZSOperationContext *)operationContext completionHandler:(void (^)(NSError* __AZSNullable, BOOL))completionHandler;

/** Creates a Shared Access Signature (SAS) token from the given policy for this Blob.
 Note that logging in this method uses the global logger configured statically on the AZSOperationContext as there is no operation being performed to provide a local operation context.

 @param parameters The shared access blob parameters from which to create the SAS token.
 @param error A pointer to a NSError*, to be set in the event of failure.
 @returns The newly created SAS token.
 */
-(NSString *) createSharedAccessSignatureWithParameters:(AZSSharedAccessBlobParameters*)parameters error:(NSError **)error;

/** Acquires a lease on this blob.
 
 @param leaseTime The span of time for which to acquire the lease, rounded down to seconds. If NIL, an infinite lease will be acquired. Must be greater than zero.
 @param proposedLeaseId The proposed lease ID for the new lease, or NIL if no lease ID is proposed.
 @param completionHandler The block of code to execute when the Acquire Lease call completes.
 
 | Parameter name | Description |
 |----------------|-------------|
 |NSError * | Nil if the operation succeeded without error, error with details about the failure otherwise.|
 |NSString * | The ID of the acquired lease.|
 */
- (void)acquireLeaseWithLeaseTime:(AZSNullable NSNumber *) leaseTime proposedLeaseId:(AZSNullable NSString *)proposedLeaseId completionHandler:(void (^)(NSError* __AZSNullable, NSString * __AZSNullable))completionHandler;

/** Acquires a lease on this blob.
 
 @param leaseTime The span of time for which to acquire the lease, rounded down to seconds. If NIL, an infinite lease will be acquired. Must be greater than zero.
 @param proposedLeaseId The proposed lease ID for the new lease, or NIL if no lease ID is proposed.
 @param accessCondition The access condition for the request.
 @param requestOptions The options to use for the request.
 @param operationContext The operation context to use for the call.
 @param completionHandler The block of code to execute when the Acquire Lease call completes.
 
 | Parameter name | Description |
 |----------------|-------------|
 |NSError * | Nil if the operation succeeded without error, error with details about the failure otherwise.|
 |NSString * | The ID of the acquired lease.|
 */
- (void)acquireLeaseWithLeaseTime:(AZSNullable NSNumber *) leaseTime proposedLeaseId:(AZSNullable NSString *)proposedLeaseId accessCondition:(AZSNullable AZSAccessCondition *)accessCondition requestOptions:(AZSNullable AZSBlobRequestOptions *)requestOptions operationContext:(AZSNullable AZSOperationContext *)operationContext completionHandler:(void (^)(NSError* __AZSNullable, NSString * __AZSNullable))completionHandler;

/** Breaks the current lease on this blob.
 
 @param breakPeriod The span of time for which to allow the lease to remain, rounded down to seconds. If NIL, the break period will be the remainder of the current lease or zero for an infinite lease.
 @param completionHandler The block of code to execute when the Break Lease call completes.
 
 | Parameter name | Description |
 |----------------|-------------|
 |NSError * | Nil if the operation succeeded without error, error with details about the failure otherwise.|
 |NSNumber * | The amount of time before the lease ends, to the second.|
 */
- (void)breakLeaseWithBreakPeriod:(AZSNullable NSNumber *) breakPeriod completionHandler:(void (^)(NSError* __AZSNullable, NSNumber* __AZSNullable))completionHandler;

/** Breaks the current lease on this blob.
 
 @param breakPeriod The span of time for which to allow the lease to remain, rounded down to seconds. If NIL, the break period will be the remainder of the current lease or zero for an infinite lease.
 @param accessCondition The access condition for the request.
 @param requestOptions The options to use for the request.
 @param operationContext The operation context to use for the call.
 @param completionHandler The block of code to execute when the Break Lease call completes.
 
 | Parameter name | Description |
 |----------------|-------------|
 |NSError * | Nil if the operation succeeded without error, error with details about the failure otherwise.|
 |NSNumber * | The amount of time before the lease ends, to the second.|
 */
- (void)breakLeaseWithBreakPeriod:(AZSNullable NSNumber *) breakPeriod accessCondition:(AZSNullable AZSAccessCondition *)accessCondition requestOptions:(AZSNullable AZSBlobRequestOptions *)requestOptions operationContext:(AZSNullable AZSOperationContext *)operationContext completionHandler:(void (^)(NSError* __AZSNullable, NSNumber* __AZSNullable))completionHandler;

/** Changes the lease ID on this blob.
 
 @param proposedLeaseId The proposed lease ID for the new lease, which cannot be null.
 @param accessCondition The access condition for the request.
 @param completionHandler The block of code to execute when the Change Lease call completes.
 
 | Parameter name | Description |
 |----------------|-------------|
 |NSError * | Nil if the operation succeeded without error, error with details about the failure otherwise.|
 |NSString * | The new lease ID.|
 */
- (void)changeLeaseWithProposedLeaseId:(NSString *) proposedLeaseId accessCondition:(AZSNullable AZSAccessCondition *)accessCondition completionHandler:(void (^)(NSError* __AZSNullable, NSString* __AZSNullable))completionHandler;

/** Changes the lease ID on this blob.
 
 @param proposedLeaseId The proposed lease ID for the new lease, which cannot be null.
 @param accessCondition The access condition for the request.
 @param requestOptions The options to use for the request.
 @param operationContext The operation context to use for the call.
 @param completionHandler The block of code to execute when the Change Lease call completes.
 
 | Parameter name | Description |
 |----------------|-------------|
 |NSError * | Nil if the operation succeeded without error, error with details about the failure otherwise.|
 |NSString * | The new lease ID.|
 */
- (void)changeLeaseWithProposedLeaseId:(NSString *) proposedLeaseId accessCondition:(AZSNullable AZSAccessCondition *)accessCondition requestOptions:(AZSNullable AZSBlobRequestOptions *)requestOptions operationContext:(AZSNullable AZSOperationContext *)operationContext completionHandler:(void (^)(NSError* __AZSNullable, NSString* __AZSNullable))completionHandler;

/** Releases the lease on this blob.
 
 @param accessCondition The access condition for the request.
 @param completionHandler The block of code to execute when the Release Lease call completes.
 
 | Parameter name | Description |
 |----------------|-------------|
 |NSError * | Nil if the operation succeeded without error, error with details about the failure otherwise.|
 */
- (void)releaseLeaseWithAccessCondition:(AZSNullable AZSAccessCondition *)accessCondition completionHandler:(void (^)(NSError* __AZSNullable))completionHandler;

/** Releases the lease on this blob.
 
 @param accessCondition The access condition for the request.
 @param requestOptions The options to use for the request.
 @param operationContext The operation context to use for the call.
 @param completionHandler The block of code to execute when the Release Lease call completes.
 
 | Parameter name | Description |
 |----------------|-------------|
 |NSError * | Nil if the operation succeeded without error, error with details about the failure otherwise.|
 */
- (void)releaseLeaseWithAccessCondition:(AZSNullable AZSAccessCondition *)accessCondition requestOptions:(AZSNullable AZSBlobRequestOptions *)requestOptions operationContext:(AZSNullable AZSOperationContext *)operationContext completionHandler:(void (^)(NSError* __AZSNullable))completionHandler;

/** Renews a lease on this blob.
 
 @param accessCondition The access condition for the request.
 @param completionHandler The block of code to execute when the Renew Lease call completes.
 
 | Parameter name | Description |
 |----------------|-------------|
 |NSError * | Nil if the operation succeeded without error, error with details about the failure otherwise.|
 */
- (void)renewLeaseWithAccessCondition:(AZSNullable AZSAccessCondition *)accessCondition completionHandler:(void (^)(NSError* __AZSNullable))completionHandler;

/** Renews a lease on this blob.
 
 @param accessCondition The access condition for the request.
 @param requestOptions The options to use for the request.
 @param operationContext The operation context to use for the call.
 @param completionHandler The block of code to execute when the Renew Lease call completes.
 
 | Parameter name | Description |
 |----------------|-------------|
 |NSError * | Nil if the operation succeeded without error, error with details about the failure otherwise.|
 */
- (void)renewLeaseWithAccessCondition:(AZSNullable AZSAccessCondition *)accessCondition requestOptions:(AZSNullable AZSBlobRequestOptions *)requestOptions operationContext:(AZSNullable AZSOperationContext *)operationContext completionHandler:(void (^)(NSError* __AZSNullable))completionHandler;

+(void)updateEtagAndLastModifiedWithResponse:(NSHTTPURLResponse *)response properties:(AZSBlobProperties *)properties updateLength:(BOOL)updateLength;

/** Downloads contents of a blob to an NSData object.
 
 @param completionHandler The block of code to execute when the call completes.
 
 | Parameter name | Description |
 |----------------|-------------|
 |NSError * | Nil if the operation succeeded without error, error with details about the failure otherwise.|
 |NSData * | The NSData object containing the data from the blob.|
 */
-(void)downloadToDataWithCompletionHandler:(void (^)(NSError * __AZSNullable, NSData * __AZSNullable))completionHandler;

/** Downloads contents of a blob to an NSData object.
 
 @param accessCondition The access condition for the request.
 @param requestOptions The options to use for the request.
 @param operationContext The operation context to use for the call.
 @param completionHandler The block of code to execute when the call completes.
 
 | Parameter name | Description |
 |----------------|-------------|
 |NSError * | Nil if the operation succeeded without error, error with details about the failure otherwise.|
 |NSData * | The NSData object containing the data from the blob.|
 */
-(void)downloadToDataWithAccessCondition:(AZSNullable AZSAccessCondition *)accessCondition requestOptions:(AZSNullable AZSBlobRequestOptions *)requestOptions operationContext:(AZSNullable AZSOperationContext *)operationContext completionHandler:(void (^)(NSError * __AZSNullable, NSData * __AZSNullable))completionHandler;

/** Downloads contents of a blob to an NSString.  Blob contents will be interpreted as UTF-8.
 
 @param completionHandler The block of code to execute when the call completes.
 
 | Parameter name | Description |
 |----------------|-------------|
 |NSError * | Nil if the operation succeeded without error, error with details about the failure otherwise.|
 |NSString * | The NSString object containing the text from the blob.|
 */
-(void)downloadToTextWithCompletionHandler:(void (^)(NSError * __AZSNullable, NSString * __AZSNullable))completionHandler;

/** Downloads contents of a blob to an NSString.  Blob contents will be interpreted as UTF-8.
 
 @param accessCondition The access condition for the request.
 @param requestOptions The options to use for the request.
 @param operationContext The operation context to use for the call.
 @param completionHandler The block of code to execute when the call completes.
 
 | Parameter name | Description |
 |----------------|-------------|
 |NSError * | Nil if the operation succeeded without error, error with details about the failure otherwise.|
 |NSString * | The NSString object containing the text from the blob.|
 */
-(void)downloadToTextWithAccessCondition:(AZSNullable AZSAccessCondition *)accessCondition requestOptions:(AZSNullable AZSBlobRequestOptions *)requestOptions operationContext:(AZSNullable AZSOperationContext *)operationContext completionHandler:(void (^)(NSError * __AZSNullable, NSString * __AZSNullable))completionHandler;

/** Downloads contents of a blob to a file.
 
 @param filePath The path to the file to download the blob to.
 @param shouldAppend YES if newly written data should be appended to any existing file contents, NO otherwise.
 @param completionHandler The block of code to execute when the call completes.
 
 | Parameter name | Description |
 |----------------|-------------|
 |NSError * | Nil if the operation succeeded without error, error with details about the failure otherwise.|
 */
-(void)downloadToFileWithPath:(NSString *)filePath append:(BOOL)shouldAppend completionHandler:(void (^)(NSError * __AZSNullable))completionHandler;

/** Downloads contents of a blob to a file.
 
 @param filePath The path to the file to download the blob to.
 @param shouldAppend YES if newly written data should be appended to any existing file contents, NO otherwise.
 @param accessCondition The access condition for the request.
 @param requestOptions The options to use for the request.
 @param operationContext The operation context to use for the call.
 @param completionHandler The block of code to execute when the call completes.
 
 | Parameter name | Description |
 |----------------|-------------|
 |NSError * | Nil if the operation succeeded without error, error with details about the failure otherwise.|
 */
-(void)downloadToFileWithPath:(NSString *)filePath append:(BOOL)shouldAppend accessCondition:(AZSNullable AZSAccessCondition *)accessCondition requestOptions:(AZSNullable AZSBlobRequestOptions *)requestOptions operationContext:(AZSNullable AZSOperationContext *)operationContext completionHandler:(void (^)(NSError * __AZSNullable))completionHandler;


/** Downloads contents of a blob to a file.
 
 @param fileURL The URL to the file to download the blob to.
 @param shouldAppend YES if newly written data should be appended to any existing file contents, NO otherwise.
 @param completionHandler The block of code to execute when the call completes.
 
 | Parameter name | Description |
 |----------------|-------------|
 |NSError * | Nil if the operation succeeded without error, error with details about the failure otherwise.|
 */
-(void)downloadToFileWithURL:(NSURL *)fileURL append:(BOOL)shouldAppend completionHandler:(void (^)(NSError * __AZSNullable))completionHandler;

/** Downloads contents of a blob to a file.
 
 @param fileURL The URL to the file to download the blob to.
 @param shouldAppend YES if newly written data should be appended to any existing file contents, NO otherwise.
 @param accessCondition The access condition for the request.
 @param requestOptions The options to use for the request.
 @param operationContext The operation context to use for the call.
 @param completionHandler The block of code to execute when the call completes.
 
 | Parameter name | Description |
 |----------------|-------------|
 |NSError * | Nil if the operation succeeded without error, error with details about the failure otherwise.|
 */
-(void)downloadToFileWithURL:(NSURL *)fileURL append:(BOOL)shouldAppend accessCondition:(AZSNullable AZSAccessCondition *)accessCondition requestOptions:(AZSNullable AZSBlobRequestOptions *)requestOptions operationContext:(AZSNullable AZSOperationContext *)operationContext completionHandler:(void (^)(NSError * __AZSNullable))completionHandler;

/** Begins an async, server-side copy to this AZSCloubBlob object.
 
 This method kicks off an async copy on the service.  The copy will complete in the background.
 
 @param sourceBlob The blob to use as the source for the copy.
 @param completionHandler The block of code to execute when the call completes.
 
 | Parameter name | Description |
 |----------------|-------------|
 |NSError * | Nil if the operation succeeded without error, error with details about the failure otherwise.|
 |NSString * | The copy ID for the copy operation.|
 */
-(void)startAsyncCopyFromBlob:(AZSCloudBlob *)sourceBlob completionHandler:(void (^)(NSError * __AZSNullable, NSString * __AZSNullable))completionHandler;

/** Begins an async, server-side copy to this AZSCloubBlob object.
 
 This method kicks off an async copy on the service.  The copy will complete in the background.
 
 @param sourceBlob The blob to use as the source for the copy.
 @param sourceAccessCondition The access condition to use to access the source for the copy.
 @param destinationAccessCondition The access condition to use to access this blob (the destination)
 @param requestOptions The options to use for the request.
 @param operationContext The operation context to use for the call.
 @param completionHandler The block of code to execute when the call completes.
 
 | Parameter name | Description |
 |----------------|-------------|
 |NSError * | Nil if the operation succeeded without error, error with details about the failure otherwise.|
 |NSString * | The copy ID for the copy operation.|
 */
-(void)startAsyncCopyFromBlob:(AZSCloudBlob *)sourceBlob sourceAccessCondition:(AZSNullable AZSAccessCondition *)sourceAccessCondition destinationAccessCondition:(AZSNullable AZSAccessCondition *)destinationAccessCondition requestOptions:(AZSNullable AZSBlobRequestOptions *)requestOptions operationContext:(AZSNullable AZSOperationContext *)operationContext completionHandler:(void (^)(NSError * __AZSNullable, NSString * __AZSNullable))completionHandler;

/** Begins an async, server-side copy to this AZSCloubBlob object.
 
 This method kicks off an async copy on the service.  The copy will complete in the background.
 
 @param sourceURL The URL to use as the source for the copy.
 @param completionHandler The block of code to execute when the call completes.
 
 | Parameter name | Description |
 |----------------|-------------|
 |NSError * | Nil if the operation succeeded without error, error with details about the failure otherwise.|
 |NSString * | The copy ID for the copy operation.|
 */
-(void)startAsyncCopyFromURL:(NSURL *)sourceURL completionHandler:(void (^)(NSError * __AZSNullable, NSString * __AZSNullable))completionHandler;

/** Begins an async, server-side copy to this AZSCloubBlob object.
 
 This method kicks off an async copy on the service.  The copy will complete in the background.
 
 @param sourceURL The URL to use as the source for the copy.
 @param sourceAccessCondition The access condition to use to access the source for the copy.
 @param destinationAccessCondition The access condition to use to access this blob (the destination)
 @param requestOptions The options to use for the request.
 @param operationContext The operation context to use for the call.
 @param completionHandler The block of code to execute when the call completes.
 
 | Parameter name | Description |
 |----------------|-------------|
 |NSError * | Nil if the operation succeeded without error, error with details about the failure otherwise.|
 |NSString * | The copy ID for the copy operation.|
 */
-(void)startAsyncCopyFromURL:(NSURL *)sourceURL sourceAccessCondition:(AZSNullable AZSAccessCondition *)sourceAccessCondition destinationAccessCondition:(AZSNullable AZSAccessCondition *)destinationAccessCondition requestOptions:(AZSNullable AZSBlobRequestOptions *)requestOptions operationContext:(AZSNullable AZSOperationContext *)operationContext completionHandler:(void (^)(NSError * __AZSNullable, NSString * __AZSNullable))completionHandler;

/** Aborts an async copy operation on the service.  The copy operation must be one with this blob (self) as the destination.
 
 @param copyId The ID of the copy operation to abort.
 @param completionHandler The block of code to execute when the call completes.
 
 | Parameter name | Description |
 |----------------|-------------|
 |NSError * | Nil if the operation succeeded without error, error with details about the failure otherwise.|
 */
-(void)abortAsyncCopyWithCopyId:(NSString *)copyId completionHandler:(void (^)(NSError * __AZSNullable))completionHandler;

/** Aborts an async copy operation on the service.  The copy operation must be one with this blob (self) as the destination.
 
 @param copyId The ID of the copy operation to abort.
 @param accessCondition The access condition for the request.
 @param requestOptions The options to use for the request.
 @param operationContext The operation context to use for the call.
 @param completionHandler The block of code to execute when the call completes.
 
 | Parameter name | Description |
 |----------------|-------------|
 |NSError * | Nil if the operation succeeded without error, error with details about the failure otherwise.|
 */
-(void)abortAsyncCopyWithCopyId:(NSString *)copyId accessCondition:(AZSNullable AZSAccessCondition *)accessCondition requestOptions:(AZSNullable AZSBlobRequestOptions *)requestOptions operationContext:(AZSNullable AZSOperationContext *)operationContext completionHandler:(void (^)(NSError * __AZSNullable))completionHandler;

// TODO: Delete If Exists... somehow we missed that one.

@end

AZS_ASSUME_NONNULL_END