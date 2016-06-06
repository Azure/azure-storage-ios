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

#import <XCTest/XCTest.h>
#import "AZSConstants.h"
#import "AZSTestHelpers.h"
#import "AZSClient.h"
#import "AZSBlobInputStream.h"
#import "AZSStreamDownloadBuffer.h"

@import ObjectiveC;

@implementation AZSTestHelpers
+(NSMutableData *)generateSampleDataWithSeed:(unsigned int *)seed length:(unsigned int)length
{
    NSMutableData *sampleData = [NSMutableData dataWithLength:length];
    Byte* sampleDataBytes = [sampleData mutableBytes];
    for (int i = 0; i < length; i++)
    {
        sampleDataBytes[i] = rand_r(seed) % 256;
    }
    return sampleData;
}

+(void)listAllInDirectoryOrContainer:(NSObject *)objectToList useFlatBlobListing:(BOOL)useFlatBlobListing blobArrayToPopulate:(NSMutableArray *)blobArrayToPopulate directoryArrayToPopulate:(NSMutableArray *)directoryArrayToPopulate continuationToken:(AZSContinuationToken *)continuationToken prefix:(NSString *)prefix blobListingDetails:(AZSBlobListingDetails)blobListingDetails maxResults:(NSUInteger)maxResults completionHandler:(void (^)(NSError *))completionHandler
{
    void (^tempCompletion)(NSError *, AZSBlobResultSegment *) = ^void(NSError *error, AZSBlobResultSegment *results) {
        if (error)
        {
            completionHandler(error);
        }
        else
        {
            [blobArrayToPopulate addObjectsFromArray:results.blobs];
            [directoryArrayToPopulate addObjectsFromArray:results.directories];
            if (results.continuationToken)
            {
                [AZSTestHelpers listAllInDirectoryOrContainer:objectToList useFlatBlobListing:useFlatBlobListing blobArrayToPopulate:blobArrayToPopulate directoryArrayToPopulate:directoryArrayToPopulate continuationToken:results.continuationToken prefix:prefix blobListingDetails:blobListingDetails maxResults:maxResults completionHandler:completionHandler];
            }
            else
            {
                completionHandler(nil);
            }
        }
    };
    
    if ([objectToList isKindOfClass:[AZSCloudBlobContainer class]])
    {
        // It's a container
        AZSCloudBlobContainer *container = (AZSCloudBlobContainer *)objectToList;
        [container listBlobsSegmentedWithContinuationToken:continuationToken prefix:nil useFlatBlobListing:useFlatBlobListing blobListingDetails:blobListingDetails maxResults:maxResults completionHandler:tempCompletion];
    }
    else
    {
        // It's a directory
        AZSCloudBlobDirectory *directory = (AZSCloudBlobDirectory *)objectToList;
        [directory listBlobsSegmentedWithContinuationToken:continuationToken useFlatBlobListing:useFlatBlobListing blobListingDetails:blobListingDetails maxResults:maxResults completionHandler:tempCompletion];
    }
}

+ (NSString *)uniqueName
{
    return [[[[NSUUID UUID] UUIDString] stringByReplacingOccurrencesOfString:@"-" withString:AZSCEmptyString] lowercaseString];
}

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
    BOOL fireStreamErrorEvent = NO;
    @synchronized(stream)
    {
        if (stream.isStreamClosed)
        {
            streamClosed = YES;
        }
        else if (stream.streamError)
        {
            fireStreamErrorEvent = YES;
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
    else if (fireStreamErrorEvent)
    {
        [stream.delegate stream:stream handleEvent:NSStreamEventErrorOccurred];
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

-(instancetype)initWithRandomSeed:(unsigned int)seed totalBlobSize:(NSUInteger)totalBlobSize isUpload:(BOOL)isUpload failBlock:(void(^)())failBlock
{
    self = [super init];
    if (self)
    {
        _currentSeed = [[AZSUIntegerHolder alloc] initWithNumber:seed];
        _dataCorrupt = NO;
        _isStreamOpen = NO;
        _isStreamClosed = NO;
        CFRunLoopSourceContext context =
            {0, (__bridge void *)(self), NULL, NULL, NULL, NULL, NULL,
            &RunLoopSourceScheduleRoutine,
            RunLoopSourceCancelRoutine,
            RunLoopSourcePerformRoutine};
        _runLoopSource = CFRunLoopSourceCreate(NULL, 0, &context);
        _runLoopsRegistered = [NSMutableArray arrayWithCapacity:1];
        _bytesRead = 0;
        _totalBytes = 0;
        _errorCount = 0;
        _errors = [NSMutableString stringWithString:AZSCEmptyString];
        _totalBlobSize = totalBlobSize;
        _currentBuffer = [NSMutableData dataWithLength:AZSCKilobyte];
        _isUpload = isUpload;
        _currentSeed = [[AZSUIntegerHolder alloc] initWithNumber:seed];
        
        __block int failCount = 0;
        _failBlock = ^void(NSString *message) {
            if (failCount < 5) {
                _streamFailed = YES;
                failBlock(message);
                failCount++;
            }
        };
    }
    return self;
}

-(instancetype) init
{
    return (self = nil);
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

-(void)stream:(NSStream *)stream handleEvent:(NSStreamEvent)eventCode
{
    if (self.dataCorrupt) {
        self.failBlock(@"Data has been corrupted.");
    }
    
    switch (eventCode) {
        case NSStreamEventHasBytesAvailable:
        {
            uint8_t temp[AZSCKilobyte];
            uint8_t *buffer = temp;
            NSUInteger curBytesRead = 0;
            
            if (arc4random() % 2){
                // If unable to access internal buffer directly, make one ourselves.
                curBytesRead = [(NSInputStream *) stream read:buffer maxLength:AZSCKilobyte];
                
                if (curBytesRead > AZSCKilobyte) {
                    self.failBlock(@"Incorrect number of bytes written to the stream.");
                    self.streamFailed = YES;
                }
            }
            else {
                BOOL accessed = [(NSInputStream *) stream getBuffer:&buffer length:&curBytesRead];
                if (!accessed) {
                    self.failBlock(@"[stream getBuffer] failed!");
                    self.streamFailed = YES;
                }
            }
            
            self.bytesRead += curBytesRead;
            
            for (int i = 0; i < curBytesRead; i++) {
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
            
            break;
        }
            
        case NSStreamEventHasSpaceAvailable:
        {
            uint8_t buf[AZSCKilobyte];
            int i;
            for (i = 0; i < AZSCKilobyte && self.bytesWritten < self.totalBlobSize; i++)
            {
                NSUInteger byteval = rand_r(&(self.currentSeed->number)) % 256;
                buf[i] = byteval;
                self.bytesWritten++;
            }
            
            NSInteger curBytesWritten = [(NSOutputStream *) stream write:(const uint8_t *)buf maxLength:i];
            if (curBytesWritten != i)
            {
                // If fewer bytes are written then the data will be corrupted because the rest of the bytes in buf will be lost.
                // If more bytes are written then the cap on maximum length was not adhered to.
                self.failBlock(@"Incorrect number of bytes written to the stream.");
                self.streamFailed = YES;
            }
            
            break;
        }
            
        case NSStreamEventEndEncountered:
            if (self.bytesRead && self.bytesRead != self.totalBlobSize) {
                self.failBlock(@"Incorrect number of bytes read from the stream.");
            }
            else if (self.bytesWritten && self.bytesWritten != self.totalBlobSize) {
                self.failBlock(@"Incorrect number of bytes written to the stream.");
            }
            else if (!self.bytesRead && self.bytesWritten) {
                self.failBlock(@"No bytes written to or read from the stream.");
            }
            
            [stream close];
            [stream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
            self.downloadComplete = YES;
            
            break;
   
        case NSStreamEventErrorOccurred:
            self.failBlock(@"Error encountered.");
            [stream close];
            [stream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
            self.downloadComplete = YES;
            
            break;
    
        default:
            break;
    }
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