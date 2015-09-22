// -----------------------------------------------------------------------------------------
// <copyright file="AZSRequestFactory.h" company="Microsoft">
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
@class AZSAccessCondition;

@interface AZSRequestFactory : NSObject


+(NSMutableURLRequest *) putRequestWithUrlComponents:(NSURLComponents *)urlComponents timeout:(NSTimeInterval)timeout;
+(NSMutableURLRequest *) getRequestWithUrlComponents:(NSURLComponents *)urlComponents timeout:(NSTimeInterval)timeout;
+(NSMutableURLRequest *) headRequestWithUrlComponents:(NSURLComponents *)urlComponents timeout:(NSTimeInterval)timeout;
+(NSMutableURLRequest *) deleteRequestWithUrlComponents:(NSURLComponents *)urlComponents timeout:(NSTimeInterval)timeout;

+(void) addMetadataToRequest:(NSMutableURLRequest *)request metadata:(NSMutableDictionary *)metadata;

+(void)applyAccessConditionToRequest:(NSMutableURLRequest*)request condition:(AZSAccessCondition*)condition;
+(void)applySourceAccessConditionToRequest:(NSMutableURLRequest*)request condition:(AZSAccessCondition*)condition;
+(void)applyLeaseIdToRequest:(NSMutableURLRequest*)request condition:(AZSAccessCondition*)condition;

+(NSString *) appendToQuery:(NSString *)query stringToAppend:(NSString *) appendString;


@end
