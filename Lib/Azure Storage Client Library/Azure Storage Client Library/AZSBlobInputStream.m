// -----------------------------------------------------------------------------------------
// <copyright file="AZSBlobInputStream.m" company="Microsoft">
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

#import "AZSBlobInputStream.h"
#import "AZSBlobProperties.h"
#import "AZSBlobRequestFactory.h"
#import "AZSBlobResponseParser.h"
#import "AZSCloudBlobClient.h"
#import "AZSCloudBlockBlob.h"
#import "AZSBlockListItem.h"
#import "AZSBlobRequestOptions.h"
#import "AZSErrors.h"
#import "AZSExecutor.h"
#import "AZSRequestResult.h"
#import "AZSResponseParser.h"
#import "AZSStorageCommand.h"
#import "AZSStreamDownloadBuffer.h"
#import "AZSOperationContext.h"

@interface AZSBlobInputStream()

@property BOOL isStreamOpen;
@property BOOL isReading;
@property BOOL isStreamClosing;
@property BOOL isStreamClosed;
@property CFRunLoopSourceRef runLoopSource;
@property (strong) NSMutableArray *runLoopsRegistered;
@property BOOL waitingOnCaller;
@property BOOL hasStreamOpenEventFired;
@property BOOL hasStreamErrorEventFired;
@property BOOL hasStreamEndEventFired;
@property (strong) AZSCloudBlob *underlyingBlob;
@property (copy, readonly) void(^beginDownload)();

-(instancetype)init;

// This method should never be called. It is only here to comply with subclassing requirements.
-(instancetype)initWithFileAtPath:(NSString *)path;

// This method should never be called. It is only here to comply with subclassing requirements.
-(instancetype)initWithData:(NSData *)data AZS_DESIGNATED_INITIALIZER;

// This method should never be called. It is only here to comply with subclassing requirements.
-(instancetype)initWithURL:(NSURL *)url AZS_DESIGNATED_INITIALIZER;

@end

// These methods need to be here because the runloop expects them, but we don't have any work to be done.
void AZSBlobInputStreamRunLoopSourceScheduleRoutine (void *info, CFRunLoopRef rl, CFStringRef mode) {}
void AZSBlobInputStreamRunLoopSourceCancelRoutine (void *info, CFRunLoopRef rl, CFStringRef mode) {}
 
void AZSBlobInputStreamRunLoopSourcePerformRoutine (void *info)
{
    AZSBlobInputStream *stream = (__bridge AZSBlobInputStream *)info;
    [stream.downloadBuffer.operationContext logAtLevel:AZSLogLevelDebug withMessage:@"Perform Routine called."];
    BOOL fireStreamOpenEvent = NO;
    BOOL hasBytesAvailable = NO;
    BOOL fireStreamErrorEvent = NO;
    BOOL downloadComplete = NO;
 
    // Syncronize access to the various constants.
    // TODO: determine if synchronizing is needed.
    @synchronized(stream) {
        if (stream.isStreamOpen && !stream.hasStreamOpenEventFired) {
            fireStreamOpenEvent = YES;
        }
 
        if (stream.streamError && !stream.hasStreamErrorEventFired) {
            fireStreamErrorEvent = YES;
        }
 
        if (stream.isStreamClosing || stream.isStreamClosed || !stream.isStreamOpen) {
            return;
        }
 
        if (stream.hasBytesAvailable && !stream.waitingOnCaller && !stream.isReading) {
            hasBytesAvailable = YES;
        }
        
        if (!stream.hasBytesAvailable && stream.downloadBuffer.downloadComplete) {
            downloadComplete = YES;
        }
    }
 
    if (fireStreamErrorEvent) {
        if ([stream.delegate respondsToSelector:@selector(stream:handleEvent:)]) {
            stream.hasStreamErrorEventFired = YES;
            [stream.delegate stream:stream handleEvent:NSStreamEventErrorOccurred];
        }
    } else if (fireStreamOpenEvent) {
        if ([stream.delegate respondsToSelector:@selector(stream:handleEvent:)]) {
            stream.hasStreamOpenEventFired = YES;
            [stream.delegate stream:stream handleEvent:NSStreamEventOpenCompleted];
        }
    } else if (hasBytesAvailable) {
        if ([stream.delegate respondsToSelector:@selector(stream:handleEvent:)]) {
            @synchronized(stream) {
                stream.waitingOnCaller = YES;
            }
            [stream.delegate stream:stream handleEvent:NSStreamEventHasBytesAvailable];
        }
    }
    else if (downloadComplete) {
        if ([stream.delegate respondsToSelector:@selector(stream:handleEvent:)]) {
            [stream.delegate stream:stream handleEvent:NSStreamEventEndEncountered];
        }
    }
}

@implementation AZSBlobInputStream

@synthesize delegate = _delegate;
@synthesize hasBytesAvailable = _hasBytesAvailable;

-(instancetype)init
{
    self = [self initWithData:[NSData alloc]];
    return nil;
}

-(instancetype)initWithFileAtPath:(NSString *)path
{
    self = [self initWithData:[NSData alloc]];
    return nil;
}

-(instancetype)initWithData:(NSData *)data
{
    self = [super initWithData:data];
    return nil;
}

-(instancetype)initWithURL:(NSURL *)url
{
    self = [super initWithURL:url];
    return nil;
}

-(instancetype)initWithBlob:(AZSCloudBlob *)blob accessCondition:(AZSAccessCondition *)accessCondition requestOptions:(AZSNullable AZSBlobRequestOptions *)requestOptions operationContext:(AZSOperationContext *)operationContext
{
    // A designated initializer must make a super call to a designated initializer of the super class.
    self = [super initWithData:[[NSData alloc] init]];
    if (self) {
        _underlyingBlob = blob;
        _downloadBuffer = [[AZSStreamDownloadBuffer alloc] initWithInputStream:self maxSizeToBuffer:requestOptions.maximumDownloadBufferSize calculateMD5:!requestOptions.disableContentMD5Validation runLoopForDownload:nil operationContext:operationContext fireEventBlock:^() {
            [self fireStreamEvent];
        } setHasBytesAvailable:^() {
            _hasBytesAvailable = YES;
        }];
        
        _isStreamOpen = NO;
        _isStreamClosing = NO;
        _isStreamClosed = NO;
        _isReading = NO;
        CFRunLoopSourceContext context =
                {0, (__bridge void *)(self), NULL, NULL, NULL, NULL, NULL,
                &AZSBlobInputStreamRunLoopSourceScheduleRoutine,
                AZSBlobInputStreamRunLoopSourceCancelRoutine,
                AZSBlobInputStreamRunLoopSourcePerformRoutine};
        _runLoopSource = CFRunLoopSourceCreate(NULL, 0, &context);
        _runLoopsRegistered = [NSMutableArray arrayWithCapacity:1];
        _waitingOnCaller = NO;
        _delegate = self;
        _hasStreamOpenEventFired = NO;
        _hasStreamErrorEventFired = NO;
        
        __weak AZSStreamDownloadBuffer *weakBuffer = _downloadBuffer;
        _beginDownload = ^() {
            AZSStorageCommand *command = [blob downloadCommandWithRange:AZSULLMakeRange(0, 0) AccessCondition:accessCondition requestOptions:requestOptions operationContext:operationContext];
            [AZSExecutor ExecuteWithStorageCommand:command requestOptions:requestOptions operationContext:operationContext downloadBuffer:weakBuffer completionHandler:^(NSError *error, id result) {
                 weakBuffer.streamError = error;
             }];
            
            return;
        };
    }
    
    return self;
}

-(void)setDelegate:(id<NSStreamDelegate>)delegate
{
    _delegate = delegate ?: self;
}

-(id<NSStreamDelegate>)delegate
{
    return _delegate;
}

- (void)stream:(NSStream *)stream handleEvent:(NSStreamEvent)eventCode
{
    // No default impementation if the user doesn't provide a delegate.
}

-(void)fireStreamEvent
{
    [self.downloadBuffer.operationContext logAtLevel:AZSLogLevelDebug withMessage:@"Fire stream event called."];
    CFRunLoopSourceSignal(self.runLoopSource);
    
    // TODO: confirm this.  I don't know if we have to wake up all runloops here.
    for (NSRunLoop *runLoop in self.runLoopsRegistered) {
        CFRunLoopWakeUp([runLoop getCFRunLoop]);
    }
}

-(void)open
{
    [self.downloadBuffer.operationContext logAtLevel:AZSLogLevelDebug withMessage:@"Called open."];
    @synchronized (self) {
        self.isStreamOpen = YES;
    }
    [self fireStreamEvent];
    
    if (self.beginDownload) {
        @synchronized (self) {
            if (self.beginDownload) {
                self.beginDownload();
                _beginDownload = nil;
            }
        }
    }
    
    // TODO: Should opening a closed stream be an error?
}

- (BOOL)getBuffer:(uint8_t * __AZSNullable *)buffer length:(NSUInteger *)length
{
    BOOL success = NO;
    @synchronized(self) {
        self.waitingOnCaller = NO;
        self.isReading = YES;
    }
    
    if (self.isStreamOpen) {
        [self.downloadBuffer processDataWithProcess:^long(uint8_t *buf, long len) {
            *buffer = buf;
            *length = len;
            return len;
        }];
        
        success = YES;
    }
    
    [self fireStreamEvent];
    
    @synchronized (self) {
        self.isReading = NO;
    }
    
    return success;
}

-(NSInteger)read:(uint8_t *)buffer maxLength:(NSUInteger)length
{
    if (!length) {
        return 0;
    }
    
    // TODO: Investigate whether or not we need to set self.waitingOnCaller to NO if this method is called with zero bytes.
    // TODO: Should these be read/write locked or are reads atomic?
    @synchronized(self) {
        self.waitingOnCaller = NO;
        self.isReading = YES;
    }
    
    if (self.streamError) {
        return -1;
    }
    
    // TODO: if length > MAX_INT32, dataCopied can overflow
    __block NSInteger dataCopied = 0;
    if (self.isStreamOpen) {
        [self.downloadBuffer processDataWithProcess:^long (uint8_t * buf, long amount) {
            dataCopied = MIN(amount, length);
            memcpy(buffer, buf, dataCopied);
            return dataCopied;
        }];
        
        if (self.downloadBuffer.currentLength <= 0) {
            _hasBytesAvailable = NO;
        }
    }
    else {
        dataCopied = 0;
    }
    
    [self fireStreamEvent];
    @synchronized(self) {
        self.isReading = NO;
    }
    
    return dataCopied;
}

-(void)close
{
    @synchronized (self) {
        self.isStreamClosing = YES;
        self.isStreamOpen = NO;
    
        [self.downloadBuffer.operationContext logAtLevel:AZSLogLevelDebug withMessage:@"Called close."];
    
        self.isStreamClosed = YES;
        self.downloadBuffer.streamClosed = YES;
        self.isStreamClosing = NO;
    }
}

// TODO: NSStreamStatusError
// What was this todo for?
-(NSStreamStatus) streamStatus
{
    [self.downloadBuffer.operationContext logAtLevel:AZSLogLevelDebug withMessage:@"Stream status requested."];
    if (self.streamError) {
        return NSStreamStatusError;
    }
    
    if (self.isStreamClosed) {
        return NSStreamStatusClosed;
    }
    
    if (self.isStreamClosing) {
        return NSStreamStatusAtEnd;
    }
    
    if (self.isReading) {
        return NSStreamStatusReading;
    }
    
    if (self.isStreamOpen) {
        return NSStreamStatusOpen;
    }
    
    return NSStreamStatusNotOpen;
}

// TODO: Do we need this?  Or can we just use the autogenerated _streamError?
-(NSError *) streamError
{
    return self.downloadBuffer.streamError;
}

-(void)scheduleInRunLoop:runLoop forMode:(NSString *)mode
{
    [self.downloadBuffer.operationContext logAtLevel:AZSLogLevelDebug withMessage:@"Schedule in run loop requested."];
    CFRunLoopRef cfRunLoop = [runLoop getCFRunLoop];
    CFRunLoopAddSource(cfRunLoop, self.runLoopSource, (__bridge CFStringRef)(mode) /*kCFRunLoopDefaultMode*/);
    
    @synchronized(self) {
        if (![self.runLoopsRegistered containsObject:runLoop]) {
            [self.runLoopsRegistered addObject:runLoop];
        }
    }
}

-(void)removeFromRunLoop:runLoop forMode:(NSString *)mode
{
    [self.downloadBuffer.operationContext logAtLevel:AZSLogLevelDebug withMessage:@"Remove from run loop requested."];
    // TODO: Call CFBridgingRelease(self).
    CFRunLoopRef cfRunLoop = [runLoop getCFRunLoop];
    CFRunLoopRemoveSource(cfRunLoop, self.runLoopSource, (__bridge CFStringRef)(mode) /*kCFRunLoopDefaultMode*/);
    
    @synchronized(self) {
        [self.runLoopsRegistered removeObject:runLoop];
    }
}

-(id)propertyForKey:(NSString *)key
{
    [self.downloadBuffer.operationContext logAtLevel:AZSLogLevelDebug withMessage:@"Property for key requested.  Key = %@", key];
    
    // TODO: Decide if we want to support NSStreamFileCurrentOffsetKey.  (Note that not all blobs are files.)
    return nil;
}

-(BOOL)setProperty:(id)property forKey:(NSString *)key
{
    [self.downloadBuffer.operationContext logAtLevel:AZSLogLevelDebug withMessage:@"SetProperty for key requested.  Key = %@", key];
    
    // TODO: Decide if we want to support NSStreamFileCurrentOffsetKey.  (Note that not all blobs are files.)
    return NO;
}

@end