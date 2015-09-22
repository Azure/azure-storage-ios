// -----------------------------------------------------------------------------------------
// <copyright file="AZSRetryInfo.m" company="Microsoft">
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

#import "AZSRetryInfo.h"
#import "AZSRetryContext.h"

@implementation AZSRetryInfo

-(instancetype)initWithShouldRetry:(BOOL)shouldRetry targetLocation:(AZSStorageLocation)targetLocation updatedLocationMode:(AZSStorageLocationMode)updatedLocationMode retryInterval:(NSTimeInterval)retryInterval
{
    self = [super init];
    if (self)
    {
        _shouldRetry = shouldRetry;
        _targetLocation = targetLocation;
        _updatedLocationMode = updatedLocationMode;
        _retryInterval = retryInterval;
    }
    
    return self;
}

-(instancetype)initDontRetry
{
    return [self initWithShouldRetry:NO targetLocation:AZSStorageLocationPrimary updatedLocationMode:AZSStorageLocationModeUnspecified retryInterval:0];
}

-(instancetype)initWithRetryContext:(AZSRetryContext *)retryContext
{
    return [self initWithShouldRetry:YES targetLocation:retryContext.nextLocation updatedLocationMode:retryContext.currentLocationMode retryInterval:3];
}

@end
