// -----------------------------------------------------------------------------------------
// <copyright file="AZSBlobUploadHelper.m" company="Microsoft">
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
#import "AZSBlobUploadHelper.h"
#import "AZSCloudBlockBlob.h"
#import "AZSBlockListItem.h"
#import "AZSBlobRequestOptions.h"
#import "AZSOperationContext.h"

@interface AZSBlobUploadHelper()
{
    CC_MD5_CTX _md5Context;
}

@property (strong) AZSCloudBlockBlob *underlyingBlob;
@property (strong) NSMutableData *dataBuffer;
@property dispatch_semaphore_t blockUploadSemaphore;
@property (strong) NSMutableArray *blockIDs;
@property NSUInteger blocksTotal;
@property NSUInteger blocksUploaded;
@property NSInteger maxOpenUploads;
@property BOOL streamWaiting;
@property (strong) NSObject *uploadLock;
@property (strong) AZSAccessCondition *accessCondition;
@property (strong) AZSBlobRequestOptions *requestOptions;
@property (copy) void (^completionHandler)(NSError*);


@end

@interface AZSBlobUploadHelper()

-(instancetype)init AZS_DESIGNATED_INITIALIZER;

@end

@implementation AZSBlobUploadHelper

-(instancetype)init
{
    return nil;
}

-(instancetype)initToBlockBlob:(AZSCloudBlockBlob *)blockBlob accessCondition:(AZSAccessCondition *)accessCondition requestOptions:(AZSBlobRequestOptions *)requestOptions operationContext:(AZSOperationContext *)operationContext completionHandler:(void (^  __AZSNullable)(NSError*))completionHandler
{
    self = [super init];
    if (self)
    {
        _underlyingBlob = blockBlob;
        _dataBuffer = [NSMutableData dataWithCapacity:4*1024*1024];  //TODO: This should be the max buffer size.
        _blockIDs = [NSMutableArray arrayWithCapacity:10];
        _maxOpenUploads = requestOptions.parallelismFactor;
        _blockUploadSemaphore = dispatch_semaphore_create(self.maxOpenUploads);
        _streamWaiting = NO;
        _uploadLock = [[NSObject alloc] init];
        _accessCondition = accessCondition;
        _requestOptions = requestOptions;
        _operationContext = operationContext;
        _completionHandler = completionHandler;
        if (requestOptions.storeBlobContentMD5)
        {
            CC_MD5_Init(&_md5Context);
        }
        _streamingError = nil;
    }
    return self;
}

-(BOOL)hasSpaceAvailable
{
    return ((!self.streamingError) && ((self.blocksTotal - self.blocksUploaded) < self.maxOpenUploads));
}

-(NSInteger)write:(const uint8_t *)buffer maxLength:(NSUInteger)length completionHandler:(void(^)())completionHandler
{
    if (self.streamingError)
    {
        return -1;
    }
    
    // TODO: Make this configurable.
    NSUInteger maxSizePerBlock = 4*1024*1024;
    int bytesCopied = 0;
    
    while (bytesCopied < length)
    {
        NSUInteger bytesToAppend = MIN(length - bytesCopied, maxSizePerBlock - [self.dataBuffer length]);
        [self.dataBuffer appendBytes:(buffer + bytesCopied) length:bytesToAppend];
        bytesCopied += bytesToAppend;
        
        if (maxSizePerBlock == [self.dataBuffer length])
        {
            [self uploadBufferWithCompletionHandler:completionHandler];
        }
    }
    return length;
}

// TODO: Consider having this method fail, rather than block, in the cannot-acquire-semaphore case.
-(BOOL) uploadBufferWithCompletionHandler:(void(^)())completionHandler
{
    [self.operationContext logAtLevel:AZSLogLevelDebug withMessage:@"Uploading buffer, buffer size = %ld", (unsigned long)[self.dataBuffer length]];
    dispatch_semaphore_wait(self.blockUploadSemaphore, DISPATCH_TIME_FOREVER);
    @synchronized(self)
    {
        self.blocksTotal++;
    }
    
    NSData *blockData = self.dataBuffer;
    self.dataBuffer = [NSMutableData dataWithCapacity:4*1028*1028];
    
    if (self.requestOptions.storeBlobContentMD5)
    {
        CC_MD5_Update(&_md5Context, blockData.bytes, (unsigned int) blockData.length);
    }
    
    NSString *blockID = [[[[NSString stringWithFormat:@"blockid%@",[[[NSUUID UUID] UUIDString] stringByReplacingOccurrencesOfString:@"-" withString:@""]] lowercaseString] dataUsingEncoding:NSUTF8StringEncoding] base64EncodedStringWithOptions:0];
    [self.blockIDs addObject:[[AZSBlockListItem alloc] initWithBlockID:blockID blockListMode:AZSBlockListModeLatest size:blockData.length]];
    
    [self.underlyingBlob uploadBlockFromData:blockData blockID:blockID contentMD5:nil accessCondition:self.accessCondition requestOptions:self.requestOptions operationContext:self.operationContext completionHandler:^(NSError * error)
     {
         if (error)
         {
             self.streamingError = error;
         }
         @synchronized(self)
         {
             self.blocksUploaded++;
         }
         dispatch_semaphore_signal(self.blockUploadSemaphore);
         completionHandler();
     }];
    
    return YES;
}

-(BOOL)allBlocksUploaded
{
    BOOL allBlocksUploaded = NO;
    @synchronized(self)
    {
        allBlocksUploaded = self.blocksTotal == self.blocksUploaded;
    }
    return allBlocksUploaded;
}

-(BOOL)closeWithCompletionHandler:(void (^)())completionHandler
{
    // TODO: If there have been no put block calls yet, just call put blob, rather than put block / put block list.
    if ((!self.streamingError) && (self.dataBuffer.length > 0))
    {
        if (![self uploadBufferWithCompletionHandler:completionHandler])
        {
            return NO;
        }
    }
    
    BOOL finished = NO;
    @synchronized(self)
    {
        finished = self.blocksTotal == self.blocksUploaded;
    }
    
    while (!finished)
    {
        // Spin until all blocks have been uploaded.
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
        @synchronized(self)
        {
            finished = self.blocksTotal == self.blocksUploaded;
        }
    }
    
    if (self.requestOptions.storeBlobContentMD5)
    {
        unsigned char md5Bytes[CC_MD5_DIGEST_LENGTH];
        CC_MD5_Final(md5Bytes, &_md5Context);
        self.underlyingBlob.properties.contentMD5 = [[[NSData alloc] initWithBytes:md5Bytes length:CC_MD5_DIGEST_LENGTH] base64EncodedStringWithOptions:0];
    }
    
    dispatch_semaphore_t blockListSemaphore = dispatch_semaphore_create(0);
    
    [self.underlyingBlob uploadBlockListFromArray:self.blockIDs accessCondition:self.accessCondition requestOptions:self.requestOptions operationContext:self.operationContext completionHandler:^(NSError * error) {
        if (!self.streamingError && error)
        {
            self.streamingError = error;
        }
        
        dispatch_semaphore_signal(blockListSemaphore);
    }];
    
    dispatch_semaphore_wait(blockListSemaphore, DISPATCH_TIME_FOREVER);
    
    return YES;
}

-(void)writeFromStreamCallbackWithStream:(NSInputStream *)inputStream;
{
    @synchronized(self.uploadLock)
    {
        if (self.streamWaiting && [self hasSpaceAvailable])
        {
            uint8_t buf[1024];
            NSUInteger len = 0;
            
            len = [inputStream read:buf maxLength:1024];
            if (len)
            {
                [self write:buf maxLength:len completionHandler:^{
                    [self writeFromStreamCallbackWithStream:inputStream];
                }];
            }
            self.streamWaiting = NO;
        }
    }
}

- (void)stream:(NSStream *)stream handleEvent:(NSStreamEvent)eventCode
{
    NSInputStream *inputStream = (NSInputStream *)stream;
    switch (eventCode) {
        case NSStreamEventHasBytesAvailable:
            // TODO: Stop reading if there was a error in uploading the blob?  Not sure if this is possible.
            @synchronized(self.uploadLock)
            {
                if ([self hasSpaceAvailable])
                {
                    uint8_t buf[1024];
                    NSUInteger len = 0;
                
                    len = [inputStream read:buf maxLength:1024];  // The 0 and -1 case should be handled by the EndEncountered and ErrorOccurred events.
                    if (len > 0)
                    {
                        [self write:buf maxLength:len completionHandler:^{
                            [self writeFromStreamCallbackWithStream:inputStream];
                        }];
                    }
                }
                else
                {
                    self.streamWaiting = YES;
                }
            }
            break;
        case NSStreamEventEndEncountered:
            // Note that the below method is syncronous for the time being.
            [self closeWithCompletionHandler:^{
                ;
            }];
            
            if (self.completionHandler)
            {
                self.completionHandler(self.streamingError);
            }
            break;
        case NSStreamEventErrorOccurred:
        {
            NSError *error = inputStream.streamError;
            [self.operationContext logAtLevel:AZSLogLevelError withMessage:@"Error in stream callback.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo];
            // Note that the below method is syncronous for the time being.
            [self closeWithCompletionHandler:^{
                ;
            }];
            
            if (self.completionHandler)
            {
                self.completionHandler(error);
            }
            break;
        }
        default:
            break;
    }
}

@end
