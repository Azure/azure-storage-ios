// -----------------------------------------------------------------------------------------
// <copyright file="AZSIPRange.m" company="Microsoft">
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
#import "AZSConstants.h"
#import "AZSErrors.h"
#import "AZSIPRange.h"
#import "AZSOperationContext.h"
#import "AZSUtil.h"
#import "arpa/inet.h"

@interface AZSIPRange()
-(instancetype) init AZS_DESIGNATED_INITIALIZER;
@end

@implementation AZSIPRange

-(instancetype) init
{
    return nil;
}

-(instancetype) initWithSingleIPString:(NSString *)ipString error:(NSError *__autoreleasing *)error
{
    struct in_addr ip;
    
    if (!inet_aton([ipString UTF8String], &ip)) {
        *error = [NSError errorWithDomain:AZSErrorDomain code:AZSEInvalidArgument userInfo:nil];
        [[AZSUtil operationlessContext] logAtLevel:AZSLogLevelError withMessage:@"Invalid IP string."];
        return nil;
    }
    return [self initWithSingleIP:ip];
}

-(instancetype) initWithMinIPString:(NSString *)minimumString maxIPString:(NSString *)maximumString error:(NSError *__autoreleasing *)error
{
    struct in_addr ipMin;
    struct in_addr ipMax;
    
    if (!inet_aton([minimumString UTF8String], &ipMin)) {
        *error = [NSError errorWithDomain:AZSErrorDomain code:AZSEInvalidArgument userInfo:nil];
        [[AZSUtil operationlessContext] logAtLevel:AZSLogLevelError withMessage:@"Invalid IP string."];
        return nil;
    }
    
    if (!inet_aton([maximumString UTF8String], &ipMax)) {
        *error = [NSError errorWithDomain:AZSErrorDomain code:AZSEInvalidArgument userInfo:nil];
        [[AZSUtil operationlessContext] logAtLevel:AZSLogLevelError withMessage:@"Invalid IP string."];
        return nil;
    }
    return [self initWithMinIP:ipMin maxIP:ipMax];
}

-(instancetype) initWithSingleIP:(struct in_addr)ip
{
    self = [super init];
    if (self) {
        _ipMinimum = ip;
        _ipMaximum = _ipMinimum;
        
        _rangeString = [NSString stringWithUTF8String:inet_ntoa(ip)];
    }
    
    return self;
}

-(instancetype) initWithMinIP:(struct in_addr)minimum maxIP:(struct in_addr)maximum
{
    self = [super init];
    if (self) {
        _ipMinimum = minimum;
        _ipMaximum = maximum;
        _rangeString = [NSString stringWithFormat:AZSCSasTemplateIpRange,
                [NSString stringWithUTF8String:inet_ntoa(minimum)],
                [NSString stringWithUTF8String:inet_ntoa(maximum)]];
    }
    
    return self;
}

@end