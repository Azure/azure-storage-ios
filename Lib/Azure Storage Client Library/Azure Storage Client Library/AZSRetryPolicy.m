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

+(AZSRetryInfo *)evaluateRetryContext:(AZSRetryContext *)retryContext maxAttempts:(NSUInteger)maxAttempts lastPrimaryAttempt:(NSDate * __strong *)lastPrimaryAttempt lastSecondaryAttempt:(NSDate * __strong *)lastSecondaryAttempt;
+(void)alignRetryIntervalWithRetryInfo:(AZSRetryInfo *)retryInfo lastPrimaryAttempt:(NSDate * __strong *)lastPrimaryAttempt lastSecondaryAttempt:(NSDate * __strong *)lastSecondaryAttempt;

@end

@implementation AZSRetryPolicyUtil

+(AZSRetryInfo *)evaluateRetryContext:(AZSRetryContext *)retryContext maxAttempts:(NSUInteger)maxAttempts lastPrimaryAttempt:(NSDate * __strong *)lastPrimaryAttempt lastSecondaryAttempt:(NSDate * __strong *)lastSecondaryAttempt
{
    if (retryContext.currentRetryCount >= maxAttempts)
    {
        return [[AZSRetryInfo alloc] initDontRetry];
    }
    
    switch (retryContext.lastRequestResult.targetLocation) {
        case AZSStorageLocationPrimary:
            *lastPrimaryAttempt = retryContext.lastRequestResult.endTime;
            break;
        case AZSStorageLocationSecondary:
            *lastSecondaryAttempt = retryContext.lastRequestResult.endTime;
            break;
        default:
            break;
    }
    
    NSInteger lastStatusCode = retryContext.lastRequestResult.response.statusCode;
    BOOL secondaryNotFound = ((retryContext.lastRequestResult.targetLocation == AZSStorageLocationSecondary) && (lastStatusCode == 404));
    
    if ((lastStatusCode >= 300) && (lastStatusCode < 500) && (lastStatusCode != 408 /* Request Timeout */) && (!secondaryNotFound))
    {
        return [[AZSRetryInfo alloc] initDontRetry];
    }
    
    if ((lastStatusCode == 501 /* Not Implemented */) || (lastStatusCode == 505 /* HTTP Version Not Supported */))
    {
        return [[AZSRetryInfo alloc] initDontRetry];
    }
    
    AZSRetryInfo *retryInfo = [[AZSRetryInfo alloc] initWithRetryContext:retryContext];
    
    if (secondaryNotFound && retryContext.currentLocationMode != AZSStorageLocationModeSecondaryOnly)
    {
        retryInfo.updatedLocationMode = AZSStorageLocationModePrimaryOnly;
        retryInfo.targetLocation = AZSStorageLocationPrimary;
    }
    
    return retryInfo;
}

+(void)alignRetryIntervalWithRetryInfo:(AZSRetryInfo *)retryInfo lastPrimaryAttempt:(NSDate * __strong *)lastPrimaryAttempt lastSecondaryAttempt:(NSDate * __strong *)lastSecondaryAttempt
{
    NSDate *lastAttempt;
    switch (retryInfo.targetLocation)
    {
        case AZSStorageLocationPrimary:
        {
            lastAttempt = *lastPrimaryAttempt;
            break;
        }
        case AZSStorageLocationSecondary:
        {
            lastAttempt = *lastSecondaryAttempt;
            break;
        }
        case AZSStorageLocationUnspecified:
        {
            break;
        }
    }
    
    if (lastAttempt)
    {
        NSTimeInterval sinceLastAttempt = [[NSDate date] timeIntervalSinceDate:lastAttempt];
        retryInfo.retryInterval = MAX(0, (retryInfo.retryInterval - sinceLastAttempt));
    }
    else
    {
        retryInfo.retryInterval = 0;
    }
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

@interface AZSRetryPolicyLinear()

@property NSDate *lastPrimaryAttempt;
@property NSDate *lastSecondaryAttempt;

@end

@implementation AZSRetryPolicyLinear

-(instancetype)init
{
    return [self initWithMaxAttempts:3 waitTimeBetweenRetries:2];
}

-(instancetype)initWithMaxAttempts:(NSInteger)maxAttempts waitTimeBetweenRetries:(NSTimeInterval)waitTimeBetweenRetries
{
    self = [super init];
    if (self)
    {
        _maxAttempts = maxAttempts;
        _waitTimeBetweenRetries = waitTimeBetweenRetries;
        _lastPrimaryAttempt = nil;
        _lastSecondaryAttempt = nil;
    }
    
    return self;
}

-(AZSRetryInfo *)evaluateRetryContext:(AZSRetryContext *)retryContext withOperationContext:(AZSOperationContext *)operationContext
{
    AZSRetryInfo *retryInfo = [AZSRetryPolicyUtil evaluateRetryContext:retryContext maxAttempts:self.maxAttempts lastPrimaryAttempt:&_lastPrimaryAttempt lastSecondaryAttempt:&_lastSecondaryAttempt];
    if (retryInfo.shouldRetry)
    {
        retryInfo.retryInterval = self.waitTimeBetweenRetries;
        [AZSRetryPolicyUtil alignRetryIntervalWithRetryInfo:retryInfo lastPrimaryAttempt:&_lastPrimaryAttempt lastSecondaryAttempt:&_lastSecondaryAttempt];
    }
    return retryInfo;
}

-(id<AZSRetryPolicy>)clone
{
    return [[AZSRetryPolicyLinear alloc] initWithMaxAttempts:self.maxAttempts waitTimeBetweenRetries:self.waitTimeBetweenRetries];
}

@end

@interface AZSRetryPolicyExponential()

@property NSDate *lastPrimaryAttempt;
@property NSDate *lastSecondaryAttempt;

@end

@implementation AZSRetryPolicyExponential

-(instancetype)init
{
    return [self initWithMaxAttempts:3 averageBackoffDelta:2];
}

-(instancetype)initWithMaxAttempts:(NSInteger)maxAttempts averageBackoffDelta:(NSTimeInterval)averageBackoffDelta
{
    self = [super init];
    if (self)
    {
        _maxAttempts = maxAttempts;
        _averageBackoffDelta = averageBackoffDelta;
        _lastPrimaryAttempt = nil;
        _lastSecondaryAttempt = nil;
    }
    return self;
}

-(AZSRetryInfo *)evaluateRetryContext:(AZSRetryContext *)retryContext withOperationContext:(AZSOperationContext *)operationContext
{
    AZSRetryInfo *retryInfo = [AZSRetryPolicyUtil evaluateRetryContext:retryContext maxAttempts:self.maxAttempts lastPrimaryAttempt:&_lastPrimaryAttempt lastSecondaryAttempt:&_lastSecondaryAttempt];
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
        
        retryInfo.retryInterval = interval;
        [AZSRetryPolicyUtil alignRetryIntervalWithRetryInfo:retryInfo lastPrimaryAttempt:&_lastPrimaryAttempt lastSecondaryAttempt:&_lastSecondaryAttempt];
    }
    return retryInfo;

}

-(id<AZSRetryPolicy>)clone
{
    return [[AZSRetryPolicyExponential alloc] initWithMaxAttempts:self.maxAttempts averageBackoffDelta:self.averageBackoffDelta];
}

@end