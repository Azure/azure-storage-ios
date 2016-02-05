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
#import "AZSConstants.h"
#import "AZSExecutor.h"
#import "AZSOperationContext.h"
#import "AZSRequestOptions.h"
#import "AZSEnums.h"
#import "AZSStorageCommand.h"
#import "AZSStorageUri.h"
#import "AZSRequestResult.h"
#import "AZSErrors.h"
#import "AZSRetryContext.h"
#import "AZSRetryInfo.h"
#import "AZSUtil.h"
#import "AZSStorageCredentials.h"

@interface AZSStreamDownloadBuffer : NSObject <NSStreamDelegate>
{
    @public
    CC_MD5_CTX _md5Context;
}

@property (strong, readonly) NSOutputStream *stream;
@property (strong, readonly) NSMutableArray *queue;
@property NSUInteger currentLength;
@property BOOL streamWaiting;
@property NSUInteger maxSizeToBuffer;
@property (strong) NSData *currentDataToStream;
@property uint64_t totalSizeStreamed;
@property (strong, readonly) NSCondition *dataDownloadCondition;
@property BOOL calculateMD5;
@property (strong, readonly) AZSOperationContext *operationContext;
@property (strong) NSError *streamError;

-(instancetype)init AZS_DESIGNATED_INITIALIZER;
-(instancetype)initWithStream:(NSOutputStream *)stream maxSizeToBuffer:(NSUInteger)maxSizeToBuffer calculateMD5:(BOOL)calculateMD5 operationContext:(AZSOperationContext *)operationContext AZS_DESIGNATED_INITIALIZER;
-(void)stream:(NSStream *)stream handleEvent:(NSStreamEvent)eventCode;
-(void)writeData:(NSData *)data;

@end

@implementation AZSStreamDownloadBuffer

-(instancetype)init
{
    return nil;
}

-(instancetype)initWithStream:(NSOutputStream *)stream maxSizeToBuffer:(NSUInteger)maxSizeToBuffer calculateMD5:(BOOL)calculateMD5 operationContext:(AZSOperationContext *)operationContext
{
    self = [super init];
    if (self)
    {
        _stream = stream;
        _queue = [[NSMutableArray alloc] init];
        _currentLength = 0;
        _streamWaiting = NO;
        _operationContext = operationContext;
        [_operationContext logAtLevel:AZSLogLevelDebug withMessage:@"Stream not waiting (init)"];
        _maxSizeToBuffer = maxSizeToBuffer;
        _currentDataToStream = nil;
        _totalSizeStreamed = 0;
        _dataDownloadCondition = [[NSCondition alloc] init];
        _calculateMD5 = calculateMD5;
        if (_calculateMD5)
        {
            CC_MD5_Init(&_md5Context);
        }
    }
    
    return self;
}

-(void)writeData:(NSData *)data
{
    if (self.calculateMD5)
    {
        CC_MD5_Update(&_md5Context, data.bytes, (unsigned int) data.length);
    }
    
    [self.operationContext logAtLevel:AZSLogLevelDebug withMessage:@"About to grab lock from data pushing"];
    
    // TODO: Optimize to remove the need for the lock (or at least, for locking the whole thing.)
    // To do this, we need to ensure that all data is written to the stream in the correct order (even if some writes are sync),
    // and that the current length and total size are consistent.
    
    [self.dataDownloadCondition lock];
    
    // TODO: self.streamWaiting should be set only if there is nothing in the buffer.  Make sure this is true, then simplify this condition.
    while (!(self.streamWaiting || (self.currentLength <= self.maxSizeToBuffer)))
    {
        [self.operationContext logAtLevel:AZSLogLevelDebug withMessage:@"Waiting on datadownloadcondition in writeData."];
        [self.dataDownloadCondition wait];
    }
    
    if (self.streamError)
    {
        // If there's an error, return.
        [self.dataDownloadCondition broadcast];
        [self.dataDownloadCondition unlock];
        return;
    }
    
    if (self.streamWaiting)
    {
        [self.operationContext logAtLevel:AZSLogLevelDebug withMessage:@"StreamWaiting = YES"];
    }
    else
    {
        [self.operationContext logAtLevel:AZSLogLevelDebug withMessage:@"StreamWaiting = NO"];
    }
    
    if (!self.streamWaiting)
    {
        [self.queue addObject:data];
        self.currentLength = self.currentLength + [data length];
        [self.operationContext logAtLevel:AZSLogLevelDebug withMessage:@"Adding to queue.  Current length = %ld, total amount streamed = %ld", (unsigned long)self.currentLength, (unsigned long)self.totalSizeStreamed];
    }
    else
    {
        NSUInteger lengthWritten = [self.stream write:(const uint8_t *)[data bytes] maxLength:[data length]];
        [self.operationContext logAtLevel:AZSLogLevelDebug withMessage:@"Wrote syncronously.  LengthWritten = %ld, desired write size = %ld.", (unsigned long)lengthWritten, (unsigned long)[data length]];
        
        if (lengthWritten == -1)
        {
            NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
            userInfo[AZSInnerErrorString] = self.stream.streamError;
            NSError *streamError = [NSError errorWithDomain:AZSErrorDomain code:AZSEOutputStreamError userInfo:userInfo];
            self.streamError = streamError;
            [self.operationContext logAtLevel:AZSLogLevelError withMessage:@"Error in writing to download stream, aborting download."];
        }
        else if (lengthWritten == 0)
        {
            NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
            userInfo[AZSInnerErrorString] = self.stream.streamError;
            NSError *streamError = [NSError errorWithDomain:AZSErrorDomain code:AZSEOutputStreamFull userInfo:userInfo];
            self.streamError = streamError;
            [self.operationContext logAtLevel:AZSLogLevelError withMessage:@"DownloadStream is full but there is more pending data, aborting download."];
        }
        else
        {
            self.totalSizeStreamed += lengthWritten;
            self.streamWaiting = NO;
            [self.operationContext logAtLevel:AZSLogLevelDebug withMessage:@"Stream not waiting."];
            // TODO: Handle 0 and -1 case;
            if (lengthWritten < [data length])
            {
                NSUInteger lengthRemaining = [data length] - lengthWritten;
                uint8_t buf[lengthRemaining];
                memcpy(buf, [data bytes] + lengthWritten, lengthRemaining);
                [self.queue addObject:[NSData dataWithBytes:buf length:lengthRemaining]];
                self.currentLength = self.currentLength + [data length];
            }
            
            [self.operationContext logAtLevel:AZSLogLevelDebug withMessage:@"Current length (wrote sync) = %ld, total amount streamed = %ld", (unsigned long)self.currentLength, (unsigned long)self.totalSizeStreamed];
        }
        // The following broadcast should never actually wake up anything, because the condition is only waited on in two cases:
        // - If the thread is done downloading and waiting for the buffer to clear (can't happen due to sync nature of didReceiveData and didCompleteWithError.)
        // - If the buffer is full and didReceiveData is thus blocking (in which case this method shouldn't be called.)
        // Leaving it in in case of any corner cases not yet thought of - this way, all writes from the buffer signals the condition.
        [self.dataDownloadCondition broadcast];
    }
    [self.dataDownloadCondition unlock];
}


-(void)stream:(NSStream *)stream handleEvent:(NSStreamEvent)eventCode
{
    if (![AZSUtil streamAvailable:stream])
    {
        return;
    }
    
    switch(eventCode) {
        case NSStreamEventHasSpaceAvailable:
        {
            [self.dataDownloadCondition lock];
            if (self.streamError)
            {
                // If there's already an error, return.
                [self.dataDownloadCondition broadcast];
                [self.dataDownloadCondition unlock];
                return;
            }
            
            [self.operationContext logAtLevel:AZSLogLevelDebug withMessage:@"Just grabbed lock from stream callback"];
            [self.operationContext logAtLevel:AZSLogLevelDebug withMessage:@"Current thread name = %@",[NSThread currentThread]];
            
            [self.operationContext logAtLevel:AZSLogLevelDebug withMessage:@"HasSpaceAvailable"];
            if ((self.currentDataToStream != nil) || ([self.queue count] > 0))
            {
                if (self.currentDataToStream == nil)
                {
                    self.currentDataToStream = (NSData *) self.queue.firstObject;
                    [self.queue removeObjectAtIndex:0];
                }
                NSUInteger lengthWritten = [self.stream write:(const uint8_t *)[self.currentDataToStream bytes] maxLength:[self.currentDataToStream length]];
                
                if (lengthWritten == -1)
                {
                    NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
                    userInfo[AZSInnerErrorString] = self.stream.streamError;
                    NSError *streamError = [NSError errorWithDomain:AZSErrorDomain code:AZSEOutputStreamError userInfo:userInfo];
                    self.streamError = streamError;
                    [self.operationContext logAtLevel:AZSLogLevelError withMessage:@"Error in writing to download stream, aborting download."];
                }
                else if (lengthWritten == 0)
                {
                    NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
                    userInfo[AZSInnerErrorString] = self.stream.streamError;
                    NSError *streamError = [NSError errorWithDomain:AZSErrorDomain code:AZSEOutputStreamFull userInfo:userInfo];
                    self.streamError = streamError;
                    [self.operationContext logAtLevel:AZSLogLevelError withMessage:@"DownloadStream is full but there is more pending data, aborting download."];
                }
                else
                {
                    self.currentLength = self.currentLength - lengthWritten;
                    self.totalSizeStreamed += lengthWritten;
                    [self.operationContext logAtLevel:AZSLogLevelDebug withMessage:@"Wrote async.  LengthWritten = %ld, desired write size = %ld.", (unsigned long)lengthWritten, (unsigned long)[self.currentDataToStream length]];
                    [self.operationContext logAtLevel:AZSLogLevelDebug withMessage:@"Current length (wrote async) = %ld, total amount streamed = %ld", (unsigned long)self.currentLength, (unsigned long)self.totalSizeStreamed];
                    
                    if (lengthWritten < [self.currentDataToStream length])
                    {
                        NSUInteger lengthRemaining = [self.currentDataToStream length] - lengthWritten;
                        uint8_t buf[lengthRemaining];
                        memcpy(buf, [self.currentDataToStream bytes] + lengthWritten, lengthRemaining);
                        self.currentDataToStream = [NSData dataWithBytes:buf length:lengthRemaining];
                    }
                    else
                    {
                        self.currentDataToStream = nil;
                    }
                }
            }
            else
            {
                self.streamWaiting = YES;
                [self.operationContext logAtLevel:AZSLogLevelDebug withMessage:@"Stream waiting."];
            }
            [self.operationContext logAtLevel:AZSLogLevelDebug withMessage:@"About to signal and release lock from stream callback"];
            [self.dataDownloadCondition broadcast];
            [self.dataDownloadCondition unlock];
            
            break;
        }
        case NSStreamEventEndEncountered:
        {
            break;
        }
        case NSStreamEventErrorOccurred:
        {
            NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
            userInfo[AZSInnerErrorString] = self.stream.streamError;
            NSError *streamError = [NSError errorWithDomain:AZSErrorDomain code:AZSEOutputStreamError userInfo:userInfo];
            self.streamError = streamError;
            [self.operationContext logAtLevel:AZSLogLevelError withMessage:@"Error in writing to download stream, aborting download."];
        }
        case NSStreamEventOpenCompleted:
        {
            break;
        }
        case NSStreamEventNone:
        {
            break;
        }
        case NSStreamEventHasBytesAvailable:
        {
            // Should never happen.
            break;
        }
    }
}
@end

@interface AZSExecutor()
@property (strong) AZSStorageCommand* storageCommand;
@property (strong) AZSRequestOptions* requestOptions;
@property (strong) AZSOperationContext* operationContext;
@property (copy) NSDate *startTime;
@property (strong) NSURLComponents *urlComponents;
@property AZSStorageLocation currentLocation;
@property (strong) NSMutableURLRequest *request;
@property (strong) AZSRequestResult *requestResult;
@property (strong) NSOutputStream *outputStream;
@property (strong) NSHTTPURLResponse *httpResponse;
@property (copy) void (^completionHandler)(NSError *, id);
@property BOOL isSourceStreamSet;
@property (strong) AZSStreamDownloadBuffer *downloadBuffer;
@property (strong) NSRunLoop *runLoopForDownload;
@property dispatch_semaphore_t semaphoreForRunloopCreation;
@property (strong) NSError *preProcessError;
@property NSUInteger retryCount;

-(instancetype)init AZS_DESIGNATED_INITIALIZER;
-(instancetype)initWithCommand:(AZSStorageCommand *)storageCommand requestOptions:(AZSRequestOptions *)requestOptions operationContext:(AZSOperationContext *) operationContext completionHandler:(void (^)(NSError *, id))completionHandler AZS_DESIGNATED_INITIALIZER;
@end

@implementation AZSExecutor

+(void)ExecuteWithStorageCommand:(AZSStorageCommand *)storageCommand requestOptions:(AZSRequestOptions *)requestOptions operationContext:(AZSOperationContext *)operationContext completionHandler:(void (^)(NSError *, id))completionHandler
{
    AZSExecutor *executor = [[AZSExecutor alloc] initWithCommand:storageCommand requestOptions:requestOptions operationContext:operationContext completionHandler:completionHandler];
    [executor execute];
}

+(void)ExecuteWithStorageCommand:(AZSStorageCommand *)storageCommand requestOptions:(AZSRequestOptions *)requestOptions operationContext:(AZSOperationContext *)operationContext retryCount:(NSUInteger)retryCount completionHandler:(void (^)(NSError *, id))completionHandler
{
    AZSExecutor *executor = [[AZSExecutor alloc] initWithCommand:storageCommand requestOptions:requestOptions operationContext:operationContext completionHandler:completionHandler];
    executor.retryCount = retryCount;
    [executor execute];
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
        // check location mode
        
        // 1. Build the request
        // Build request by setting a start time, creating a uri(builder?), calling storageCommand.buildRequest(), and initializing a RequestResult.
        AZSStorageUri *transformedUri = [self.storageCommand.credentials transformWithStorageUri:self.storageCommand.storageUri];
        [self setStartTime:[NSDate date]];  //UTC
        [self setUrlComponents:[NSURLComponents componentsWithURL: [transformedUri urlWithLocation:self.currentLocation] resolvingAgainstBaseURL:NO]];
        [self setRequest:self.storageCommand.buildRequest(self.urlComponents, self.requestOptions.serverTimeout, self.operationContext)];
        [self setRequestResult:[[AZSRequestResult alloc] initWithStartTime:self.startTime location:self.currentLocation]];
        
        
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

-(void)createAndSpinRunloopWithOutputStream:(id)outputStream
{
    @autoreleasepool {
        self.runLoopForDownload = [NSRunLoop currentRunLoop];
        [outputStream scheduleInRunLoop:self.runLoopForDownload forMode:NSDefaultRunLoopMode];
        [self.outputStream open];
        dispatch_semaphore_signal(self.semaphoreForRunloopCreation);
        
        // TODO: Make the below timeout value for the runloop configurable.
        BOOL runLoopSuccess = YES;
        while (([AZSUtil streamAvailable:outputStream]) && runLoopSuccess)
        {
            @autoreleasepool {
                NSDate *loopUntil = [NSDate dateWithTimeIntervalSinceNow:2.0];//[NSDate distantFuture];
                [self.runLoopForDownload runMode:NSDefaultRunLoopMode beforeDate:loopUntil];
                [self.operationContext logAtLevel:AZSLogLevelDebug withMessage:@"(Waking up) Current thread name = %@",[NSThread currentThread]];
                
                if ([outputStream streamError])
                {
                    NSError *error = [outputStream streamError];
                    [self.operationContext logAtLevel:AZSLogLevelDebug withMessage:@"StreamError.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo];
                }
                else
                {
                    [self.operationContext logAtLevel:AZSLogLevelDebug withMessage:@"No stream error while in runloop."];
                }
            }
        }
        [self.operationContext logAtLevel:AZSLogLevelDebug withMessage:@"Exiting spin."];
    }
}

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

    self.requestResult = [[AZSRequestResult alloc] initWithStartTime:self.startTime location:self.currentLocation response:self.httpResponse error:nil];
    self.preProcessError = self.storageCommand.preProcessResponse(self.httpResponse, self.requestResult, self.operationContext);
    
    if (self.preProcessError != nil)
    {
        self.outputStream = [NSOutputStream outputStreamToMemory];
    }
    else
    {
        // TODO: Don't bother with all the stream stuff (especially thread creation) if there is no body.
        if (self.storageCommand.destinationStream == nil)
        {
            self.outputStream = [NSOutputStream outputStreamToMemory];
        }
        else
        {
            self.outputStream = self.storageCommand.destinationStream;
        }
    }
    
    self.downloadBuffer = [[AZSStreamDownloadBuffer alloc]initWithStream:self.outputStream maxSizeToBuffer:self.requestOptions.maximumDownloadBufferSize calculateMD5:(self.storageCommand.calculateResponseMD5 && (self.requestResult.contentReceivedMD5 != nil)) operationContext:self.operationContext];
    
    [self.outputStream setDelegate:self.downloadBuffer];
    
    self.runLoopForDownload = self.requestOptions.runLoopForDownload;
    if (self.runLoopForDownload == nil)
    {
        // In this case, we will open the stream inside the createAndSpinRunloopWithOutputStream method.
        self.semaphoreForRunloopCreation = dispatch_semaphore_create(0);

        [NSThread detachNewThreadSelector:@selector(createAndSpinRunloopWithOutputStream:) toTarget:self withObject:self.outputStream];
        
        dispatch_semaphore_wait(self.semaphoreForRunloopCreation, DISPATCH_TIME_FOREVER);
    }
    else
    {
        [self.outputStream scheduleInRunLoop:self.runLoopForDownload forMode:NSDefaultRunLoopMode];
        [self.outputStream open];
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

    if (self.downloadBuffer.calculateMD5)
    {
        unsigned char md5Bytes[CC_MD5_DIGEST_LENGTH];
        CC_MD5_Final(md5Bytes, &(self.downloadBuffer->_md5Context));
        self.requestResult.calculatedResponseMD5 = [[[NSData alloc] initWithBytes:md5Bytes length:CC_MD5_DIGEST_LENGTH] base64EncodedStringWithOptions:0];
    }
    
    [self.downloadBuffer.dataDownloadCondition lock];
    [self.operationContext logAtLevel:AZSLogLevelDebug withMessage:@"Grabbed lock in didComplete."];
    
    while ((self.downloadBuffer.currentLength > 0) && !self.downloadBuffer.streamError)
    {
        [self.operationContext logAtLevel:AZSLogLevelDebug withMessage:@"Waiting on condition in didComplete.  CurrentLength = %ld.", (unsigned long)self.downloadBuffer.currentLength];
        [self.downloadBuffer.dataDownloadCondition wait];
    }
    [self.downloadBuffer.dataDownloadCondition unlock];
    [self.operationContext logAtLevel:AZSLogLevelDebug withMessage:@"Released lock in didComplete."];
    
    [self.outputStream close];
    [self.outputStream removeFromRunLoop:self.runLoopForDownload forMode:NSDefaultRunLoopMode];
    
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

-(void)finishRequestWithSession:(NSURLSession *)session error:(NSError *)error retval:(id)retval
{
    // Required to release memory related to the session, etc:
    [self.operationContext logAtLevel:AZSLogLevelDebug withMessage:@"Finishing session."];
    [session finishTasksAndInvalidate];
    
    self.requestResult = [[AZSRequestResult alloc] initWithStartTime:self.startTime location:self.currentLocation response:self.httpResponse error:error];
    [self.operationContext addRequestResult:self.requestResult];
    self.retryCount++;
    
    BOOL retry = YES;
    
    // Don't retry if there wasn't an error.
    if (retry && !error)
    {
        retry = NO;
    }

    // We cannot recover and retry the request if any data has been written to the caller's stream.
    if (retry && (((self.storageCommand.destinationStream == self.outputStream) && self.downloadBuffer.totalSizeStreamed > 0)))
    {
        retry = NO;
    }
    
    // Evaluate using the retry policy.
    AZSRetryInfo *retryInfo = nil;
    if (retry)
    {
        AZSRetryContext *retryContext = [[AZSRetryContext alloc] initWithCurrentRetryCount:self.retryCount lastRequestResult:self.requestResult nextLocation:AZSStorageLocationPrimary currentLocationMode:AZSStorageLocationModePrimaryOnly];
        retryInfo = [[self.operationContext.retryPolicy clone] evaluateRetryContext:retryContext withOperationContext:self.operationContext];
        if (!retryInfo.shouldRetry)
        {
            retry = NO;
        }
    }
    
    if (retry)
    {
        [self.operationContext logAtLevel:AZSLogLevelInfo withMessage:[NSString stringWithFormat:@"Retrying on HTTP status code %ld.", (long)self.requestResult.response.statusCode]];
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
        
        [AZSExecutor ExecuteWithStorageCommand:self.storageCommand requestOptions:self.requestOptions operationContext:self.operationContext retryCount:self.retryCount completionHandler:self.completionHandler];
    }
    else
    {
        self.operationContext.endTime = [NSDate date];
        self.completionHandler(error, retval);
    }
}

-(instancetype)init
{
    return nil;
}

-(instancetype) initWithCommand:(AZSStorageCommand *)storageCommand requestOptions:(AZSRequestOptions *)requestOptions operationContext:(AZSOperationContext *) operationContext completionHandler:(void (^)(NSError *, id))completionHandler
{
    self = [super init];
    if (self)
    {
        _storageCommand = storageCommand;
        _requestOptions = requestOptions;
        _operationContext = operationContext;
        _completionHandler = completionHandler;
        _retryCount = 0;
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
