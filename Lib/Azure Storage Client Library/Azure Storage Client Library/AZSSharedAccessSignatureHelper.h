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
@class AZSSharedAccessAccountParameters;
@class AZSSharedAccessBlobParameters;
@class AZSStorageCredentials;
@class AZSUriQueryBuilder;

@interface AZSSharedAccessSignatureHelper : NSObject

// Generate SAS Token

+(AZSUriQueryBuilder *)sharedAccessSignatureForBlobWithParameters:(AZSSharedAccessBlobParameters*)parameters resourceType:(NSString*)resourceType signature:(NSString *)signature error:(NSError **)error;

+(AZSUriQueryBuilder *)sharedAccessSignatureForAccountWithParameters:(AZSSharedAccessAccountParameters*)parameters signature:(NSString *)signature error:(NSError **)error;

// Generate Signature

+(NSString *)sharedAccessSignatureHashForBlobWithParameters:(AZSSharedAccessBlobParameters*)parameters resourceName:(NSString*)resourceName client:(AZSCloudClient*)client error:(NSError **)error;

+(NSString *)sharedAccessSignatureHashForAccountWithParameters:(AZSSharedAccessAccountParameters*)parameters accountName:(NSString *)accountName credentials:(AZSStorageCredentials *)credentials error:(NSError **)error;

// Permissions

+(NSString *)stringFromPermissions:(AZSSharedAccessPermissions)permissions error:(NSError **)error;

+(AZSSharedAccessPermissions)permissionsFromString:(NSString *)permissionString error:(NSError **)error;

@end