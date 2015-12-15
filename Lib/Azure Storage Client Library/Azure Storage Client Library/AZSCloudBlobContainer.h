// -----------------------------------------------------------------------------------------
// <copyright file="AZSCloudBlobContainer.h" company="Microsoft">
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

@class AZSCloudBlobClient;
@class AZSContainerResultSegment;
@class AZSOperationContext;
@class AZSBlobRequestOptions;
@class AZSAccessCondition;
@class AZSStorageUri;
@class AZSCloudBlockBlob;
@class AZSContinuationToken;
@class AZSBlobResultSegment;
@class AZSBlobContainerProperties;
@class AZSBlobContainerPermissions;
@class AZSSharedAccessBlobParameters;
@class AZSSharedAccessHeaders;
@class AZSStorageCredentials;

// TODO: Figure out if we should combine all these into one generic 'Null response completion handler' or something.
// TODO: Figure out how to get this typedef to work with Appledocs.

//typedef void (^AZSCreateContainerCompletionHandler)(NSError*);
//typedef void (^AZSDeleteContainerCompletionHandler)(NSError*);

/** AZSCloudBlobContainer represents a Blob Container object on the Storage Service.
 
 A blob container is a logical container object for blobs on the Azure Storage Service.  An instance of 
 this class is used to interface with the corresponding container on the service.
 */
@interface AZSCloudBlobContainer : NSObject

/** The name of this container.*/
@property (copy) NSString *name;

/** The AZSCloudBlobClient representing the blob service that this container is in.*/
@property (strong) AZSCloudBlobClient *client;

/** The StorageUri to this container.*/
@property (strong) AZSStorageUri *storageUri;

/** The metadata on this container.*/
@property (strong) NSMutableDictionary *metadata;

/** The properties of this container.*/
@property (strong) AZSBlobContainerProperties *properties;

/** Initializes a newly allocated AZSCloudBlobContainer object.
 
 @param containerName The name of this container.
 @param client The AZSCloudBlobClient representing the blob service that this container is in.
 @returns The newly allocated object.
 */
- (instancetype)initWithName:(NSString *)containerName client:(AZSCloudBlobClient *)client AZS_DESIGNATED_INITIALIZER;

/** Initializes a newly allocated AZSCloudBlobContainer object.
 
 @param containerAbsoluteUrl The absolute URL to this container.
 @returns The newly allocated object.
 */
- (instancetype)initWithUrl:(NSURL *)containerAbsoluteUrl;

/** Initializes a newly allocated AZSCloudBlobContainer object.
 
 @param containerAbsoluteUrl The absolute URL to this container.
 @param credentials The AZSStorageCredentials used to authenticate to the container.
 @returns The newly allocated object.
 */
- (instancetype)initWithUrl:(NSURL *)containerAbsoluteUrl credentials:(AZSNullable AZSStorageCredentials *)credentials;

/** Initializes a newly allocated AZSCloudBlobContainer object.
 
 @param containerAbsoluteUri The StorageURI to this container.
 @returns The newly allocated object.
 */
- (instancetype)initWithStorageUri:(AZSStorageUri *)containerAbsoluteUri;

/** Initializes a newly allocated AZSCloudBlobContainer object.
 
 @param containerAbsoluteUri The StorageURI to this container.
 @param credentials The AZSStorageCredentials used to authenticate to the container.
 @returns The newly allocated object.
 */
- (instancetype)initWithStorageUri:(AZSStorageUri *)containerAbsoluteUri credentials:(AZSNullable AZSStorageCredentials *)credentials AZS_DESIGNATED_INITIALIZER;

/** Creates the container on the service.  Will fail if the container already exists.
 
 @param completionHandler The block of code to execute when the create call completes.
 
 | Parameter name | Description |
 |----------------|-------------|
 |NSError * | Nil if the operation succeeded without error, error with details about the failure otherwise.|
 */
- (void)createContainerWithCompletionHandler:(void (^)(NSError* __AZSNullable))completionHandler;

/** Creates the container on the service.  Will fail if the container already exists.
 
 @param accessType The access type that the container should have.
 @param requestOptions The options to use for the request.
 @param operationContext The operation context to use for the call.
 @param completionHandler The block of code to execute when the create call completes.
 
 | Parameter name | Description |
 |----------------|-------------|
 |NSError * | Nil if the operation succeeded without error, error with details about the failure otherwise.|
 */
- (void)createContainerWithAccessType:(AZSContainerPublicAccessType)accessType requestOptions:(AZSNullable AZSBlobRequestOptions *)requestOptions operationContext:(AZSNullable AZSOperationContext *)operationContext completionHandler:(void (^)(NSError* __AZSNullable))completionHandler;

/** Deletes the container on the service.  Will fail if the container does not exist.
 
 @param completionHandler The block of code to execute when the delete call completes.
 
 | Parameter name | Description |
 |----------------|-------------|
 |NSError * | Nil if the operation succeeded without error, error with details about the failure otherwise.|
 */
- (void)deleteContainerWithCompletionHandler:(void (^)(NSError* __AZSNullable))completionHandler;

/** Deletes the container on the service.  Will fail if the container does not exist.
 
 @param accessCondition The access condition for the request.
 @param requestOptions The options to use for the request.
 @param operationContext The operation context to use for the call.
 @param completionHandler The block of code to execute when the delete call completes.
 
 | Parameter name | Description |
 |----------------|-------------|
 |NSError * | Nil if the operation succeeded without error, error with details about the failure otherwise.|
 */
- (void)deleteContainerWithAccessCondition:(AZSNullable AZSAccessCondition *)accessCondition requestOptions:(AZSNullable AZSBlobRequestOptions *)requestOptions operationContext:(AZSNullable AZSOperationContext *)operationContext completionHandler:(void (^)(NSError* __AZSNullable))completionHandler;

/** Makes a service call to detect whether or not the container already exists on the service.
 
 @param completionHandler The block of code to execute when the exists call completes.
 
 | Parameter name | Description |
 |----------------|-------------|
 |NSError * | Nil if the operation succeeded without error, error with details about the failure otherwise.|
 |BOOL      | YES if the container exists on the service, NO otherwise.|
 */
- (void)existsWithCompletionHandler:(void (^)(NSError* __AZSNullable, BOOL))completionHandler;

/** Makes a service call to detect whether or not the container already exists on the service.
 
 @param accessCondition The access condition for the request.
 @param requestOptions The options to use for the request.
 @param operationContext The operation context to use for the call.
 @param completionHandler The block of code to execute when the exists call completes.
 
 | Parameter name | Description |
 |----------------|-------------|
 |NSError * | Nil if the operation succeeded without error, error with details about the failure otherwise.|
 |BOOL      | YES if the container exists on the service, NO otherwise.|
 */
- (void)existsWithAccessCondition:(AZSNullable AZSAccessCondition *)accessCondition requestOptions:(AZSNullable AZSBlobRequestOptions *)requestOptions operationContext:(AZSNullable AZSOperationContext *)operationContext completionHandler:(void (^)(NSError* __AZSNullable, BOOL))completionHandler;

/** Creates the container on the service.  Will return success if the container already exists.
 
 @param completionHandler The block of code to execute when the create call completes.
 
 | Parameter name | Description |
 |----------------|-------------|
 |NSError * | Nil if the operation succeeded without error, error with details about the failure otherwise.|
 */
- (void)createContainerIfNotExistsWithCompletionHandler:(void (^)(NSError* __AZSNullable, BOOL))completionHandler;


/** Creates the container on the service.  Will return success if the container already exists.
 
 @param accessType The access type that the container should have.
 @param requestOptions The options to use for the request.
 @param operationContext The operation context to use for the call.
 @param completionHandler The block of code to execute when the create call completes.
 
 | Parameter name | Description |
 |----------------|-------------|
 |NSError * | Nil if the operation succeeded without error, error with details about the failure otherwise.|
 */
- (void)createContainerIfNotExistsWithAccessType:(AZSContainerPublicAccessType )accessType requestOptions:(AZSNullable AZSBlobRequestOptions *)requestOptions operationContext:(AZSNullable AZSOperationContext *)operationContext completionHandler:(void (^)(NSError* __AZSNullable, BOOL))completionHandler;

/** Deletes the container on the service.  Will return success if the container does not exist.
 
 @param completionHandler The block of code to execute when the delete call completes.
 
 | Parameter name | Description |
 |----------------|-------------|
 |NSError * | Nil if the operation succeeded without error, error with details about the failure otherwise.|
 */
- (void)deleteContainerIfExistsWithCompletionHandler:(void (^)(NSError* __AZSNullable, BOOL))completionHandler;

/** Deletes the container on the service.  Will return success if the container does not exist.
 
 @param accessCondition The access condition for the request.
 @param requestOptions The options to use for the request.
 @param operationContext The operation context to use for the call.
 @param completionHandler The block of code to execute when the delete call completes.
 
 | Parameter name | Description |
 |----------------|-------------|
 |NSError * | Nil if the operation succeeded without error, error with details about the failure otherwise.|
 */
- (void)deleteContainerIfExistsWithAccessCondition:(AZSNullable AZSAccessCondition *)accessCondition requestOptions:(AZSNullable AZSBlobRequestOptions *)requestOptions operationContext:(AZSNullable AZSOperationContext *)operationContext completionHandler:(void (^)(NSError* __AZSNullable, BOOL))completionHandler;

/** Performs one segmented blob listing operation.
 
 This method lists the blobs in the given container.  It will perform exactly one REST call, which will list blobs
 beginning with the container represented in the AZSContinuationToken.  If no token is provided, it will list 
 blobs from the beginning.  Only blobs that begin with the input prefix will be listed.
 
 Any number of blobs can be listed, from zero up to a set maximum.  Even if this method returns zero results, if
 the AZSContinuationToken in the result is not nil, there may be more containers on the service that have not been listed.
 
 Non-flat listing is currently not supported; this is coming soon.
 
 @param token The token representing where the listing operation should start.
 @param prefix The prefix to use for container listing.  Only containers that begin with the input prefix
 will be listed.
 @param useFlatBlobListing YES if the blob list should be flat (only blobs).
 @param blobListingDetails Details about how to list blobs.  See AZSBlobListingDetails for the possible options.
 @param maxResults The maximum number of results to return for this operation.  Use -1 to not set a limit.
 @param completionHandler The block of code to execute with the results of the listing operation.
 
 | Parameter name | Description |
 |----------------|-------------|
 |NSError * | Nil if the operation succeeded without error, error with details about the failure otherwise.|
 |AZSBlobResultSegment * | The blob result segment containing the result of the listing operation.|
 */
- (void)listBlobsSegmentedWithContinuationToken:(AZSNullable AZSContinuationToken *)token prefix:(AZSNullable NSString *)prefix useFlatBlobListing:(BOOL)useFlatBlobListing blobListingDetails:(AZSBlobListingDetails)blobListingDetails maxResults:(NSInteger)maxResults completionHandler:(void (^)(NSError * __AZSNullable, AZSBlobResultSegment * __AZSNullable))completionHandler;

/** Performs one segmented blob listing operation.
 
 This method lists the blobs in the given container.  It will perform exactly one REST call, which will list blobs
 beginning with the container represented in the AZSContinuationToken.  If no token is provided, it will list
 blobs from the beginning.  Only blobs that begin with the input prefix will be listed.
 
 Any number of blobs can be listed, from zero up to a set maximum.  Even if this method returns zero results, if
 the AZSContinuationToken in the result is not nil, there may be more containers on the service that have not been listed.
 
 Non-flat listing is currently not supported; this is coming soon.
 
 @param token The token representing where the listing operation should start.
 @param prefix The prefix to use for container listing.  Only containers that begin with the input prefix
 will be listed.
 @param useFlatBlobListing YES if the blob list should be flat (only blobs).
 @param blobListingDetails Details about how to list blobs.  See AZSBlobListingDetails for the possible options.
 @param maxResults The maximum number of results to return for this operation.  Use -1 to not set a limit.
 @param accessCondition The access condition for the request.
 @param requestOptions The options to use for the request.
 @param operationContext The operation context to use for the call.
 @param completionHandler The block of code to execute with the results of the listing operation.
 
 | Parameter name | Description |
 |----------------|-------------|
 |NSError * | Nil if the operation succeeded without error, error with details about the failure otherwise.|
 |AZSBlobResultSegment * | The blob result segment containing the result of the listing operation.|
 */
- (void)listBlobsSegmentedWithContinuationToken:(AZSNullable AZSContinuationToken *)token prefix:(AZSNullable NSString *)prefix useFlatBlobListing:(BOOL)useFlatBlobListing blobListingDetails:(AZSBlobListingDetails)blobListingDetails maxResults:(NSInteger)maxResults accessCondition:(AZSNullable AZSAccessCondition *)accessCondition requestOptions:(AZSNullable AZSBlobRequestOptions *)requestOptions operationContext:(AZSNullable AZSOperationContext *)operationContext completionHandler:(void (^)(NSError * __AZSNullable, AZSBlobResultSegment * __AZSNullable))completionHandler;

/** Initialize a local AZSCloudBlockBlob object
 
 This creates an AZSCloudBlockBlob object with the input name.
 
 TODO: Consider renaming this 'blockBlobFromName'.  This is better Objective-C style, but may confuse users into
 thinking that this method creates a blob on the service, which is does not.
 
 @warning This method does not make a service call.  If properties, metadata, etc have been set on the service
 for this blob, this will not be reflected in the local container object.
 @param blobName The name of the block blob (part of the URL)
 @return The new block blob object.
 */
- (AZSCloudBlockBlob *)blockBlobReferenceFromName:(NSString *)blobName;

/** Sets the container's user defined metadata.
 
 @param completionHandler The block of code to execute when the Upload Metadata call completes.
 
 | Parameter name | Description |
 |----------------|-------------|
 |NSError * | Nil if the operation succeeded without error, error with details about the failure otherwise.|
 */
- (void)uploadMetadataWithCompletionHandler:(void (^)(NSError* __AZSNullable))completionHandler;

/** Sets the container's user defined metadata.
 
 @param accessCondition The access condition for the request.
 @param requestOptions The options to use for the request.
 @param operationContext The operation context to use for the call.
 @param completionHandler The block of code to execute when the Upload Metadata call completes.
 
 | Parameter name | Description |
 |----------------|-------------|
 |NSError * | Nil if the operation succeeded without error, error with details about the failure otherwise.|
 */
- (void)uploadMetadataWithAccessCondition:(AZSNullable AZSAccessCondition *)accessCondition requestOptions:(AZSNullable AZSBlobRequestOptions *)requestOptions operationContext:(AZSNullable AZSOperationContext *)operationContext completionHandler:(void (^)(NSError* __AZSNullable))completionHandler;

/** Uploads a set of permissions for the container.
 
 @param permissions The permissions to upload.
 @param completionHandler The block of code to execute when the Upload Permissions call completes.
 
 | Parameter name | Description |
 |----------------|-------------|
 |NSError *       | Nil if the operation succeeded without error, error with details about the failure otherwise.|
 */
- (void)uploadPermissions:(AZSBlobContainerPermissions *)permissions completionHandler:(void (^)(NSError *))completionHandler;

/** Uploads a set of permissions for the container.
 
 @param permissions The permissions to upload.
 @param accessCondition The access conditions for the container.
 @param requestOptions Specifies any additional options for the request. Specifying nil will use the default request options from the associated client.
 @param operationContext Represents the context for the current operation.  Can be used to track requests to the storage service, and to provide additional runtime information about the operation.
 @param completionHandler The block of code to execute when the Upload Permissions call completes.
 
 | Parameter name | Description |
 |----------------|-------------|
 |NSError *       | Nil if the operation succeeded without error, error with details about the failure otherwise.|
 */
- (void)uploadPermissions:(AZSBlobContainerPermissions *)permissions accessCondition:(AZSAccessCondition * __AZSNullable)accessCondition requestOptions:(AZSBlobRequestOptions * __AZSNullable)requestOptions operationContext:(AZSOperationContext * __AZSNullable)operationContext completionHandler:(void (^)(NSError *))completionHandler;

/** Retrieves the container's attributes.
 
 @param completionHandler The block of code to execute when the Fetch Attributes call completes.
 
 | Parameter name | Description |
 |----------------|-------------|
 |NSError * | Nil if the operation succeeded without error, error with details about the failure otherwise.|
 */
- (void)fetchAttributesWithCompletionHandler:(void (^)(NSError* __AZSNullable))completionHandler;

/** Retrieves the container's attributes.
 
 @param accessCondition The access condition for the request.
 @param requestOptions The options to use for the request.
 @param operationContext The operation context to use for the call.
 @param completionHandler The block of code to execute when the Fetch Attributes call completes.
 
 | Parameter name | Description |
 |----------------|-------------|
 |NSError * | Nil if the operation succeeded without error, error with details about the failure otherwise.|
 */
- (void)fetchAttributesWithAccessCondition:(AZSNullable AZSAccessCondition *)accessCondition requestOptions:(AZSNullable AZSBlobRequestOptions *)requestOptions operationContext:(AZSNullable AZSOperationContext *)operationContext completionHandler:(void (^)(NSError* __AZSNullable))completionHandler;

/** Retrieves the stored container permissions.
 
 @param completionHandler The block of code to execute when the Download Permissions call completes.
 
 | Parameter name | Description |
 |----------------|-------------|
 |NSError * | Nil if the operation succeeded without error, error with details about the failure otherwise.|
 */
- (void)downloadPermissionsWithCompletionHandler:(void (^)(NSError* __AZSNullable, AZSBlobContainerPermissions * __AZSNullable))completionHandler;

/** Retrieves the stored container permissions.
 
 @param accessCondition The access condition for the request.
 @param requestOptions The options to use for the request.
 @param operationContext The operation context to use for the call.
 @param completionHandler The block of code to execute when the Download Permissions call completes.
 
 | Parameter name | Description |
 |----------------|-------------|
 |NSError * | Nil if the operation succeeded without error, error with details about the failure otherwise.|
 */
- (void)downloadPermissionsWithAccessCondition:(AZSAccessCondition * __AZSNullable)accessCondition requestOptions:(AZSBlobRequestOptions * __AZSNullable)requestOptions operationContext:(AZSNullable AZSOperationContext *)operationContext completionHandler:(void (^)(NSError* __AZSNullable, AZSBlobContainerPermissions * __AZSNullable))completionHandler;

/** Acquires a lease on this container.
 
 @param leaseTime The span of time for which to acquire the lease, rounded down to seconds. If NIL, an infinite lease will be acquired. Must be greater than zero.
 @param proposedLeaseId The proposed lease ID for the new lease, or NIL if no lease ID is proposed.
 @param completionHandler The block of code to execute when the Acquire Lease call completes.
 
 | Parameter name | Description |
 |----------------|-------------|
 |NSError * | Nil if the operation succeeded without error, error with details about the failure otherwise.|
 |NSString * | The ID of the acquired lease.|
 */
- (void)acquireLeaseWithLeaseTime:(AZSNullable NSNumber *) leaseTime proposedLeaseId:(AZSNullable NSString *)proposedLeaseId completionHandler:(void (^)(NSError* __AZSNullable, NSString * __AZSNullable))completionHandler;

/** Acquires a lease on this container.
 
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

/** Breaks the current lease on this container.
 
 @param breakPeriod The span of time for which to allow the lease to remain, rounded down to seconds. If NIL, the break period will be the remainder of the current lease or zero for an infinite lease.
 @param completionHandler The block of code to execute when the Break Lease call completes.
 
 | Parameter name | Description |
 |----------------|-------------|
 |NSError * | Nil if the operation succeeded without error, error with details about the failure otherwise.|
 |NSNumber * | The amount of time before the lease ends, to the second.|
 */
- (void)breakLeaseWithBreakPeriod:(AZSNullable NSNumber *) breakPeriod completionHandler:(void (^)(NSError* __AZSNullable, NSNumber* __AZSNullable))completionHandler;

/** Breaks the current lease on this container.
 
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

/** Changes the lease ID on this container.
 
 @param proposedLeaseId The proposed lease ID for the new lease, which cannot be null.
 @param accessCondition The access condition for the request.
 @param completionHandler The block of code to execute when the Change Lease call completes.
 
 | Parameter name | Description |
 |----------------|-------------|
 |NSError * | Nil if the operation succeeded without error, error with details about the failure otherwise.|
 |NSString * | The new lease ID.|
 */
- (void)changeLeaseWithProposedLeaseId:(NSString *) proposedLeaseId accessCondition:(AZSNullable AZSAccessCondition *)accessCondition completionHandler:(void (^)(NSError* __AZSNullable, NSString* __AZSNullable))completionHandler;

/** Changes the lease ID on this container.
 
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

/** Releases the lease on this container.
 
 @param accessCondition The access condition for the request.
 @param completionHandler The block of code to execute when the Release Lease call completes.
 
 | Parameter name | Description |
 |----------------|-------------|
 |NSError * | Nil if the operation succeeded without error, error with details about the failure otherwise.|
 */
- (void)releaseLeaseWithAccessCondition:(AZSNullable AZSAccessCondition *)accessCondition completionHandler:(void (^)(NSError* __AZSNullable))completionHandler;

/** Releases the lease on this container.
 
 @param accessCondition The access condition for the request.
 @param requestOptions The options to use for the request.
 @param operationContext The operation context to use for the call.
 @param completionHandler The block of code to execute when the Release Lease call completes.
 
 | Parameter name | Description |
 |----------------|-------------|
 |NSError * | Nil if the operation succeeded without error, error with details about the failure otherwise.|
 */
- (void)releaseLeaseWithAccessCondition:(AZSNullable AZSAccessCondition *)accessCondition requestOptions:(AZSNullable AZSBlobRequestOptions *)requestOptions operationContext:(AZSNullable AZSOperationContext *)operationContext completionHandler:(void (^)(NSError* __AZSNullable))completionHandler;

/** Renews a lease on this container.
 
 @param accessCondition The access condition for the request.
 @param completionHandler The block of code to execute when the Renew Lease call completes.
 
 | Parameter name | Description |
 |----------------|-------------|
 |NSError * | Nil if the operation succeeded without error, error with details about the failure otherwise.|
 */
- (void)renewLeaseWithAccessCondition:(AZSNullable AZSAccessCondition *)accessCondition completionHandler:(void (^)(NSError* __AZSNullable))completionHandler;

/** Renews a lease on this container.
 
 @param accessCondition The access condition for the request.
 @param requestOptions The options to use for the request.
 @param operationContext The operation context to use for the call.
 @param completionHandler The block of code to execute when the Renew Lease call completes.
 
 | Parameter name | Description |
 |----------------|-------------|
 |NSError * | Nil if the operation succeeded without error, error with details about the failure otherwise.|
 */
- (void)renewLeaseWithAccessCondition:(AZSNullable AZSAccessCondition *)accessCondition requestOptions:(AZSNullable AZSBlobRequestOptions *)requestOptions operationContext:(AZSNullable AZSOperationContext *)operationContext completionHandler:(void (^)(NSError* __AZSNullable))completionHandler;

/** Creates a Shared Access Signature (SAS) token from the given parameters for this Container.
 Note that logging in this method uses the global logger configured statically on the AZSOperationContext as there is no operation being performed to provide a local operation context.
 
 @param parameters The shared access blob parameters from which to create the SAS token.
 @param error A pointer to a NSError*, to be set in the event of failure.
 @returns The newly created SAS token.
 */
- (NSString *) createSharedAccessSignatureWithParameters:(AZSSharedAccessBlobParameters *)parameters error:(NSError **)error;

@end

AZS_ASSUME_NONNULL_END