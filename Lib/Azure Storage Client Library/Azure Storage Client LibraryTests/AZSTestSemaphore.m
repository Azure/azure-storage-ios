// -----------------------------------------------------------------------------------------
// <copyright file="AZSTestSemaphore.m" company="Microsoft">
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

#import "AZSTestSemaphore.h"

@implementation AZSTestSemaphore

+(void) barrierOnSemaphores:(NSArray *)semaphores
{
    for (AZSTestSemaphore *lock in semaphores) {
        [lock wait];
    }
}

-(instancetype) init
{
    self = [super init];
    if (self) {
        _done = NO;
        _condition = [[NSCondition alloc] init];
    }

    return self;
}

-(void) signal
{
    [self.condition lock];
    self.done = YES;
    [self.condition signal];
    [self.condition unlock];
}

-(void) wait
{
    [self.condition lock];
    while (!self.done) {
        [self.condition wait];
    }
    
    self.done = NO;
    [self.condition unlock];
}

@end
