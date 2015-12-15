// -----------------------------------------------------------------------------------------
// <copyright file="AZSSharedAccessSignatureHelper.h" company="Microsoft">
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

@class AZSCloudClient;
@class AZSStorageUri;
@class AZSSharedAccessHeaders;
@class AZSSharedAccessBlobParameters;
@class AZSUriQueryBuilder;

@interface AZSSharedAccessSignatureHelper : NSObject

+(AZSUriQueryBuilder *)sharedAccessSignatureForBlobWithParameters:(AZSSharedAccessBlobParameters*)parameters resourceType:(NSString*)resourceType signature:(NSString *)signature error:(NSError **)error;

+(NSString *)sharedAccessSignatureHashForBlobWithParameters:(AZSSharedAccessBlobParameters*)parameters resourceName:(NSString*)resourceName client:(AZSCloudClient*)client error:(NSError **)error;

+(NSString *)stringFromPermissions:(AZSSharedAccessPermissions)permissions error:(NSError **)error;

+(AZSSharedAccessPermissions)permissionsFromString:(NSString *)permissionString error:(NSError **)error;

@end
