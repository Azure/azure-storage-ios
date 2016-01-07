// -----------------------------------------------------------------------------------------
// <copyright file="AZSSharedKeyBlobAuthenticationHandler.m" company="Microsoft">
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

#include <time.h>
#include <xlocale.h>
#import <CommonCrypto/CommonHMAC.h>
#import "AZSAuthenticationHandler.h"
#import "AZSConstants.h"
#import "AZSSharedKeyBlobAuthenticationHandler.h"
#import "AZSStorageCredentials.h"
#import "AZSEnums.h"
#import "AZSOperationContext.h"
#import "AZSUtil.h"

@interface AZSSharedKeyBlobAuthenticationHandler()

-(instancetype)init AZS_DESIGNATED_INITIALIZER;

@end

@implementation AZSSharedKeyBlobAuthenticationHandler

-(void) appendWithNewlineToString:(NSMutableString *)string stringToAppend:(NSString *)stringToAppend
{
    if (stringToAppend != nil)
    {
        [string appendString:stringToAppend];
    }
    [string appendString:@"\n"];
}

-(NSString *) getStringToSignWithRequest:(NSMutableURLRequest *)request operationContext:(AZSOperationContext *)operationContext
{
    NSMutableString *stringToSign = [[NSMutableString alloc] init];
    
    // VERB
    [self appendWithNewlineToString:stringToSign stringToAppend:request.HTTPMethod];
    
    // Standard headers
    [self appendWithNewlineToString:stringToSign stringToAppend:[request valueForHTTPHeaderField:AZSCXmlContentEncoding]];
    [self appendWithNewlineToString:stringToSign stringToAppend:[request valueForHTTPHeaderField:AZSCXmlContentLanguage]];
    
    NSString *contentLengthValue = [request valueForHTTPHeaderField:AZSCXmlContentLength];
    if ([contentLengthValue isEqualToString:@"0"])
    {
        contentLengthValue = nil;
    }
    [self appendWithNewlineToString:stringToSign stringToAppend:contentLengthValue];
    
    [self appendWithNewlineToString:stringToSign stringToAppend:[request valueForHTTPHeaderField:AZSCXmlContentMd5]];
    [self appendWithNewlineToString:stringToSign stringToAppend:[request valueForHTTPHeaderField:AZSCXmlContentType]];
    [self appendWithNewlineToString:stringToSign stringToAppend:nil]; // Date header
    [self appendWithNewlineToString:stringToSign stringToAppend:[request valueForHTTPHeaderField:AZSCHeaderValueIfModifiedSince]];
    [self appendWithNewlineToString:stringToSign stringToAppend:[request valueForHTTPHeaderField:AZSCHeaderValueIfMatch]];
    [self appendWithNewlineToString:stringToSign stringToAppend:[request valueForHTTPHeaderField:AZSCHeaderValueIfNoneMatch]];
    [self appendWithNewlineToString:stringToSign stringToAppend:[request valueForHTTPHeaderField:AZSCHeaderValueIfUnmodifiedSince]];
    [self appendWithNewlineToString:stringToSign stringToAppend:[request valueForHTTPHeaderField:AZSCXmlRange]];
    
    // x-ms-* headers (Canonicalized headers)
    NSDictionary *allHeaders = [request allHTTPHeaderFields];
    NSMutableDictionary *xmsHeaders = [[NSMutableDictionary alloc] init];
    for (id key in allHeaders)
    {
        if ([key hasPrefix:AZSCHeaderPrefix])
        {
            xmsHeaders[[key lowercaseString]] = allHeaders[key];
        }
    }
    
    NSArray* sortedKeys = [[xmsHeaders allKeys] sortedArrayUsingSelector:@selector(compare:)];
    
    for (id key in sortedKeys)
    {
        NSString *modifiedKey = [[key componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] componentsJoinedByString:@" "];
        [stringToSign appendString:modifiedKey];
        [stringToSign appendString:@":"];
        
        NSString *modifiedValue = [[xmsHeaders[key] componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] componentsJoinedByString:@" "];
        [self appendWithNewlineToString:stringToSign stringToAppend:modifiedValue];
    }
    
    // Canonicalized resource string
    NSURLComponents *urlComponents = [NSURLComponents componentsWithURL:request.URL resolvingAgainstBaseURL:NO];

    [stringToSign appendString:@"/"];
    [stringToSign appendString:self.storageCredentials.accountName];
    if ([urlComponents.percentEncodedPath length] == 0)
    {
        [stringToSign appendString:@"/"];
    }
    else
    {
        [stringToSign appendString:urlComponents.percentEncodedPath];
    }
    
    // TODO: Fix when moving to iOS 8, use urlComponents.queryItems
    NSString *fullQueryString = urlComponents.query;
    
    NSArray *allQueryParameters = [fullQueryString componentsSeparatedByString:@"&"];
    NSMutableDictionary *queryParameters = [NSMutableDictionary dictionaryWithCapacity:allQueryParameters.count];
    for (id queryParameter in allQueryParameters)
    {
        NSUInteger firstEqualOccurrence = [queryParameter rangeOfString:@"="].location;
        NSString *queryKey = [queryParameter substringWithRange:NSMakeRange(0, firstEqualOccurrence)];
        NSString *queryValue = [queryParameter substringWithRange:NSMakeRange(firstEqualOccurrence + 1, [queryParameter length] - (firstEqualOccurrence + 1))];
        
        queryParameters[[queryKey lowercaseString]] = queryValue;
    }
    
    NSArray *sortedQueryKeys = [[queryParameters allKeys] sortedArrayUsingSelector:@selector(compare:)];
    
    for (id queryKey in sortedQueryKeys)
    {
        [stringToSign appendString:@"\n"];
        [stringToSign appendString:queryKey];
        [stringToSign appendString:@":"];
        [stringToSign appendString:queryParameters[queryKey]];
    }
    
    [operationContext logAtLevel:AZSLogLevelInfo withMessage:@"String to sign = %@", stringToSign];
    return stringToSign;
}

-(void) signRequest:(NSMutableURLRequest *)request operationContext:(AZSOperationContext *)operationContext
{
    char buffer[30];
    struct tm * timeptr;
    time_t time = (time_t) [[NSDate date] timeIntervalSince1970];
    timeptr = gmtime(&time);
    if (!strftime_l(buffer, 30, [AZSCDateFormatColloquial UTF8String], timeptr, NULL))
    {
        // TODO: Add proper error handling to signing.
        NSException* myException = [NSException
                                    exceptionWithName:@"Error in date/time format"
                                    reason:@"Unknown"
                                    userInfo:nil];
        @throw myException;
    }
    
    [request setValue:[NSString stringWithUTF8String:buffer] forHTTPHeaderField:AZSCHeaderDate];
    
    NSString *stringToSign = [self getStringToSignWithRequest:request operationContext:operationContext];
    
    NSString *signature = [AZSUtil computeHmac256WithString:stringToSign credentials:self.storageCredentials];
    
    [request setValue:[NSString stringWithFormat:AZSCSharedTemplateAuthorization,self.storageCredentials.accountName,signature] forHTTPHeaderField:AZSCHeaderAuthorization];
}

-(instancetype)init
{
    return nil;
}

-(instancetype) initWithStorageCredentials:(AZSStorageCredentials *)storageCredentials
{
    self = [super init];
    if (self)
    {
        _storageCredentials = storageCredentials;
    }
    
    return self;
}

@end