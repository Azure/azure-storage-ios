// -----------------------------------------------------------------------------------------
// <copyright file="AZSTestHelpers.m" company="Microsoft">
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

#import "AZSTestHelpers.h"
#import <XCTest/XCTest.h>
@import ObjectiveC;

@implementation AZSTestHelpers

@end

@implementation AZSUIntegerHolder

-(instancetype)initWithNumber:(unsigned int)theNumber
{
    self = [super init];
    if (self)
    {
        self->number = theNumber;
    }
    return self;
}

@end

@interface AZSByteValidationStream()
@property AZSUIntegerHolder *currentSeed;
@property BOOL isStreamOpen;
@property BOOL isStreamClosed;
@property CFRunLoopSourceRef runLoopSource;
@property NSMutableArray *runLoopsRegistered;
@property NSUInteger totalBlobSize;
@property NSMutableData *currentBuffer;
@property BOOL isUpload;


@end

void RunLoopSourceScheduleRoutine (void *info, CFRunLoopRef rl, CFStringRef mode)
{
}

void RunLoopSourcePerformRoutine (void *info)
{
    AZSByteValidationStream *stream = (__bridge AZSByteValidationStream *)info;
    BOOL streamClosed = NO;
    @synchronized(stream)
    {
        if (stream.isStreamClosed)
        {
            streamClosed = YES;
        }
        else if (!stream.isStreamOpen)
        {
            // TODO: Emit relevant events to the stream delegate here.
            return;
        }
    }
    
    // TODO: If delegate responds to selector
    if (streamClosed)
    {
        [stream.delegate stream:stream handleEvent:NSStreamEventEndEncountered];
    }
    else
    {
        if (stream.isUpload)
        {
            [stream.delegate stream:stream handleEvent:NSStreamEventHasBytesAvailable];
        }
        else
        {
            [stream.delegate stream:stream handleEvent:NSStreamEventHasSpaceAvailable];
        }
    }
}


void RunLoopSourceCancelRoutine (void *info, CFRunLoopRef rl, CFStringRef mode)
{
}

@interface AZSByteValidationStream()
{
    id<NSStreamDelegate> _delegate;
    NSError *_streamError;
}

@end

@implementation AZSByteValidationStream

-(instancetype)initWithRandomSeed:(unsigned int)seed totalBlobSize:(NSUInteger)totalBlobSize isUpload:(BOOL)isUpload
{
    self = [super init];
    if (self)
    {
        self.currentSeed = [[AZSUIntegerHolder alloc] initWithNumber:seed];
        self.dataCorrupt = NO;
        self.isStreamOpen = NO;
        self.isStreamClosed = NO;
        CFRunLoopSourceContext    context = {0, (__bridge void *)(self), NULL, NULL, NULL, NULL, NULL,
            &RunLoopSourceScheduleRoutine,
            RunLoopSourceCancelRoutine,
            RunLoopSourcePerformRoutine};
        self.runLoopSource = CFRunLoopSourceCreate(NULL, 0, &context);
        self.runLoopsRegistered = [NSMutableArray arrayWithCapacity:1];
        self.totalBytes = 0;
        self.errorCount = 0;
        self.errors = [NSMutableString stringWithFormat:@""];
        self.totalBlobSize = totalBlobSize;
        self.currentBuffer = [NSMutableData dataWithLength:1024];
        self.isUpload = isUpload;

    }
    return self;
}

-(void)fireStreamEvent
{
    CFRunLoopSourceSignal(self.runLoopSource);
    
    // TODO: confirm this.  I don't know if we have to wake up all runloops here.
    for (NSRunLoop *runLoop in self.runLoopsRegistered) {
        CFRunLoopWakeUp([runLoop getCFRunLoop]);
    }
}

-(void)open
{
    self.isStreamOpen = YES;
    [self fireStreamEvent];
}

-(void)close
{
    self.isStreamOpen = NO;
    self.isStreamClosed = YES;
}

-(void)scheduleInRunLoop:runLoop forMode:(NSString *)mode
{
    NSLog(@"Schedule in run loop requested.");
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
    NSLog(@"Remove from run loop requested.");
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
    return nil;
}
-(BOOL)setProperty:(id)property forKey:(NSString *)key
{
    return YES;
}

// NSOutputStream methods and properties:
-(BOOL) hasSpaceAvailable
{
    return YES;
}

-(NSInteger)write:(const uint8_t *)buffer maxLength:(NSUInteger)length
{
    for (int i = 0; i < length; i++)
    {
        NSUInteger byteVal = buffer[i];
        NSUInteger expectedByteVal = rand_r(&(self.currentSeed->number)) % 256;
        if (expectedByteVal != byteVal)
        {
            self.dataCorrupt = YES;
            self.errorCount++;
            if (self.errorCount <= 5)
            {
                [self.errors appendFormat:@"Error discovered in stream validation.  Expected value = %ld, actual value = %ld.\n", (unsigned long)byteVal, (unsigned long)expectedByteVal];
            }
        }
    }
    self.totalBytes += length;
    [self fireStreamEvent];
    return length;
}

// NSInputStream:
-(BOOL) hasBytesAvailable
{
    return YES;
}

-(NSInteger)read:(uint8_t *)buffer maxLength:(NSUInteger)length
{
    // Note: this method contains the extraneous local variables 'totalBlobSize' and 'totalBytes' because otherwise it contaminates profiling results.
    NSUInteger bytesUploaded = 0;
    NSUInteger totalBlobSize = self.totalBlobSize;
    NSUInteger totalBytes = self.totalBytes;
    for (int i = 0; (i < length) && (totalBytes < totalBlobSize); i++)
    {
        buffer[i] = rand_r(&(self.currentSeed->number)) % 256;
        bytesUploaded++;
        totalBytes++;
    }
    
    self.totalBytes = totalBytes;
    self.totalBlobSize = totalBlobSize;
    
    if (self.totalBytes >= self.totalBlobSize)
    {
        self.isStreamClosed = YES;
    }
    
    [self fireStreamEvent];
    return bytesUploaded;
}

-(BOOL)getBuffer:(uint8_t **)buffer length:(NSUInteger *)len
{
    return NO;
}

-(NSStreamStatus) streamStatus
{
    if (self.isStreamClosed)
    {
        return NSStreamStatusClosed;
    }
    if (self.isStreamOpen)
    {
        return NSStreamStatusOpen;
    }
    return NSStreamStatusNotOpen;
}

-(id<NSStreamDelegate>) delegate
{
    return _delegate;
}

-(void)setDelegate:(id<NSStreamDelegate>)delegate
{
    _delegate = delegate;
}

-(NSError *)streamError
{
    return _streamError;
}

-(void)setStreamError:(NSError *)streamError
{
    _streamError = streamError;
}

@end
