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
    urlComponents.percentEncodedQuery = [AZSRequestFactory appendToQuery:urlComponents.percentEncodedQuery stringToAppend:@"restype=container"];
    NSMutableURLRequest *request = [AZSRequestFactory putRequestWithUrlComponents:urlComponents timeout:timeout];
    
    switch (accessType)
    {
        case AZSContainerPublicAccessTypeContainer:
            [request setValue:@"container" forHTTPHeaderField:@"x-ms-blob-public-access"];
            break;
        case AZSContainerPublicAccessTypeBlob:
            [request setValue:@"blob" forHTTPHeaderField:@"x-ms-blob-public-access"];
            break;
        case AZSContainerPublicAccessTypeOff:
        default:
            break;
    }

    [AZSRequestFactory addMetadataToRequest:request metadata:cloudMetadata];

    return request;
}

+(NSMutableURLRequest *) deleteContainerWithAccessCondition:(AZSAccessCondition *)accessCondition urlComponents:(NSURLComponents *)urlComponents timeout:(NSTimeInterval)timeout operationContext:(AZSOperationContext *)operationContext;
{
    // TODO: IOS 8 - update this to use urlComponents.queryItems
    urlComponents.percentEncodedQuery = [AZSRequestFactory appendToQuery:urlComponents.percentEncodedQuery stringToAppend:@"restype=container"];
    NSMutableURLRequest *request = [AZSRequestFactory deleteRequestWithUrlComponents:urlComponents timeout:timeout];
    
    [AZSRequestFactory applyAccessConditionToRequest:request condition:accessCondition];
    return request;
}

+(NSMutableURLRequest *) listContainersWithPrefix:(NSString *)prefix containerListingDetails:(AZSContainerListingDetails)containerListingDetails maxResults:(NSInteger)maxResults continuationToken:(AZSContinuationToken *)continuationToken urlComponents:(NSURLComponents *)urlComponents timeout:(NSTimeInterval)timeout operationContext:(AZSOperationContext *)operationContext
{
    urlComponents.percentEncodedQuery = [AZSRequestFactory appendToQuery:urlComponents.percentEncodedQuery stringToAppend:@"comp=list"];
    if (prefix != nil && [prefix length] > 0)
    {
        urlComponents.percentEncodedQuery = [AZSRequestFactory appendToQuery:urlComponents.percentEncodedQuery stringToAppend:[NSString stringWithFormat:@"prefix=%@", prefix]];
    }
    
    if (continuationToken.nextMarker != nil && [continuationToken.nextMarker length] > 0)
    {
        urlComponents.percentEncodedQuery = [AZSRequestFactory appendToQuery:urlComponents.percentEncodedQuery stringToAppend:[NSString stringWithFormat:@"marker=%@", continuationToken.nextMarker]];
    }
    
    if (maxResults > 0)
    {
        urlComponents.percentEncodedQuery = [AZSRequestFactory appendToQuery:urlComponents.percentEncodedQuery stringToAppend:[NSString stringWithFormat:@"maxresults=%ld", (long)maxResults]];
    }
    
    if ((containerListingDetails & AZSContainerListingDetailsMetadata) != 0)
    {
        urlComponents.percentEncodedQuery = [AZSRequestFactory appendToQuery:urlComponents.percentEncodedQuery stringToAppend:@"include=metadata"];
    }
    
    NSMutableURLRequest *request = [AZSRequestFactory getRequestWithUrlComponents:urlComponents timeout:timeout];
    return request;
}

+(NSMutableURLRequest *) uploadContainerMetadataWithCloudMetadata:(NSMutableDictionary *) cloudMetadata accessCondition:(AZSAccessCondition *)accessCondition urlComponents:(NSURLComponents *)urlComponents timeout:(NSTimeInterval)timeout operationContext:(AZSOperationContext *)operationContext
{
    // TODO: IOS 8 - update this to use urlComponents.queryItems
    urlComponents.percentEncodedQuery = [AZSRequestFactory appendToQuery:urlComponents.percentEncodedQuery stringToAppend:@"restype=container"];
    urlComponents.percentEncodedQuery = [AZSRequestFactory appendToQuery:urlComponents.percentEncodedQuery stringToAppend:@"comp=metadata"];
    NSMutableURLRequest *request = [AZSRequestFactory putRequestWithUrlComponents:urlComponents timeout:timeout];
    
    [AZSRequestFactory addMetadataToRequest:request metadata:cloudMetadata];
    
    [AZSRequestFactory applyAccessConditionToRequest:request condition:accessCondition];
    return request;
}

+(NSMutableURLRequest *) fetchContainerAttributesWithAccessCondition:(AZSAccessCondition *)accessCondition urlComponents:(NSURLComponents *)urlComponents timeout:(NSTimeInterval)timeout operationContext:(AZSOperationContext *)operationContext
{
    // TODO: IOS 8 - update this to use urlComponents.queryItems
    urlComponents.percentEncodedQuery = [AZSRequestFactory appendToQuery:urlComponents.percentEncodedQuery stringToAppend:@"restype=container"];
    NSMutableURLRequest *request = [AZSRequestFactory headRequestWithUrlComponents:urlComponents timeout:timeout];
    
    [AZSRequestFactory applyAccessConditionToRequest:request condition:accessCondition];
    return request;
}

+(NSMutableURLRequest *) downloadContainerPermissionsWithAccessCondition:(AZSAccessCondition *)accessCondition urlComponents:(NSURLComponents *)urlComponents timeout:(NSTimeInterval)timeout operationContext:(AZSOperationContext *)operationContext
{
    // TODO: IOS 8 - update this to use urlComponents.queryItems
    urlComponents.percentEncodedQuery = [AZSRequestFactory appendToQuery:urlComponents.percentEncodedQuery stringToAppend:@"restype=container"];
    urlComponents.percentEncodedQuery = [AZSRequestFactory appendToQuery:urlComponents.percentEncodedQuery stringToAppend:@"comp=acl"];
    NSMutableURLRequest *request = [AZSRequestFactory getRequestWithUrlComponents:urlComponents timeout:timeout];
    
    [AZSRequestFactory applyAccessConditionToRequest:request condition:accessCondition];
    return request;
}

+(NSMutableURLRequest *)leaseContainerWithLeaseAction:(AZSLeaseAction)leaseAction proposedLeaseId:(NSString *)proposedLeaseId leaseDuration:(NSNumber *)leaseDuration leaseBreakPeriod:(NSNumber *)leaseBreakPeriod accessCondition:(AZSAccessCondition *)accessCondition urlComponents:(NSURLComponents *)urlComponents timeout:(NSTimeInterval)timeout operationContext:(AZSOperationContext *)operationContext
{
    // TODO: IOS 8 - update this to use urlComponents.queryItems
    urlComponents.percentEncodedQuery = [AZSRequestFactory appendToQuery:urlComponents.percentEncodedQuery stringToAppend:@"restype=container"];
    urlComponents.percentEncodedQuery = [AZSRequestFactory appendToQuery:urlComponents.percentEncodedQuery stringToAppend:@"comp=lease"];
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
    urlComponents.percentEncodedQuery = [AZSRequestFactory appendToQuery:urlComponents.percentEncodedQuery stringToAppend:@"restype=container"];
    urlComponents.percentEncodedQuery = [AZSRequestFactory appendToQuery:urlComponents.percentEncodedQuery stringToAppend:@"comp=acl"];
    NSMutableURLRequest *request = [AZSRequestFactory putRequestWithUrlComponents:urlComponents timeout:timeout];

    [request setValue:[NSString stringWithFormat:@"%lu", (unsigned long)length] forHTTPHeaderField:@"Content-Length"];
    
    switch (publicAccess) {
        case AZSContainerPublicAccessTypeBlob:
            [AZSUtil addOptionalHeaderToRequest:request header:@"x-ms-blob-public-access" stringValue:@"blob"];
            break;
            
        case AZSContainerPublicAccessTypeContainer:
            [AZSUtil addOptionalHeaderToRequest:request header:@"x-ms-blob-public-access" stringValue:@"container"];
            break;
            
        case AZSContainerPublicAccessTypeOff:
            break;
    }
    
    [AZSRequestFactory applyAccessConditionToRequest:request condition:accessCondition];
    
    return request;
}

+(NSMutableURLRequest *) putBlockBlobWithLength:(NSUInteger)length blobProperties:(AZSBlobProperties *)blobProperties contentMD5:(NSString *)contentMD5 cloudMetadata:(NSMutableDictionary *)cloudMetadata AccessCondition:(AZSAccessCondition *)accessCondition urlComponents:(NSURLComponents *)urlComponents timeout:(NSTimeInterval)timeout operationContext:(AZSOperationContext *)operationContext
{
    // TODO: IOS 8 - update this to use urlComponents.queryItems
    NSMutableURLRequest *request = [AZSRequestFactory putRequestWithUrlComponents:urlComponents timeout:timeout];
    [request setValue:[NSString stringWithFormat:@"%lu", (unsigned long)length] forHTTPHeaderField:@"Content-Length"];
    [request setValue:@"BlockBlob" forHTTPHeaderField:@"x-ms-blob-type"];
    
    [AZSRequestFactory addMetadataToRequest:request metadata:cloudMetadata];
    [AZSBlobRequestFactory addBlobPropertiesToRequest:request properties:blobProperties];
    
    [AZSRequestFactory applyAccessConditionToRequest:request condition:accessCondition];
    [AZSUtil addOptionalHeaderToRequest:request header:@"Content-MD5" stringValue:contentMD5];
    return request;
}

+(NSMutableURLRequest *) putBlockWithLength:(NSUInteger)length blockID:(NSString *)blockID contentMD5:(NSString *)contentMD5 AccessCondition:(AZSAccessCondition *)accessCondition urlComponents:(NSURLComponents *)urlComponents timeout:(NSTimeInterval)timeout operationContext:(AZSOperationContext *)operationContext
{
    urlComponents.percentEncodedQuery = [AZSRequestFactory appendToQuery:urlComponents.percentEncodedQuery stringToAppend:@"comp=block"];
    urlComponents.percentEncodedQuery = [AZSRequestFactory appendToQuery:urlComponents.percentEncodedQuery stringToAppend:[NSString stringWithFormat:@"blockid=%@",blockID]];

    // TODO: IOS 8 - update this to use urlComponents.queryItems
    NSMutableURLRequest *request = [AZSRequestFactory putRequestWithUrlComponents:urlComponents timeout:timeout];
    [request setValue:[NSString stringWithFormat:@"%lu", (unsigned long)length] forHTTPHeaderField:@"Content-Length"];
    
    [AZSRequestFactory applyLeaseIdToRequest:request condition:accessCondition];
    [AZSUtil addOptionalHeaderToRequest:request header:@"Content-MD5" stringValue:contentMD5];
    [AZSRequestFactory applyAccessConditionToRequest:request condition:accessCondition];
    return request;
}

+(NSMutableURLRequest *) putBlockListWithLength:(NSUInteger)length blobProperties:(AZSBlobProperties *)blobProperties contentMD5:(NSString *)contentMD5 cloudMetadata:(NSMutableDictionary *)cloudMetadata AccessCondition:(AZSAccessCondition *)accessCondition urlComponents:(NSURLComponents *)urlComponents timeout:(NSTimeInterval)timeout operationContext:(AZSOperationContext *)operationContext
{
    urlComponents.percentEncodedQuery = [AZSRequestFactory appendToQuery:urlComponents.percentEncodedQuery stringToAppend:@"comp=blocklist"];
    // TODO: IOS 8 - update this to use urlComponents.queryItems
    NSMutableURLRequest *request = [AZSRequestFactory putRequestWithUrlComponents:urlComponents timeout:timeout];
    [request setValue:[NSString stringWithFormat:@"%lu", (unsigned long)length] forHTTPHeaderField:@"Content-Length"];
    
    [AZSRequestFactory addMetadataToRequest:request metadata:cloudMetadata];
    [AZSBlobRequestFactory addBlobPropertiesToRequest:request properties:blobProperties];
    
    [AZSRequestFactory applyAccessConditionToRequest:request condition:accessCondition];
    [AZSUtil addOptionalHeaderToRequest:request header:@"Content-MD5" stringValue:contentMD5];
    
    return request;
}

+(NSMutableURLRequest *) getBlockListWithBlockListFilter:(AZSBlockListFilter)blockListFilter snapshotTime:(NSString *)snapshotTime accessCondition:(AZSAccessCondition *)accessCondition urlComponents:(NSURLComponents *)urlComponents timeout:(NSTimeInterval)timeout operationContext:(AZSOperationContext *)operationContext
{
    urlComponents.percentEncodedQuery = [AZSRequestFactory appendToQuery:urlComponents.percentEncodedQuery stringToAppend:@"comp=blocklist"];
    
    NSString *blockListSpecifier;
    switch (blockListFilter)
    {
        case AZSBlockListFilterAll:
            blockListSpecifier = @"all";
            break;
        case AZSBlockListFilterCommitted:
            blockListSpecifier = @"committed";
            break;
        case AZSBlockListFilterUncommitted:
            blockListSpecifier = @"uncommitted";
            break;
    }
    
    urlComponents.percentEncodedQuery = [AZSRequestFactory appendToQuery:urlComponents.percentEncodedQuery stringToAppend:[NSString stringWithFormat:@"blocklisttype=%@", blockListSpecifier]];
    if (snapshotTime)
    {
        urlComponents.percentEncodedQuery = [AZSRequestFactory appendToQuery:urlComponents.percentEncodedQuery stringToAppend:[NSString stringWithFormat:@"snapshot=%@", snapshotTime]];
    }
    
    NSMutableURLRequest *request = [AZSRequestFactory getRequestWithUrlComponents:urlComponents timeout:timeout];
    
    [AZSRequestFactory applyAccessConditionToRequest:request condition:accessCondition];
    return request;
}


+(NSMutableURLRequest *) getBlobWithSnapshotTime:(NSString *)snapshotTime range:(NSRange)range getRangeContentMD5:(BOOL)getRangeContentMD5 accessCondition:(AZSAccessCondition *)accessCondition urlComponents:(NSURLComponents *)urlComponents timeout:(NSTimeInterval)timeout operationContext:(AZSOperationContext *)operationContext
{
    if (snapshotTime)
    {
        urlComponents.percentEncodedQuery = [AZSRequestFactory appendToQuery:urlComponents.percentEncodedQuery stringToAppend:[NSString stringWithFormat:@"snapshot=%@", snapshotTime]];
    }
    
    NSMutableURLRequest *request = [AZSRequestFactory getRequestWithUrlComponents:urlComponents timeout:timeout];

    if (range.length > 0)
    {
        [AZSUtil addOptionalHeaderToRequest:request header:@"x-ms-range" stringValue:[NSString stringWithFormat:@"%lu-%lu",(unsigned long)range.location, ((unsigned long)range.location + (unsigned long)range.length)]];
        if (getRangeContentMD5)
        {
            [AZSUtil addOptionalHeaderToRequest:request header:@"x-ms-range-get-content-md5" stringValue:@"true"];
        }
    }
    
    [AZSRequestFactory applyAccessConditionToRequest:request condition:accessCondition];
    return request;
}

+(NSMutableURLRequest *) deleteBlobWithSnapshotsOption:(AZSDeleteSnapshotsOption)deleteSnapshotsOption snapshotTime:(NSString *)snapshotTime accessCondition:(AZSAccessCondition *)accessCondition urlComponents:(NSURLComponents *)urlComponents timeout:(NSTimeInterval)timeout operationContext:(AZSOperationContext *)operationContext
{
    if (snapshotTime)
    {
        urlComponents.percentEncodedQuery = [AZSRequestFactory appendToQuery:urlComponents.percentEncodedQuery stringToAppend:[NSString stringWithFormat:@"snapshot=%@", snapshotTime]];
    }
    NSMutableURLRequest *request = [AZSRequestFactory deleteRequestWithUrlComponents:urlComponents timeout:timeout];
    
    switch (deleteSnapshotsOption)
    {
        case AZSDeleteSnapshotsOptionDeleteSnapshotsOnly:
            [request setValue:@"only" forHTTPHeaderField:@"x-ms-delete-snapshots"];
            break;
        case AZSDeleteSnapshotsOptionIncludeSnapshots:
            [request setValue:@"include" forHTTPHeaderField:@"x-ms-delete-snapshots"];
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
    urlComponents.percentEncodedQuery = [AZSRequestFactory appendToQuery:urlComponents.percentEncodedQuery stringToAppend:@"comp=snapshot"];
    NSMutableURLRequest *request = [AZSRequestFactory putRequestWithUrlComponents:urlComponents timeout:timeout];
    
    [AZSRequestFactory addMetadataToRequest:request metadata:metadata];
    
    [AZSRequestFactory applyAccessConditionToRequest:request condition:accessCondition];
    return request;
}

+(NSMutableURLRequest *) listBlobsWithPrefix:(NSString *)prefix delimiter:(NSString *)delimiter blobListingDetails:(AZSBlobListingDetails)blobListingDetails maxResults:(NSInteger)maxResults continuationToken:(AZSContinuationToken *)continuationToken urlComponents:(NSURLComponents *)urlComponents timeout:(NSTimeInterval)timeout operationContext:(AZSOperationContext *)operationContext
{
    urlComponents.percentEncodedQuery = [AZSRequestFactory appendToQuery:urlComponents.percentEncodedQuery stringToAppend:@"restype=container"];
    urlComponents.percentEncodedQuery = [AZSRequestFactory appendToQuery:urlComponents.percentEncodedQuery stringToAppend:@"comp=list"];
    
    if (prefix != nil && [prefix length] > 0)
    {
        urlComponents.percentEncodedQuery = [AZSRequestFactory appendToQuery:urlComponents.percentEncodedQuery stringToAppend:[NSString stringWithFormat:@"prefix=%@", prefix]];
    }

    if (delimiter != nil && [delimiter length] > 0)
    {
        urlComponents.percentEncodedQuery = [AZSRequestFactory appendToQuery:urlComponents.percentEncodedQuery stringToAppend:[NSString stringWithFormat:@"delimiter=%@", delimiter]];
    }
    
    if (continuationToken.nextMarker != nil && [continuationToken.nextMarker length] > 0)
    {
        urlComponents.percentEncodedQuery = [AZSRequestFactory appendToQuery:urlComponents.percentEncodedQuery stringToAppend:[NSString stringWithFormat:@"marker=%@", continuationToken.nextMarker]];
    }
    
    if (maxResults > 0)
    {
        urlComponents.percentEncodedQuery = [AZSRequestFactory appendToQuery:urlComponents.percentEncodedQuery stringToAppend:[NSString stringWithFormat:@"maxresults=%ld", (long)maxResults]];
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
            
            [includes appendString:@"snapshots"];
        }
        
        if ((blobListingDetails & AZSBlobListingDetailsMetadata) != 0)
        {
            if (includes.length > 0)
            {
                [includes appendString:@","];
            }
            
            [includes appendString:@"metadata"];
        }

        if ((blobListingDetails & AZSBlobListingDetailsUncommittedBlobs) != 0)
        {
            if (includes.length > 0)
            {
                [includes appendString:@","];
            }
            
            [includes appendString:@"uncommittedblobs"];
        }

        if ((blobListingDetails & AZSBlobListingDetailsCopy) != 0)
        {
            if (includes.length > 0)
            {
                [includes appendString:@","];
            }
            
            [includes appendString:@"copy"];
        }

        urlComponents.percentEncodedQuery = [AZSRequestFactory appendToQuery:urlComponents.percentEncodedQuery stringToAppend:[NSString stringWithFormat:@"include=%@", includes]];
    }
    
    NSMutableURLRequest *request = [AZSRequestFactory getRequestWithUrlComponents:urlComponents timeout:timeout];
    return request;
}

+(NSMutableURLRequest *) uploadBlobPropertiesWithBlobProperties:(AZSBlobProperties *)blobProperties cloudMetadata:(NSMutableDictionary *)cloudMetadata accessCondition:(AZSAccessCondition *)accessCondition urlComponents:(NSURLComponents *)urlComponents timeout:(NSTimeInterval)timeout operationContext:(AZSOperationContext *)operationContext
{
    // TODO: IOS 8 - update this to use urlComponents.queryItems
    urlComponents.percentEncodedQuery = [AZSRequestFactory appendToQuery:urlComponents.percentEncodedQuery stringToAppend:@"comp=properties"];
    NSMutableURLRequest *request = [AZSRequestFactory putRequestWithUrlComponents:urlComponents timeout:timeout];
    
    [AZSRequestFactory addMetadataToRequest:request metadata:cloudMetadata];
    [AZSBlobRequestFactory addBlobPropertiesToRequest:request properties:blobProperties];
    [AZSRequestFactory applyAccessConditionToRequest:request condition:accessCondition];
    return request;
}

+(NSMutableURLRequest *) uploadBlobMetadataWithCloudMetadata:(NSMutableDictionary *) cloudMetadata accessCondition:(AZSAccessCondition *)accessCondition urlComponents:(NSURLComponents *)urlComponents timeout:(NSTimeInterval)timeout operationContext:(AZSOperationContext *)operationContext
{
    // TODO: IOS 8 - update this to use urlComponents.queryItems
    urlComponents.percentEncodedQuery = [AZSRequestFactory appendToQuery:urlComponents.percentEncodedQuery stringToAppend:@"comp=metadata"];
    NSMutableURLRequest *request = [AZSRequestFactory putRequestWithUrlComponents:urlComponents timeout:timeout];
    
    [AZSRequestFactory addMetadataToRequest:request metadata:cloudMetadata];
    
    [AZSRequestFactory applyAccessConditionToRequest:request condition:accessCondition];
    return request;
}

+(NSMutableURLRequest *) fetchBlobAttributesWithAccessCondition:(AZSAccessCondition *)accessCondition snapshotTime:(NSString *)snapshotTime urlComponents:(NSURLComponents *)urlComponents timeout:(NSTimeInterval)timeout operationContext:(AZSOperationContext *)operationContext
{
    // TODO: IOS 8 - update this to use urlComponents.queryItems
    if (snapshotTime)
    {
        urlComponents.percentEncodedQuery = [AZSRequestFactory appendToQuery:urlComponents.percentEncodedQuery stringToAppend:[NSString stringWithFormat:@"snapshot=%@", snapshotTime]];
    }
    NSMutableURLRequest *request = [AZSRequestFactory headRequestWithUrlComponents:urlComponents timeout:timeout];
    
    [AZSRequestFactory applyAccessConditionToRequest:request condition:accessCondition];
    return request;
}

+(NSMutableURLRequest *)leaseBlobWithLeaseAction:(AZSLeaseAction)leaseAction proposedLeaseId:(NSString *)proposedLeaseId leaseDuration:(NSNumber *)leaseDuration leaseBreakPeriod:(NSNumber *)leaseBreakPeriod accessCondition:(AZSAccessCondition *)accessCondition urlComponents:(NSURLComponents *)urlComponents timeout:(NSTimeInterval)timeout operationContext:(AZSOperationContext *)operationContext
{
    // TODO: IOS 8 - update this to use urlComponents.queryItems
    urlComponents.percentEncodedQuery = [AZSRequestFactory appendToQuery:urlComponents.percentEncodedQuery stringToAppend:@"comp=lease"];
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
    [request addValue:sourceURL.absoluteString forHTTPHeaderField:@"x-ms-copy-source"];
    [AZSRequestFactory applySourceAccessConditionToRequest:request condition:sourceAccessCondition];
    
    [AZSRequestFactory applyAccessConditionToRequest:request condition:accessCondition];
    [AZSRequestFactory addMetadataToRequest:request metadata:cloudMetadata];
    return request;
}

+(NSMutableURLRequest *) abortCopyBlobWithCopyId:(NSString *)copyId accessCondition:(AZSAccessCondition *)accessCondition urlComponents:(NSURLComponents *)urlComponents timeout:(NSTimeInterval)timeout operationContext:(AZSOperationContext *)operationContext
{
    // TODO: IOS 8 - update this to use urlComponents.queryItems
    urlComponents.percentEncodedQuery = [AZSRequestFactory appendToQuery:urlComponents.percentEncodedQuery stringToAppend:@"comp=copy"];
    urlComponents.percentEncodedQuery = [AZSRequestFactory appendToQuery:urlComponents.percentEncodedQuery stringToAppend:[NSString stringWithFormat:@"copyid=%@", copyId]];

    NSMutableURLRequest *request = [AZSRequestFactory putRequestWithUrlComponents:urlComponents timeout:timeout];
    [request addValue:@"abort" forHTTPHeaderField:@"x-ms-copy-action"];
    [AZSRequestFactory applyLeaseIdToRequest:request condition:accessCondition];
    return request;
}

+(void) addBlobPropertiesToRequest:(NSMutableURLRequest*)request properties:(AZSBlobProperties*)blobProperties
{
    if (blobProperties)
    {
        [AZSUtil addOptionalHeaderToRequest:request header:@"x-ms-blob-cache-control" stringValue:blobProperties.cacheControl];
        [AZSUtil addOptionalHeaderToRequest:request header:@"x-ms-blob-content-disposition" stringValue:blobProperties.contentDisposition];
        [AZSUtil addOptionalHeaderToRequest:request header:@"x-ms-blob-content-encoding" stringValue:blobProperties.contentEncoding];
        [AZSUtil addOptionalHeaderToRequest:request header:@"x-ms-blob-content-language" stringValue:blobProperties.contentLanguage];
        [AZSUtil addOptionalHeaderToRequest:request header:@"x-ms-blob-content-md5" stringValue:blobProperties.contentMD5];
        [AZSUtil addOptionalHeaderToRequest:request header:@"x-ms-blob-content-type" stringValue:blobProperties.contentType];
    }
}

+(void) addLeaseActionToRequest:(NSMutableURLRequest*)request leaseAction:(AZSLeaseAction)leaseAction
{
    NSString * leaseActionHeader = @"x-ms-lease-action";
    switch (leaseAction)
    {
        case AZSLeaseActionAcquire:
            [request addValue:@"acquire" forHTTPHeaderField:leaseActionHeader];
            break;
        case AZSLeaseActionBreak:
            [request addValue:@"break" forHTTPHeaderField:leaseActionHeader];
            break;
        case AZSLeaseActionChange:
            [request addValue:@"change" forHTTPHeaderField:leaseActionHeader];
            break;
        case AZSLeaseActionRelease:
            [request addValue:@"release" forHTTPHeaderField:leaseActionHeader];
            break;
        case AZSLeaseActionRenew:
            [request addValue:@"renew" forHTTPHeaderField:leaseActionHeader];
            break;
    }
}

+(void) addLeaseDurationToRequest:(NSMutableURLRequest*)request leaseDuration:(NSNumber*)leaseDuration
{
    [AZSUtil addOptionalHeaderToRequest:request header:@"x-ms-lease-duration" intValue:leaseDuration];
}

+(void) addProposedLeaseIdToRequest:(NSMutableURLRequest*)request proposedLeaseId:(NSString*)proposedLeaseId
{
    [AZSUtil addOptionalHeaderToRequest:request header:@"x-ms-proposed-lease-id" stringValue:proposedLeaseId];
}

+(void) addLeaseBreakPeriodToRequest:(NSMutableURLRequest*)request leaseBreakPeriod:(NSNumber*)leaseBreakPeriod
{
    [AZSUtil addOptionalHeaderToRequest:request header:@"x-ms-lease-break-period" intValue:leaseBreakPeriod];
}

@end
