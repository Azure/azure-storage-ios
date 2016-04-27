// -----------------------------------------------------------------------------------------
// <copyright file="AZSUtil.m" company="Microsoft">
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

#import <CommonCrypto/CommonHMAC.h>
#import "AZSConstants.h"
#import "AZSErrors.h"
#import "AZSOperationContext.h"
#import "AZSUtil.h"
#import "AZSStorageCredentials.h"

@implementation AZSUtil

+(NSDateFormatter *) dateFormatterWithFormat:(NSString *)format
{
    static NSDateFormatter *df = nil;
    if (!df) {
        df = [[NSDateFormatter alloc] init];
        [df setLocale:[[NSLocale alloc] initWithLocaleIdentifier:AZSCPosix]];
        [df setCalendar: [[NSCalendar alloc] initWithCalendarIdentifier:AZSGregorianCalendar]];
        [df setTimeZone:[NSTimeZone timeZoneWithName:AZSCUtc]];
    }
    
    NSDateFormatter *dateFormat = [df copy];
    [dateFormat setDateFormat:format];
    return dateFormat;
}

+(void) addOptionalHeaderToRequest:(NSMutableURLRequest *)request header:(NSString *)header stringValue:(NSString *)value
{
    if (value)
    {
        [request addValue:value forHTTPHeaderField:header];
    }
}

+(void) addOptionalHeaderToRequest:(NSMutableURLRequest *)request header:(NSString *)header intValue:(NSNumber *)value
{
    if (value)
    {
        [request addValue:[NSString stringWithFormat:@"%ld", [value longValue]] forHTTPHeaderField:header];
    }
}

+(NSString *) convertDateToHttpString:(NSDate *)date
{
    if (date)
    {
        return [[AZSUtil dateFormatterWithRFCFormat] stringFromDate:date];
    }
    else
    {
        return nil;
    }
}

+(NSDateFormatter *) dateFormatterWithRFCFormat
{
    return [AZSUtil dateFormatterWithFormat:AZSCDateFormatRFC];
}

+(NSDateFormatter *) dateFormatterWithRoundtripFormat
{
    return [AZSUtil dateFormatterWithFormat:AZSCDateFormatRoundtrip];
}

+(NSString *) utcTimeOrEmptyWithDate:(NSDate *)date
{
    if (!date) {
        return AZSCEmptyString;
    }
    
    return [[AZSUtil dateFormatterWithFormat: AZSCDateFormatIso8601] stringFromDate:date];
}

+(BOOL)streamAvailable:(NSStream *)stream
{
    NSStreamStatus status = [stream streamStatus];
    return !((status == NSStreamStatusClosed) || (status == NSStreamStatusError) || (status == NSStreamStatusAtEnd));
}

// This should be adequate for some parts of the query, but it's not accurate in all cases.
// Either way, it's better than the built-in NSString percent encoding.
// It should be fine for the values in a SAS token (including the sig), which is what we're currently using it for.
+(NSString *) URLEncodedStringWithString:(NSString *)stringToConvert
{
    NSMutableString *encodedString = [NSMutableString string];
    const char *sourceUTF8 = [stringToConvert cStringUsingEncoding:NSUTF8StringEncoding];
    unsigned long length = strlen(sourceUTF8);
    for (int i = 0; i < length; i++)
    {
        const char currentChar = sourceUTF8[i];
        if (currentChar == '.' || currentChar == '-' || currentChar == '_' || currentChar == '~' ||
                   (currentChar >= 'a' && currentChar <= 'z') ||
                   (currentChar >= 'A' && currentChar <= 'Z') ||
                   (currentChar >= '0' && currentChar <= '9'))
        {
            [encodedString appendFormat:@"%c", currentChar];
        }
        else
        {
            [encodedString appendFormat:@"%%%02X", currentChar];
        }
    }
    return encodedString;
}


+(NSMutableDictionary *) parseQueryWithQueryString:(NSString *)query
{
    NSMutableDictionary *result = [[NSMutableDictionary alloc] init];
    
    if (!query || [query isEqualToString:AZSCEmptyString])
    {
        return result;
    }
    
    if ([query characterAtIndex:0] == '?')
    {
        if ([query length] == 1)
        {
            return result;
        }
        
        query = [query substringFromIndex:1];
    }
    
    NSArray *valuePairs = [query componentsSeparatedByString:@"&"];
    
    for (NSString *pair in valuePairs)
    {
        NSString *key;
        NSString *val;
        
        NSRange equalDex = [pair rangeOfString:@"="];
        if (equalDex.length < 1 || equalDex.location == 0)
        {
            key = AZSCEmptyString;
            val = [pair stringByRemovingPercentEncoding];
        }
        else
        {
            key = [[pair substringToIndex:equalDex.location] stringByRemovingPercentEncoding];
            val = [[pair substringFromIndex:equalDex.location + 1] stringByRemovingPercentEncoding];
        }
        
        NSString *existing = [result objectForKey:key];
        if (existing)
        {
            [result setObject:[[val stringByAppendingString:@","] stringByAppendingString:val] forKey:key];
        }
        else
        {
            [result setObject:val forKey:key];
        }
    }
    
    return result;
}

+(BOOL) usePathStyleAddressing:(NSURL *)url
{
    static NSInteger pathStylePorts[20] = {10000, 10001, 10002, 10003, 10004, 10100, 10101, 10102, 10103, 10104, 11000, 11001, 11002, 11003, 10004, 11100, 11101, 11102, 11103, 11104};
    
    // Path-style is something like: https://10.234.234.106:10100/accountname/containername/blobname
    if (url) {
        NSString *host = [url host];
        if (!host) {
            return YES;
        }
        
        for (int i = 0; i < 20; i++) {
            if (pathStylePorts[i] == [url.port intValue]) {
                return [AZSUtil isPathDnsNameWithHost:host];
            }
        }
    }
    
    return NO;
}

+(BOOL) isPathDnsNameWithHost:(NSString *)host
{
    for (int i = 0; i < [host length]; i++) {
        char hostC = [host characterAtIndex:i];
        if (hostC != '.' || hostC <= '0' || hostC >= '9') {
            return NO;
        }
    }
    
    return YES;
}

+(NSString *) computeHmac256WithString:(NSString*)stringToSign credentials:(AZSStorageCredentials *)credentials
{
    const char* stringToSignChar = [stringToSign cStringUsingEncoding:NSUTF8StringEncoding];
    unsigned char cHMAC[CC_SHA256_DIGEST_LENGTH];
    CCHmac(kCCHmacAlgSHA256, [credentials.accountKey bytes], [credentials.accountKey length], stringToSignChar, strlen(stringToSignChar), cHMAC);
    
    NSData *hmac = [[NSData alloc] initWithBytes:cHMAC length:sizeof(cHMAC)];
    return [hmac base64EncodedStringWithOptions:0];
}

+(NSError *) createErrorFromError:(NSError *)err domain:(NSString *)domain code:(NSInteger)code userInfo:(NSDictionary*)userInfo
{
    if (!err) {
        return [[NSError alloc] initWithDomain:domain code:code userInfo:userInfo];
    }
    
    [err.userInfo setValue:[AZSUtil createErrorFromError:[err.userInfo objectForKey:@"Internal Error"] domain:domain code:code userInfo:userInfo] forKey:@"Internal Error"];
    return err;
}

+(AZSOperationContext *) operationlessContext
{
    /* Context used for logging when no service call is being made. */
    static __strong AZSOperationContext *context = nil;
    static dispatch_once_t allowOnce;
    
    dispatch_once(&allowOnce, ^{
        context = [[AZSOperationContext alloc] init];
    });

    return context;
}

+(NSString *)calculateMD5FromData:(NSData *)data
{
    unsigned char md5Bytes[CC_MD5_DIGEST_LENGTH];
    CC_MD5(data.bytes, (CC_LONG) data.length, md5Bytes);
    return [[[NSData alloc] initWithBytes:md5Bytes length:CC_MD5_DIGEST_LENGTH] base64EncodedStringWithOptions:0];
}

@end