// -----------------------------------------------------------------------------------------
// <copyright file="AZSUtil.h" company="Microsoft">
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
@class AZSOperationContext;
@class AZSStorageCredentials;
@class AZSStorageUri;

@interface AZSUtil : NSObject

+(void) addOptionalHeaderToRequest:(NSMutableURLRequest *)request header:(NSString *)header stringValue:(NSString *)value;
+(void) addOptionalHeaderToRequest:(NSMutableURLRequest *)request header:(NSString *)header intValue:(NSNumber *)value;

+(NSDateFormatter *) dateFormatterWithRFCFormat;
+(NSDateFormatter *) dateFormatterWithRoundtripFormat;

+(NSString *) convertDateToHttpString:(NSDate *)date;
+(BOOL)streamAvailable:(NSStream *)stream;

+(NSMutableDictionary *) parseQueryWithQueryString:(NSString *)query;

+(BOOL) usePathStyleAddressing:(NSURL *)url;

+(NSString *) URLEncodedStringWithString:(NSString *)stringToConvert;
+(NSString *) computeHmac256WithString:(NSString *)stringToSign credentials:(AZSStorageCredentials *)credentials;
+(NSString *) utcTimeOrEmptyWithDate:(NSDate *)date;

+(AZSOperationContext *) operationlessContext;

@end



