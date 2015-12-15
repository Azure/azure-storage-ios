// -----------------------------------------------------------------------------------------
// <copyright file="AZSCloudBlobDirectory.h" company="Microsoft">
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
#import "AZSEnums.h"
#import "AZSConstants.h"

AZS_ASSUME_NONNULL_BEGIN

@class AZSCloudBlockBlob;
@class AZSCloudBlobContainer;
@class AZSStorageUri;
@class AZSCloudBlobClient;
@class AZSContinuationToken;
@class AZSBlobResultSegment;
@class AZSBlobRequestOptions;
@class AZSOperationContext;
@class AZSAccessCondition;
@class AZSCloudPageBlob;
@class AZSCloudAppendBlob;

@interface AZSCloudBlobDirectory : NSObject

/** The container in which this blob directory exists.*/
@property (strong, readonly) AZSCloudBlobContainer *blobContainer;

/** The full StorageURI to this blob directory.*/
@property (strong, readonly) AZSStorageUri *storageUri;

/** The blob client representing the blob service for this blob directory.*/
@property (strong, readonly) AZSCloudBlobClient *client;

/** The name of this directory.*/
@property (strong, readonly) NSString *name;

/** Initializes a newly allocated AZSCloudBlockDirectory object
 
 @param directoryName The name of the directory.  This should be the path to the directory,
 relative to the container name.  For example:
 
 If the full URI to the directory is
 https://myaccount.blob.core.windows.net/mycontainer/dir1/dir2/dir3
 then this parameter should be:
 dir1/dir2/dir3.
 
 @param container The AZSCloudBlobContainer in which the container exists.
 @return The newly allocated instance.
 */
- (instancetype)initWithDirectoryName:(NSString *)directoryName container:(AZSCloudBlobContainer *)container AZS_DESIGNATED_INITIALIZER;

/** Initialize a local AZSCloudBlockBlob object
 
 This creates an AZSCloudBlockBlob object with the input name.
 
 TODO: Consider renaming this 'blockBlobFromName'.  This is better Objective-C style, but may confuse users into
 thinking that this method creates a blob on the service, which is does not.
 
 @warning This method does not make a service call.  If properties, metadata, etc have been set on the service
 for this blob, this will not be reflected in the local container object.
 @param blobName The name of the block blob (part of the URL)
 @return The block blob object.
 */
- (AZSCloudBlockBlob *)blockBlobReferenceFromName:(NSString *)blobName;

/** Initialize a local AZSCloudBlockBlob object
 
 This creates an AZSCloudBlockBlob object with the input name.
 
 TODO: Consider renaming this 'blockBlobFromName'.  This is better Objective-C style, but may confuse users into
 thinking that this method creates a blob on the service, which is does not.
 
 @warning This method does not make a service call.  If properties, metadata, etc have been set on the service
 for this blob, this will not be reflected in the local container object.
 @param blobName The name of the block blob (part of the URL)
 @param snapshotTime The snapshot time for the blob.  Nil means the root blob (not a snapshot).
 @return The block blob object.
 */
- (AZSCloudBlockBlob *)blockBlobReferenceFromName:(NSString *)blobName snapshotTime:(AZSNullable NSString *)snapshotTime;

/** Initialize a local AZSCloudPageBlob object
 
 This creates an AZSCloudPageBlob object with the input name.
 
 @warning This method does not make a service call.  If properties, metadata, etc have been set on the service
 for this blob, this will not be reflected in the local container object.
 @param blobName The name of the page blob (part of the URL)
 @return The new page blob object.
 */
- (AZSCloudPageBlob *)pageBlobReferenceFromName:(NSString *)blobName;

/** Initialize a local AZSCloudPageBlob object
 
 This creates an AZSCloudPageBlob object with the input name.
 
 @warning This method does not make a service call.  If properties, metadata, etc have been set on the service
 for this blob, this will not be reflected in the local container object.
 @param blobName The name of the page blob (part of the URL)
 @param snapshotTime The snapshot time for the blob.  Nil means the root blob (not a snapshot).
 @return The new page blob object.
 */
- (AZSCloudPageBlob *)pageBlobReferenceFromName:(NSString *)blobName snapshotTime:(AZSNullable NSString *)snapshotTime;

/** Initialize a local AZSCloudAppendBlob object
 
 This creates an AZSCloudAppendBlob object with the input name.
 
 @warning This method does not make a service call.  If properties, metadata, etc have been set on the service
 for this blob, this will not be reflected in the local container object.
 @param blobName The name of the append blob (part of the URL)
 @return The new append blob object.
 */
- (AZSCloudAppendBlob *)appendBlobReferenceFromName:(NSString *)blobName;

/** Initialize a local AZSCloudAppendBlob object
 
 This creates an AZSCloudAppendBlob object with the input name.
 
 @warning This method does not make a service call.  If properties, metadata, etc have been set on the service
 for this blob, this will not be reflected in the local container object.
 @param blobName The name of the block blob (part of the URL)
 @param snapshotTime The snapshot time for the blob.  Nil means the root blob (not a snapshot).
 @return The new block blob object.
 */
- (AZSCloudAppendBlob *)appendBlobReferenceFromName:(NSString *)blobName snapshotTime:(AZSNullable NSString *)snapshotTime;

/** Initialize a AZSCloudBlobDiretory object that represents the 'parent' directory of the current object.
 
 For example, if the current directory has the name:
 
 "sample/a/b/c"
 
 this method will return a new CloudBlobDirectory object with the name:
 
 "sample/a/b".
 
 The delimiter used is the one set in self.client.
 
 @return The newly allocated parent directory object.
 */
- (AZSCloudBlobDirectory *)parentReference;

/** Initialize a AZSCloudBlobDiretory object that represents the 'child' directory of the current object.
 
 For example, if the current directory has the name:
 
 "sample/a/b/c"
 
 and this method is called with input "next", it will return a new CloudBlobDirectory object with the name:
 
 "sample/a/b/c/next".
 
 The delimiter used is the one set in self.client.
 
 @param subdirectoryName The name of the subdirectory.
 @return The newly allocated subdirectory object.
 */
- (AZSCloudBlobDirectory *)subdirectoryReferenceFromName:(NSString *)subdirectoryName;

/** Performs one segmented blob listing operation.
 
 This method lists the blobs in the given directory.  It will perform exactly one REST call, which will list blobs
 beginning with the directory represented in the AZSContinuationToken.  If no token is provided, it will list
 blobs from the beginning.  Only blobs that begin with the input prefix will be listed.
 
 Any number of blobs can be listed, from zero up to a set maximum.  Even if this method returns zero results, if
 the AZSContinuationToken in the result is not nil, there may be more blobs on the service that have not been listed.
 
 @param token The token representing where the listing operation should start.
 @param useFlatBlobListing YES if the blob list should be flat (list all blobs as if their names were only strings, no directories).  NO if it should list with directories.
 @param blobListingDetails Details about how to list blobs.  See AZSBlobListingDetails for the possible options.
 @param maxResults The maximum number of results to return for this operation.  Use -1 to not set a limit.
 @param completionHandler The block of code to execute with the results of the listing operation.
 
 | Parameter name | Description |
 |----------------|-------------|
 |NSError * | Nil if the operation succeeded without error, error with details about the failure otherwise.|
 |AZSBlobResultSegment * | The blob result segment containing the result of the listing operation.|
 */
- (void)listBlobsSegmentedWithContinuationToken:(AZSNullable AZSContinuationToken *)token useFlatBlobListing:(BOOL)useFlatBlobListing blobListingDetails:(AZSBlobListingDetails)blobListingDetails maxResults:(NSInteger)maxResults completionHandler:(void (^)(NSError * __AZSNullable, AZSBlobResultSegment * __AZSNullable))completionHandler;

/** Performs one segmented blob listing operation.
 
 This method lists the blobs in the given directory.  It will perform exactly one REST call, which will list blobs
 beginning with the directory represented in the AZSContinuationToken.  If no token is provided, it will list
 blobs from the beginning.  Only blobs that begin with the input prefix will be listed.
 
 Any number of blobs can be listed, from zero up to a set maximum.  Even if this method returns zero results, if
 the AZSContinuationToken in the result is not nil, there may be more blobs on the service that have not been listed.
 
 @param token The token representing where the listing operation should start.
 @param useFlatBlobListing YES if the blob list should be flat (list all blobs as if their names were only strings, no directories).  NO if it should list with directories.
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
- (void)listBlobsSegmentedWithContinuationToken:(AZSNullable AZSContinuationToken *)token useFlatBlobListing:(BOOL)useFlatBlobListing blobListingDetails:(AZSBlobListingDetails)blobListingDetails maxResults:(NSInteger)maxResults accessCondition:(AZSNullable AZSAccessCondition *)accessCondition requestOptions:(AZSNullable AZSBlobRequestOptions *)requestOptions operationContext:(AZSNullable AZSOperationContext *)operationContext completionHandler:(void (^)(NSError * __AZSNullable, AZSBlobResultSegment * __AZSNullable))completionHandler;

@end

AZS_ASSUME_NONNULL_END