// -----------------------------------------------------------------------------------------
// <copyright file="AZSRetryInfo.h" company="Microsoft">
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

@class AZSRetryContext;

/** An AZSRetryInfo object represents retry information that the library will use to determine if and how to retry.
 It is the output of a RetryPolicy's evaluate method.
 */
@interface AZSRetryInfo : NSObject

/** If YES, then the request should be retried.  Otherwise, the request should not be retried.*/
@property BOOL shouldRetry;
@property AZSStorageLocation targetLocation;
@property AZSStorageLocationMode updatedLocationMode;

/** The NSTimeInterval to wait before retrying the operation.
 Only has meaning if shouldRetry is YES.*/
@property NSTimeInterval retryInterval;

/** Initializes a fresh AZSRetryInfo instance.
 
 @param shouldRetry If the request should be retried.
 @param targetLocation The location for the next request.
 @param updatedLocationMode The location mode to use for the next request.
 @param retryInterval The NSTimeInterval to wait before retrying the operation.
 Only has meaning if shouldRetry is YES.
 */
-(instancetype)initWithShouldRetry:(BOOL)shouldRetry targetLocation:(AZSStorageLocation)targetLocation updatedLocationMode:(AZSStorageLocationMode)updatedLocationMode retryInterval:(NSTimeInterval)retryInterval AZS_DESIGNATED_INITIALIZER;

/** Initializes the RetryInfo with a default, don't-retry instance.*/
-(instancetype)initDontRetry;

// The following is a helper, meant for internal use only:
-(instancetype)initWithRetryContext:(AZSRetryContext *)retryContext;
@end

AZS_ASSUME_NONNULL_END
