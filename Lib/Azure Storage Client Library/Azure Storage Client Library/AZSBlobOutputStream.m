// -----------------------------------------------------------------------------------------
// <copyright file="AZSBlobOutputStream.m" company="Microsoft">
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

#import "AZSBlobOutputStream.h"
#import "AZSCloudBlockBlob.h"
#import "AZSBlockListItem.h"
#import "AZSBlobUploadHelper.h"
#import "AZSOperationContext.h"

@interface AZSBlobOutputStream()

@property BOOL isStreamOpen;
@property BOOL isStreamClosing;
@property BOOL isStreamClosed;
@property CFRunLoopSourceRef runLoopSource;
@property (strong) NSMutableArray *runLoopsRegistered;
@property BOOL waitingOnCaller;
@property BOOL hasStreamOpenEventFired;
@property BOOL hasStreamErrorEventFired;
@property (strong) AZSBlobUploadHelper *blobUploadHelper;


@end

// These two methods two need to be here because the runloop expects them, but we don't have any work to be done.
void AZSBlobOutputStreamRunLoopSourceScheduleRoutine (void *info, CFRunLoopRef rl, CFStringRef mode)
{
}

void AZSBlobOutputStreamRunLoopSourceCancelRoutine (void *info, CFRunLoopRef rl, CFStringRef mode)
{
}

void AZSBlobOutputStreamRunLoopSourcePerformRoutine (void *info)
{
    AZSBlobOutputStream *stream = (__bridge AZSBlobOutputStream *)info;
    [stream.blobUploadHelper.operationContext logAtLevel:AZSLogLevelDebug withMessage:@"Perform Routine called."];
    BOOL fireStreamOpenEvent = NO;
    BOOL hasSpaceAvailable = NO;
    BOOL fireStreamErrorEvent = NO;
    
    // Syncronize access to the various constants.
    // TODO: determine if synchronizing is needed.
    @synchronized(stream)
    {
        if (stream.isStreamOpen && !stream.hasStreamOpenEventFired)
        {
            fireStreamOpenEvent = YES;
        }

        if (stream.streamError && !stream.hasStreamErrorEventFired)
        {
            fireStreamErrorEvent = YES;
        }

        if (stream.isStreamClosing || stream.isStreamClosed || !stream.isStreamOpen)
        {
            return;
        }
        
        if (stream.blobUploadHelper.hasSpaceAvailable && !stream.waitingOnCaller)
        {
            hasSpaceAvailable = YES;
        }
    }
    
    if (fireStreamOpenEvent)
    {
        if ([stream.delegate respondsToSelector:@selector(stream:handleEvent:)])
        {
            stream.hasStreamOpenEventFired = YES;
            [stream.delegate stream:stream handleEvent:NSStreamEventOpenCompleted];
        }
    }
    if (hasSpaceAvailable)
    {
        if ([stream.delegate respondsToSelector:@selector(stream:handleEvent:)])
        {
            @synchronized(stream)
            {
                stream.waitingOnCaller = YES;
            }
            [stream.delegate stream:stream handleEvent:NSStreamEventHasSpaceAvailable];
        }
    }
    if (fireStreamErrorEvent)
    {
        if ([stream.delegate respondsToSelector:@selector(stream:handleEvent:)])
        {
            stream.hasStreamErrorEventFired = YES;
            [stream.delegate stream:stream handleEvent:NSStreamEventErrorOccurred];
        }
    }
}


@implementation AZSBlobOutputStream

@synthesize delegate = _delegate;
@synthesize hasSpaceAvailable = _hasSpaceAvailable;

-(instancetype)initToBlockBlob:(AZSCloudBlockBlob *)blockBlob accessCondition:(AZSAccessCondition *)accessCondition requestOptions:(AZSBlobRequestOptions *)requestOptions operationContext:(AZSOperationContext *)operationContext
{
    self = [super init];
    if (self)
    {
        _blobUploadHelper = [[AZSBlobUploadHelper alloc] initToBlockBlob:blockBlob accessCondition:accessCondition requestOptions:requestOptions operationContext:operationContext completionHandler:nil];
        _isStreamOpen = NO;
        _isStreamClosing = NO;
        _isStreamClosed = NO;
        CFRunLoopSourceContext    context = {0, (__bridge void *)(self), NULL, NULL, NULL, NULL, NULL,
            &AZSBlobOutputStreamRunLoopSourceScheduleRoutine,
            AZSBlobOutputStreamRunLoopSourceCancelRoutine,
            AZSBlobOutputStreamRunLoopSourcePerformRoutine};
        _runLoopSource = CFRunLoopSourceCreate(NULL, 0, &context);
        _runLoopsRegistered = [NSMutableArray arrayWithCapacity:1];
        _waitingOnCaller = NO;
        _delegate = self;
        _hasStreamOpenEventFired = NO;
        _hasStreamErrorEventFired = NO;
    }
    return self;
}

-(void)setDelegate:(id<NSStreamDelegate>)delegate
{
    if (delegate == nil)
    {
        _delegate = self;
    }
    else
    {
        _delegate = delegate;
    }
}

-(id<NSStreamDelegate>)delegate
{
    return _delegate;
}

- (void)stream:(NSStream *)stream handleEvent:(NSStreamEvent)eventCode
{

    // No default impementation if the user doesn't provide a delegate.
    return;
}

-(void)fireStreamEvent
{
    [self.blobUploadHelper.operationContext logAtLevel:AZSLogLevelDebug withMessage:@"Fire stream event called."];

    CFRunLoopSourceSignal(self.runLoopSource);
    
    // TODO: confirm this.  I don't know if we have to wake up all runloops here.
    for (NSRunLoop *runLoop in self.runLoopsRegistered) {
        CFRunLoopWakeUp([runLoop getCFRunLoop]);
    }
}

-(void)open
{
    [self.blobUploadHelper.operationContext logAtLevel:AZSLogLevelDebug withMessage:@"Called open."];
    self.isStreamOpen = YES;
    [self fireStreamEvent];
}


-(NSInteger)write:(const uint8_t *)buffer maxLength:(NSUInteger)length
{
    // TODO: Investigate whether or not we need to set self.waitingOnCaller to NO if this method is called with zero bytes.
    @synchronized(self)
    {
        self.waitingOnCaller = NO;
    }

    if (self.streamError)
    {
        return -1;
    }
    
    NSInteger dataCopied = 0;
    if (self.isStreamOpen)
    {
        dataCopied = [self.blobUploadHelper write:buffer maxLength:length completionHandler:^{
            [self fireStreamEvent];
        }];        
    }
    else
    {
        dataCopied = 0;
    }
    
    [self fireStreamEvent];
    return dataCopied;
}

-(void)close
{
    [self.blobUploadHelper.operationContext logAtLevel:AZSLogLevelDebug withMessage:@"Called close."];
    self.isStreamClosing = YES;
    self.isStreamOpen = NO;
    if (![self.blobUploadHelper closeWithCompletionHandler:^{
        [self fireStreamEvent];
    }])
    {
        // TODO: Error.
    }
    
    self.isStreamClosed = YES;
    self.isStreamClosing = NO;
}

// TODO: NSStreamStatusError
-(NSStreamStatus) streamStatus
{
    [self.blobUploadHelper.operationContext logAtLevel:AZSLogLevelDebug withMessage:@"Stream status requested."];
    if (self.streamError)
    {
        return NSStreamStatusError;
    }
    if (self.isStreamClosed)
    {
        return NSStreamStatusClosed;
    }
    if (self.isStreamClosing)
    {
        return NSStreamStatusAtEnd;
    }
    if (![self.blobUploadHelper allBlocksUploaded])
    {
        return NSStreamStatusWriting;
    }
    if (self.isStreamOpen)
    {
        return NSStreamStatusOpen;
    }
    return NSStreamStatusNotOpen;
}

// TODO: Do we need this?  Or can we just use the autogenerated _streamError?
-(NSError *) streamError
{
    return self.blobUploadHelper.streamingError;
}

-(void)scheduleInRunLoop:runLoop forMode:(NSString *)mode
{
    [self.blobUploadHelper.operationContext logAtLevel:AZSLogLevelDebug withMessage:@"Schedule in run loop requested."];
    CFRunLoopRef cfRunLoop = [runLoop getCFRunLoop];
    CFRunLoopAddSource(cfRunLoop, self.runLoopSource, (__bridge CFStringRef)(mode) /*kCFRunLoopDefaultMode*/);
    
    @synchronized(self)
    {
        if (![self.runLoopsRegistered containsObject:runLoop])
        {
            [self.runLoopsRegistered addObject:runLoop];
        }
    }
}

-(void)removeFromRunLoop:runLoop forMode:(NSString *)mode
{
    [self.blobUploadHelper.operationContext logAtLevel:AZSLogLevelDebug withMessage:@"Remove from run loop requested."];
    // TODO: Call CFBridgingRelease(self).
    CFRunLoopRef cfRunLoop = [runLoop getCFRunLoop];
    CFRunLoopRemoveSource(cfRunLoop, self.runLoopSource, (__bridge CFStringRef)(mode) /*kCFRunLoopDefaultMode*/);
    
    @synchronized(self)
    {
        [self.runLoopsRegistered removeObject:runLoop];
    }
}

-(id)propertyForKey:(NSString *)key
{
    [self.blobUploadHelper.operationContext logAtLevel:AZSLogLevelDebug withMessage:@"Property for key requested.  Key = %@", key];

    // TODO: Decide if we want to support NSStreamFileCurrentOffsetKey.  (Note that not all blobs are files.)
    return nil;
}

-(BOOL)setProperty:(id)property forKey:(NSString *)key
{
    [self.blobUploadHelper.operationContext logAtLevel:AZSLogLevelDebug withMessage:@"SetProperty for key requested.  Key = %@", key];

    // TODO: Decide if we want to support NSStreamFileCurrentOffsetKey.  (Note that not all blobs are files.)
    return NO;
}

@end