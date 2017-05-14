// -----------------------------------------------------------------------------------------
// <copyright file="AZSStreamDownloadBuffer.m" company="Microsoft">
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
#import "AZSErrors.h"
#import "AZSOperationContext.h"
#import "AZSStorageCredentials.h"
#import "AZSStreamDownloadBuffer.h"
#import "AZSUtil.h"

@interface AZSStreamDownloadBuffer()

@property CC_MD5_CTX md5Context;
@property (strong, readonly) NSMutableArray *queue;
@property (strong) NSRunLoop *runLoopForDownload;
@property BOOL streamWaiting;
@property NSUInteger maxSizeToBuffer;
@property NSInteger currentDataOffset;
@property (strong) NSData *currentDataToStream;
@property (strong, readonly) void(^fireEventBlock)();
@property (strong, readonly) NSStream *stream;

-(instancetype)init AZS_DESIGNATED_INITIALIZER;
-(instancetype)initWithStream:(NSStream *)stream maxSizeToBuffer:(NSUInteger)maxSizeToBuffer calculateMD5:(BOOL)calculateMD5 runLoopForDownload:(NSRunLoop *)runLoop  operationContext:(AZSOperationContext *)operationContext AZS_DESIGNATED_INITIALIZER;

@end

@implementation AZSStreamDownloadBuffer

-(instancetype)init
{
    return nil;
}

-(instancetype)initWithStream:(NSStream *)stream maxSizeToBuffer:(NSUInteger)maxSizeToBuffer calculateMD5:(BOOL)calculateMD5 runLoopForDownload:(NSRunLoop *)runLoop  operationContext:(AZSOperationContext *)operationContext
{
    self = [super init];
    if (self) {
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
        if (_calculateMD5) {
            CC_MD5_Init(&_md5Context);
        }
        
        _runLoopForDownload = runLoop;
    }
    
    return self;
}

-(instancetype)initWithInputStream:(NSInputStream *)stream maxSizeToBuffer:(NSUInteger)maxSizeToBuffer calculateMD5:(BOOL)calculateMD5 runLoopForDownload:(NSRunLoop *)runLoop operationContext:(AZSOperationContext *)operationContext fireEventBlock:(void (^)())fireEventBlock
{
    self = [self initWithStream:stream maxSizeToBuffer:maxSizeToBuffer calculateMD5:calculateMD5 runLoopForDownload:runLoop operationContext:operationContext];
    if (self) {
        _fireEventBlock = fireEventBlock;
    }
    
    return self;
}

-(instancetype)initWithOutputStream:(NSOutputStream *)stream maxSizeToBuffer:(NSUInteger)maxSizeToBuffer calculateMD5:(BOOL)calculateMD5 runLoopForDownload:(NSRunLoop *)runLoop  operationContext:(AZSOperationContext *)operationContext
{
    self = [self initWithStream:stream maxSizeToBuffer:maxSizeToBuffer calculateMD5:calculateMD5 runLoopForDownload:runLoop operationContext:operationContext];
    if (self) {
        [_stream setDelegate:self];
    }
    
    return self;
}

-(void)processDataWithProcess:(long(^)(uint8_t *, long))process
{
    [self.dataDownloadCondition lock];
    if (self.streamError) {
        // Return if there's already an error
        [self.dataDownloadCondition broadcast];
        [self.dataDownloadCondition unlock];
        return;
    }
    
    [self.operationContext logAtLevel:AZSLogLevelDebug withMessage:@"Just grabbed lock from stream callback"];
    [self.operationContext logAtLevel:AZSLogLevelDebug withMessage:@"Current thread name = %@",[NSThread currentThread]];
    
    // If there is still data to process
    if ((self.currentDataToStream && (self.currentDataOffset < self.currentDataToStream.length)) || ([self.queue count] > 0)) {
        // If we need a new NSData object from the queue
        if (!self.currentDataToStream || (self.currentDataOffset >= self.currentDataToStream.length)) {
            self.currentDataToStream = (NSData *) self.queue.firstObject;
            self.currentDataOffset = 0;
            [self.queue removeObjectAtIndex:0];
        }
        
        long lengthProcessed = process((uint8_t *) ([self.currentDataToStream bytes] + self.currentDataOffset), [self.currentDataToStream length] - self.currentDataOffset);
        [self updateOffsetWithData:self.currentDataToStream lengthProcessed:lengthProcessed];
        self.currentLength -= (lengthProcessed > 0) ? lengthProcessed : 0;
    }
    else {
        self.streamWaiting = YES;
        [self.operationContext logAtLevel:AZSLogLevelDebug withMessage:@"Stream waiting."];
    }
    
    [self.operationContext logAtLevel:AZSLogLevelDebug withMessage:@"About to signal and release lock from stream callback"];
    [self.dataDownloadCondition broadcast];
    [self.dataDownloadCondition unlock];
}

-(void)writeData:(NSData *)data
{
    _totalSizeStreamed += data.length;
    
    if (self.calculateMD5) {
        CC_MD5_Update(&_md5Context, data.bytes, (unsigned int) data.length);
    }
    
    [self.operationContext logAtLevel:AZSLogLevelDebug withMessage:@"About to grab lock from data pushing"];
    
    // TODO: Optimize to remove the need for the lock (or at least, for locking the whole thing.)
    // To do this, we need to ensure that all data is written to the stream in the correct order (even if some writes are sync),
    // and that the current length and total size are consistent.
    
    [self.dataDownloadCondition lock];
    
    // TODO: self.streamWaiting should be set only if there is nothing in the buffer.  Make sure this is true, then simplify this condition.
    while (!(self.streamWaiting || (self.currentLength <= self.maxSizeToBuffer))) {
        [self.operationContext logAtLevel:AZSLogLevelDebug withMessage:@"Waiting on dataDownloadCondition in writeData."];
        [self.dataDownloadCondition wait];
    }
    
    if (self.streamError || self.streamClosed) {
        // If there's an error or the stream is closed, return.
        [self.dataDownloadCondition broadcast];
        [self.dataDownloadCondition unlock];
        return;
    }
    
    if (self.streamWaiting) {
        [self.operationContext logAtLevel:AZSLogLevelDebug withMessage:@"StreamWaiting = YES"];
    }
    else {
        [self.operationContext logAtLevel:AZSLogLevelDebug withMessage:@"StreamWaiting = NO"];
    }
    
    // self.stream must be either a NSOutputStream or an AZSInputStream, and only NSOutputStream has a write method.
    if (self.streamWaiting && [self.stream respondsToSelector:@selector(write:maxLength:)]) {
        // If the stream is waiting, write the data to it.
        NSInteger lengthWritten = [((NSOutputStream *) self.stream) write:data.bytes maxLength:data.length];
        [self.operationContext logAtLevel:AZSLogLevelDebug withMessage:@"Wrote syncronously.  LengthWritten = %ld, desired write size = %ld.", lengthWritten, data.length];
        
        // If any data is left unwritten, store it to be processed later.
        self.currentDataOffset = 0;
        [self updateOffsetWithData:data lengthProcessed:lengthWritten];
        if(self.currentDataToStream) {
            self.currentLength += (lengthWritten > 0) ? (data.length - self.currentDataOffset) : 0;
        }
        
        // The following broadcast should never actually wake up anything, because the condition is only waited on in two cases:
        // - If the thread is done downloading and waiting for the buffer to clear (can't happen due to sync nature of didReceiveData and didCompleteWithError.)
        // - If the buffer is full and didReceiveData is thus blocking (in which case this method shouldn't be called.)
        // Leaving it in in case of any corner cases not yet thought of - this way, all writes from the buffer signals the condition.
        [self.dataDownloadCondition broadcast];
    }
    else {
        // Otherwise, just add the data to the queue so it can be processed in order.
        [self.queue addObject:data];
        self.currentLength += data.length;
        [self.operationContext logAtLevel:AZSLogLevelDebug withMessage:@"Adding to queue.  Current length = %ld, total amount streamed = %ld", self.currentLength, self.totalSizeStreamed];
    }
    
    // Tells the input stream there is more data to process.
    if (self.fireEventBlock) {
        self.fireEventBlock();
    }
    
    [self.dataDownloadCondition unlock];
}

-(void)updateOffsetWithData:(NSData *)data lengthProcessed:(NSInteger)lengthProcessed
{
    if (lengthProcessed < 0) {
        // Error Occurred
        NSDictionary *userInfo = self.stream.streamError ? @{AZSInnerErrorString : self.stream.streamError} : nil;
        self.streamError = [NSError errorWithDomain:AZSErrorDomain code:AZSEInputStreamError userInfo:userInfo];
        [self.operationContext logAtLevel:AZSLogLevelError withMessage:@"Error in processing download stream, aborting download."];
    }
    else if (lengthProcessed == 0) {
        // Capacity Reached
        self.streamError = [NSError errorWithDomain:AZSErrorDomain code:AZSEInputStreamEmpty userInfo:@{AZSInnerErrorString : self.stream.streamError}];
        [self.operationContext logAtLevel:AZSLogLevelError withMessage:@"DownloadStream is empty, aborting download."];
    }
    else {
        // Increment self.currentDataOffset if doing so wouldn't go beyond the end of data and update self.currentDataToStream
        [self.operationContext logAtLevel:AZSLogLevelDebug withMessage:@"Process async. LengthRead = %ld, desired size = %ld.", (unsigned long) lengthProcessed, (unsigned long) [self.currentDataToStream length]];
        [self.operationContext logAtLevel:AZSLogLevelDebug withMessage:@"Current length (process async) = %ld, total amount streamed = %ld", (unsigned long) self.currentLength, (unsigned long) self.totalSizeStreamed];
        
        self.streamWaiting = NO;
        [self.operationContext logAtLevel:AZSLogLevelDebug withMessage:@"Stream not waiting."];
        
        if (self.currentDataOffset + lengthProcessed <= [data length]) {
            self.currentDataOffset += lengthProcessed;
            self.currentDataToStream = data;
            return;
        }
    }
    
    // If anything went wrong or no data was left over, reset these.
    self.currentDataOffset = 0;
    self.currentDataToStream = nil;
}

-(void)stream:(NSStream *)stream handleEvent:(NSStreamEvent)eventCode
{
    if (![AZSUtil streamAvailable:stream]) {
        return;
    }
    
    switch(eventCode) {
        case NSStreamEventHasSpaceAvailable:
        {
            [self.operationContext logAtLevel:AZSLogLevelDebug withMessage:@"NSStreamEventHasSpaceAvailable"];
            [self processDataWithProcess:^long(uint8_t * buffer, long length) {
                return [((NSOutputStream *) stream) write:buffer maxLength:length];
            }];
            
            break;
        }
        case NSStreamEventEndEncountered:
        {
            [self.operationContext logAtLevel:AZSLogLevelDebug withMessage:@"NSStreamEventEndEncountered"];
            break;
        }
        case NSStreamEventErrorOccurred:
        {
            [self.operationContext logAtLevel:AZSLogLevelDebug withMessage:@"NSStreamEventErrorOccurred"];
            NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
            userInfo[AZSInnerErrorString] = stream.streamError;
            NSError *streamError = [NSError errorWithDomain:AZSErrorDomain code:AZSEOutputStreamError userInfo:userInfo];
            self.streamError = streamError;
            [self.operationContext logAtLevel:AZSLogLevelError withMessage:@"Error in writing to download stream, aborting download."];
        }
        case NSStreamEventOpenCompleted:
        {
            [self.operationContext logAtLevel:AZSLogLevelDebug withMessage:@"NSStreamEventOpenCompleted"];
            break;
        }
        case NSStreamEventNone:
        {
            [self.operationContext logAtLevel:AZSLogLevelDebug withMessage:@"NSStreamEventNone"];
            break;
        }
        case NSStreamEventHasBytesAvailable:
        {
            // Should never happen.
            [self.operationContext logAtLevel:AZSLogLevelDebug withMessage:@"NSStreamEventHasBytesAvailable"];
            break;
        }
        default:
        {
            [self.operationContext logAtLevel:AZSLogLevelDebug withMessage:@"NSStreamEventdefault"];
            break;
        }
    }
}

-(void)createAndSpinRunloop
{
    if (!self.runLoopForDownload) {
        // In this case, we will open the stream inside the createAndSpinRunloopWithStream method.
        dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
        [NSThread detachNewThreadSelector:@selector(createAndSpinRunloopWithSemaphore:) toTarget:self withObject:semaphore];
        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    }
    else {
        [_stream scheduleInRunLoop:self.runLoopForDownload forMode:NSDefaultRunLoopMode];
        [_stream open];
    }
}

-(void)createAndSpinRunloopWithSemaphore:(dispatch_semaphore_t)semaphore
{
    @autoreleasepool {
        self.runLoopForDownload = [NSRunLoop currentRunLoop];
        [self.stream scheduleInRunLoop:self.runLoopForDownload forMode:NSDefaultRunLoopMode];
        [self.stream open];
        dispatch_semaphore_signal(semaphore);
        
        // TODO: Make the below timeout value for the runloop configurable.
        while ([AZSUtil streamAvailable:self.stream])
        {
            @autoreleasepool {
                NSDate *loopUntil = [NSDate dateWithTimeIntervalSinceNow:2];
                [self.runLoopForDownload runMode:NSDefaultRunLoopMode beforeDate:loopUntil];
                [self.operationContext logAtLevel:AZSLogLevelDebug withMessage:@"(Waking up) Current thread name = %@",[NSThread currentThread]];
                
                if ([self.stream streamError])
                {
                    NSError *error = [self.stream streamError];
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

-(void)removeFromRunLoop
{
    [[self stream] close];
    [[self stream] removeFromRunLoop:self.runLoopForDownload forMode:NSDefaultRunLoopMode];
}

-(NSString *)checkMD5
{
    if (self.calculateMD5)
    {
        unsigned char md5Bytes[CC_MD5_DIGEST_LENGTH];
        CC_MD5_Final(md5Bytes, &_md5Context);
        return [[[NSData alloc] initWithBytes:md5Bytes length:CC_MD5_DIGEST_LENGTH] base64EncodedStringWithOptions:0];
    }
    
    return nil;
}

@end