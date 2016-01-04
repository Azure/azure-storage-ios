// -----------------------------------------------------------------------------------------
// <copyright file="AZSOperationContext.m" company="Microsoft">
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

#import "AZSOperationContext.h"

@implementation AZSOperationContext
{
    aslclient _logger;
    NSCondition *_logCondition;
    NSMutableArray *_requestResults;
}

static void (^_globalLogFunction)(AZSLogLevel logLevel, NSString* logMessage);
static AZSLogLevel _globalLogLevel;
static aslclient _globalLogger;
static NSCondition *_globalLogCondition;

+(void)initialize
{
    if (self == [AZSOperationContext class])
    {
        _globalLogCondition = [[NSCondition alloc] init];
    }
}

+(AZSLogLevel)globalLogLevel
{
    return _globalLogLevel;
}

+(void)setGlobalLogLevel:(AZSLogLevel)globalLogLevel
{
    _globalLogLevel = globalLogLevel;
}

+(aslclient)globalLogger
{
    return _globalLogger;
}

+(void)setGlobalLogger:(aslclient)globalLogger
{
    _globalLogger = globalLogger;
}

+(void)setGlobalLogFunction:(void (^)(AZSLogLevel logLevel, NSString * stringToLog))globalLogFunction
{
    _globalLogFunction = globalLogFunction;
}

+(void(^)(AZSLogLevel logLevel, NSString * stringToLog)) globalLogFunction
{
    return _globalLogFunction;
}

-(instancetype)init
{
    self = [super init];
    if (self)
    {
        _clientRequestId = [[NSUUID UUID] UUIDString];
        _requestResults = [NSMutableArray arrayWithCapacity:1];
        _retryPolicy = [[AZSRetryPolicyExponential alloc] init];
    }
    
    return self;
}

-(aslclient)logger
{
    return _logger;
}

-(NSCondition *)loggerCondition
{
    return _logCondition;
}

-(void)setLogger:(aslclient)logger withCondition:(NSCondition *)condition
{
    _logger = logger;
    _logCondition = condition;
}

-(void)logAtLevel:(AZSLogLevel)logLevel withMessage:(NSString *)stringToLog,...
{
    // TODO: add more helpful information to the message?
    // Don't log anything at this level.
    if (logLevel == AZSLogLevelNoLogging)
    {
        return;
    }
    
    va_list args;
    va_start(args, stringToLog);
    NSString *finalLogString;
    
    // Static section:
    if (logLevel <= _globalLogLevel)
    {
        if (_globalLogFunction)
        {
            if (!finalLogString)
            {
                finalLogString = [[NSString alloc] initWithFormat:stringToLog arguments:args];
            }
            _globalLogFunction(logLevel, finalLogString);
        }
        else
        {
            if (_globalLogger)
            {
                aslmsg message = asl_new(ASL_TYPE_MSG);
                // This algorithm is taken from the ASL_PREFILTER_LOG macro, except we can't use it directly, because we want to
                // format the string using Objective-C format specifiers, not C ones.  (%@ instead of %s, for example.)
                // We want to format the string only if the log message will not get filtered out.
                // Unfortuantely, the _asl_evaluate_send is undocumented, so this may be unstable.
                // TODO: Write a test to ensure that the logging works properly in future versions.
                uint32_t _asl_eval = _asl_evaluate_send(_globalLogger, message, logLevel);
                if (_asl_eval != 0)
                {
                    if (!finalLogString)
                    {
                        finalLogString = [[NSString alloc] initWithFormat:stringToLog arguments:args];
                    }
                    
                    [_globalLogCondition lock];
                    asl_log(_globalLogger, message, logLevel, "%s", [finalLogString cStringUsingEncoding:NSUTF8StringEncoding]);
                    [_globalLogCondition unlock];
                }
                asl_free(message);
            }
        }
    }
    
    // Instance section:
    if (logLevel <= self.logLevel)
    {
        if (self.logFunction)
        {
            if (!finalLogString)
            {
                finalLogString = [[NSString alloc] initWithFormat:stringToLog arguments:args];
            }
            self.logFunction(logLevel, finalLogString);
        }
        else
        {
            if (_logger && _logCondition)
            {
                aslmsg message = asl_new(ASL_TYPE_MSG);
                uint32_t _asl_eval = _asl_evaluate_send(_logger, message, logLevel);
                if (_asl_eval != 0)
                {
                    if (!finalLogString)
                    {
                        finalLogString = [[NSString alloc] initWithFormat:stringToLog arguments:args];
                    }
                    
                    [_logCondition lock];
                    asl_log(_logger, message, logLevel, "%s", [finalLogString cStringUsingEncoding:NSUTF8StringEncoding]);
                    [_logCondition unlock];
                }
                asl_free(message);
            }
        }
    }
    
    va_end(args);  // Free the memory used for args.
}

-(NSArray *)requestResults
{
    return _requestResults;
}

-(void)addRequestResult:(AZSRequestResult *)requestResultToAdd
{
    [_requestResults addObject:requestResultToAdd];
}

@end