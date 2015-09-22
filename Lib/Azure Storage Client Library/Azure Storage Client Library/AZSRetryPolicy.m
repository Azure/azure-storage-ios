// -----------------------------------------------------------------------------------------
// <copyright file="AZSRetryPolicy.m" company="Microsoft">
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

#import "AZSRetryPolicy.h"
#import "AZSRetryInfo.h"
#import "AZSRetryContext.h"
#import "AZSRequestResult.h"

@interface AZSRetryPolicyUtil : NSObject

+(AZSRetryInfo *)evaluateRetryContext:(AZSRetryContext *)retryContext maxAttempts:(NSUInteger)maxAttempts;

@end

@implementation AZSRetryPolicyUtil

// TODO: enable support for retry-secondary, once we have read-from-secondary.
+(AZSRetryInfo *)evaluateRetryContext:(AZSRetryContext *)retryContext maxAttempts:(NSUInteger)maxAttempts
{
    if (retryContext.currentRetryCount >= maxAttempts)
    {
        return [[AZSRetryInfo alloc] initDontRetry];
    }
    
    NSInteger lastStatusCode = retryContext.lastRequestResult.response.statusCode;
    if ((lastStatusCode >= 300) && (lastStatusCode < 500) && (lastStatusCode != 408 /* Request Timeout */))
    {
        return [[AZSRetryInfo alloc] initDontRetry];
    }
    
    if ((lastStatusCode == 501 /* Not Implemented */) || (lastStatusCode == 505 /* HTTP Version Not Supported */))
    {
        return [[AZSRetryInfo alloc] initDontRetry];
    }
    
    return [[AZSRetryInfo alloc] initWithRetryContext:retryContext];
}

@end

@implementation AZSRetryPolicyNoRetry

-(AZSRetryInfo *)evaluateRetryContext:(AZSRetryContext *)retryContext withOperationContext:(AZSOperationContext *)operationContext
{
    return [[AZSRetryInfo alloc] initDontRetry];
}

-(id<AZSRetryPolicy>)clone
{
    return [[AZSRetryPolicyNoRetry alloc] init];
}

@end

@implementation AZSRetryPolicyLinear

-(instancetype)initWithMaxAttempts:(NSInteger)maxAttempts waitTimeBetweenRetries:(NSTimeInterval)waitTimeBetweenRetries
{
    self = [super init];
    if (self)
    {
        _maxAttempts = maxAttempts;
        _waitTimeBetweenRetries = waitTimeBetweenRetries;
    }
    
    return self;
}

-(AZSRetryInfo *)evaluateRetryContext:(AZSRetryContext *)retryContext withOperationContext:(AZSOperationContext *)operationContext
{
    AZSRetryInfo *retryInfo = [AZSRetryPolicyUtil evaluateRetryContext:retryContext maxAttempts:self.maxAttempts];
    if (retryInfo.shouldRetry)
    {
        // TODO: Once we have read-from-secondary support, this needs to be more complicated, with the wait time being the amount of time
        // since the last request to this storage location.
        retryInfo.retryInterval = self.waitTimeBetweenRetries;
    }
    return retryInfo;
}

-(id<AZSRetryPolicy>)clone
{
    return [[AZSRetryPolicyLinear alloc] initWithMaxAttempts:self.maxAttempts waitTimeBetweenRetries:self.waitTimeBetweenRetries];
}

@end

@implementation AZSRetryPolicyExponential

-(instancetype)initWithMaxAttempts:(NSInteger)maxAttempts averageBackoffDelta:(NSTimeInterval)averageBackoffDelta
{
    self = [super init];
    if (self)
    {
        _maxAttempts = maxAttempts;
        _averageBackoffDelta = averageBackoffDelta;
    }
    return self;
}

-(AZSRetryInfo *)evaluateRetryContext:(AZSRetryContext *)retryContext withOperationContext:(AZSOperationContext *)operationContext
{
    AZSRetryInfo *retryInfo = [AZSRetryPolicyUtil evaluateRetryContext:retryContext maxAttempts:self.maxAttempts];
    if (retryInfo.shouldRetry)
    {
        double maxExponentialRetryInterval = 120;
        double minExponentialRetryInterval = 0.5;

        double minimumBackoffDelta = self.averageBackoffDelta * 0.8;
        double maximumBackoffDelta = self.averageBackoffDelta * 1.2;

        
        long long maxRand = 0x100000000LL;
        double randBackoffTime = ((((double)arc4random()) / maxRand)*(maximumBackoffDelta - minimumBackoffDelta)) + minimumBackoffDelta;
        
        double increment;
        if (retryContext.currentRetryCount < 30)
        {
            increment = ((1 << retryContext.currentRetryCount) - 1) * randBackoffTime;
        }
        else
        {
            increment = (pow(2, retryContext.currentRetryCount) - 1) * randBackoffTime;
        }
        double interval = MAX(MIN((increment < 0) ? maxExponentialRetryInterval : increment, maxExponentialRetryInterval), minExponentialRetryInterval);
        
        // TODO: Once we have read-from-secondary support, this needs to be more complicated, with the wait time being the amount of time
        // since the last request to this storage location.
        retryInfo.retryInterval = interval;
    }
    return retryInfo;

}

-(id<AZSRetryPolicy>)clone
{
    return [[AZSRetryPolicyExponential alloc] initWithMaxAttempts:self.maxAttempts averageBackoffDelta:self.averageBackoffDelta];
}

@end