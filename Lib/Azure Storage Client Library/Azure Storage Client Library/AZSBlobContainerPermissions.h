// -----------------------------------------------------------------------------------------
// <copyright file="AZSBlobContainerPermissions.h" company="Microsoft">
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

/** The shared access permissions to use for a container.*/
@interface AZSBlobContainerPermissions : NSObject

/** A dictionary containing the shared access policies for the container.
 Use the policy identifier as a key to access the stored AZSSharedAccessPolicy as a value. */
@property (strong, readonly) NSMutableDictionary *sharedAccessPolicies;

/** The public access setting of the container. */
@property AZSContainerPublicAccessType publicAccess;

@end

AZS_ASSUME_NONNULL_END