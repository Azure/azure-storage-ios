// -----------------------------------------------------------------------------------------
// <copyright file="AZSCloudBlobClient.h" company="Microsoft">
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
#import "AZSCloudClient.h"
#import "AZSEnums.h"
#import "AZSMacros.h"

AZS_ASSUME_NONNULL_BEGIN

@class AZSStorageUri;
@class AZSStorageCredentials;
@class AZSCloudBlobContainer;
@class AZSContainerResultSegment;
@class AZSContinuationToken;
@class AZSBlobRequestOptions;
@class AZSOperationContext;
@class AZSServiceProperties;


// TODO: Figure out how to get this typedef to work with Appledocs.
//typedef void (^AZSListContainersSegmentedHandler) (NSError *, AZSContainerResultSegment *);

/** The AZSCloudBlobClient represents a the blob service for a given storage account.
 
 The AZSCloudBlobClient is used to perform service-level operations, including listing containers and
 (forthcoming) setting service-level properties.
 */
@interface AZSCloudBlobClient : AZSCloudClient

/** The default AZSBlobRequestOptions to use for all service calls made from this client.

 If you make a service call with the library and either do not provide an AZSBlobRequestOptions object, or do
 not set some subset of the options, the options set in this object will be used as defaults.  This object is
 used for both calls made on this client object, and calls made with AZSCloudBlobContainer and AZSCloudBlob objects
 created from this AZSCloudBlobClient object.*/
@property (strong, AZSNullable) AZSBlobRequestOptions *defaultRequestOptions;

/** The delimiter to use to separate out blob directories.
 */
@property (strong) NSString *directoryDelimiter;

- (instancetype)initWithStorageUri:(AZSStorageUri *) storageUri credentials:(AZSStorageCredentials *) credentials AZS_DESIGNATED_INITIALIZER;

/** Initialize a local AZSCloudBlobContainer object
 
 This creates an AZSCloudBlobContainer object with the input name.
 
 TODO: Consider renaming this 'containerFromName'.  This is better Objective-C style, but may confuse users into
 thinking that this method creates a container on the service, which is does not.
 
 @warning This method does not make a service call.  If properties, metadata, etc have been set on the service
 for this container, this will not be reflected in the local container object.
 @param containerName The name of the container (part of the URL)
 @return The new container object.
 */
- (AZSCloudBlobContainer *)containerReferenceFromName:(NSString *)containerName;

// TODO: Figure out the correct way to appledoc the continuationHandler parameters.

/** Performs one segmented container listing operation.
 
 This method lists the containers on the blob service for the associated account.  It will perform exactly one REST
 call, which will list containers beginning with the container represented in the AZSContinuationToken.  If no token
 is provided, it will list containers from the beginning.
 
 Any number of containers can be listed, from zero up to a set maximum.  Even if this method returns zero results, if
 the AZSContinuationToken in the result is not nil, there may be more containers on the service that have not been listed.
 
 @param continuationToken The token representing where the listing operation should start.
 @param completionHandler The block of code to execute with the results of the listing operation.
 
 | Parameter name | Description |
 |----------------|-------------|
 |NSError * | Nil if the operation succeeded without error, error with details about the failure otherwise.|
 |AZSContainerResultSegment * | The result segment containing the result of the listing operation.|
 */
- (void)listContainersSegmentedWithContinuationToken:(AZSNullable AZSContinuationToken *)continuationToken completionHandler:(void (^) (NSError * __AZSNullable, AZSContainerResultSegment * __AZSNullable))completionHandler;

/** Performs one segmented container listing operation.
 
 This method lists the containers on the blob service for the associated account.  It will perform exactly one REST
 call, which will list containers beginning with the container represented in the AZSContinuationToken.  If no token
 is provided, it will list containers from the beginning.  Only containers that begin with the input prefix will be listed.
 
 Any number of containers can be listed, from zero up to a set maximum.  Even if this method returns zero results, if
 the AZSContinuationToken in the result is not nil, there may be more containers on the service that have not been listed.
 
 @param continuationToken The token representing where the listing operation should start.
 @param prefix The prefix to use for container listing.  Only containers that begin with the input prefix
 will be listed.
 @param completionHandler The block of code to execute with the results of the listing operation.
 
 | Parameter name | Description |
 |----------------|-------------|
 |NSError * | Nil if the operation succeeded without error, error with details about the failure otherwise.|
 |AZSContainerResultSegment * | The result segment containing the result of the listing operation.|
 */
- (void)listContainersSegmentedWithContinuationToken:(AZSNullable AZSContinuationToken *)continuationToken prefix:(AZSNullable NSString *)prefix completionHandler:(void (^) (NSError * __AZSNullable, AZSContainerResultSegment * __AZSNullable))completionHandler;

/** Performs one segmented container listing operation.
 
 This method lists the containers on the blob service for the associated account.  It will perform exactly one REST
 call, which will list containers beginning with the container represented in the AZSContinuationToken.  If no token
 is provided, it will list containers from the beginning.  Only containers that begin with the input prefix will be listed.
 
 Any number of containers can be listed, from zero up to 'maxResults'.  Even if this method returns zero results, if
 the AZSContinuationToken in the result is not nil, there may be more containers on the service that have not been listed.
 
 @param continuationToken The token representing where the listing operation should start.
 @param prefix The prefix to use for container listing.  Only containers that begin with the input prefix
 will be listed.
 @param containerListingDetails Any additional data that should be returned in the listing operation.
 @param maxResults The maximum number of results to return.  The service will return up to this number of results.
 @param completionHandler The block of code to execute with the results of the listing operation.
 
 | Parameter name | Description |
 |----------------|-------------|
 |NSError * | Nil if the operation succeeded without error, error with details about the failure otherwise.|
 |AZSContainerResultSegment * | The result segment containing the result of the listing operation.|
 */
- (void)listContainersSegmentedWithContinuationToken:(AZSNullable AZSContinuationToken *)continuationToken prefix:(AZSNullable NSString *)prefix containerListingDetails:(AZSContainerListingDetails)containerListingDetails maxResults:(NSInteger)maxResults completionHandler:(void (^) (NSError * __AZSNullable, AZSContainerResultSegment * __AZSNullable))completionHandler;

/** Performs one segmented container listing operation.
 
 This method lists the containers on the blob service for the associated account.  It will perform exactly one REST
 call, which will list containers beginning with the container represented in the AZSContinuationToken.  If no token
 is provided, it will list containers from the beginning.  Only containers that begin with the input prefix will be listed.
 
 Any number of containers can be listed, from zero up to 'maxResults'.  Even if this method returns zero results, if
 the AZSContinuationToken in the result is not nil, there may be more containers on the service that have not been listed.
 
 @param continuationToken The token representing where the listing operation should start.
 @param prefix The prefix to use for container listing.  Only containers that begin with the input prefix
 will be listed.
 @param containerListingDetails Any additional data that should be returned in the listing operation.
 @param maxResults The maximum number of results to return.  The service will return up to this number of results.
 @param requestOptions The options to use for the request.
 @param operationContext The operation context to use for the call.
 @param completionHandler The block of code to execute with the results of the listing operation.
 
 | Parameter name | Description |
 |----------------|-------------|
 |NSError * | Nil if the operation succeeded without error, error with details about the failure otherwise.|
 |AZSContainerResultSegment * | The result segment containing the result of the listing operation.|
 */
- (void)listContainersSegmentedWithContinuationToken:(AZSNullable AZSContinuationToken *)continuationToken prefix:(AZSNullable NSString *)prefix containerListingDetails:(AZSContainerListingDetails)containerListingDetails maxResults:(NSInteger)maxResults requestOptions:(AZSNullable AZSBlobRequestOptions *)requestOptions operationContext:(AZSNullable AZSOperationContext *)operationContext completionHandler:(void (^) (NSError * __AZSNullable, AZSContainerResultSegment * __AZSNullable))completionHandler;

/** Uploads service properties.

 @param serviceProperties The service properties to upload.
 @param completionHandler The block of code to execute when the Upload Permissions call completes.

 | Parameter name | Description |
 |----------------|-------------|
 |NSError *       | Nil if the operation succeeded without error, error with details about the failure otherwise.|
 */
- (void)uploadServicePropertiesWithServiceProperties:(AZSServiceProperties *)serviceProperties completionHandler:(void (^)(NSError * __AZSNullable))completionHandler;

/** Uploads service properties.

 @param serviceProperties The service properties to upload.
 @param requestOptions Specifies any additional options for the request. Specifying nil will use the default request options from the associated client.
 @param operationContext Represents the context for the current operation.  Can be used to track requests to the storage service, and to provide additional runtime information about the operation.
 @param completionHandler The block of code to execute when the Upload Service Properties call completes.

 | Parameter name | Description |
 |----------------|-------------|
 |NSError *       | Nil if the operation succeeded without error, error with details about the failure otherwise.|
 */
- (void)uploadServicePropertiesWithServiceProperties:(AZSServiceProperties *)serviceProperties requestOptions:(AZSNullable AZSBlobRequestOptions *)requestOptions operationContext:(AZSNullable AZSOperationContext *)operationContext completionHandler:(void (^)(NSError * __AZSNullable))completionHandler;

/** Retrieves the stored service properties.

 @param completionHandler The block of code to execute when the Download Service Properties call completes.

 | Parameter name | Description |
 |----------------|-------------|
 |NSError * | Nil if the operation succeeded without error, error with details about the failure otherwise.|
 |AZSServiceProperties * | The resulting service properties returned from the get service properties operation.|
 */
- (void)downloadServicePropertiesWithCompletionHandler:(void (^)(NSError* __AZSNullable, AZSServiceProperties * __AZSNullable))completionHandler;

/** Retrieves the stored service properties.

 @param requestOptions The options to use for the request.
 @param operationContext The operation context to use for the call.
 @param completionHandler The block of code to execute when the Download Service Properties call completes.

 | Parameter name | Description |
 |----------------|-------------|
 |NSError * | Nil if the operation succeeded without error, error with details about the failure otherwise.|
 |AZSServiceProperties * | The resulting service properties returned from the get service properties operation.|
 */
- (void)downloadServicePropertiesWithCompletionHandler:(AZSNullable AZSBlobRequestOptions *)requestOptions operationContext:(AZSNullable AZSOperationContext *)operationContext completionHandler:(void (^)(NSError* __AZSNullable, AZSServiceProperties * __AZSNullable))completionHandler;

@end

AZS_ASSUME_NONNULL_END
