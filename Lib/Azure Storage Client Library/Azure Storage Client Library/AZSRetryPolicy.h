// -----------------------------------------------------------------------------------------
// <copyright file="AZSRetryPolicy.h" company="Microsoft">
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
#import "AZSMacros.h"

AZS_ASSUME_NONNULL_BEGIN

@class AZSRetryContext;
@class AZSRetryInfo;
@class AZSOperationContext;

/** A Retry Policy is what the library will call to determine if a failing request should be retried or not.
 The important method is evaluateRetryContext.  This takes in an AZSRetryContext as input, which contains all the necessary
 data to determine whether or not the request should be retried.
 It outputs an AZSRetryInfo object, which determines whether or not the library will retry the request, and if so, how long
 the library will wait.*/
@protocol AZSRetryPolicy <NSObject>

/** The method that evaluates the RetryContext to determine if the request should be retried or not.
 
 @param retryContext The AZSRetryContext containing information about the most recent request.
 @param operationContext The AZSOperationContext for the entire operation thus far.
 @returns An AZSRetryInfo object that contains whether or not the request should be retried, and if so, how long to wait until the
 next trial.*/
-(AZSRetryInfo *) evaluateRetryContext:(AZSRetryContext *)retryContext withOperationContext:(AZSNullable AZSOperationContext *)operationContext;

/** Clone this retry policy.  Required internally in the library.  Must return a fresh instance with the same parameters.
 @returns The cloned retry policy.*/
-(id<AZSRetryPolicy>)clone;

@end

/** The simplest possible retry policy, tells the library to never retry anything.
 */
@interface AZSRetryPolicyNoRetry : NSObject <AZSRetryPolicy>

@end

/** A retry policy with a linear retry interval.
 
 This policy will evaluate whether or not the request should be retried depending on the HTTP status code of the response.  If the 
 status code indicates that the request should be retried, it will specify a constant wait time, regardless of the retry count.*/
@interface AZSRetryPolicyLinear : NSObject <AZSRetryPolicy>

/** The maximum number of retries the policy will allow.*/
@property NSInteger maxAttempts;

/** The time the retry policy will specify to wait between retries.*/
@property NSTimeInterval waitTimeBetweenRetries;

/** Initializes a fresh instance of the linear retry policy.
 
 @return The newly allocated instance.
 */
-(instancetype)init;

/** Initializes a fresh instance of the linear retry policy.
 
 @param maxAttempts The maximum number of retries the policy will allow.
 @param waitTimeBetweenRetries The time the retry policy will specify to wait between retries.
 @return The newly allocated instance.
 */
-(instancetype)initWithMaxAttempts:(NSInteger)maxAttempts waitTimeBetweenRetries:(NSTimeInterval)waitTimeBetweenRetries AZS_DESIGNATED_INITIALIZER;

@end

/** A retry policy with an exponentially increasing wait time between retries.
 
 This policy will evaluate whether or not the request should be retried depending on the HTTP status code of the response.  If the
 status code indicates that the request should be retried, it will specify an exponentially increasing wait time (each retry will wait roughly twice as long as the prior one.)
 This policy has a hard-coded minimum of 0.01 seconds, and maximum of 120 seconds, regardless of retry count or backOffDelta.
 
 Time intervals are slightly randomized.
 
 This should be the default policy for most operations.  This policy works best when the service is throttling an account due to overuse.
 */
@interface AZSRetryPolicyExponential : NSObject <AZSRetryPolicy>

/** The maximum number of retries the policy will allow.*/
@property NSInteger maxAttempts;

/** The average wait time for the first retry (other than the randomization).
 For example, if this is set to 3 seconds, then the first retry will wait roughly 3 seconds.  The second will wait 6, the third 12, the fourth 24, etc.
 */
@property NSTimeInterval averageBackoffDelta;

/** Initializes a fresh instance of the exponential retry policy.
 
 @return The newly allocated instance.
 */
-(instancetype)init;

/** Initializes a fresh instance of the exponential retry policy.
 
 @param maxAttempts The maximum number of retries the policy will allow.
 @param averageBackoffDelta The time the retry policy will specify to wait between retries, for the first retry.  Afterwards, time will roughly double
 with each retry.
 @return The newly allocated instance.
 */
-(instancetype)initWithMaxAttempts:(NSInteger)maxAttempts averageBackoffDelta:(NSTimeInterval)averageBackoffDelta AZS_DESIGNATED_INITIALIZER;

@end

AZS_ASSUME_NONNULL_END