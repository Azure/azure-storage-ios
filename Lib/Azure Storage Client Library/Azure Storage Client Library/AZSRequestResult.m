// -----------------------------------------------------------------------------------------
// <copyright file="AZSRequestResult.m" company="Microsoft">
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

#include <time.h>
#import "AZSConstants.h"
#import "AZSRequestResult.h"

@interface AZSRequestResult()

-(instancetype)init AZS_DESIGNATED_INITIALIZER;

@end

@implementation AZSRequestResult

- (instancetype)init
{
    return nil;
}

-(instancetype) initWithStartTime:(NSDate *)startTime location:(AZSStorageLocation)targetLocation
{
    self = [super init];
    if (self)
    {
        _startTime = startTime;
        _targetLocation = targetLocation;
        _responseAvailable = NO;
        _endTime = [NSDate date];
    }
    
    return self;
}

-(instancetype) initWithStartTime:(NSDate *)startTime location:(AZSStorageLocation)targetLocation response:(NSHTTPURLResponse *)response error:(NSError * __AZSNullable)error
{
    self = [super init];
    if (self)
    {
        _response = response;
        _startTime = startTime;
        _targetLocation = targetLocation;
        _responseAvailable = YES;
        _endTime = [NSDate date];
        _error = error;
        _serviceRequestID = response.allHeaderFields[AZSCHeaderRequestId];
        
        if (response.allHeaderFields[AZSCContentLength])
        {
            _contentReceivedLength = [NSNumber numberWithLongLong:[response.allHeaderFields[AZSCContentLength] longLongValue]].unsignedIntegerValue;
        }
        
        _contentReceivedMD5 = response.allHeaderFields[AZSCContentMd5];
        _etag = response.allHeaderFields[AZSCXmlETag];
        
        if (response.allHeaderFields[AZSCHeaderValueDate])
        {
            const char * dateString = [response.allHeaderFields[AZSCHeaderValueDate] UTF8String];
            struct tm timeptr;
            strptime(dateString, [AZSCDateFormatColloquial UTF8String], &timeptr);
            _serviceRequestDate = [NSDate dateWithTimeIntervalSince1970:mktime(&timeptr)];
        }
    }
    
    return self;
}

@end