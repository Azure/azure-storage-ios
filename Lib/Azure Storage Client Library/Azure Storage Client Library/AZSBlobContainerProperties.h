// -----------------------------------------------------------------------------------------
// <copyright file="AZSBlobContainerProperties.h" company="Microsoft">
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

/** A collection of properties for the container.*/
@interface AZSBlobContainerProperties : NSObject

/** The eTag for this container, as far as the library is aware.  Call fetchAttributes to update.*/
@property (copy, AZSNullable) NSString *eTag;

/** The last modified time for the container, as far as the library is aware.  Call fetchAttributes to update.*/
@property (copy, AZSNullable) NSDate *lastModified;

/** The lease status for the container, as far as the library is aware.  Call fetchAttributes to update.*/
@property AZSLeaseStatus leaseStatus;

/** The lease state for the container, as far as the library is aware.  Call fetchAttributes to update.*/
@property AZSLeaseState leaseState;

/** The lease duration for the container, as far as the library is aware.  Call fetchAttributes to update.*/
@property AZSLeaseDuration leaseDuration;

@end

AZS_ASSUME_NONNULL_END