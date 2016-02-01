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

#import <Foundation/Foundation.h>
#import <XCTest/XCTest.h>
#import "AZSConstants.h"
#import "AZSBlobTestBase.h"
#import "AZSTestHelpers.h"
#import "AZSTestSemaphore.h"
#import "Azure_Storage_Client_Library.h"

@interface AZSBlobUploadTestDelegate : NSObject <NSStreamDelegate>

@property (nonatomic, copy) void (^streamEventBlock)(NSStream *, NSStreamEvent);

-(instancetype)initWithBlock:(void(^)(NSStream *, NSStreamEvent))block;
-(void)stream:(NSStream *)stream handleEvent:(NSStreamEvent)eventCode;

@end

@implementation AZSBlobUploadTestDelegate

-(void)stream:(NSStream *)stream handleEvent:(NSStreamEvent)eventCode
{
    self.streamEventBlock(stream, eventCode);
}

-(instancetype)initWithBlock:(void (^)(NSStream *, NSStreamEvent))block
{
    self = [super init];
    if (self)
    {
        self.streamEventBlock = block;
    }
    return self;
}

@end

@interface AZSBlobOutputStreamTests : AZSBlobTestBase
@property NSString *containerName;
@property AZSCloudBlobContainer *blobContainer;

@end


@implementation AZSBlobOutputStreamTests

- (void)setUp
{
    [super setUp];
    self.containerName = [NSString stringWithFormat:@"sampleioscontainer%@", [AZSTestHelpers uniqueName]];
    self.blobContainer = [self.blobClient containerReferenceFromName:self.containerName];
    AZSTestSemaphore *semaphore = [[AZSTestSemaphore alloc] init];
    
    [self.blobContainer createContainerIfNotExistsWithCompletionHandler:^(NSError *error, BOOL exists) {
        [semaphore signal];
    }];
    [semaphore wait];
    
    // Put setup code here; it will be run once, before the first test case.
}

- (void)tearDown
{
    // Put teardown code here; it will be run once, after the last test case.
    AZSCloudBlobContainer *blobContainer = [self.blobClient containerReferenceFromName:self.containerName];
    AZSTestSemaphore *semaphore = [[AZSTestSemaphore alloc] init];
    
    [blobContainer deleteContainerIfExistsWithCompletionHandler:^(NSError *error, BOOL exists) {
        [semaphore signal];
    }];
    [semaphore wait];
    [super tearDown];
}

- (BOOL)runInternalTestOutputStreamWithBlobSize:(NSUInteger)blobSize blobToUpload:(AZSCloudBlob *)blob createOutputStreamCall:(AZSBlobOutputStream *(^)(AZSAccessCondition *, AZSBlobRequestOptions *, AZSOperationContext *))createOutputStreamCall
{
    AZSTestSemaphore *semaphore = [[AZSTestSemaphore alloc] init];
    unsigned int __block randSeed = (unsigned int)time(NULL);

    AZSUIntegerHolder *randSeedHolderCopy = [[AZSUIntegerHolder alloc]initWithNumber:randSeed];
    NSUInteger writeSize = 10000;
    NSUInteger __block bytesWritten = 0;
    BOOL __block uploadFailed = NO;
    BOOL __block testFailedInDownload = NO;
    
    AZSBlobUploadTestDelegate *uploadDelegate = [[AZSBlobUploadTestDelegate alloc] initWithBlock:^(NSStream *stream, NSStreamEvent eventCode) {
        NSOutputStream *outputStream = (NSOutputStream *)stream;
        switch (eventCode) {
            case NSStreamEventHasSpaceAvailable:
            {
                uint8_t buf[writeSize];
                int i = 0;
                for (i = 0; i < writeSize && bytesWritten < blobSize; i++)
                {
                    NSUInteger byteval = rand_r(&(randSeedHolderCopy->number)) % 256;
                    buf[i] = byteval;
                    bytesWritten++;
                }
                
                NSInteger curBytesWritten = [outputStream write:(const uint8_t *)buf maxLength:i];
                if (curBytesWritten != writeSize)
                {
                    XCTAssertTrue(NO, @"Incorrect number of bytes written to the stream.");
                    uploadFailed = YES;
                }
                break;
            }
                
            default:
                break;
        }
    }];
    
    AZSBlobRequestOptions *options = [[AZSBlobRequestOptions alloc] init];
    options.absorbConditionalErrorsOnRetry = YES;

    AZSBlobOutputStream *blobOutputStream = createOutputStreamCall(nil, options, nil);
    [blobOutputStream setDelegate:uploadDelegate];
    [blobOutputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [blobOutputStream open];
    
    while ((!uploadFailed) && (bytesWritten < blobSize))
    {
        BOOL loopSuccess = [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
        if (!loopSuccess)
        {
            break;
        }
    }
    
    [blobOutputStream close];
    [blobOutputStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    
    AZSByteValidationStream *targetStream = [[AZSByteValidationStream alloc]initWithRandomSeed:randSeed totalBlobSize:blobSize isUpload:NO];
    
    [blob downloadToStream:((NSOutputStream *)targetStream) accessCondition:nil requestOptions:nil operationContext:nil completionHandler:^(NSError * error) {
        XCTAssertNil(error, @"Error in downloading blob.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
        XCTAssert(targetStream.totalBytes == blobSize, @"Downloaded blob is wrong size.  Size = %ld, expected size = %ld", (unsigned long)targetStream.totalBytes, (unsigned long)(blobSize));
        XCTAssertFalse(targetStream.dataCorrupt, @"Downloaded blob is corrupt.  Error count = %ld, first few errors = sample\nsample%@", (unsigned long)targetStream.errorCount, targetStream.errors);
        
        if ((error != nil) || (targetStream.totalBytes != blobSize) || (targetStream.dataCorrupt))
        {
            testFailedInDownload = YES;
        }
        
        [semaphore signal];
    }];
    [semaphore wait];
    return testFailedInDownload;
}

// Note: This test works with ~200 MB blobs (you can watch memory consumption, it doesn't rise that far),
// but it takes a while.
-(void)testBlockBlobOutputStreamIterate
{
    int failures = 0;
    for (int i = 0; i < 2; i++)
    {
        @autoreleasepool {
            NSString *blobName = @"blobName";
            AZSCloudBlockBlob *blob = [self.blobContainer blockBlobReferenceFromName:blobName];
            if ([self runInternalTestOutputStreamWithBlobSize:20000000 blobToUpload:blob createOutputStreamCall:^AZSBlobOutputStream *(AZSAccessCondition *accessCondition, AZSBlobRequestOptions *requestOptions, AZSOperationContext *operationContext) {
                return [blob createOutputStreamWithAccessCondition:accessCondition requestOptions:requestOptions operationContext:operationContext];
            }])
            {
                failures++;
            }
        }
    }
    XCTAssertEqual(0, failures, @"%d failure(s) detected.", failures);
}

// Note: This test works with ~200 MB blobs (you can watch memory consumption, it doesn't rise that far),
// but it takes a while.
-(void)testPageBlobOutputStreamCreateNewIterate
{
    int blobSize = 512*40000;
    int failures = 0;
    for (int i = 0; i < 2; i++)
    {
        @autoreleasepool {
            NSString *blobName = @"blobName";
            AZSCloudPageBlob *blob = [self.blobContainer pageBlobReferenceFromName:blobName];
            if ([self runInternalTestOutputStreamWithBlobSize:blobSize blobToUpload:blob createOutputStreamCall:^AZSBlobOutputStream *(AZSAccessCondition *accessCondition, AZSBlobRequestOptions *requestOptions, AZSOperationContext *operationContext) {
                return [blob createOutputStreamWithSize:[NSNumber numberWithInt:blobSize] sequenceNumber:[NSNumber numberWithInt:100] accessCondition:accessCondition requestOptions:requestOptions operationContext:operationContext];
            }])
            {
                failures++;
            }
        }
    }
    XCTAssertEqual(0, failures, @"%d failure(s) detected.", failures);
}

// Note: This test works with ~200 MB blobs (you can watch memory consumption, it doesn't rise that far),
// but it takes a while.
-(void)testPageBlobOutputStreamExistingIterate
{
    int blobSize = 512*40000;
    __block int failures = 0;
    for (int i = 0; i < 2; i++)
    {
        @autoreleasepool {
            AZSTestSemaphore *semaphore = [[AZSTestSemaphore alloc] init];
            NSString *blobName = @"blobName";
            AZSCloudPageBlob *blob = [self.blobContainer pageBlobReferenceFromName:blobName];
            [blob createWithSize:[NSNumber numberWithInt:blobSize] completionHandler:^(NSError * _Nullable error) {
                XCTAssertNil(error, @"Error in creating blob.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
                if ([self runInternalTestOutputStreamWithBlobSize:blobSize blobToUpload:blob createOutputStreamCall:^AZSBlobOutputStream *(AZSAccessCondition *accessCondition, AZSBlobRequestOptions *requestOptions, AZSOperationContext *operationContext) {
                    return [blob createOutputStreamWithAccessCondition:accessCondition requestOptions:requestOptions operationContext:operationContext];
                }])
                {
                    failures++;
                }
                [semaphore signal];
            }];
            [semaphore wait];
        }
    }
    XCTAssertEqual(0, failures, @"%d failure(s) detected.", failures);
}


// Note: This test works with ~200 MB blobs (you can watch memory consumption, it doesn't rise that far),
// but it takes a while.
-(void)testAppendBlobOutputStreamCreateNewIterate
{
    int failures = 0;
    for (int i = 0; i < 2; i++)
    {
        @autoreleasepool {
            NSString *blobName = @"blobName";
            AZSCloudAppendBlob *blob = [self.blobContainer appendBlobReferenceFromName:blobName];
            if ([self runInternalTestOutputStreamWithBlobSize:20000000 blobToUpload:blob createOutputStreamCall:^AZSBlobOutputStream *(AZSAccessCondition *accessCondition, AZSBlobRequestOptions *requestOptions, AZSOperationContext *operationContext) {
                return [blob createOutputStreamWithCreateNew:YES accessCondition:accessCondition requestOptions:requestOptions operationContext:operationContext];
            }])
            {
                failures++;
            }
        }
    }
    XCTAssertEqual(0, failures, @"%d failure(s) detected.", failures);
}

// Note: This test works with ~200 MB blobs (you can watch memory consumption, it doesn't rise that far),
// but it takes a while.
-(void)testAppendBlobOutputStreamUseExistingIterate
{
    __block int failures = 0;
    for (int i = 0; i < 2; i++)
    {
        @autoreleasepool {
            AZSTestSemaphore *semaphore = [[AZSTestSemaphore alloc] init];
            NSString *blobName = @"blobName";
            AZSCloudAppendBlob *blob = [self.blobContainer appendBlobReferenceFromName:blobName];
            [blob createWithCompletionHandler:^(NSError * _Nullable error) {
                XCTAssertNil(error, @"Error in creating blob.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
                if ([self runInternalTestOutputStreamWithBlobSize:20000000 blobToUpload:blob createOutputStreamCall:^AZSBlobOutputStream *(AZSAccessCondition *accessCondition, AZSBlobRequestOptions *requestOptions, AZSOperationContext *operationContext) {
                    return [blob createOutputStreamWithCreateNew:NO accessCondition:accessCondition requestOptions:requestOptions operationContext:operationContext];
                }])
                {
                    failures++;
                }
                [semaphore signal];
            }];
            [semaphore wait];
        }
    }
    XCTAssertEqual(0, failures, @"%d failure(s) detected.", failures);
}

-(BOOL)runTestUploadFromStreamWithBlobSize:(NSUInteger)blobSize blobToUpload:(AZSCloudBlob *)blob uploadCall:(void (^)(NSInputStream * , AZSAccessCondition *, AZSBlobRequestOptions *, AZSOperationContext *, void(^)(NSError * error)))uploadCall
{
    AZSTestSemaphore *semaphore = [[AZSTestSemaphore alloc] init];
    unsigned int __block randSeed = (unsigned int)time(NULL);
    BOOL __block testFailedInDownload = NO;
    
    AZSByteValidationStream *sourceStream = [[AZSByteValidationStream alloc]initWithRandomSeed:randSeed totalBlobSize:blobSize isUpload:YES];
    AZSBlobRequestOptions *options = [[AZSBlobRequestOptions alloc] init];
    options.maximumDownloadBufferSize = 20000000;
    options.parallelismFactor = 2;
    options.absorbConditionalErrorsOnRetry = YES;
    
    uploadCall((NSInputStream *)sourceStream, nil, options, nil, ^(NSError * error) {
        XCTAssertNil(error, @"Error in uploading blob.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
        
        AZSByteValidationStream *targetStream =[[AZSByteValidationStream alloc]initWithRandomSeed:randSeed totalBlobSize:blobSize isUpload:NO];
        
        [blob downloadToStream:((NSOutputStream *)targetStream) accessCondition:nil requestOptions:options operationContext:nil completionHandler:^(NSError * error) {
            XCTAssertNil(error, @"Error in downloading blob.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
            XCTAssert(targetStream.totalBytes == blobSize, @"Downloaded blob is wrong size.  Size = %ld, expected size = %ld", (unsigned long)targetStream.totalBytes, (unsigned long)(blobSize));
            XCTAssertFalse(targetStream.dataCorrupt, @"Downloaded blob is corrupt.  Error count = %ld, first few errors = sample\nsample%@", (unsigned long)targetStream.errorCount, targetStream.errors);
            
            if ((error != nil) || (targetStream.totalBytes != blobSize) || (targetStream.dataCorrupt))
            {
                testFailedInDownload = YES;
            }
            
            [semaphore signal];
        }];

    });
    
    [semaphore wait];
    return testFailedInDownload;
}

-(void)testBlockBlobFromToStreamIterate
{
    int failures = 0;
    for (int i = 0; i < 2; i++)
    {
        @autoreleasepool {
            
            NSString *blobName = @"blobName";
            AZSCloudBlockBlob *blob = [self.blobContainer blockBlobReferenceFromName:blobName];
            
            if ([self runTestUploadFromStreamWithBlobSize:20000000 blobToUpload:blob uploadCall:^(NSInputStream *sourceStream, AZSAccessCondition *accessCondition, AZSBlobRequestOptions *blobRequestOptions, AZSOperationContext *operationContext, void(^completionHandler)(NSError * error)) {
                [blob uploadFromStream:sourceStream accessCondition:accessCondition requestOptions:blobRequestOptions operationContext:operationContext completionHandler:completionHandler];
            }])
            {
                failures++;
            }
        }
    }
    XCTAssertEqual(0, failures, @"%d failure(s) detected.", failures);
}

-(void)testPageBlobFromToStreamUseExistingIterate
{
    int blobSize = 512*40000;
    __block int failures = 0;
    for (int i = 0; i < 2; i++)
    {
        @autoreleasepool {
            AZSTestSemaphore *semaphore = [[AZSTestSemaphore alloc] init];
            NSString *blobName = @"blobName";
            AZSCloudPageBlob *blob = [self.blobContainer pageBlobReferenceFromName:blobName];
            
            [blob createWithSize:[NSNumber numberWithInt:blobSize] completionHandler:^(NSError * _Nullable error) {
                XCTAssertNil(error, @"Error in creating blob.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
                if ([self runTestUploadFromStreamWithBlobSize:blobSize blobToUpload:blob uploadCall:^(NSInputStream *sourceStream, AZSAccessCondition *accessCondition, AZSBlobRequestOptions *blobRequestOptions, AZSOperationContext *operationContext, void(^completionHandler)(NSError * error)) {
                    [blob uploadFromStream:sourceStream accessCondition:accessCondition requestOptions:blobRequestOptions operationContext:operationContext completionHandler:completionHandler];
                }])
                {
                    failures++;
                }
                [semaphore signal];
            }];
            [semaphore wait];
        }
    }
    XCTAssertEqual(0, failures, @"%d failure(s) detected.", failures);
}

-(void)testPageBlobFromToStreamCreateNewIterate
{
    int blobSize = 512*40000;
    int failures = 0;
    for (int i = 0; i < 2; i++)
    {
        @autoreleasepool {
            
            NSString *blobName = @"blobName";
            AZSCloudPageBlob *blob = [self.blobContainer pageBlobReferenceFromName:blobName];
            
            if ([self runTestUploadFromStreamWithBlobSize:blobSize blobToUpload:blob uploadCall:^(NSInputStream *sourceStream, AZSAccessCondition *accessCondition, AZSBlobRequestOptions *blobRequestOptions, AZSOperationContext *operationContext, void(^completionHandler)(NSError * error)) {
                [blob uploadFromStream:sourceStream size:[NSNumber numberWithInt:blobSize] initialSequenceNumber:[NSNumber numberWithInt:100] accessCondition:accessCondition requestOptions:blobRequestOptions operationContext:operationContext completionHandler:completionHandler];
            }])
            {
                failures++;
            }
        }
    }
    XCTAssertEqual(0, failures, @"%d failure(s) detected.", failures);
}

-(void)testAppendBlobFromToStreamUseExistingIterate
{
    int blobSize = 20000000;
    __block int failures = 0;
    for (int i = 0; i < 2; i++)
    {
        @autoreleasepool {
            AZSTestSemaphore *semaphore = [[AZSTestSemaphore alloc] init];
            NSString *blobName = @"blobName";
            AZSCloudAppendBlob *blob = [self.blobContainer appendBlobReferenceFromName:blobName];
            
            [blob createWithCompletionHandler:^(NSError * _Nullable error) {
                XCTAssertNil(error, @"Error in creating blob.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
                if ([self runTestUploadFromStreamWithBlobSize:blobSize blobToUpload:blob uploadCall:^(NSInputStream *sourceStream, AZSAccessCondition *accessCondition, AZSBlobRequestOptions *blobRequestOptions, AZSOperationContext *operationContext, void(^completionHandler)(NSError * error)) {
                    [blob uploadFromStream:sourceStream createNew:NO accessCondition:accessCondition requestOptions:blobRequestOptions operationContext:operationContext completionHandler:completionHandler];
                }])
                {
                    failures++;
                }
                [semaphore signal];
            }];
            [semaphore wait];
        }
    }
    XCTAssertEqual(0, failures, @"%d failure(s) detected.", failures);
}

-(void)testAppendBlobFromToStreamCreateNewIterate
{
    int blobSize = 20000000;
    int failures = 0;
    for (int i = 0; i < 2; i++)
    {
        @autoreleasepool {
            
            NSString *blobName = @"blobName";
            AZSCloudAppendBlob *blob = [self.blobContainer appendBlobReferenceFromName:blobName];
            
            if ([self runTestUploadFromStreamWithBlobSize:blobSize blobToUpload:blob uploadCall:^(NSInputStream *sourceStream, AZSAccessCondition *accessCondition, AZSBlobRequestOptions *blobRequestOptions, AZSOperationContext *operationContext, void(^completionHandler)(NSError * error)) {
                [blob uploadFromStream:sourceStream createNew:YES accessCondition:accessCondition requestOptions:blobRequestOptions operationContext:operationContext completionHandler:completionHandler];
            }])
            {
                failures++;
            }
        }
    }
    XCTAssertEqual(0, failures, @"%d failure(s) detected.", failures);
}

@end