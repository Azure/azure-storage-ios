// -----------------------------------------------------------------------------------------
// <copyright file="AZSRequestFactory.m" company="Microsoft">
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

#import "AZSRequestFactory.h"
#import "AZSAccessCondition.h"
#import "AZSConstants.h"
#import "AZSUtil.h"
@implementation AZSRequestFactory

// TODO: Make a helper method for all these.  Remove UA string setting (or move the version in executor to here.)
+(NSMutableURLRequest *) putRequestWithUrlComponents:(NSURLComponents *)urlComponents timeout:(NSTimeInterval)timeout
{
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[urlComponents URL] cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:timeout];
    [request setHTTPMethod:AZSCHttpPut];
    [request setValue:AZSCTargetStorageVersion forHTTPHeaderField:AZSCHeaderVersion];
    
    return request;
}

+(NSMutableURLRequest *) getRequestWithUrlComponents:(NSURLComponents *)urlComponents timeout:(NSTimeInterval)timeout
{
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[urlComponents URL] cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:timeout];
    [request setHTTPMethod:AZSCHttpGet];
    [request setValue:AZSCTargetStorageVersion forHTTPHeaderField:AZSCHeaderVersion];
    
    return request;
}

+(NSMutableURLRequest *) headRequestWithUrlComponents:(NSURLComponents *)urlComponents timeout:(NSTimeInterval)timeout
{
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[urlComponents URL] cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:timeout];
    [request setHTTPMethod:AZSCHttpHead];
    [request setValue:AZSCTargetStorageVersion forHTTPHeaderField:AZSCHeaderVersion];
    
    return request;
}

+(NSMutableURLRequest *) deleteRequestWithUrlComponents:(NSURLComponents *)urlComponents timeout:(NSTimeInterval)timeout
{
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[urlComponents URL] cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:timeout];
    [request setHTTPMethod:AZSCHttpDelete];
	    [request setValue:AZSCTargetStorageVersion forHTTPHeaderField:AZSCHeaderVersion];
    
    return request;
}


+(void) addMetadataToRequest:(NSMutableURLRequest *)request metadata:(NSMutableDictionary *)metadata
{
    if (metadata)
    {
        for (NSString* key in metadata)
        {
            [request setValue:[metadata objectForKey:key] forHTTPHeaderField:[NSString stringWithFormat:@"%@%@", AZSCHeaderMetaPrefix, key]];
        }
    }
}


+(void)applyAccessConditionToRequest:(NSMutableURLRequest*)request condition:(AZSAccessCondition*)condition
{
    if (condition)
    {
        [AZSUtil addOptionalHeaderToRequest:request header:AZSCHeaderValueIfMatch stringValue:condition.ifMatchETag];
        [AZSUtil addOptionalHeaderToRequest:request header:AZSCHeaderValueIfNoneMatch stringValue:condition.ifNoneMatchETag];
        [AZSUtil addOptionalHeaderToRequest:request header:AZSCHeaderValueIfModifiedSince stringValue:[AZSUtil convertDateToHttpString:condition.ifModifiedSinceDate]];
        [AZSUtil addOptionalHeaderToRequest:request header:AZSCHeaderValueIfUnmodifiedSince stringValue:[AZSUtil convertDateToHttpString:condition.ifNotModifiedSinceDate]];

        [AZSRequestFactory applyLeaseIdToRequest:request condition:condition];
    }
}

+(void)applySourceAccessConditionToRequest:(NSMutableURLRequest*)request condition:(AZSAccessCondition*)condition
{
    if (condition)
    {
        [AZSUtil addOptionalHeaderToRequest:request header:AZSCHeaderSourceIfMatch stringValue:condition.ifMatchETag];
        [AZSUtil addOptionalHeaderToRequest:request header:AZSCHeaderSourceIfNoneMatch stringValue:condition.ifNoneMatchETag];
        [AZSUtil addOptionalHeaderToRequest:request header:AZSCHeaderSourceIfModifiedSince stringValue:[AZSUtil convertDateToHttpString:condition.ifModifiedSinceDate]];
        [AZSUtil addOptionalHeaderToRequest:request header:AZSCHeaderSourceIfUnmodifiedSince stringValue:[AZSUtil convertDateToHttpString:condition.ifNotModifiedSinceDate]];
        
        if (condition.leaseId)
        {
            //throw new exception? lease not supported on source.
        }
    }
}

+(void) applyLeaseIdToRequest:(NSMutableURLRequest*)request condition:(AZSAccessCondition*)condition
{
    if (condition)
    {
        [AZSUtil addOptionalHeaderToRequest:request header:AZSCHeaderLeaseId stringValue:condition.leaseId];
    }
}

// TODO: Consider using NSMutableString* for better perf if necessary
+(NSString *) appendToQuery:(NSString *)query stringToAppend:(NSString *) appendString
{
    if (query == nil)
    {
        return appendString;
    }
    else
    {
        return [query stringByAppendingString:[NSString stringWithFormat:@"&%@",appendString]];
    }
}

@end