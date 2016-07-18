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
#import "AZSConstants.h"
#import "AZSErrors.h"
#import "AZSBlobUploadHelper.h"
#import "AZSCloudBlockBlob.h"
#import "AZSCloudPageBlob.h"
#import "AZSCloudAppendBlob.h"
#import "AZSBlockListItem.h"
#import "AZSBlobRequestOptions.h"
#import "AZSOperationContext.h"
#import "AZSBlobProperties.h"
#import "AZSAccessCondition.h"

@interface AZSBlobUploadHelper()
{
    CC_MD5_CTX _md5Context;
}

@property (strong) AZSCloudBlob *underlyingBlob;
@property (strong) NSMutableData *dataBuffer;
@property (strong) NSMutableArray *blockIDs;
@property NSUInteger chunksTotal;
@property NSUInteger chunksUploaded;
@property NSUInteger blobOffset;
@property NSInteger maxOpenUploads;
@property BOOL streamWaiting;
@property (strong) NSObject *uploadLock;
@property (strong) AZSAccessCondition *accessCondition;
@property (strong) AZSBlobRequestOptions *requestOptions;
@property (copy) void (^completionHandler)(NSError*);
@property BOOL createNew;
@property NSNumber *totalPageBlobSize;
@property NSNumber *initialPageBlobSequenceNumber;
@property (strong) NSCondition *maxUploadsCondition;
@property BOOL closeCalled;

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
        _blobType = AZSBlobTypeBlockBlob;
        _dataBuffer = [NSMutableData dataWithCapacity:AZSCMaxBlockSize];  //TODO: This should be user-settable.
        _blockIDs = [NSMutableArray arrayWithCapacity:10];
        _maxOpenUploads = requestOptions.parallelismFactor;
        _maxUploadsCondition = [[NSCondition alloc] init];
        _streamWaiting = NO;
        _uploadLock = [[NSObject alloc] init];
        _accessCondition = accessCondition ?: [[AZSAccessCondition alloc] init];
        _requestOptions = requestOptions;
        _operationContext = operationContext;
        _completionHandler = completionHandler;
        if (requestOptions.storeBlobContentMD5)
        {
            CC_MD5_Init(&_md5Context);
        }
        _streamingError = nil;
        _createNew = NO;
        _closeCalled = NO;
    }
    return self;
}

-(instancetype)initToPageBlob:(AZSCloudPageBlob *)pageBlob totalBlobSize:(NSNumber *)totalBlobSize initialSequenceNumber:(NSNumber *)initialSequenceNumber accessCondition:(AZSAccessCondition *)accessCondition requestOptions:(AZSBlobRequestOptions *)requestOptions operationContext:(AZSOperationContext *)operationContext completionHandler:(void (^)(NSError * _Nullable))completionHandler
{
    self = [super init];
    if (self)
    {
        _underlyingBlob = pageBlob;
        _blobType = AZSBlobTypePageBlob;
        _dataBuffer = [NSMutableData dataWithCapacity:AZSCMaxBlockSize];  //TODO: This should be user-settable.
        _maxOpenUploads = requestOptions.parallelismFactor;
        _maxUploadsCondition = [[NSCondition alloc] init];
        _streamWaiting = NO;
        _uploadLock = [[NSObject alloc] init];
        _accessCondition = accessCondition ?: [[AZSAccessCondition alloc] init];
        _requestOptions = requestOptions;
        _operationContext = operationContext;
        _completionHandler = completionHandler;
        if (requestOptions.storeBlobContentMD5)
        {
            CC_MD5_Init(&_md5Context);
        }
        _streamingError = nil;
        if (totalBlobSize)
        {
            _createNew = YES;
            _totalPageBlobSize = totalBlobSize;
            _initialPageBlobSequenceNumber = initialSequenceNumber;
        }
        _closeCalled = NO;
    }
    return self;
}

-(instancetype)initToAppendBlob:(AZSCloudAppendBlob *)appendBlob createNew:(BOOL)createNew accessCondition:(AZSAccessCondition *)accessCondition requestOptions:(AZSBlobRequestOptions *)requestOptions operationContext:(AZSOperationContext *)operationContext completionHandler:(void (^)(NSError * _Nullable))completionHandler
{
    self = [super init];
    if (self)
    {
        _underlyingBlob = appendBlob;
        _blobType = AZSBlobTypeAppendBlob;
        _dataBuffer = [NSMutableData dataWithCapacity:AZSCMaxBlockSize];  //TODO: This should be the user-settable.
        _maxOpenUploads = 1; //TODO: Investigate if this should always be 1, or if we should use the value in requestOptions.parallelismFactor.
        _maxUploadsCondition = [[NSCondition alloc] init];
        _streamWaiting = NO;
        _uploadLock = [[NSObject alloc] init];
        _accessCondition = accessCondition ?: [[AZSAccessCondition alloc] init];
        _requestOptions = requestOptions;
        _operationContext = operationContext;
        _completionHandler = completionHandler;
        if (requestOptions.storeBlobContentMD5)
        {
            CC_MD5_Init(&_md5Context);
        }
        _streamingError = nil;
        _createNew = createNew;
        _closeCalled = NO;
    }
    return self;
}

-(BOOL)hasSpaceAvailable
{
    switch (self.blobType)
    {
        case AZSBlobTypeBlockBlob:
            return ((!self.streamingError) && ((self.chunksTotal - self.chunksUploaded) < self.maxOpenUploads));
            break;
        case AZSBlobTypePageBlob:
            return ((!self.streamingError) && ((self.chunksTotal - self.chunksUploaded) < self.maxOpenUploads));
            // TODO: Check total blob size?
            break;
        case AZSBlobTypeAppendBlob:
            return ((!self.streamingError) && ((self.chunksTotal - self.chunksUploaded) < self.maxOpenUploads));
            break;
        default:
            return NO;
            break;
    }
}

-(NSInteger)write:(const uint8_t *)buffer length:(NSUInteger)length completionHandler:(void(^)())completionHandler
{
    if (self.streamingError) {
        return -1;
    }
    
    if (!self.hasSpaceAvailable) {
        return 0;
    }
    
    if (self.closeCalled) {
        return 0;
    }
    
    // TODO: Make this configurable.
    NSUInteger maxSizePerBlock = AZSCMaxBlockSize;
    int bytesCopied = 0;
    
    // TODO: If length > MAX_INT32 this is an infinite loop (because length is unsigned)
    while (bytesCopied < length) {
        NSUInteger bytesToAppend = MIN(length - bytesCopied, maxSizePerBlock - [self.dataBuffer length]);
        [self.dataBuffer appendBytes:(buffer + bytesCopied) length:bytesToAppend];
        bytesCopied += bytesToAppend;
        
        if (maxSizePerBlock == [self.dataBuffer length]) {
            [self uploadBufferWithCompletionHandler:completionHandler];
        }
    }
    
    return length;
}

// TODO: Consider having this method fail, rather than block, in the cannot-acquire-semaphore case.
-(BOOL) uploadBufferWithCompletionHandler:(void(^)())completionHandler
{
    [self.operationContext logAtLevel:AZSLogLevelDebug withMessage:@"Uploading buffer, buffer size = %ld", (unsigned long)[self.dataBuffer length]];
    
    [self.maxUploadsCondition lock];
    while (self.chunksTotal - self.chunksUploaded >= self.maxOpenUploads) {
        [self.maxUploadsCondition unlock];
        // Spin until there's an available slot to upload.
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
        [self.maxUploadsCondition lock];
    }
    
    self.chunksTotal++;
    [self.maxUploadsCondition unlock];
    
    NSData *blockData = self.dataBuffer;
    self.dataBuffer = [NSMutableData dataWithCapacity:AZSCMaxBlockSize];
    
    if (self.requestOptions.storeBlobContentMD5)
    {
        CC_MD5_Update(&_md5Context, blockData.bytes, (unsigned int) blockData.length);
    }
    
    switch (self.blobType)
    {
        case AZSBlobTypeBlockBlob:
        {
            NSString *blockID = [[[[NSString stringWithFormat:@"blockid%@",[[[NSUUID UUID] UUIDString] stringByReplacingOccurrencesOfString:@"-" withString:AZSCEmptyString]] lowercaseString] dataUsingEncoding:NSUTF8StringEncoding] base64EncodedStringWithOptions:0];
            [self.blockIDs addObject:[[AZSBlockListItem alloc] initWithBlockID:blockID blockListMode:AZSBlockListModeLatest size:blockData.length]];
            
            AZSCloudBlockBlob *blob = (AZSCloudBlockBlob *)self.underlyingBlob;
            [blob uploadBlockFromData:blockData blockID:blockID contentMD5:nil accessCondition:self.accessCondition requestOptions:self.requestOptions operationContext:self.operationContext completionHandler:^(NSError * error)
             {
                 if (error)
                 {
                     self.streamingError = error;
                 }
                 [self.maxUploadsCondition lock];
                 self.chunksUploaded++;
                 [self.maxUploadsCondition unlock];
                 completionHandler();
             }];
            break;
        }
        case AZSBlobTypePageBlob:
        {
            if ([blockData length] % AZSCPageSize != 0) {
                self.streamingError = [NSError errorWithDomain:AZSErrorDomain code:AZSEInvalidArgument userInfo:@{NSLocalizedDescriptionKey:@"Page blob uploads must be 512-byte aligned."}];
            }
            else {
                NSUInteger currentOffset = 0;
                @synchronized(self) {
                    currentOffset = self.blobOffset;
                    self.blobOffset = self.blobOffset + [blockData length];
                }
            
                AZSCloudPageBlob *blob = (AZSCloudPageBlob *)self.underlyingBlob;
                [blob uploadPagesWithData:blockData startOffset:[NSNumber numberWithUnsignedInteger:currentOffset] contentMD5:nil accessCondition:self.accessCondition requestOptions:self.requestOptions operationContext:self.operationContext completionHandler:^(NSError * _Nullable error) {
                    if (error)
                    {
                        self.streamingError = error;
                    }
                    [self.maxUploadsCondition lock];
                    self.chunksUploaded++;
                    [self.maxUploadsCondition unlock];
                    completionHandler();
                }];
            }
            break;
        }
        case AZSBlobTypeAppendBlob:
        {
            // Here we worry about simultaneous uploads.
            NSUInteger currentOffset = 0;
            @synchronized(self) {
                currentOffset = self.blobOffset;
                self.blobOffset = self.blobOffset + [blockData length];
            }
            
            if ((self.accessCondition.maxSize) && (self.accessCondition.maxSize.unsignedIntegerValue < self.blobOffset))
            {
                // TODO: improve this error
                self.streamingError = [NSError errorWithDomain:AZSErrorDomain code:AZSEOutputStreamError userInfo:nil];

                completionHandler();
            }
            else
            {
                AZSCloudAppendBlob *blob = (AZSCloudAppendBlob *)self.underlyingBlob;
                
                self.accessCondition.appendPosition = [NSNumber numberWithUnsignedInteger:currentOffset];
                
                NSUInteger currentResultsCount = self.operationContext.requestResults.count;
                
                [blob appendBlockWithData:blockData contentMD5:nil accessCondition:self.accessCondition requestOptions:self.requestOptions operationContext:self.operationContext completionHandler:^(NSError * _Nullable error, NSNumber * _Nonnull appendOffset) {
                    if (error)
                    {
                        // check for stuff
                        
                        if (self.requestOptions.absorbConditionalErrorsOnRetry && (error.userInfo[AZSCHttpStatusCode] == [NSNumber numberWithInt:412]) && ([error.userInfo[AZSCXmlCode] isEqualToString:@"AppendPositionConditionNotMet"] || [error.userInfo[AZSCXmlCode] isEqualToString:@"MaxBlobSizeConditionNotMet"]) && (self.operationContext.requestResults.count - currentResultsCount > 1))
                        {
                            [self.operationContext logAtLevel:AZSLogLevelWarning withMessage:@"Pre-condition failure on a retry is being ignored as the request should have succeeded in the first attempt."];
                        }
                        else
                        {
                            self.streamingError = error;
                        }
                    }
                    [self.maxUploadsCondition lock];
                    self.chunksUploaded++;
                    [self.maxUploadsCondition unlock];
                    completionHandler();
                }];
            }

            break;
        }
        default:
            break;
    }
    
    
    return YES;
}

-(BOOL)allDataUploaded
{
    BOOL allDataUploaded = NO;
    [self.maxUploadsCondition lock];
    allDataUploaded = self.chunksTotal == self.chunksUploaded;
    [self.maxUploadsCondition unlock];
    return allDataUploaded;
}

-(BOOL)closeWithCompletionHandler:(void (^)())completionHandler uploadBufferCompletionHandler:(void (^)())uploadBufferCompletionHandler
{
    self.closeCalled = YES;
    if ((!self.streamingError) && (self.dataBuffer.length > 0))
    {
        [self.maxUploadsCondition lock];
        NSInteger chunksTotal = self.chunksTotal;
        [self.maxUploadsCondition unlock];
        
        if ((self.blobType == AZSBlobTypeBlockBlob) && (chunksTotal == 0) && (self.dataBuffer.length <= self.requestOptions.singleBlobUploadThreshold))
        {
            AZSCloudBlockBlob *blockBlob = (AZSCloudBlockBlob *)self.underlyingBlob;
            [self.maxUploadsCondition lock];
            self.chunksTotal = 1;
            [self.maxUploadsCondition unlock];
            // uploadFromData calls put blob internally if the data buffer is less than the single blob upload threshold.
            [blockBlob uploadFromData:self.dataBuffer accessCondition:self.accessCondition requestOptions:self.requestOptions operationContext:self.operationContext completionHandler:^(NSError * _Nullable error) {
                if (error)
                {
                    self.streamingError = error;
                }
                [self.maxUploadsCondition lock];
                self.chunksUploaded = 1;
                [self.maxUploadsCondition unlock];
                uploadBufferCompletionHandler();
                completionHandler(self.streamingError);
            }];
            return YES;
        }
        else
        {
            if (![self uploadBufferWithCompletionHandler:uploadBufferCompletionHandler])
            {
                return NO;
            }
        }
    }
    
    // If there's an error, abort.
    if (self.streamingError)
    {
        completionHandler(self.streamingError);
        return NO;
    }
    
    BOOL finished = NO;
    [self.maxUploadsCondition lock];
    finished = self.chunksTotal == self.chunksUploaded;
    while (!finished)
    {
        // Spin until all blocks have been uploaded.
        [self.maxUploadsCondition unlock];
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
        [self.maxUploadsCondition lock];
        finished = self.chunksTotal == self.chunksUploaded;
    }
    [self.maxUploadsCondition unlock];

    if (self.requestOptions.storeBlobContentMD5)
    {
        unsigned char md5Bytes[CC_MD5_DIGEST_LENGTH];
        CC_MD5_Final(md5Bytes, &_md5Context);
        self.underlyingBlob.properties.contentMD5 = [[[NSData alloc] initWithBytes:md5Bytes length:CC_MD5_DIGEST_LENGTH] base64EncodedStringWithOptions:0];
    }
    
    switch (self.blobType) {
        case AZSBlobTypeBlockBlob:
        {
            AZSCloudBlockBlob *blob = (AZSCloudBlockBlob *)self.underlyingBlob;
            [blob uploadBlockListFromArray:self.blockIDs accessCondition:self.accessCondition requestOptions:self.requestOptions operationContext:self.operationContext completionHandler:^(NSError * error) {
                if (!self.streamingError && error)
                {
                    self.streamingError = error;
                }
                completionHandler(self.streamingError);
            }];
            break;
        }
        case AZSBlobTypePageBlob:
        {
            if (self.requestOptions.storeBlobContentMD5)
            {
                [self.underlyingBlob uploadPropertiesWithAccessCondition:self.accessCondition requestOptions:self.requestOptions operationContext:self.operationContext completionHandler:^(NSError * _Nullable error) {
                    if (!self.streamingError && error)
                    {
                        self.streamingError = error;
                    }
                    completionHandler(self.streamingError);
                }];
            }
            else
            {
                completionHandler(self.streamingError);
            }
            break;
        }
        case AZSBlobTypeAppendBlob:
        {
            if (self.requestOptions.storeBlobContentMD5)
            {
                [self.underlyingBlob uploadPropertiesWithAccessCondition:self.accessCondition requestOptions:self.requestOptions operationContext:self.operationContext completionHandler:^(NSError * _Nullable error) {
                    if (!self.streamingError && error)
                    {
                        self.streamingError = error;
                    }
                    completionHandler(self.streamingError);
                }];
            }
            else
            {
                completionHandler(self.streamingError);
            }
            break;
        }
            
        default:
            return NO;
            break;
    }
    return YES;
}

-(void)writeFromStreamCallbackWithStream:(NSInputStream *)inputStream;
{
    @synchronized(self.uploadLock)
    {
        if (self.streamWaiting && [self hasSpaceAvailable])
        {
            uint8_t buf[AZSCKilobyte];
            NSUInteger len = 0;
            
            len = [inputStream read:buf maxLength:AZSCKilobyte];
            if (len)
            {
                [self write:buf length:len completionHandler:^{
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
        {
            // TODO: Stop reading if there was a error in uploading the blob?  Not sure if this is possible.
            @synchronized(self.uploadLock)
            {
                if ([self hasSpaceAvailable])
                {
                    uint8_t buf[AZSCKilobyte];
                    NSUInteger len = 0;
                
                    len = [inputStream read:buf maxLength:AZSCKilobyte];  // The 0 and -1 case should be handled by the EndEncountered and ErrorOccurred events.
                    if (len > 0)
                    {
                        [self write:buf length:len completionHandler:^{
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
        }
        case NSStreamEventEndEncountered:
        {
            [self closeWithCompletionHandler:^{
                if (self.completionHandler)
                {
                    self.completionHandler(self.streamingError);
                }
            } uploadBufferCompletionHandler:^{
                ;
            }];
            
            break;
        }
        case NSStreamEventErrorOccurred:
        {
            NSError *error = inputStream.streamError;
            [self.operationContext logAtLevel:AZSLogLevelError withMessage:@"Error in stream callback.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo];
            [self closeWithCompletionHandler:^{
                if (self.completionHandler)
                {
                    self.completionHandler(error);
                }
            } uploadBufferCompletionHandler:^{
                ;
            }];
            break;
        }
        default:
            break;
    }
}

-(void)openWithCompletionHandler:(void (^)(BOOL))completionHandler
{
    if (!self.createNew)
    {
        completionHandler(YES);
    }
    else
    {
        switch (self.blobType)
        {
            case AZSBlobTypePageBlob:
            {
                AZSCloudPageBlob *blob = (AZSCloudPageBlob *)self.underlyingBlob;
                [blob createWithSize:self.totalPageBlobSize sequenceNumber:self.initialPageBlobSequenceNumber accessCondition:self.accessCondition requestOptions:self.requestOptions operationContext:self.operationContext completionHandler:^(NSError * _Nullable error) {
                    if (error)
                    {
                        self.streamingError = error;
                        completionHandler(NO);
                    }
                    else
                    {
                        completionHandler(YES);
                    }
                }];
                break;
            }
            case AZSBlobTypeAppendBlob:
            {
                AZSCloudAppendBlob *blob = (AZSCloudAppendBlob *)self.underlyingBlob;
                [blob createWithAccessCondition:self.accessCondition requestOptions:self.requestOptions operationContext:self.operationContext completionHandler:^(NSError * _Nullable error) {
                    if (error)
                    {
                        self.streamingError = error;
                        completionHandler(NO);
                    }
                    else
                    {
                        completionHandler(YES);
                    }
                }];
                break;
            }
            default:
            {
                completionHandler(NO);
                break;
            }
        }
    }
}

@end