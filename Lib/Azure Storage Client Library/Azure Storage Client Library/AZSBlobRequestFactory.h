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
#import "AZSULLRange.h"
@class AZSOperationContext;
@class AZSRequestResult;
@class AZSAccessCondition;
@class AZSContinuationToken;
@class AZSBlobProperties;
@class AZSBlobContainerProperties;
@class AZSBlobRequestOptions;
@class AZSCopyState;

@interface AZSBlobRequestFactory : NSObject

// Service
+(NSMutableURLRequest *) uploadServicePropertiesWithLength:(NSUInteger)length urlComponents:(NSURLComponents *)urlComponents options:(AZSBlobRequestOptions *)options timeout:(NSTimeInterval)timeout operationContext:(AZSOperationContext *)operationContext;
+(NSMutableURLRequest *) downloadServicePropertiesWithUrlComponents:(NSURLComponents *)urlComponents timeout:(NSTimeInterval)timeout operationContext:(AZSOperationContext *)operationContext;

// Container
+(NSMutableURLRequest *) createContainerWithAccessType:(AZSContainerPublicAccessType)accessType cloudMetadata:(NSMutableDictionary *)cloudMetadata urlComponents:(NSURLComponents *)urlComponents timeout:(NSTimeInterval)timeout operationContext:(AZSOperationContext *)operationContext;
+(NSMutableURLRequest *) deleteContainerWithAccessCondition:(AZSAccessCondition *)accessCondition urlComponents:(NSURLComponents *)urlComponents timeout:(NSTimeInterval)timeout operationContext:(AZSOperationContext *)operationContext;
+(NSMutableURLRequest *) listContainersWithPrefix:(NSString *)prefix containerListingDetails:(AZSContainerListingDetails)containerListingDetails maxResults:(NSInteger)maxResults continuationToken:(AZSContinuationToken *)continuationToken urlComponents:(NSURLComponents *)urlComponents timeout:(NSTimeInterval)timeout operationContext:(AZSOperationContext *)operationContext;
+(NSMutableURLRequest *) uploadContainerMetadataWithCloudMetadata:(NSMutableDictionary *)cloudMetadata accessCondition:(AZSAccessCondition *)accessCondition urlComponents:(NSURLComponents *)urlComponents timeout:(NSTimeInterval)timeout operationContext:(AZSOperationContext *) operationContext;
+(NSMutableURLRequest *) downloadContainerAttributesWithAccessCondition:(AZSAccessCondition *)accessCondition urlComponents:(NSURLComponents *)urlComponents timeout:(NSTimeInterval)timeout operationContext:(AZSOperationContext *)operationContext;
+(NSMutableURLRequest *) downloadContainerPermissionsWithAccessCondition:(AZSAccessCondition *)accessCondition urlComponents:(NSURLComponents *)urlComponents timeout:(NSTimeInterval)timeout operationContext:(AZSOperationContext *)operationContext;
+(NSMutableURLRequest *) leaseContainerWithLeaseAction:(AZSLeaseAction)leaseAction proposedLeaseId:(NSString *)proposedLeaseId leaseDuration:(NSNumber *)leaseDuration leaseBreakPeriod:(NSNumber *)leaseBreakPeriod accessCondition:(AZSAccessCondition *)accessCondition urlComponents:(NSURLComponents *)urlComponents timeout:(NSTimeInterval)timeout operationContext:(AZSOperationContext *)operationContext;
+(NSMutableURLRequest *) uploadContainerPermissionsWithLength:(NSUInteger)length urlComponents:(NSURLComponents *)urlComponents options:(AZSBlobRequestOptions *)options accessCondition:(AZSAccessCondition *)accessCondition publicAccess:(AZSContainerPublicAccessType)publicAccess timeout:(NSTimeInterval)timeout operationContext:(AZSOperationContext *)operationContext;

// All blobs
+(NSMutableURLRequest *) getBlobWithSnapshotTime:(NSString *)snapshotTime range:(AZSULLRange)range getRangeContentMD5:(BOOL)getRangeContentMD5 accessCondition:(AZSAccessCondition *)accessCondition urlComponents:(NSURLComponents *)urlComponents timeout:(NSTimeInterval)timeout operationContext:(AZSOperationContext *)operationContext;
+(NSMutableURLRequest *) deleteBlobWithSnapshotsOption:(AZSDeleteSnapshotsOption)deleteSnapshotsOption snapshotTime:(NSString *)snapshotTime accessCondition:(AZSAccessCondition *)accessCondition urlComponents:(NSURLComponents *)urlComponents timeout:(NSTimeInterval)timeout operationContext:(AZSOperationContext *)operationContext;
+(NSMutableURLRequest *) listBlobsWithPrefix:(NSString *)prefix delimiter:(NSString *)delimiter blobListingDetails:(AZSBlobListingDetails)blobListingDetails maxResults:(NSInteger)maxResults continuationToken:(AZSContinuationToken *)continuationToken urlComponents:(NSURLComponents *)urlComponents timeout:(NSTimeInterval)timeout operationContext:(AZSOperationContext *)operationContext;
+(NSMutableURLRequest *) uploadBlobMetadataWithCloudMetadata:(NSMutableDictionary *)cloudMetadata accessCondition:(AZSAccessCondition *)accessCondition urlComponents:(NSURLComponents *)urlComponents timeout:(NSTimeInterval)timeout operationContext:(AZSOperationContext *) operationContext;
+(NSMutableURLRequest *) uploadBlobPropertiesWithBlobProperties:(AZSBlobProperties *)blobProperties cloudMetadata:(NSMutableDictionary *)cloudMetadata accessCondition:(AZSAccessCondition *)accessCondition urlComponents:(NSURLComponents *)urlComponents timeout:(NSTimeInterval)timeout operationContext:(AZSOperationContext *) operationContext;
+(NSMutableURLRequest *) downloadBlobAttributesWithAccessCondition:(AZSAccessCondition *)accessCondition snapshotTime:(NSString *)snapshotTime urlComponents:(NSURLComponents *)urlComponents timeout:(NSTimeInterval)timeout operationContext:(AZSOperationContext *)operationContext;
+(NSMutableURLRequest *) snapshotBlobWithMetadata:(NSDictionary *)metadata accessCondition:(AZSAccessCondition *)accessCondition urlComponents:(NSURLComponents *)urlComponents timeout:(NSTimeInterval)timeout operationContext:(AZSOperationContext *)operationContext;
+(NSMutableURLRequest *) leaseBlobWithLeaseAction:(AZSLeaseAction)leaseAction proposedLeaseId:(NSString *)proposedLeaseId leaseDuration:(NSNumber *)leaseDuration leaseBreakPeriod:(NSNumber *)leaseBreakPeriod accessCondition:(AZSAccessCondition *)accessCondition urlComponents:(NSURLComponents *)urlComponents timeout:(NSTimeInterval)timeout operationContext:(AZSOperationContext *)operationContext;
+(NSMutableURLRequest *) copyBlobWithSourceURL:(NSURL *)sourceURL sourceAccessCondition:(AZSAccessCondition *)sourceAccessCondition cloudMetadata:(NSMutableDictionary *)cloudMetadata accessCondition:(AZSAccessCondition *)accessCondition urlComponents:(NSURLComponents *)urlComponents timeout:(NSTimeInterval)timeout operationContext:(AZSOperationContext *)operationContext;
+(NSMutableURLRequest *) abortCopyBlobWithCopyId:(NSString *)copyId accessCondition:(AZSAccessCondition *)accessCondition urlComponents:(NSURLComponents *)urlComponents timeout:(NSTimeInterval)timeout operationContext:(AZSOperationContext *)operationContext;

// Block blobs
+(NSMutableURLRequest *) putBlockBlobWithLength:(NSUInteger)length blobProperties:(AZSBlobProperties *)blobPropertes contentMD5:(NSString *)contentMD5 cloudMetadata:(NSMutableDictionary *)cloudMetadata AccessCondition:(AZSAccessCondition *)accessCondition urlComponents:(NSURLComponents *)urlComponents timeout:(NSTimeInterval)timeout operationContext:(AZSOperationContext *)operationContext;
+(NSMutableURLRequest *) putBlockWithLength:(NSUInteger)length blockID:(NSString *)blockID contentMD5:(NSString *)contentMD5 accessCondition:(AZSAccessCondition *)accessCondition urlComponents:(NSURLComponents *)urlComponents timeout:(NSTimeInterval)timeout operationContext:(AZSOperationContext *)operationContext;
+(NSMutableURLRequest *) putBlockListWithLength:(NSUInteger)length blobProperties:(AZSBlobProperties *)blobPropertes contentMD5:(NSString *)contentMD5 cloudMetadata:(NSMutableDictionary *)cloudMetadata AccessCondition:(AZSAccessCondition *)accessCondition urlComponents:(NSURLComponents *)urlComponents timeout:(NSTimeInterval)timeout operationContext:(AZSOperationContext *)operationContext;
+(NSMutableURLRequest *) getBlockListWithBlockListFilter:(AZSBlockListFilter)blockListFilter snapshotTime:(NSString *)snapshotTime accessCondition:(AZSAccessCondition *)accessCondition urlComponents:(NSURLComponents *)urlComponents timeout:(NSTimeInterval)timeout operationContext:(AZSOperationContext *)operationContext;

// Page blobs
+(NSMutableURLRequest *) createPageBlobWithSize:(NSNumber *)totalBlobSize sequenceNumber:(NSNumber *)sequenceNumber blobProperties:(AZSBlobProperties *)blobProperties cloudMetadata:(NSMutableDictionary *)cloudMetadata accessCondition:(AZSAccessCondition *)accessCondition urlComponents:(NSURLComponents *)urlComponents timeout:(NSTimeInterval)timeout operationContext:(AZSOperationContext *)operationContext;
+(NSMutableURLRequest *) putPagesWithPageRange:(AZSULLRange)pageRange clear:(BOOL)clear contentMD5:(NSString *)contentMD5 accessCondition:(AZSAccessCondition *)accessCondition urlComponents:(NSURLComponents *)urlComponents timeout:(NSTimeInterval)timeout operationContext:(AZSOperationContext *)operationContext;
+(NSMutableURLRequest *) getPageRangesWithRange:(AZSULLRange)range snapshotTime:(NSString *)snapshotTime accessCondition:(AZSAccessCondition *)accessCondition urlComponents:(NSURLComponents *)urlComponents timeout:(NSTimeInterval)timeout operationContext:(AZSOperationContext *)operationContext;
+(NSMutableURLRequest *) resizePageBlobWithSize:(NSNumber *)totalBlobSize accessCondition:(AZSAccessCondition *)accessCondition urlComponents:(NSURLComponents *)urlComponents timeout:(NSTimeInterval)timeout operationContext:(AZSOperationContext *)operationContext;
+(NSMutableURLRequest *) setPageBlobSequenceNumberWithNewSequenceNumber:(NSNumber *)newSequenceNumber isIncrement:(BOOL)isIncrement useMaximum:(BOOL)useMaximum accessCondition:(AZSAccessCondition *)accessCondition urlComponents:(NSURLComponents *)urlComponents timeout:(NSTimeInterval)timeout operationContext:(AZSOperationContext *)operationContext;

// Append blobs
+(NSMutableURLRequest *) createAppendBlobWithBlobProperties:(AZSBlobProperties *)blobProperties cloudMetadata:(NSMutableDictionary *)cloudMetadata accessCondition:(AZSAccessCondition *)accessCondition urlComponents:(NSURLComponents *)urlComponents timeout:(NSTimeInterval)timeout operationContext:(AZSOperationContext *)operationContext;
+(NSMutableURLRequest *) appendBlockWithLength:(NSUInteger)length contentMD5:(NSString *)contentMD5 accessCondition:(AZSAccessCondition *)accessCondition urlComponents:(NSURLComponents *)urlComponents timeout:(NSTimeInterval)timeout operationContext:(AZSOperationContext *)operationContext;

+(void) addBlobPropertiesToRequest:(NSMutableURLRequest*)request properties:(AZSBlobProperties*)blobProperties;
+(void) addLeaseActionToRequest:(NSMutableURLRequest*)request leaseAction:(AZSLeaseAction)leaseAction;
+(void) addLeaseDurationToRequest:(NSMutableURLRequest*)request leaseDuration:(NSNumber*)leaseDuration;
+(void) addProposedLeaseIdToRequest:(NSMutableURLRequest*)request proposedLeaseId:(NSString*)proposedLeaseId;
+(void) addLeaseBreakPeriodToRequest:(NSMutableURLRequest*)request leaseBreakPeriod:(NSNumber*)leaseBreakPeriod;

@end
