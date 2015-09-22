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
#import "AZSUtil.h"
@implementation AZSRequestFactory

// TODO: Make a helper method for all these.  Remove UA string setting (or move the version in executor to here.)
+(NSMutableURLRequest *) putRequestWithUrlComponents:(NSURLComponents *)urlComponents timeout:(NSTimeInterval)timeout
{
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[urlComponents URL] cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:timeout];
    [request setHTTPMethod:@"PUT"];
    [request setValue:@"iOS-v0.0.0" forHTTPHeaderField:@"User-Agent"];
    [request setValue:@"2015-02-21" forHTTPHeaderField:@"x-ms-version"];
    
    return request;
}

+(NSMutableURLRequest *) getRequestWithUrlComponents:(NSURLComponents *)urlComponents timeout:(NSTimeInterval)timeout
{
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[urlComponents URL] cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:timeout];
    [request setHTTPMethod:@"GET"];
    [request setValue:@"iOS-v0.0.0" forHTTPHeaderField:@"User-Agent"];
    [request setValue:@"2015-02-21" forHTTPHeaderField:@"x-ms-version"];
    
    return request;
}

+(NSMutableURLRequest *) headRequestWithUrlComponents:(NSURLComponents *)urlComponents timeout:(NSTimeInterval)timeout
{
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[urlComponents URL] cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:timeout];
    [request setHTTPMethod:@"HEAD"];
    [request setValue:@"iOS-v0.0.0" forHTTPHeaderField:@"User-Agent"];
    [request setValue:@"2015-02-21" forHTTPHeaderField:@"x-ms-version"];
    
    return request;
}

+(NSMutableURLRequest *) deleteRequestWithUrlComponents:(NSURLComponents *)urlComponents timeout:(NSTimeInterval)timeout
{
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[urlComponents URL] cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:timeout];
    [request setHTTPMethod:@"DELETE"];
    [request setValue:@"iOS-v0.0.0" forHTTPHeaderField:@"User-Agent"];
    [request setValue:@"2015-02-21" forHTTPHeaderField:@"x-ms-version"];
    
    return request;
}


+(void) addMetadataToRequest:(NSMutableURLRequest *)request metadata:(NSMutableDictionary *)metadata
{
    if (metadata)
    {
        for (NSString* key in metadata)
        {
            [request setValue:[metadata objectForKey:key] forHTTPHeaderField:[NSString stringWithFormat:@"x-ms-meta-%@", key]];
        }
    }
}


+(void)applyAccessConditionToRequest:(NSMutableURLRequest*)request condition:(AZSAccessCondition*)condition
{
    if (condition)
    {
        [AZSUtil addOptionalHeaderToRequest:request header:@"If-Match" stringValue:condition.ifMatchETag];
        [AZSUtil addOptionalHeaderToRequest:request header:@"If-None-Match" stringValue:condition.ifNoneMatchETag];
        [AZSUtil addOptionalHeaderToRequest:request header:@"If-Modified-Since" stringValue:[AZSUtil convertDateToHttpString:condition.ifModifiedSinceDate]];
        [AZSUtil addOptionalHeaderToRequest:request header:@"If-Unmodified-Since" stringValue:[AZSUtil convertDateToHttpString:condition.ifNotModifiedSinceDate]];

        [AZSRequestFactory applyLeaseIdToRequest:request condition:condition];
    }
}

+(void)applySourceAccessConditionToRequest:(NSMutableURLRequest*)request condition:(AZSAccessCondition*)condition
{
    if (condition)
    {
        [AZSUtil addOptionalHeaderToRequest:request header:@"x-ms-source-if-match" stringValue:condition.ifMatchETag];
        [AZSUtil addOptionalHeaderToRequest:request header:@"x-ms-source-if-none-match" stringValue:condition.ifNoneMatchETag];
        [AZSUtil addOptionalHeaderToRequest:request header:@"x-ms-source-if-modified-since" stringValue:[AZSUtil convertDateToHttpString:condition.ifModifiedSinceDate]];
        [AZSUtil addOptionalHeaderToRequest:request header:@"x-ms-source-if-unmodified-since" stringValue:[AZSUtil convertDateToHttpString:condition.ifNotModifiedSinceDate]];
        
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
        [AZSUtil addOptionalHeaderToRequest:request header:@"x-ms-lease-id" stringValue:condition.leaseId];
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
