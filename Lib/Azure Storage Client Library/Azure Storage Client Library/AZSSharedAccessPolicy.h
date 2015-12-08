// -----------------------------------------------------------------------------------------
// <copyright file="AZSSharedAccessPolicy.h" company="Microsoft">
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

AZS_ASSUME_NONNULL_BEGIN

/** A shared access policy.  Specifies the start time, expiry time, and permissions for the SAS. */
@interface AZSSharedAccessPolicy : NSObject

/** The permissions for a SAS associated with this policy. */
@property AZSSharedAccessPermissions permissions;

/** The expiry time for a SAS associated with this policy. */
@property (strong, AZSNullable) NSDate *sharedAccessExpiryTime;

/** The start time for a SAS associated with this policy. */
@property (strong, AZSNullable) NSDate *sharedAccessStartTime;

@property (strong) NSString *policyIdentifier;

/** Initializes a newly allocated AZSSharedAccessPolicy using the permissions provided
 
 @param identifier The identifier to use when storing this policy on the service.
 @returns The newly initialized policy.
 */
-(instancetype) initWithIdentifier:(NSString *)identifier AZS_DESIGNATED_INITIALIZER;

@end

AZS_ASSUME_NONNULL_END