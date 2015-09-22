// -----------------------------------------------------------------------------------------
// <copyright file="AZSRetryContext.h" company="Microsoft">
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

@class AZSRequestResult;

/** A RetryContext is an input to a RetryPolicy's evaluate method.
 It contains all the information necessary for a RetryPolicy to evaluate whether or not
 the request should be retried.*/
@interface AZSRetryContext : NSObject

/** The retry count.  Begins at 1 (if the first attempt fails, this will be 1 when evaluating whether or not to retry.*/
@property NSInteger currentRetryCount;

/** The most recent (failing) request result.*/
@property (strong) AZSRequestResult *lastRequestResult;

/** The next location to try.*/
@property AZSStorageLocation nextLocation;

/** The current location mode.*/
@property AZSStorageLocationMode currentLocationMode;

-(instancetype)initWithCurrentRetryCount:(NSInteger)currentRetryCount lastRequestResult:(AZSRequestResult *)lastRequestResult nextLocation:(AZSStorageLocation)nextLocation currentLocationMode:(AZSStorageLocationMode) currentLocationMode AZS_DESIGNATED_INITIALIZER;

@end

AZS_ASSUME_NONNULL_END