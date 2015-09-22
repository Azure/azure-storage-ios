// -----------------------------------------------------------------------------------------
// <copyright file="AZSRequestOptions.m" company="Microsoft">
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

#import "AZSRequestOptions.h"

@interface AZSRequestOptions()
{
    BOOL _runLoopForDownloadSet;
    BOOL _serverTimeoutSet;
    BOOL _maximumDownloadBufferSizeSet;
    BOOL _maximumExecutionTimeSet;
}

-(AZSRequestOptions *)copy;

@end

@implementation AZSRequestOptions

@synthesize runLoopForDownload = _runLoopForDownload;
@synthesize serverTimeout = _serverTimeout;
@synthesize maximumDownloadBufferSize = _maximumDownloadBufferSize;
@synthesize maximumExecutionTime = _maximumExecutionTime;
@synthesize operationExpiryTime = _operationExpiryTime;

-(instancetype)init
{
    self = [super init];
    if (self)
    {
        _runLoopForDownload = nil;
        _runLoopForDownloadSet = NO;
        _serverTimeout = 30;
        _serverTimeoutSet = NO;
        _maximumDownloadBufferSize = 1024*1024;
        _maximumDownloadBufferSizeSet = NO;
        _maximumExecutionTime = 600.0;
        _maximumExecutionTimeSet = NO;
    }
    
    return self;
}

-(instancetype)copy
{
    AZSRequestOptions *newOptions = [[AZSRequestOptions alloc] init];
    [newOptions  applyDefaultsFromOptions:self];
    return newOptions;
}

+(instancetype)copyOptions:(AZSRequestOptions *)optionsToCopy
{
    if (optionsToCopy != nil)
    {
        return [optionsToCopy copy];
    }
    else
    {
        return [[AZSRequestOptions alloc] init];
    }
}

-(instancetype)applyDefaultsFromOptions:(AZSRequestOptions *)sourceOptions
{
    if (sourceOptions != nil)
    {
        if (sourceOptions->_runLoopForDownloadSet)
        {
            self.runLoopForDownload = sourceOptions.runLoopForDownload;
        }
        
        if (sourceOptions->_serverTimeoutSet)
        {
            self.serverTimeout = sourceOptions.serverTimeout;
        }
        
        if (sourceOptions->_maximumDownloadBufferSizeSet)
        {
            self.maximumDownloadBufferSize = sourceOptions.maximumDownloadBufferSize;
        }
        
        if (sourceOptions->_maximumExecutionTimeSet)
        {
            self.maximumExecutionTime = sourceOptions.maximumExecutionTime;
        }
        
        _operationExpiryTime = [NSDate dateWithTimeIntervalSinceNow:self.maximumExecutionTime];
    }
    
    return self;
}

-(NSRunLoop *)runLoopForDownload
{
    return _runLoopForDownload;
}

-(void)setRunLoopForDownload:(NSRunLoop *)runLoopForDownload
{
    _runLoopForDownload = runLoopForDownload;
    _runLoopForDownloadSet = YES;
}

-(NSTimeInterval)serverTimeout
{
    return _serverTimeout;
}

-(void)setServerTimeout:(NSTimeInterval)serverTimeout
{
    _serverTimeout = serverTimeout;
    _serverTimeoutSet = YES;
}

-(NSUInteger)maximumDownloadBufferSize
{
    return _maximumDownloadBufferSize;
}

-(void)setMaximumDownloadBufferSize:(NSUInteger)maximumDownloadBufferSize
{
    _maximumDownloadBufferSize = maximumDownloadBufferSize;
    _maximumDownloadBufferSizeSet = YES;
}

-(NSTimeInterval)maximumExecutionTime
{
    return _maximumExecutionTime;
}

-(void)setMaximumExecutionTime:(NSTimeInterval)maximumExecutionTime
{
    _maximumExecutionTime = maximumExecutionTime;
    _maximumExecutionTimeSet = YES;
}

@end
