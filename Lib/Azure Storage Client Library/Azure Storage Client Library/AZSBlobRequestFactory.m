// -----------------------------------------------------------------------------------------
// <copyright file="AZSBlobRequestFactory.m" company="Microsoft">
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

#import "AZSBlobRequestFactory.h"
#import "AZSAccessCondition.h"
#import "AZSConstants.h"
#import "AZSContinuationToken.h"
#import "AZSBlobContainerProperties.h"
#import "AZSEnums.h"
#import "AZSCopyState.h"
#import "AZSBlobProperties.h"
#import "AZSRequestFactory.h"
#import "AZSUtil.h"

@implementation AZSBlobRequestFactory

+(NSMutableURLRequest *) createContainerWithAccessType:(AZSContainerPublicAccessType)accessType cloudMetadata:(NSMutableDictionary *)cloudMetadata urlComponents:(NSURLComponents *)urlComponents timeout:(NSTimeInterval)timeout operationContext:(AZSOperationContext *)operationContext
{
    // TODO: IOS 8 - update this to use urlComponents.queryItems
    urlComponents.percentEncodedQuery = [AZSRequestFactory appendToQuery:urlComponents.percentEncodedQuery stringToAppend:AZSCQueryRestypeContainer];
    NSMutableURLRequest *request = [AZSRequestFactory putRequestWithUrlComponents:urlComponents timeout:timeout];
    
    [AZSBlobRequestFactory addAccessTypeToRequest:request accessType:accessType];

    [AZSRequestFactory addMetadataToRequest:request metadata:cloudMetadata];

    return request;
}

+(void) addAccessTypeToRequest:(NSMutableURLRequest *)request accessType:(AZSContainerPublicAccessType)accessType
{
    switch (accessType) {
        case AZSContainerPublicAccessTypeBlob:
            [AZSUtil addOptionalHeaderToRequest:request header:AZSCHeaderBlobPublicAccess stringValue:AZSCBlob];
            break;
            
        case AZSContainerPublicAccessTypeContainer:
            [AZSUtil addOptionalHeaderToRequest:request header:AZSCHeaderBlobPublicAccess stringValue:AZSCContainer];
            break;
            
        case AZSContainerPublicAccessTypeOff:
            break;
    }
}

+(NSMutableURLRequest *) deleteContainerWithAccessCondition:(AZSAccessCondition *)accessCondition urlComponents:(NSURLComponents *)urlComponents timeout:(NSTimeInterval)timeout operationContext:(AZSOperationContext *)operationContext;
{
    // TODO: IOS 8 - update this to use urlComponents.queryItems
    urlComponents.percentEncodedQuery = [AZSRequestFactory appendToQuery:urlComponents.percentEncodedQuery stringToAppend:AZSCQueryRestypeContainer];
    NSMutableURLRequest *request = [AZSRequestFactory deleteRequestWithUrlComponents:urlComponents timeout:timeout];
    
    [AZSRequestFactory applyAccessConditionToRequest:request condition:accessCondition];
    return request;
}

+(NSMutableURLRequest *) listContainersWithPrefix:(NSString *)prefix containerListingDetails:(AZSContainerListingDetails)containerListingDetails maxResults:(NSInteger)maxResults continuationToken:(AZSContinuationToken *)continuationToken urlComponents:(NSURLComponents *)urlComponents timeout:(NSTimeInterval)timeout operationContext:(AZSOperationContext *)operationContext
{
    urlComponents.percentEncodedQuery = [AZSRequestFactory appendToQuery:urlComponents.percentEncodedQuery stringToAppend:AZSCQueryCompList];
    if (prefix != nil && [prefix length] > 0)
    {
        urlComponents.percentEncodedQuery = [AZSRequestFactory appendToQuery:urlComponents.percentEncodedQuery stringToAppend:[NSString stringWithFormat:AZSCQueryTemplatePrefix, prefix]];
    }
    
    if (continuationToken.nextMarker != nil && [continuationToken.nextMarker length] > 0)
    {
        urlComponents.percentEncodedQuery = [AZSRequestFactory appendToQuery:urlComponents.percentEncodedQuery stringToAppend:[NSString stringWithFormat:AZSCQueryTemplateMarker, continuationToken.nextMarker]];
    }
    
    if (maxResults > 0)
    {
        urlComponents.percentEncodedQuery = [AZSRequestFactory appendToQuery:urlComponents.percentEncodedQuery stringToAppend:[NSString stringWithFormat:AZSCQueryTemplateMaxResults, (long)maxResults]];
    }
    
    if ((containerListingDetails & AZSContainerListingDetailsMetadata) != 0)
    {
        urlComponents.percentEncodedQuery = [AZSRequestFactory appendToQuery:urlComponents.percentEncodedQuery stringToAppend:AZSCQueryIncludeMetadata];
    }
    
    NSMutableURLRequest *request = [AZSRequestFactory getRequestWithUrlComponents:urlComponents timeout:timeout];
    return request;
}

+(NSMutableURLRequest *) uploadContainerMetadataWithCloudMetadata:(NSMutableDictionary *) cloudMetadata accessCondition:(AZSAccessCondition *)accessCondition urlComponents:(NSURLComponents *)urlComponents timeout:(NSTimeInterval)timeout operationContext:(AZSOperationContext *)operationContext
{
    // TODO: IOS 8 - update this to use urlComponents.queryItems
    urlComponents.percentEncodedQuery = [AZSRequestFactory appendToQuery:urlComponents.percentEncodedQuery stringToAppend:AZSCQueryRestypeContainer];
    urlComponents.percentEncodedQuery = [AZSRequestFactory appendToQuery:urlComponents.percentEncodedQuery stringToAppend:AZSCQueryCompMetadata];
    NSMutableURLRequest *request = [AZSRequestFactory putRequestWithUrlComponents:urlComponents timeout:timeout];
    
    [AZSRequestFactory addMetadataToRequest:request metadata:cloudMetadata];
    
    [AZSRequestFactory applyAccessConditionToRequest:request condition:accessCondition];
    return request;
}

+(NSMutableURLRequest *) downloadContainerAttributesWithAccessCondition:(AZSAccessCondition *)accessCondition urlComponents:(NSURLComponents *)urlComponents timeout:(NSTimeInterval)timeout operationContext:(AZSOperationContext *)operationContext
{
    // TODO: IOS 8 - update this to use urlComponents.queryItems
    urlComponents.percentEncodedQuery = [AZSRequestFactory appendToQuery:urlComponents.percentEncodedQuery stringToAppend:AZSCQueryRestypeContainer];
    NSMutableURLRequest *request = [AZSRequestFactory headRequestWithUrlComponents:urlComponents timeout:timeout];
    
    [AZSRequestFactory applyAccessConditionToRequest:request condition:accessCondition];
    return request;
}

+(NSMutableURLRequest *) downloadContainerPermissionsWithAccessCondition:(AZSAccessCondition *)accessCondition urlComponents:(NSURLComponents *)urlComponents timeout:(NSTimeInterval)timeout operationContext:(AZSOperationContext *)operationContext
{
    // TODO: IOS 8 - update this to use urlComponents.queryItems
    urlComponents.percentEncodedQuery = [AZSRequestFactory appendToQuery:urlComponents.percentEncodedQuery stringToAppend:AZSCQueryRestypeContainer];
    urlComponents.percentEncodedQuery = [AZSRequestFactory appendToQuery:urlComponents.percentEncodedQuery stringToAppend:AZSCQueryCompAcl];
    NSMutableURLRequest *request = [AZSRequestFactory getRequestWithUrlComponents:urlComponents timeout:timeout];
    
    [AZSRequestFactory applyAccessConditionToRequest:request condition:accessCondition];
    return request;
}

+(NSMutableURLRequest *)leaseContainerWithLeaseAction:(AZSLeaseAction)leaseAction proposedLeaseId:(NSString *)proposedLeaseId leaseDuration:(NSNumber *)leaseDuration leaseBreakPeriod:(NSNumber *)leaseBreakPeriod accessCondition:(AZSAccessCondition *)accessCondition urlComponents:(NSURLComponents *)urlComponents timeout:(NSTimeInterval)timeout operationContext:(AZSOperationContext *)operationContext
{
    // TODO: IOS 8 - update this to use urlComponents.queryItems
    urlComponents.percentEncodedQuery = [AZSRequestFactory appendToQuery:urlComponents.percentEncodedQuery stringToAppend:AZSCQueryRestypeContainer];
    urlComponents.percentEncodedQuery = [AZSRequestFactory appendToQuery:urlComponents.percentEncodedQuery stringToAppend:AZSCQueryCompLease];
    NSMutableURLRequest *request = [AZSRequestFactory putRequestWithUrlComponents:urlComponents timeout:timeout];
    
    [AZSBlobRequestFactory addLeaseActionToRequest:request leaseAction:leaseAction];
    [AZSBlobRequestFactory addLeaseDurationToRequest:request leaseDuration:leaseDuration];
    [AZSBlobRequestFactory addProposedLeaseIdToRequest:request proposedLeaseId:proposedLeaseId];
    [AZSBlobRequestFactory addLeaseBreakPeriodToRequest:request leaseBreakPeriod:leaseBreakPeriod];
    
    [AZSRequestFactory applyAccessConditionToRequest:request condition:accessCondition];
    return request;
}

+(NSMutableURLRequest *) uploadContainerPermissionsWithLength:(NSUInteger)length urlComponents:(NSURLComponents *)urlComponents options:(AZSBlobRequestOptions *)options accessCondition:(AZSAccessCondition *)accessCondition publicAccess:(AZSContainerPublicAccessType)publicAccess timeout:(NSTimeInterval)timeout operationContext:(AZSOperationContext *)operationContext
{
    urlComponents.percentEncodedQuery = [AZSRequestFactory appendToQuery:urlComponents.percentEncodedQuery stringToAppend:AZSCQueryRestypeContainer];
    urlComponents.percentEncodedQuery = [AZSRequestFactory appendToQuery:urlComponents.percentEncodedQuery stringToAppend:AZSCQueryCompAcl];
    NSMutableURLRequest *request = [AZSRequestFactory putRequestWithUrlComponents:urlComponents timeout:timeout];

    [request setValue:[NSString stringWithFormat:@"%lu", (unsigned long)length] forHTTPHeaderField:AZSCContentLength];
    
    [AZSBlobRequestFactory addAccessTypeToRequest:request accessType:publicAccess];
    
    [AZSRequestFactory applyAccessConditionToRequest:request condition:accessCondition];
    
    return request;
}

+(NSMutableURLRequest *) putBlockBlobWithLength:(NSUInteger)length blobProperties:(AZSBlobProperties *)blobProperties contentMD5:(NSString *)contentMD5 cloudMetadata:(NSMutableDictionary *)cloudMetadata AccessCondition:(AZSAccessCondition *)accessCondition urlComponents:(NSURLComponents *)urlComponents timeout:(NSTimeInterval)timeout operationContext:(AZSOperationContext *)operationContext
{
    // TODO: IOS 8 - update this to use urlComponents.queryItems
    NSMutableURLRequest *request = [AZSRequestFactory putRequestWithUrlComponents:urlComponents timeout:timeout];
    [request setValue:[NSString stringWithFormat:@"%lu", (unsigned long)length] forHTTPHeaderField:AZSCContentLength];
    [request setValue:AZSCBlobBlockBlob forHTTPHeaderField:AZSCHeaderBlobType];
    
    [AZSRequestFactory addMetadataToRequest:request metadata:cloudMetadata];
    [AZSBlobRequestFactory addBlobPropertiesToRequest:request properties:blobProperties];
    
    [AZSRequestFactory applyAccessConditionToRequest:request condition:accessCondition];
    [AZSUtil addOptionalHeaderToRequest:request header:AZSCContentMd5 stringValue:contentMD5];
    return request;
}

+(NSMutableURLRequest *) putBlockWithLength:(NSUInteger)length blockID:(NSString *)blockID contentMD5:(NSString *)contentMD5 accessCondition:(AZSAccessCondition *)accessCondition urlComponents:(NSURLComponents *)urlComponents timeout:(NSTimeInterval)timeout operationContext:(AZSOperationContext *)operationContext
{
    urlComponents.percentEncodedQuery = [AZSRequestFactory appendToQuery:urlComponents.percentEncodedQuery stringToAppend:AZSCQueryCompBlock];
    urlComponents.percentEncodedQuery = [AZSRequestFactory appendToQuery:urlComponents.percentEncodedQuery stringToAppend:[NSString stringWithFormat:AZSCQueryTemplateBlockId,blockID]];

    // TODO: IOS 8 - update this to use urlComponents.queryItems
    NSMutableURLRequest *request = [AZSRequestFactory putRequestWithUrlComponents:urlComponents timeout:timeout];
    [request setValue:[NSString stringWithFormat:@"%lu", (unsigned long)length] forHTTPHeaderField:AZSCContentLength];
    
    [AZSRequestFactory applyLeaseIdToRequest:request condition:accessCondition];
    [AZSUtil addOptionalHeaderToRequest:request header:AZSCContentMd5 stringValue:contentMD5];
    [AZSRequestFactory applyAccessConditionToRequest:request condition:accessCondition];
    return request;
}

+(NSMutableURLRequest *) putBlockListWithLength:(NSUInteger)length blobProperties:(AZSBlobProperties *)blobProperties contentMD5:(NSString *)contentMD5 cloudMetadata:(NSMutableDictionary *)cloudMetadata AccessCondition:(AZSAccessCondition *)accessCondition urlComponents:(NSURLComponents *)urlComponents timeout:(NSTimeInterval)timeout operationContext:(AZSOperationContext *)operationContext
{
    urlComponents.percentEncodedQuery = [AZSRequestFactory appendToQuery:urlComponents.percentEncodedQuery stringToAppend:AZSCQueryCompBlockList];
    // TODO: IOS 8 - update this to use urlComponents.queryItems
    NSMutableURLRequest *request = [AZSRequestFactory putRequestWithUrlComponents:urlComponents timeout:timeout];
    [request setValue:[NSString stringWithFormat:@"%lu", (unsigned long)length] forHTTPHeaderField:AZSCContentLength];
    
    [AZSRequestFactory addMetadataToRequest:request metadata:cloudMetadata];
    [AZSBlobRequestFactory addBlobPropertiesToRequest:request properties:blobProperties];
    
    [AZSRequestFactory applyAccessConditionToRequest:request condition:accessCondition];
    [AZSUtil addOptionalHeaderToRequest:request header:AZSCContentMd5 stringValue:contentMD5];
    
    return request;
}

+(NSMutableURLRequest *) getBlockListWithBlockListFilter:(AZSBlockListFilter)blockListFilter snapshotTime:(NSString *)snapshotTime accessCondition:(AZSAccessCondition *)accessCondition urlComponents:(NSURLComponents *)urlComponents timeout:(NSTimeInterval)timeout operationContext:(AZSOperationContext *)operationContext
{
    urlComponents.percentEncodedQuery = [AZSRequestFactory appendToQuery:urlComponents.percentEncodedQuery stringToAppend:AZSCQueryCompBlockList];
    
    NSString *blockListSpecifier;
    switch (blockListFilter)
    {
        case AZSBlockListFilterAll:
            blockListSpecifier = AZSCHeaderValueAll;
            break;
        case AZSBlockListFilterCommitted:
            blockListSpecifier = AZSCHeaderValueCommitted;
            break;
        case AZSBlockListFilterUncommitted:
            blockListSpecifier = AZSCHeaderValueUncommitted;
            break;
    }
    
    urlComponents.percentEncodedQuery = [AZSRequestFactory appendToQuery:urlComponents.percentEncodedQuery stringToAppend:[NSString stringWithFormat:AZSCQueryTemplateBlockListType, blockListSpecifier]];
    if (snapshotTime)
    {
        urlComponents.percentEncodedQuery = [AZSRequestFactory appendToQuery:urlComponents.percentEncodedQuery stringToAppend:[NSString stringWithFormat:AZSCQueryTemplateSnapshot, snapshotTime]];
    }
    
    NSMutableURLRequest *request = [AZSRequestFactory getRequestWithUrlComponents:urlComponents timeout:timeout];
    
    [AZSRequestFactory applyAccessConditionToRequest:request condition:accessCondition];
    return request;
}


+(NSMutableURLRequest *) getBlobWithSnapshotTime:(NSString *)snapshotTime range:(NSRange)range getRangeContentMD5:(BOOL)getRangeContentMD5 accessCondition:(AZSAccessCondition *)accessCondition urlComponents:(NSURLComponents *)urlComponents timeout:(NSTimeInterval)timeout operationContext:(AZSOperationContext *)operationContext
{
    if (snapshotTime)
    {
        urlComponents.percentEncodedQuery = [AZSRequestFactory appendToQuery:urlComponents.percentEncodedQuery stringToAppend:[NSString stringWithFormat:AZSCQueryTemplateSnapshot, snapshotTime]];
    }
    
    NSMutableURLRequest *request = [AZSRequestFactory getRequestWithUrlComponents:urlComponents timeout:timeout];

    if (range.length > 0)
    {
        [AZSUtil addOptionalHeaderToRequest:request header:AZSCHeaderRange stringValue:[NSString stringWithFormat:@"%lu-%lu",(unsigned long)range.location, ((unsigned long)range.location + (unsigned long)range.length)]];
        if (getRangeContentMD5)
        {
            [AZSUtil addOptionalHeaderToRequest:request header:AZSCHeaderRangeGetContent stringValue:AZSCTrue];
        }
    }
    
    [AZSRequestFactory applyAccessConditionToRequest:request condition:accessCondition];
    return request;
}

+(NSMutableURLRequest *) deleteBlobWithSnapshotsOption:(AZSDeleteSnapshotsOption)deleteSnapshotsOption snapshotTime:(NSString *)snapshotTime accessCondition:(AZSAccessCondition *)accessCondition urlComponents:(NSURLComponents *)urlComponents timeout:(NSTimeInterval)timeout operationContext:(AZSOperationContext *)operationContext
{
    if (snapshotTime)
    {
        urlComponents.percentEncodedQuery = [AZSRequestFactory appendToQuery:urlComponents.percentEncodedQuery stringToAppend:[NSString stringWithFormat:AZSCQueryTemplateSnapshot, snapshotTime]];
    }
    NSMutableURLRequest *request = [AZSRequestFactory deleteRequestWithUrlComponents:urlComponents timeout:timeout];
    
    switch (deleteSnapshotsOption)
    {
        case AZSDeleteSnapshotsOptionDeleteSnapshotsOnly:
            [request setValue:AZSCHeaderValueOnly forHTTPHeaderField:AZSCHeaderDeleteSnapshots];
            break;
        case AZSDeleteSnapshotsOptionIncludeSnapshots:
            [request setValue:AZSCHeaderValueInclude forHTTPHeaderField:AZSCHeaderDeleteSnapshots];
            break;
        case AZSDeleteSnapshotsOptionNone:
        default:
            break;
    }
    
    [AZSRequestFactory applyAccessConditionToRequest:request condition:accessCondition];
    return request;
}

+(NSMutableURLRequest *) snapshotBlobWithMetadata:(NSMutableDictionary *)metadata accessCondition:(AZSAccessCondition *)accessCondition urlComponents:(NSURLComponents *)urlComponents timeout:(NSTimeInterval)timeout operationContext:(AZSOperationContext *)operationContext
{
    urlComponents.percentEncodedQuery = [AZSRequestFactory appendToQuery:urlComponents.percentEncodedQuery stringToAppend:AZSCQueryCompSnapshot];
    NSMutableURLRequest *request = [AZSRequestFactory putRequestWithUrlComponents:urlComponents timeout:timeout];
    
    [AZSRequestFactory addMetadataToRequest:request metadata:metadata];
    
    [AZSRequestFactory applyAccessConditionToRequest:request condition:accessCondition];
    return request;
}

+(NSMutableURLRequest *) listBlobsWithPrefix:(NSString *)prefix delimiter:(NSString *)delimiter blobListingDetails:(AZSBlobListingDetails)blobListingDetails maxResults:(NSInteger)maxResults continuationToken:(AZSContinuationToken *)continuationToken urlComponents:(NSURLComponents *)urlComponents timeout:(NSTimeInterval)timeout operationContext:(AZSOperationContext *)operationContext
{
    urlComponents.percentEncodedQuery = [AZSRequestFactory appendToQuery:urlComponents.percentEncodedQuery stringToAppend:AZSCQueryRestypeContainer];
    urlComponents.percentEncodedQuery = [AZSRequestFactory appendToQuery:urlComponents.percentEncodedQuery stringToAppend:AZSCQueryCompList];
    
    if (prefix != nil && [prefix length] > 0)
    {
        urlComponents.percentEncodedQuery = [AZSRequestFactory appendToQuery:urlComponents.percentEncodedQuery stringToAppend:[NSString stringWithFormat:AZSCQueryTemplatePrefix, prefix]];
    }

    if (delimiter != nil && [delimiter length] > 0)
    {
        urlComponents.percentEncodedQuery = [AZSRequestFactory appendToQuery:urlComponents.percentEncodedQuery stringToAppend:[NSString stringWithFormat:AZSCQueryTemplateDelimiter, delimiter]];
    }
    
    if (continuationToken.nextMarker != nil && [continuationToken.nextMarker length] > 0)
    {
        urlComponents.percentEncodedQuery = [AZSRequestFactory appendToQuery:urlComponents.percentEncodedQuery stringToAppend:[NSString stringWithFormat:AZSCQueryTemplateMarker, continuationToken.nextMarker]];
    }
    
    if (maxResults > 0)
    {
        urlComponents.percentEncodedQuery = [AZSRequestFactory appendToQuery:urlComponents.percentEncodedQuery stringToAppend:[NSString stringWithFormat:AZSCQueryTemplateMaxResults, (long) maxResults]];
    }
    
    if (blobListingDetails != AZSBlobListingDetailsNone)
    {
        NSMutableString *includes = [NSMutableString stringWithCapacity:10];
        
        if ((blobListingDetails & AZSBlobListingDetailsSnapshots) != 0)
        {
            if (includes.length > 0)
            {
                [includes appendString:@","];
            }
            
            [includes appendString:AZSCHeaderValueSnapshots];
        }
        
        if ((blobListingDetails & AZSBlobListingDetailsMetadata) != 0)
        {
            if (includes.length > 0)
            {
                [includes appendString:@","];
            }
            
            [includes appendString:AZSCHeaderValueMetadata];
        }

        if ((blobListingDetails & AZSBlobListingDetailsUncommittedBlobs) != 0)
        {
            if (includes.length > 0)
            {
                [includes appendString:@","];
            }
            
            [includes appendString:AZSCHeaderValueUncommittedBlobs];
        }

        if ((blobListingDetails & AZSBlobListingDetailsCopy) != 0)
        {
            if (includes.length > 0)
            {
                [includes appendString:@","];
            }
            
            [includes appendString:AZSCHeaderValueCopy];
        }

        urlComponents.percentEncodedQuery = [AZSRequestFactory appendToQuery:urlComponents.percentEncodedQuery stringToAppend:[NSString stringWithFormat:AZSCQueryTemplateInclude, includes]];
    }
    
    NSMutableURLRequest *request = [AZSRequestFactory getRequestWithUrlComponents:urlComponents timeout:timeout];
    return request;
}

+(NSMutableURLRequest *) uploadBlobPropertiesWithBlobProperties:(AZSBlobProperties *)blobProperties cloudMetadata:(NSMutableDictionary *)cloudMetadata accessCondition:(AZSAccessCondition *)accessCondition urlComponents:(NSURLComponents *)urlComponents timeout:(NSTimeInterval)timeout operationContext:(AZSOperationContext *)operationContext
{
    // TODO: IOS 8 - update this to use urlComponents.queryItems
    urlComponents.percentEncodedQuery = [AZSRequestFactory appendToQuery:urlComponents.percentEncodedQuery stringToAppend:AZSCQueryCompProperties];
    NSMutableURLRequest *request = [AZSRequestFactory putRequestWithUrlComponents:urlComponents timeout:timeout];
    
    [AZSRequestFactory addMetadataToRequest:request metadata:cloudMetadata];
    [AZSBlobRequestFactory addBlobPropertiesToRequest:request properties:blobProperties];
    [AZSRequestFactory applyAccessConditionToRequest:request condition:accessCondition];
    return request;
}

+(NSMutableURLRequest *) uploadBlobMetadataWithCloudMetadata:(NSMutableDictionary *) cloudMetadata accessCondition:(AZSAccessCondition *)accessCondition urlComponents:(NSURLComponents *)urlComponents timeout:(NSTimeInterval)timeout operationContext:(AZSOperationContext *)operationContext
{
    // TODO: IOS 8 - update this to use urlComponents.queryItems
    urlComponents.percentEncodedQuery = [AZSRequestFactory appendToQuery:urlComponents.percentEncodedQuery stringToAppend:AZSCQueryCompMetadata];
    NSMutableURLRequest *request = [AZSRequestFactory putRequestWithUrlComponents:urlComponents timeout:timeout];
    
    [AZSRequestFactory addMetadataToRequest:request metadata:cloudMetadata];
    
    [AZSRequestFactory applyAccessConditionToRequest:request condition:accessCondition];
    return request;
}

+(NSMutableURLRequest *) downloadBlobAttributesWithAccessCondition:(AZSAccessCondition *)accessCondition snapshotTime:(NSString *)snapshotTime urlComponents:(NSURLComponents *)urlComponents timeout:(NSTimeInterval)timeout operationContext:(AZSOperationContext *)operationContext
{
    // TODO: IOS 8 - update this to use urlComponents.queryItems
    if (snapshotTime)
    {
        urlComponents.percentEncodedQuery = [AZSRequestFactory appendToQuery:urlComponents.percentEncodedQuery stringToAppend:[NSString stringWithFormat:AZSCQueryTemplateSnapshot, snapshotTime]];
    }
    NSMutableURLRequest *request = [AZSRequestFactory headRequestWithUrlComponents:urlComponents timeout:timeout];
    
    [AZSRequestFactory applyAccessConditionToRequest:request condition:accessCondition];
    return request;
}

+(NSMutableURLRequest *)leaseBlobWithLeaseAction:(AZSLeaseAction)leaseAction proposedLeaseId:(NSString *)proposedLeaseId leaseDuration:(NSNumber *)leaseDuration leaseBreakPeriod:(NSNumber *)leaseBreakPeriod accessCondition:(AZSAccessCondition *)accessCondition urlComponents:(NSURLComponents *)urlComponents timeout:(NSTimeInterval)timeout operationContext:(AZSOperationContext *)operationContext
{
    // TODO: IOS 8 - update this to use urlComponents.queryItems
    urlComponents.percentEncodedQuery = [AZSRequestFactory appendToQuery:urlComponents.percentEncodedQuery stringToAppend:AZSCQueryCompLease];
    NSMutableURLRequest *request = [AZSRequestFactory putRequestWithUrlComponents:urlComponents timeout:timeout];
    
    [AZSBlobRequestFactory addLeaseActionToRequest:request leaseAction:leaseAction];
    [AZSBlobRequestFactory addLeaseDurationToRequest:request leaseDuration:leaseDuration];
    [AZSBlobRequestFactory addProposedLeaseIdToRequest:request proposedLeaseId:proposedLeaseId];
    [AZSBlobRequestFactory addLeaseBreakPeriodToRequest:request leaseBreakPeriod:leaseBreakPeriod];
    
    [AZSRequestFactory applyAccessConditionToRequest:request condition:accessCondition];
    return request;
}

+(NSMutableURLRequest *) copyBlobWithSourceURL:(NSURL *)sourceURL sourceAccessCondition:(AZSAccessCondition *)sourceAccessCondition cloudMetadata:(NSMutableDictionary *)cloudMetadata accessCondition:(AZSAccessCondition *)accessCondition urlComponents:(NSURLComponents *)urlComponents timeout:(NSTimeInterval)timeout operationContext:(AZSOperationContext *)operationContext
{
    // TODO: IOS 8 - update this to use urlComponents.queryItems
    NSMutableURLRequest *request = [AZSRequestFactory putRequestWithUrlComponents:urlComponents timeout:timeout];
    [request addValue:sourceURL.absoluteString forHTTPHeaderField:AZSCHeaderCopySource];
    [AZSRequestFactory applySourceAccessConditionToRequest:request condition:sourceAccessCondition];
    
    [AZSRequestFactory applyAccessConditionToRequest:request condition:accessCondition];
    [AZSRequestFactory addMetadataToRequest:request metadata:cloudMetadata];
    return request;
}

+(NSMutableURLRequest *) abortCopyBlobWithCopyId:(NSString *)copyId accessCondition:(AZSAccessCondition *)accessCondition urlComponents:(NSURLComponents *)urlComponents timeout:(NSTimeInterval)timeout operationContext:(AZSOperationContext *)operationContext
{
    // TODO: IOS 8 - update this to use urlComponents.queryItems
    urlComponents.percentEncodedQuery = [AZSRequestFactory appendToQuery:urlComponents.percentEncodedQuery stringToAppend:AZSCQueryCompCopy];
    urlComponents.percentEncodedQuery = [AZSRequestFactory appendToQuery:urlComponents.percentEncodedQuery stringToAppend:[NSString stringWithFormat:AZSCQueryTemplateCopyId, copyId]];

    NSMutableURLRequest *request = [AZSRequestFactory putRequestWithUrlComponents:urlComponents timeout:timeout];
    [request addValue:AZSCHeaderValueAbort forHTTPHeaderField:AZSCHeaderCopyAction];
    [AZSRequestFactory applyLeaseIdToRequest:request condition:accessCondition];
    return request;
}

+(NSMutableURLRequest *) createPageBlobWithSize:(NSNumber *)totalBlobSize sequenceNumber:(NSNumber *)sequenceNumber blobProperties:(AZSBlobProperties *)blobProperties cloudMetadata:(NSMutableDictionary *)cloudMetadata accessCondition:(AZSAccessCondition *)accessCondition urlComponents:(NSURLComponents *)urlComponents timeout:(NSTimeInterval)timeout operationContext:(AZSOperationContext *)operationContext
{
    NSMutableURLRequest *request = [AZSRequestFactory putRequestWithUrlComponents:urlComponents timeout:timeout];
    [request setValue:AZSCBlobPageBlob forHTTPHeaderField:AZSCHeaderBlobType];
    
    [AZSRequestFactory addMetadataToRequest:request metadata:cloudMetadata];
    [AZSBlobRequestFactory addBlobPropertiesToRequest:request properties:blobProperties];
    [AZSRequestFactory applyAccessConditionToRequest:request condition:accessCondition];
    
    [AZSBlobRequestFactory addTotalContentSizeToRequest:request size:totalBlobSize];
    [AZSBlobRequestFactory addSequenceNumberToRequest:request sequenceNumber:sequenceNumber];
    
    return request;
}

+(NSMutableURLRequest *) putPagesWithPageRange:(NSRange)pageRange clear:(BOOL)clear contentMD5:(NSString *)contentMD5 accessCondition:(AZSAccessCondition *)accessCondition urlComponents:(NSURLComponents *)urlComponents timeout:(NSTimeInterval)timeout operationContext:(AZSOperationContext *)operationContext
{
    urlComponents.percentEncodedQuery = [AZSRequestFactory appendToQuery:urlComponents.percentEncodedQuery stringToAppend:AZSCQueryCompPage];
    
    // TODO: IOS 8 - update this to use urlComponents.queryItems
    NSMutableURLRequest *request = [AZSRequestFactory putRequestWithUrlComponents:urlComponents timeout:timeout];
    
    [AZSRequestFactory applyLeaseIdToRequest:request condition:accessCondition];
    unsigned long endByte;
    if (pageRange.length >= 1)
    {
        endByte = (unsigned long)(pageRange.location + pageRange.length - 1);
    }
    else
    {
        endByte = pageRange.location;
    }
    
    [request setValue:[NSString stringWithFormat:AZSCQueryTemplateBytes, (unsigned long)pageRange.location, (unsigned long)endByte] forHTTPHeaderField:AZSCHeaderRange];
        
    if (clear)
    {
        [request setValue:@"0" forHTTPHeaderField:AZSCContentLength];
        [request setValue:AZSCHeaderValueClear forHTTPHeaderField:AZSCHeaderPageWrite];
    }
    else
    {
        [request setValue:[NSString stringWithFormat:@"%lu", (unsigned long)pageRange.length] forHTTPHeaderField:AZSCContentLength];
        [request setValue:AZSCHeaderValueUpdate forHTTPHeaderField:AZSCHeaderPageWrite];
        [AZSUtil addOptionalHeaderToRequest:request header:AZSCContentMd5 stringValue:contentMD5];
    }
    [AZSRequestFactory applyAccessConditionToRequest:request condition:accessCondition];
    [AZSBlobRequestFactory applySequenceNumberConditionToRequest:request condition:accessCondition];
    return request;
}

+(NSMutableURLRequest *) getPageRangesWithRange:(NSRange)range snapshotTime:(NSString *)snapshotTime accessCondition:(AZSAccessCondition *)accessCondition urlComponents:(NSURLComponents *)urlComponents timeout:(NSTimeInterval)timeout operationContext:(AZSOperationContext *)operationContext
{
    urlComponents.percentEncodedQuery = [AZSRequestFactory appendToQuery:urlComponents.percentEncodedQuery stringToAppend:AZSCQueryCompPageList];
    if (snapshotTime)
    {
        urlComponents.percentEncodedQuery = [AZSRequestFactory appendToQuery:urlComponents.percentEncodedQuery stringToAppend:[NSString stringWithFormat:AZSCQueryTemplateSnapshot, snapshotTime]];
    }
    
    NSMutableURLRequest *request = [AZSRequestFactory getRequestWithUrlComponents:urlComponents timeout:timeout];
    
    if (range.length > 0)
    {
        [AZSUtil addOptionalHeaderToRequest:request header:AZSCHeaderRange stringValue:[NSString stringWithFormat:AZSCQueryTemplateBytes,(unsigned long)range.location, ((unsigned long)range.location + (unsigned long)range.length)]];
    }

    [AZSRequestFactory applyAccessConditionToRequest:request condition:accessCondition];
    return request;
}

+(NSMutableURLRequest *) resizePageBlobWithSize:(NSNumber *)totalBlobSize accessCondition:(AZSAccessCondition *)accessCondition urlComponents:(NSURLComponents *)urlComponents timeout:(NSTimeInterval)timeout operationContext:(AZSOperationContext *)operationContext
{
    urlComponents.percentEncodedQuery = [AZSRequestFactory appendToQuery:urlComponents.percentEncodedQuery stringToAppend:AZSCQueryCompProperties];
    NSMutableURLRequest *request = [AZSRequestFactory putRequestWithUrlComponents:urlComponents timeout:timeout];
    
    [AZSBlobRequestFactory addTotalContentSizeToRequest:request size:totalBlobSize];
    [AZSRequestFactory applyAccessConditionToRequest:request condition:accessCondition];
    return request;
}

+(NSMutableURLRequest *) setPageBlobSequenceNumberWithNewSequenceNumber:(NSNumber *)newSequenceNumber isIncrement:(BOOL)isIncrement useMaximum:(BOOL)useMaximum accessCondition:(AZSAccessCondition *)accessCondition urlComponents:(NSURLComponents *)urlComponents timeout:(NSTimeInterval)timeout operationContext:(AZSOperationContext *)operationContext
{
    urlComponents.percentEncodedQuery = [AZSRequestFactory appendToQuery:urlComponents.percentEncodedQuery stringToAppend:AZSCQueryCompProperties];
    NSMutableURLRequest *request = [AZSRequestFactory putRequestWithUrlComponents:urlComponents timeout:timeout];
    
    if (isIncrement)
    {
        [request setValue:AZSCHeaderValueIncrement forHTTPHeaderField:AZSCHeaderSequenceNumberAction];
    }
    else
    {
        [request setValue:newSequenceNumber.stringValue forHTTPHeaderField:AZSCHeaderBlobSequenceNumber];
        if (useMaximum)
        {
            [request setValue:AZSCHeaderValueMax forHTTPHeaderField:AZSCHeaderSequenceNumberAction];
        }
        else
        {
            [request setValue:AZSCHeaderValueUpdate forHTTPHeaderField:AZSCHeaderSequenceNumberAction];
        }
    }
    [AZSRequestFactory applyAccessConditionToRequest:request condition:accessCondition];
    return request;
}

+(NSMutableURLRequest *) createAppendBlobWithBlobProperties:(AZSBlobProperties *)blobProperties cloudMetadata:(NSMutableDictionary *)cloudMetadata accessCondition:(AZSAccessCondition *)accessCondition urlComponents:(NSURLComponents *)urlComponents timeout:(NSTimeInterval)timeout operationContext:(AZSOperationContext *)operationContext
{
    NSMutableURLRequest *request = [AZSRequestFactory putRequestWithUrlComponents:urlComponents timeout:timeout];
    [request setValue:AZSCBlobAppendBlob forHTTPHeaderField:AZSCHeaderBlobType];
    
    [AZSRequestFactory addMetadataToRequest:request metadata:cloudMetadata];
    [AZSBlobRequestFactory addBlobPropertiesToRequest:request properties:blobProperties];
    [AZSRequestFactory applyAccessConditionToRequest:request condition:accessCondition];
        
    return request;
}

+(NSMutableURLRequest *) appendBlockWithLength:(NSUInteger)length contentMD5:(NSString *)contentMD5 accessCondition:(AZSAccessCondition *)accessCondition urlComponents:(NSURLComponents *)urlComponents timeout:(NSTimeInterval)timeout operationContext:(AZSOperationContext *)operationContext
{
    urlComponents.percentEncodedQuery = [AZSRequestFactory appendToQuery:urlComponents.percentEncodedQuery stringToAppend:AZSCQueryCompAppendBlock];
    
    // TODO: IOS 8 - update this to use urlComponents.queryItems
    NSMutableURLRequest *request = [AZSRequestFactory putRequestWithUrlComponents:urlComponents timeout:timeout];
    [request setValue:[NSString stringWithFormat:@"%lu", (unsigned long)length] forHTTPHeaderField:AZSCContentLength];
    
    [AZSRequestFactory applyLeaseIdToRequest:request condition:accessCondition];
    [AZSUtil addOptionalHeaderToRequest:request header:AZSCContentMd5 stringValue:contentMD5];
    [AZSRequestFactory applyAccessConditionToRequest:request condition:accessCondition];
    [AZSBlobRequestFactory applyMaxSizeAndAppendPositionToRequest:request condition:accessCondition];
    return request;
}

+(void) addBlobPropertiesToRequest:(NSMutableURLRequest*)request properties:(AZSBlobProperties*)blobProperties
{
    if (blobProperties)
    {
        [AZSUtil addOptionalHeaderToRequest:request header:AZSCHeaderBlobCacheControl stringValue:blobProperties.cacheControl];
        [AZSUtil addOptionalHeaderToRequest:request header:AZSCHeaderBlobContentDisposition stringValue:blobProperties.contentDisposition];
        [AZSUtil addOptionalHeaderToRequest:request header:AZSCHeaderBlobContentEncoding stringValue:blobProperties.contentEncoding];
        [AZSUtil addOptionalHeaderToRequest:request header:AZSCHeaderBlobContentLanguage stringValue:blobProperties.contentLanguage];
        [AZSUtil addOptionalHeaderToRequest:request header:AZSCHeaderBlobContentMd5 stringValue:blobProperties.contentMD5];
        [AZSUtil addOptionalHeaderToRequest:request header:AZSCHeaderBlobContentType stringValue:blobProperties.contentType];
    }
}

+(void) addLeaseActionToRequest:(NSMutableURLRequest*)request leaseAction:(AZSLeaseAction)leaseAction
{
    NSString * leaseActionHeader = AZSCHeaderLeaseAction;
    switch (leaseAction)
    {
        case AZSLeaseActionAcquire:
            [request addValue:AZSCHeaderValueAcquire forHTTPHeaderField:leaseActionHeader];
            break;
        case AZSLeaseActionBreak:
            [request addValue:AZSCHeaderValueBreak forHTTPHeaderField:leaseActionHeader];
            break;
        case AZSLeaseActionChange:
            [request addValue:AZSCHeaderValueChange forHTTPHeaderField:leaseActionHeader];
            break;
        case AZSLeaseActionRelease:
            [request addValue:AZSCHeaderValueRelease forHTTPHeaderField:leaseActionHeader];
            break;
        case AZSLeaseActionRenew:
            [request addValue:AZSCHeaderValueRenew forHTTPHeaderField:leaseActionHeader];
            break;
    }
}

+(void) addLeaseDurationToRequest:(NSMutableURLRequest*)request leaseDuration:(NSNumber*)leaseDuration
{
    [AZSUtil addOptionalHeaderToRequest:request header:AZSCHeaderLeaseDuration intValue:leaseDuration];
}

+(void) addProposedLeaseIdToRequest:(NSMutableURLRequest*)request proposedLeaseId:(NSString*)proposedLeaseId
{
    [AZSUtil addOptionalHeaderToRequest:request header:AZSCHeaderProposedLeaseId stringValue:proposedLeaseId];
}

+(void) addLeaseBreakPeriodToRequest:(NSMutableURLRequest*)request leaseBreakPeriod:(NSNumber*)leaseBreakPeriod
{
    [AZSUtil addOptionalHeaderToRequest:request header:AZSCHeaderLeaseBreakPeriod intValue:leaseBreakPeriod];
}

+(void) addTotalContentSizeToRequest:(NSMutableURLRequest *)request size:(NSNumber *)size
{
    [AZSUtil addOptionalHeaderToRequest:request header:AZSCHeaderBlobContentLength intValue:size];
}

+(void) addSequenceNumberToRequest:(NSMutableURLRequest *)request sequenceNumber:(NSNumber *)sequenceNumber
{
    [AZSUtil addOptionalHeaderToRequest:request header:AZSCHeaderBlobSequenceNumber intValue:sequenceNumber];
}

+(void) applySequenceNumberConditionToRequest:(NSMutableURLRequest *)request condition:(AZSAccessCondition *)accessCondition
{
    switch (accessCondition.sequenceNumberOperator) {
        case AZSSequenceNumberOperatorNone:
            break;
        case AZSSequenceNumberOperatorLessThanOrEqualTo:
            [request setValue:accessCondition.sequenceNumber.stringValue forHTTPHeaderField:AZSCHeaderIfSequenceNumberLE];
            break;
        case AZSSequenceNumberOperatorEqualTo:
            [request setValue:accessCondition.sequenceNumber.stringValue forHTTPHeaderField:AZSCHeaderIfSequenceNumberEQ];
            break;
        case AZSSequenceNumberOperatorLessThan:
            [request setValue:accessCondition.sequenceNumber.stringValue forHTTPHeaderField:AZSCHeaderIfSequenceNumberLT];
            break;
        default:
            break;
    }
}

+(void) applyMaxSizeAndAppendPositionToRequest:(NSMutableURLRequest *)request condition:(AZSAccessCondition *)accessCondition
{
    if (accessCondition.maxSize)
    {
        [request setValue:accessCondition.maxSize.stringValue forHTTPHeaderField:AZSCHeaderBlobConditionMaxSize];
    }
    if (accessCondition.appendPosition)
    {
        [request setValue:accessCondition.appendPosition.stringValue forHTTPHeaderField:AZSCHeaderBlobConditionAppendPos];
    }
}

@end