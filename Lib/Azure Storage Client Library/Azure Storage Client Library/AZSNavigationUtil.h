// -----------------------------------------------------------------------------------------
// <copyright file="AZSNavigationUtil.h" company="Microsoft">
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

@class AZSStorageCredentials;
@class AZSStorageUri;

@interface AZSNavigationUtil : NSObject

+(NSURL*)getServiceClientBaseAddressWithUri: (NSURL *)addressUri usePathStyle:(BOOL)usePathStyle;
+(AZSStorageUri*)getServiceClientBaseAddressWithStorageUri: (AZSStorageUri*)storageUri usePathStyle:(BOOL)usePathStyle;

+(AZSStorageCredentials*) parseSASQueryWithQueryParameters:(NSMutableDictionary*)queryParameters;
+(NSMutableArray*)parseBlobQueryAndVerifyWithStorageUri:(AZSStorageUri*)blobAddress;

+(NSString *)getContainerNameWithContainerAddress:(NSURL*)uri isPathStyle:(BOOL)isPathStyle;

+(NSString *)getBlobNameWithBlobAddress:(NSURL*)uri isPathStyle:(BOOL)isPathStyle;

@end
