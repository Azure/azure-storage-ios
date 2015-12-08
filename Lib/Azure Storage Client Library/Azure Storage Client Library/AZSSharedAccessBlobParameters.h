// -----------------------------------------------------------------------------------------
// <copyright file="AZSSharedAccessBlobPolicy.h" company="Microsoft">
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
#import "AZSEnums.h"
#import "AZSMacros.h"
#import "AZSSharedAccessHeaders.h"
#import "AZSSharedAccessPolicy.h"

AZS_ASSUME_NONNULL_BEGIN

/** A shared access policy for blobs.  Specifies the start time, expiry time, and permissions for the SAS. */
@interface AZSSharedAccessBlobParameters : NSObject

/** The permissions to be included in the SAS token. */
@property AZSSharedAccessPermissions permissions;

/** The expiry time to be included in the SAS token. */
@property (strong, AZSNullable) NSDate *sharedAccessExpiryTime;

/** The start time to be included in the SAS token. */
@property (strong, AZSNullable) NSDate *sharedAccessStartTime;

/** The shared access headers to be included in the SAS token. */
@property (strong, AZSNullable) AZSSharedAccessHeaders *headers;

/** An identifier for a stored policy to be included in the SAS token. */
@property (strong, AZSNullable) NSString *storedPolicyIdentifier;

/** Initializes a newly allocated AZSSharedAccessBlobParameters.
 
 @returns The newly initialized parameters.
 */
-(instancetype) init AZS_DESIGNATED_INITIALIZER;

@end

AZS_ASSUME_NONNULL_END