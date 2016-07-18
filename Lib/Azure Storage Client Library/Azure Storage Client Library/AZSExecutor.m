// -----------------------------------------------------------------------------------------
// <copyright file="AZSExecutor.m" company="Microsoft">
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

#import <CommonCrypto/CommonDigest.h>
#import "AZSBlobInputStream.h"
#import "AZSConstants.h"
#import "AZSExecutor.h"
#import "AZSOperationContext.h"
#import "AZSRequestOptions.h"
#import "AZSEnums.h"
#import "AZSStorageCommand.h"
#import "AZSStorageUri.h"
#import "AZSStreamDownloadBuffer.h"
#import "AZSRequestResult.h"
#import "AZSErrors.h"
#import "AZSRetryContext.h"
#import "AZSRetryInfo.h"
#import "AZSUtil.h"
#import "AZSStorageCredentials.h"

@interface AZSExecutor()
@property (strong) AZSStorageCommand* storageCommand;
@property (strong) AZSRequestOptions* requestOptions;
@property (strong) AZSOperationContext* operationContext;
@property (copy) NSDate *startTime;
@property (strong) NSURLComponents *urlComponents;
@property (strong) NSMutableURLRequest *request;
@property (strong) AZSRequestResult *requestResult;
@property (strong) NSHTTPURLResponse *httpResponse;
@property (copy) void (^completionHandler)(NSError *, id);
@property BOOL isSourceStreamSet;
@property (strong) AZSStreamDownloadBuffer *originalDownloadBuffer;
@property (strong) AZSStreamDownloadBuffer *downloadBuffer;
@property (strong) NSError *preProcessError;
@property (strong) id<AZSRetryPolicy> retryPolicy;
@property NSUInteger retryCount;
@property AZSStorageLocation currentStorageLocation;
@property AZSStorageLocationMode currentStorageLocationMode;
@property BOOL removeFromRunLoop;
@property (strong) NSOutputStream *outputStream;

-(instancetype)init AZS_DESIGNATED_INITIALIZER;
-(instancetype)initWithCommand:(AZSStorageCommand *)storageCommand requestOptions:(AZSRequestOptions *)requestOptions operationContext:(AZSOperationContext *) operationContext downloadBuffer:(AZSStreamDownloadBuffer *)downloadBuffer completionHandler:(void (^)(NSError *, id))completionHandler AZS_DESIGNATED_INITIALIZER;

@end

@implementation AZSExecutor

+(void)ExecuteWithStorageCommand:(AZSStorageCommand *)storageCommand requestOptions:(AZSRequestOptions *)requestOptions operationContext:(AZSOperationContext *)operationContext completionHandler:(void (^)(NSError *, id))completionHandler
{
    [AZSExecutor ExecuteWithStorageCommand:storageCommand requestOptions:requestOptions operationContext:operationContext downloadBuffer:nil completionHandler:completionHandler];
}

+(void)ExecuteWithStorageCommand:(AZSStorageCommand *)storageCommand requestOptions:(AZSRequestOptions *)requestOptions operationContext:(AZSOperationContext *)operationContext downloadBuffer:(AZSStreamDownloadBuffer *)downloadBuffer completionHandler:(void (^)(NSError*, id))completionHandler
{
    AZSExecutor *executor = [[AZSExecutor alloc] initWithCommand:storageCommand requestOptions:requestOptions operationContext:operationContext downloadBuffer:downloadBuffer completionHandler:completionHandler];
    [executor execute];
}

-(NSString *)validateLocationMode
{
    BOOL isValid = NO;
    switch (self.currentStorageLocationMode)
    {
        case AZSStorageLocationModePrimaryOnly:
        {
            isValid = self.storageCommand.storageUri.primaryUri != nil;
            break;
        }
        case AZSStorageLocationModeSecondaryOnly:
        {
            isValid = self.storageCommand.storageUri.secondaryUri != nil;
            break;
        }
        default:
        {
            isValid = (self.storageCommand.storageUri.primaryUri != nil) && (self.storageCommand.storageUri.secondaryUri != nil);
            break;
        }
    }

    if (!isValid)
    {
        return @"No URI specified for input AZSStorageLocationMode.";
    }
    
    switch (self.storageCommand.allowedStorageLocation)
    {
        case AZSAllowedStorageLocationPrimaryOnly:
        {
            if (self.currentStorageLocationMode == AZSStorageLocationModeSecondaryOnly)
            {
                return @"Cannot make this request to secondary.";
            }
            self.currentStorageLocationMode = AZSStorageLocationModePrimaryOnly;
            self.currentStorageLocation = AZSStorageLocationPrimary;
            break;
        }
        case AZSAllowedStorageLocationSecondaryOnly:
        {
            if (self.currentStorageLocationMode == AZSStorageLocationModePrimaryOnly)
            {
                return @"Cannot make this request to primary.";
            }
            self.currentStorageLocationMode = AZSStorageLocationModeSecondaryOnly;
            self.currentStorageLocation = AZSStorageLocationSecondary;
            break;
        }
        default:
        {
            break;
        }
    }
    
    return nil;
}

-(void)execute
{
    if (!self.operationContext.startTime)
    {
        self.operationContext.startTime = [NSDate date];
    }
    
    // do-while (to allow for retries)
    {
        // 0. Begin the request
        NSString *locationModeError = [self validateLocationMode];
        if (locationModeError)
        {
            NSError *storageError = [NSError errorWithDomain:AZSErrorDomain code:AZSEInvalidArgument userInfo:@{NSLocalizedDescriptionKey:locationModeError}];
            
            self.completionHandler(storageError, nil);
            return;
        }
        
        // 1. Build the request
        // Build request by setting a start time, creating a uri(builder?), calling storageCommand.buildRequest(), and initializing a RequestResult.
        AZSStorageUri *transformedUri = [self.storageCommand.credentials transformWithStorageUri:self.storageCommand.storageUri];
        [self setStartTime:[NSDate date]];  //UTC
        [self setUrlComponents:[NSURLComponents componentsWithURL: [transformedUri urlWithLocation:self.currentStorageLocation] resolvingAgainstBaseURL:NO]];
        [self setRequest:self.storageCommand.buildRequest(self.urlComponents, self.requestOptions.serverTimeout, self.operationContext)];
        [self setRequestResult:[[AZSRequestResult alloc] initWithStartTime:self.startTime location:self.currentStorageLocation]];
        
        
        // Log that we're starting the request
        
        // 2. Set the headers on the request
        // Request ID header
        NSString *clientRequestId = self.operationContext.clientRequestId;
        if ([clientRequestId length] != 0)
        {
            [self.request setValue:clientRequestId forHTTPHeaderField:AZSCHeaderClientRequestId];
        }
        
        // User headers from op context
        // Set the request body on the request object
        // Potentially set the destination stream
        // Inform that we're ready to send by calling SendingRequest()
        // Note: We may want to just set all headers here, or we could set some (like the user-agent string) in the NSURLSessionConfiguration.

        // TODO: make this static, so that we're not querying the OS each time
        NSString *operationSystemVersionString = [NSProcessInfo processInfo].operatingSystemVersionString;
        [self.request setValue:[NSString stringWithFormat:AZSCHeaderValueUserAgent,operationSystemVersionString] forHTTPHeaderField:AZSCHeaderUserAgent];
        
        // Add the user headers, if they exist.
        if (self.operationContext.userHeaders)
        {
           [self.operationContext.userHeaders enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
               [self.request setValue:obj forHTTPHeaderField:key];
           }];
        }
        
        // Inform the caller of the request being sent.
        if (self.operationContext.sendingRequest)
        {
            self.operationContext.sendingRequest(self.request, self.operationContext);
        }
        
        // 3. Sign request
        self.storageCommand.signRequest(self.request, self.operationContext);
        
        // 4. Configure http client
        // Set timeout
        // Set http buffer size
        // Set chunksize
        
        NSURLSessionConfiguration *sessionConfiguration = [NSURLSessionConfiguration ephemeralSessionConfiguration];
        sessionConfiguration.URLCache = nil;
        sessionConfiguration.requestCachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
        
        NSTimeInterval clientTimeout = [self remainingTime];
        if (clientTimeout <= 0)
        {
            NSDictionary *userInfo = @{};
            NSError *storageError = [NSError errorWithDomain:AZSErrorDomain code:AZSEClientTimeout userInfo:userInfo];
            
            self.completionHandler(storageError, nil);
            return;
        }
        
        sessionConfiguration.timeoutIntervalForResource = clientTimeout;
        
        [self.operationContext logAtLevel:AZSLogLevelInfo withMessage:@"Sending Request with URL:%@", [self.request.URL absoluteString]];
        for (NSString *headerName in [self.request allHTTPHeaderFields])
        {
            [self.operationContext logAtLevel:AZSLogLevelInfo withMessage:@"Sending header name = %@; value = %@", headerName, [[self.request allHTTPHeaderFields] objectForKey:headerName]];
        }
        
        // TODO: Set this if necessary (if we use a session for more than one request at once).
        // sessionConfiguration.HTTPMaximumConnectionsPerHost = ?
        // Do we need to set min/max TLS protocol version?
        
        // 5. Initiate request, possibly uploading data
        // TODO: Decide what to do about the delegate queue - should we have greater control over this?  Should we allow users to pass in a delegate queue?
        // Passing in nil will allow the NSURLSession to create a default serial delegate queue.
        NSURLSession *session = [NSURLSession sessionWithConfiguration:sessionConfiguration delegate:self delegateQueue:nil];
        NSURLSessionDataTask *task;
        if (self.storageCommand.source != nil)
        {
            task = [session uploadTaskWithRequest:self.request fromData:self.storageCommand.source];
        }
        else
        {
            task = [session dataTaskWithRequest:self.request];
        }
        [task resume];
    }
}

// Note: We need to use an NSData for upload, not an NSInputStream, because we need to know the length in advance for signing purposes (at least for shared key.)
// Thus, the following method is not implemented.
// TODO: Figure out if we need to support streaming for SAS.
//-(void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task needNewBodyStream:(void (^)(NSInputStream *))completionHandler;
 
 /*
 -(void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didSendBodyData:(int64_t)bytesSent totalBytesSent:(int64_t)totalBytesSent totalBytesExpectedToSend:(int64_t)totalBytesExpectedToSend
 {
 // TODO: Update status with data sent
 }
 */

-(void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler
{
    self.httpResponse = (NSHTTPURLResponse *) response;

    [self.operationContext logAtLevel:AZSLogLevelInfo withMessage:@"Response HTTP status code = %ld", (long)self.httpResponse.statusCode];
    for (id headerkey in self.httpResponse.allHeaderFields)
    {
        [self.operationContext logAtLevel:AZSLogLevelInfo withMessage:@"Response header name = %@; value = %@",headerkey, self.httpResponse.allHeaderFields[headerkey]];
    }

    if (self.operationContext.responseReceived)
    {
        self.operationContext.responseReceived(self.request, self.httpResponse, self.operationContext);
    }

    self.requestResult = [[AZSRequestResult alloc] initWithStartTime:self.startTime location:self.currentStorageLocation response:self.httpResponse error:nil];
    self.preProcessError = self.storageCommand.preProcessResponse(self.httpResponse, self.requestResult, self.operationContext);
    
    // TODO: Don't bother with all the stream stuff (especially thread creation) if there is no body.
    if (self.preProcessError) {
        // In case of error, we want a memory stream and clean download buffer.
        self.outputStream = [NSOutputStream outputStreamToMemory];
        self.downloadBuffer = [[AZSStreamDownloadBuffer alloc] initWithOutputStream:self.outputStream maxSizeToBuffer:self.requestOptions.maximumDownloadBufferSize calculateMD5:(self.storageCommand.calculateResponseMD5 && (self.requestResult.contentReceivedMD5 != nil)) runLoopForDownload:self.requestOptions.runLoopForDownload operationContext:self.operationContext];
        
        [self.downloadBuffer createAndSpinRunloop];
        self.removeFromRunLoop = YES;
    }
    else {
        // Otherwise we should use the same download buffer every time, and the user supplied stream (if any).
        if (!self.originalDownloadBuffer) {
            self.outputStream = self.storageCommand.destinationStream ?: [NSOutputStream outputStreamToMemory];
            self.originalDownloadBuffer = [[AZSStreamDownloadBuffer alloc] initWithOutputStream:self.outputStream maxSizeToBuffer:self.requestOptions.maximumDownloadBufferSize calculateMD5:(self.storageCommand.calculateResponseMD5 && (self.requestResult.contentReceivedMD5 != nil)) runLoopForDownload:self.requestOptions.runLoopForDownload operationContext:self.operationContext];
            [self.originalDownloadBuffer createAndSpinRunloop];
            self.removeFromRunLoop = YES;
        }
        
        self.downloadBuffer = self.originalDownloadBuffer;
    }
    
    completionHandler(NSURLSessionResponseAllow);
}

-(void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data
{
    // Note that the following call will block if the buffer is full.  This is by design.
    if (!self.downloadBuffer.streamError)
    {
        [self.downloadBuffer writeData:data];
    }
}

-(void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{
    // This is called upon task completion.  If there were no error, *error will be nil.

    self.requestResult.calculatedResponseMD5 = [self.downloadBuffer checkMD5];
    
    [self.downloadBuffer.dataDownloadCondition lock];
    [self.operationContext logAtLevel:AZSLogLevelDebug withMessage:@"Grabbed lock in didComplete."];
    
    while ((self.downloadBuffer.currentLength > 0) && !self.downloadBuffer.streamError)
    {
        [self.operationContext logAtLevel:AZSLogLevelDebug withMessage:@"Waiting on condition in didComplete.  CurrentLength = %ld.", (unsigned long)self.downloadBuffer.currentLength];
        [self.downloadBuffer.dataDownloadCondition wait];
    }
    [self.downloadBuffer.dataDownloadCondition unlock];
    [self.operationContext logAtLevel:AZSLogLevelDebug withMessage:@"Released lock in didComplete."];
    
    self.downloadBuffer.downloadComplete = YES;
    if (self.removeFromRunLoop) {
        [self.downloadBuffer removeFromRunLoop];
    }
    
    if (error) // If DidCompleteWithError was passed an error
    {
        // TODO: Make this error retryable, and have more information with it.
        NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
        userInfo[AZSInnerErrorString] = error;
        NSError *clientError = [NSError errorWithDomain:AZSErrorDomain code:AZSEURLSessionClientError userInfo:userInfo];
        [self finishRequestWithSession:session error:clientError retval:nil];
    }
    else if (self.downloadBuffer.streamError) // If there was an error in streaming
    {
        [self finishRequestWithSession:session error:self.downloadBuffer.streamError retval:nil];
    }
    else if (self.preProcessError) // If there was a server error, we can parse the XML from the service.
    {
        NSError *serverError = self.preProcessError;
        NSError *parsingError;
        self.storageCommand.processError(self.outputStream, &serverError, &parsingError);
        self.preProcessError = serverError;
        if (parsingError)
        {
            [self finishRequestWithSession:session error:parsingError retval:nil];
        }
        else
        {
            [self finishRequestWithSession:session error:self.preProcessError retval:nil];
        }
    }
    else if (!self.httpResponse)
    {
        // Occasionally, didCompleteWithError is called without didRecieveResponse being called.  This code block catches that case.
        // TODO: Figure out why this happens.  It might have something to do with a flaky internet connection?
        // TODO: Make this error retryable, and have more information with it.
        NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
        self.preProcessError = [NSError errorWithDomain:AZSErrorDomain code:AZSEServerError userInfo:userInfo];
        [self finishRequestWithSession:session error:self.preProcessError retval:nil];
    }
    else // No errors
    {
        id retval = nil;
        NSError *error = nil;
        if (self.storageCommand.postProcessResponse)
        {
            retval = self.storageCommand.postProcessResponse(self.httpResponse, self.requestResult, self.outputStream, self.operationContext, &error);
        }
        
        [self finishRequestWithSession:session error:error retval:retval];
    }
}

-(void)URLSession:(NSURLSession *)session didBecomeInvalidWithError:(NSError *)error
{
    // This is called if/when the session becomes invalid for some reason on the client.
    // This is not called for server errors.
    if (error)
    {
        NSDictionary *userInfo = @{AZSInnerErrorString: error};
        NSError *storageError = [NSError errorWithDomain:AZSErrorDomain code:AZSEURLSessionClientError userInfo:userInfo];
        [self finishRequestWithSession:session error:storageError retval:nil];
    }
}

-(AZSStorageLocation) getNextLocation
{
    switch (self.currentStorageLocationMode)
    {
        case AZSStorageLocationModePrimaryOnly:
        {
            return AZSStorageLocationPrimary;
        }
        case AZSStorageLocationModeSecondaryOnly:
        {
            return AZSStorageLocationSecondary;
        }
        case AZSStorageLocationModeUnspecified:
        {
            return AZSStorageLocationPrimary;
        }
        default:
        {
            return (self.currentStorageLocation == AZSStorageLocationPrimary ? AZSStorageLocationSecondary : AZSStorageLocationPrimary);
        }
    }
}

-(void)finishRequestWithSession:(NSURLSession *)session error:(NSError *)error retval:(id)retval
{
    // Required to release memory related to the session, etc:
    [self.operationContext logAtLevel:AZSLogLevelDebug withMessage:@"Finishing session."];
    [session finishTasksAndInvalidate];
    
    self.requestResult = [[AZSRequestResult alloc] initWithStartTime:self.startTime location:self.currentStorageLocation response:self.httpResponse error:error];
    [self.operationContext addRequestResult:self.requestResult];
    self.retryCount++;
    
    BOOL retry = YES;
    
    // Don't retry if there wasn't an error.
    if (retry && !error)
    {
        retry = NO;
    }

    // We cannot recover and retry the request if any data has been written to the caller's stream.
    if (retry && (self.storageCommand.destinationStream == self.outputStream) && (self.downloadBuffer.totalSizeStreamed > 0))
    {
        retry = NO;
    }
    
    // Evaluate using the retry policy.
    AZSRetryInfo *retryInfo = nil;
    if (retry)
    {
        AZSRetryContext *retryContext = [[AZSRetryContext alloc] initWithCurrentRetryCount:self.retryCount lastRequestResult:self.requestResult nextLocation:[self getNextLocation] currentLocationMode:self.currentStorageLocationMode];
        retryInfo = [self.retryPolicy evaluateRetryContext:retryContext withOperationContext:self.operationContext];
        if (!retryInfo.shouldRetry)
        {
            retry = NO;
        }
    }
    
    if (retry)
    {
        [self.operationContext logAtLevel:AZSLogLevelInfo withMessage:[NSString stringWithFormat:@"Retrying on HTTP status code %ld.", (long)self.requestResult.response.statusCode]];
        
        self.currentStorageLocation = retryInfo.targetLocation;
        self.currentStorageLocationMode = retryInfo.updatedLocationMode;
        NSDate *retryTime = [NSDate dateWithTimeIntervalSinceNow:retryInfo.retryInterval];
        
        NSDate *loopUntil = [NSDate dateWithTimeIntervalSinceNow:0.1];
        while ([[NSDate date] compare:retryTime] == NSOrderedAscending)
        {
            BOOL runloopSuccess = [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:loopUntil];
            
            if (!runloopSuccess)
            {
                [NSThread sleepForTimeInterval:MIN(1.0, [retryTime timeIntervalSinceDate:[NSDate date]])];
            }
            
            loopUntil = [NSDate dateWithTimeIntervalSinceNow:0.1];
        }
        
        [self execute];
    }
    else
    {
        if (!self.downloadBuffer.streamError) {
            self.downloadBuffer.streamError = error;
        }
        
        if (self.originalDownloadBuffer && self.originalDownloadBuffer != self.downloadBuffer)
        {
            self.originalDownloadBuffer.streamError = self.downloadBuffer.streamError;
            self.originalDownloadBuffer.downloadComplete = YES;
        }
        self.operationContext.endTime = [NSDate date];
        if (self.removeFromRunLoop) {
            [self.outputStream close];
        }
        
        self.completionHandler(error, retval);
    }
}

-(instancetype)init
{
    return nil;
}

+(AZSStorageLocation) getFirstLocationWithStorageLocationMode:(AZSStorageLocationMode)locationMode
{
    switch (locationMode) {
        case AZSStorageLocationModePrimaryOnly:
        case AZSStorageLocationModePrimaryThenSecondary:
        case AZSStorageLocationModeUnspecified:
        {
            return AZSStorageLocationPrimary;
        }
        case AZSStorageLocationModeSecondaryOnly:
        case AZSStorageLocationModeSecondaryThenPrimary:
        {
            return AZSStorageLocationSecondary;
        }
    }
}

-(instancetype) initWithCommand:(AZSStorageCommand *)storageCommand requestOptions:(AZSRequestOptions *)requestOptions operationContext:(AZSOperationContext *) operationContext downloadBuffer:(AZSStreamDownloadBuffer *)downloadBuffer completionHandler:(void (^)(NSError *, id))completionHandler
{
    self = [super init];
    if (self)
    {
        _storageCommand = storageCommand;
        _requestOptions = requestOptions;
        _operationContext = operationContext;
        _completionHandler = completionHandler;
        _originalDownloadBuffer = downloadBuffer;
        _downloadBuffer = downloadBuffer;
        _retryCount = 0;
        _retryPolicy = [operationContext.retryPolicy clone];
        _currentStorageLocation = [AZSExecutor getFirstLocationWithStorageLocationMode:requestOptions.storageLocationMode];
        _currentStorageLocationMode = requestOptions.storageLocationMode;
    }
    
    return self;
}

-(NSTimeInterval) remainingTime
{
    if (self.requestOptions.operationExpiryTime)
    {
        return [self.requestOptions.operationExpiryTime timeIntervalSinceNow];
    }
    else
    {
        return 60*60*24*7;  // 7 days is the default timeout in iOS, although we don't have to stick to that.
    }
}

@end