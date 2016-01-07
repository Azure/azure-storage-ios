// -----------------------------------------------------------------------------------------
// <copyright file="AZSBlobRequestFactory.h" company="Microsoft">
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
@class AZSOperationContext;
@class AZSRequestResult;
@class AZSAccessCondition;
@class AZSContinuationToken;
@class AZSBlobProperties;
@class AZSBlobContainerProperties;
@class AZSBlobRequestOptions;
@class AZSCopyState;

@interface AZSBlobRequestFactory : NSObject
// Container
+(NSMutableURLRequest *) createContainerWithAccessType:(AZSContainerPublicAccessType)accessType cloudMetadata:(NSMutableDictionary *)cloudMetadata urlComponents:(NSURLComponents *)urlComponents timeout:(NSTimeInterval)timeout operationContext:(AZSOperationContext *)operationContext;
+(NSMutableURLRequest *) deleteContainerWithAccessCondition:(AZSAccessCondition *)accessCondition urlComponents:(NSURLComponents *)urlComponents timeout:(NSTimeInterval)timeout operationContext:(AZSOperationContext *)operationContext;
+(NSMutableURLRequest *) listContainersWithPrefix:(NSString *)prefix containerListingDetails:(AZSContainerListingDetails)containerListingDetails maxResults:(NSInteger)maxResults continuationToken:(AZSContinuationToken *)continuationToken urlComponents:(NSURLComponents *)urlComponents timeout:(NSTimeInterval)timeout operationContext:(AZSOperationContext *)operationContext;
+(NSMutableURLRequest *) uploadContainerMetadataWithCloudMetadata:(NSMutableDictionary *)cloudMetadata accessCondition:(AZSAccessCondition *)accessCondition urlComponents:(NSURLComponents *)urlComponents timeout:(NSTimeInterval)timeout operationContext:(AZSOperationContext *) operationContext;
+(NSMutableURLRequest *) downloadContainerAttributesWithAccessCondition:(AZSAccessCondition *)accessCondition urlComponents:(NSURLComponents *)urlComponents timeout:(NSTimeInterval)timeout operationContext:(AZSOperationContext *)operationContext;
+(NSMutableURLRequest *) downloadContainerPermissionsWithAccessCondition:(AZSAccessCondition *)accessCondition urlComponents:(NSURLComponents *)urlComponents timeout:(NSTimeInterval)timeout operationContext:(AZSOperationContext *)operationContext;
+(NSMutableURLRequest *) leaseContainerWithLeaseAction:(AZSLeaseAction)leaseAction proposedLeaseId:(NSString *)proposedLeaseId leaseDuration:(NSNumber *)leaseDuration leaseBreakPeriod:(NSNumber *)leaseBreakPeriod accessCondition:(AZSAccessCondition *)accessCondition urlComponents:(NSURLComponents *)urlComponents timeout:(NSTimeInterval)timeout operationContext:(AZSOperationContext *)operationContext;
+(NSMutableURLRequest *) uploadContainerPermissionsWithLength:(NSUInteger)length urlComponents:(NSURLComponents *)urlComponents options:(AZSBlobRequestOptions *)options accessCondition:(AZSAccessCondition *)accessCondition publicAccess:(AZSContainerPublicAccessType)publicAccess timeout:(NSTimeInterval)timeout operationContext:(AZSOperationContext *)operationContext;

// Blob
+(NSMutableURLRequest *) putBlockBlobWithLength:(NSUInteger)length blobProperties:(AZSBlobProperties *)blobPropertes contentMD5:(NSString *)contentMD5 cloudMetadata:(NSMutableDictionary *)cloudMetadata AccessCondition:(AZSAccessCondition *)accessCondition urlComponents:(NSURLComponents *)urlComponents timeout:(NSTimeInterval)timeout operationContext:(AZSOperationContext *)operationContext;
+(NSMutableURLRequest *) putBlockWithLength:(NSUInteger)length blockID:(NSString *)blockID contentMD5:(NSString *)contentMD5 AccessCondition:(AZSAccessCondition *)accessCondition urlComponents:(NSURLComponents *)urlComponents timeout:(NSTimeInterval)timeout operationContext:(AZSOperationContext *)operationContext;
+(NSMutableURLRequest *) putBlockListWithLength:(NSUInteger)length blobProperties:(AZSBlobProperties *)blobPropertes contentMD5:(NSString *)contentMD5 cloudMetadata:(NSMutableDictionary *)cloudMetadata AccessCondition:(AZSAccessCondition *)accessCondition urlComponents:(NSURLComponents *)urlComponents timeout:(NSTimeInterval)timeout operationContext:(AZSOperationContext *)operationContext;
+(NSMutableURLRequest *) getBlobWithSnapshotTime:(NSString *)snapshotTime range:(NSRange)range getRangeContentMD5:(BOOL)getRangeContentMD5 accessCondition:(AZSAccessCondition *)accessCondition urlComponents:(NSURLComponents *)urlComponents timeout:(NSTimeInterval)timeout operationContext:(AZSOperationContext *)operationContext;
+(NSMutableURLRequest *) getBlockListWithBlockListFilter:(AZSBlockListFilter)blockListFilter snapshotTime:(NSString *)snapshotTime accessCondition:(AZSAccessCondition *)accessCondition urlComponents:(NSURLComponents *)urlComponents timeout:(NSTimeInterval)timeout operationContext:(AZSOperationContext *)operationContext;
+(NSMutableURLRequest *) deleteBlobWithSnapshotsOption:(AZSDeleteSnapshotsOption)deleteSnapshotsOption snapshotTime:(NSString *)snapshotTime accessCondition:(AZSAccessCondition *)accessCondition urlComponents:(NSURLComponents *)urlComponents timeout:(NSTimeInterval)timeout operationContext:(AZSOperationContext *)operationContext;
+(NSMutableURLRequest *) listBlobsWithPrefix:(NSString *)prefix delimiter:(NSString *)delimiter blobListingDetails:(AZSBlobListingDetails)blobListingDetails maxResults:(NSInteger)maxResults continuationToken:(AZSContinuationToken *)continuationToken urlComponents:(NSURLComponents *)urlComponents timeout:(NSTimeInterval)timeout operationContext:(AZSOperationContext *)operationContext;
+(NSMutableURLRequest *) uploadBlobMetadataWithCloudMetadata:(NSMutableDictionary *)cloudMetadata accessCondition:(AZSAccessCondition *)accessCondition urlComponents:(NSURLComponents *)urlComponents timeout:(NSTimeInterval)timeout operationContext:(AZSOperationContext *) operationContext;
+(NSMutableURLRequest *) uploadBlobPropertiesWithBlobProperties:(AZSBlobProperties *)blobProperties cloudMetadata:(NSMutableDictionary *)cloudMetadata accessCondition:(AZSAccessCondition *)accessCondition urlComponents:(NSURLComponents *)urlComponents timeout:(NSTimeInterval)timeout operationContext:(AZSOperationContext *) operationContext;
+(NSMutableURLRequest *) downloadBlobAttributesWithAccessCondition:(AZSAccessCondition *)accessCondition snapshotTime:(NSString *)snapshotTime urlComponents:(NSURLComponents *)urlComponents timeout:(NSTimeInterval)timeout operationContext:(AZSOperationContext *)operationContext;
+(NSMutableURLRequest *) snapshotBlobWithMetadata:(NSDictionary *)metadata accessCondition:(AZSAccessCondition *)accessCondition urlComponents:(NSURLComponents *)urlComponents timeout:(NSTimeInterval)timeout operationContext:(AZSOperationContext *)operationContext;
+(NSMutableURLRequest *) leaseBlobWithLeaseAction:(AZSLeaseAction)leaseAction proposedLeaseId:(NSString *)proposedLeaseId leaseDuration:(NSNumber *)leaseDuration leaseBreakPeriod:(NSNumber *)leaseBreakPeriod accessCondition:(AZSAccessCondition *)accessCondition urlComponents:(NSURLComponents *)urlComponents timeout:(NSTimeInterval)timeout operationContext:(AZSOperationContext *)operationContext;
+(NSMutableURLRequest *) copyBlobWithSourceURL:(NSURL *)sourceURL sourceAccessCondition:(AZSAccessCondition *)sourceAccessCondition cloudMetadata:(NSMutableDictionary *)cloudMetadata accessCondition:(AZSAccessCondition *)accessCondition urlComponents:(NSURLComponents *)urlComponents timeout:(NSTimeInterval)timeout operationContext:(AZSOperationContext *)operationContext;
+(NSMutableURLRequest *) abortCopyBlobWithCopyId:(NSString *)copyId accessCondition:(AZSAccessCondition *)accessCondition urlComponents:(NSURLComponents *)urlComponents timeout:(NSTimeInterval)timeout operationContext:(AZSOperationContext *)operationContext;

@end