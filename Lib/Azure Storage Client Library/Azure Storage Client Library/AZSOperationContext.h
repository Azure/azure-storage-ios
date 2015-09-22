// -----------------------------------------------------------------------------------------
// <copyright file="AZSOperationContext.h" company="Microsoft">
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

#include <asl.h>

#import <Foundation/Foundation.h>
#import "AZSRetryPolicy.h"
#import "AZSMacros.h"
#import "AZSEnums.h"

@class AZSRequestResult;

AZS_ASSUME_NONNULL_BEGIN

/** The AZSOperationContext class contains all data relevant to an operation
 
 An AZSOperationContext is designed to be created by the code calling into Storage.  All
 methods that perform service requests optionally take in an AZSOperationContext.  The instance should
 be empty when passed into the Storage library, except where noted.  Once the operation is 
 finished, the AZSOperationContext will be populated with relevant information from the request.
 
 AZSOperationContext instances should not be resued between calls.
 
 This class is always optional.  If you do not provide one, you will not have access to the
 relevant information.
 
 AZSOperationContext is distinguished from AZSRequestResult because the AZSOperationContext
 represents an entire operation, which may contain multiple requests (if the operation retries,
 or requires multiple HTTP requests.)
 
 AZSOperationContext is distinguished from AZSRequestOptions classes because the AZSOperationContext represents
 the results from an entire operation and will be populated throughout the operation, while the 
 AZSRequestOptions is a set of options that governs how the library makes requests.  AZSRequestOptions instances
 can be reused freely in multiple operations, AZSOperationContext instances cannot.
 */
@interface AZSOperationContext : NSObject
{
}

/** A string representing the client request ID to assign to the request.
 This will automatically be initialized to a GUID when the class is initialized,
 but this may be overridden.
 */
@property (copy) NSString * clientRequestId;

/** Optional.  If non-nil, it's a block that the library will call shortly before it signs and sends a request.
 The request is included in the call; the block may modify the request as desired.
 Blocking here will block the request.
 */
@property (copy, AZSNullable) void(^sendingRequest)(NSMutableURLRequest *, AZSOperationContext *);

/** Optional.  If non-nil, it's a block that the library will call immediately upon receiving the response headers
 (before data is downloaded.)
 Blocking here will block the request.
 */
@property (copy, AZSNullable) void(^responseReceived)(NSMutableURLRequest *, NSHTTPURLResponse *, AZSOperationContext *);
// TODO: Should we have the other block methods from C# as well?

/**
 Optional.  An NSDictionary mapping strings to strings.  All objects in this dictionary will be interpreted as additional headers to
 be added to the request, with the keys being the name of the header and the value the header value.  The library will sign these if necessary.
 */
@property (strong, AZSNullable) NSDictionary *userHeaders;

/** The start time for the operation. */
@property (copy, AZSNullable) NSDate *startTime;

/** The end time for the operation. */
@property (copy, AZSNullable) NSDate *endTime;

/** An array of request results objects.  Populated by the library. */
@property (strong, readonly) NSArray *requestResults;

/** The retry policy for the request. */
@property (strong, AZSNullable) id<AZSRetryPolicy> retryPolicy;

/** The log level for this OperationContext instance.  Messages will only be logged if their severity is
 equal to or more severe than this. */
@property AZSLogLevel logLevel;

/** Optional.  A function that the caller can set.  If set, this function will be called when the library wants to log a message.
 This function will only be called if the severity of the message is high enough, compared to the logLevel.
 This function is designed if you have a specific logger or logging framework you would like to use.
 If this function is set, the instance logger (the logger property on this OperationContext instance) will be ignored.
 If this function is not set, and the instance logger is not set, no messages will be logged on this instance.  
 (Global logging may still occur.)
 
 | Parameter name | Description |
 |----------------|-------------|
 |logLevel | The log level of this particular log message.|
 |stringToLog | The formatted log message.|
 */
@property (copy) void(^logFunction)(AZSLogLevel logLevel, NSString * stringToLog);

/** The log level for all requests for the static logger.  A static variable.*/
+(AZSLogLevel)globalLogLevel;

/** Sets the log level for all requests for the static logger.  A static variable.

 @param globalLogLevel The global log level for the library.  Messages will only be logged to the global logger if their severity is
 equal to or more severe than this.
 */
+(void)setGlobalLogLevel:(AZSLogLevel)globalLogLevel;

/** Optional.  Returns the function that the caller can set.  See the setter documentation for details. */
+(void(^)(AZSLogLevel logLevel, NSString * stringToLog)) globalLogFunction;

/** Optional.  A function that the caller can set.  If set, this function will be called when the library wants to log a message globally.
 This function will only be called if the severity of the message is high enough, compared to the globalLogLevel.
 This function is designed if you have a specific logger or logging framework you would like to use.
 If this function is set, the global logger (the globalLogger property on the OperationContext class) will be ignored.
 If this function is not set, and the globalLogger is not set, no messages will be logged globally.  (Instance logging may still occur.)
 
 @param globalLogFunction The block of code to execute when the upload call completes.
 
 | Parameter name | Description |
 |----------------|-------------|
 |logLevel | The log level of this particular log message.|
 |stringToLog | The formatted log message.|

 */
+(void)setGlobalLogFunction:(void(^)(AZSLogLevel logLevel, NSString * stringToLog))globalLogFunction;

/** Optional.  The global (static) logger that the library will log messages to.  See the setter for more details.
 */
+(aslclient)globalLogger;

/** Optional.  The global (static) logger that the library will log messages to.  
 Assign an aslclient to this, and the library will log messages to it.
 If this is not set, and the globalLogFunction is not set, no messages will be logged globally.  (Instance logging may still occur.)
 Note that if the globalLogFunction is set, this is ignored.
 
 @param globalLogger The logger to use globally.
 */
+(void)setGlobalLogger:(aslclient)globalLogger;

/** Optional.  The global (static) logger that the library will log messages to.  See the setter for more details.
 */
-(aslclient)logger;

/** The NSCondition object that the OperationContext will use to avoid multiple messages being logged to the logger simultaneously.*/
-(NSCondition *)loggerCondition;

/** Optional.  The global (static) logger that the library will log messages to.
 Assign an aslclient to this, and the library will log messages to it.
 If this is not set, and the logFunction is not set, no messages will be logged on this instance.(Global logging may still occur.)
 Note that if the logFunction is set, this is ignored.
 The caller must also specify an NSCondition that the library can lock upon.  It is a requirement that aslclient instances are not accessed in parallel,
 this input NSCondition here is used to guard against that.  If you give the same aslclient instance to multiple operations at once, you must also specify the 
 same condition object, otherwise behavior will be undefined.
 
 @param logger The logger for this instance to use.
 @param condition The NSCondition to protect the logger.
 */
-(void)setLogger:(aslclient)logger withCondition:(NSCondition *)condition;

// This is what the library will call to log a message.
// Both the instance and global loggers will be tried.
-(void)logAtLevel:(AZSLogLevel)logLevel withMessage:(NSString *)stringToLog,...;

-(void)addRequestResult:(AZSRequestResult *)requestResultToAdd;

@end

AZS_ASSUME_NONNULL_END
