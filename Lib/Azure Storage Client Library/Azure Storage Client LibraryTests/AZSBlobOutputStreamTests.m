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
    self.containerName = [[NSString stringWithFormat:@"sampleioscontainer%@", [[[NSUUID UUID] UUIDString] stringByReplacingOccurrencesOfString:@"-" withString:AZSCEmptyString]] lowercaseString];
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

- (BOOL)runInternalTestOutputStreamWithBlobSize:(NSUInteger)blobSize
{
    AZSTestSemaphore *semaphore = [[AZSTestSemaphore alloc] init];
    NSString *blobName = @"blobName";
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
    
    AZSCloudBlockBlob *blockBlob = [self.blobContainer blockBlobReferenceFromName:blobName];
    AZSBlobOutputStream *blobOutputStream = [blockBlob createOutputStream];
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
    
    [blockBlob downloadToStream:((NSOutputStream *)targetStream) accessCondition:nil requestOptions:nil operationContext:nil completionHandler:^(NSError * error) {
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
-(void)testOutputStreamIterate
{
    int failures = 0;
    for (int i = 0; i < 2; i++)
    {
        @autoreleasepool {
            if ([self runInternalTestOutputStreamWithBlobSize:20000000])
            {
                failures++;
            }
        }
    }
    XCTAssertTrue(0 == failures, @"%d failure(s) detected.", failures);
}

-(BOOL)runTestUploadFromStreamWithBlobSize:(NSUInteger)blobSize
{
    AZSTestSemaphore *semaphore = [[AZSTestSemaphore alloc] init];
    NSString *blobName = @"blobName";
    unsigned int __block randSeed = (unsigned int)time(NULL);
    BOOL __block testFailedInDownload = NO;
    
    AZSByteValidationStream *sourceStream = [[AZSByteValidationStream alloc]initWithRandomSeed:randSeed totalBlobSize:blobSize isUpload:YES];
    AZSCloudBlockBlob *blockBlob = [self.blobContainer blockBlobReferenceFromName:blobName];
    AZSBlobRequestOptions *options = [[AZSBlobRequestOptions alloc] init];
    options.maximumDownloadBufferSize = 20000000;
    options.parallelismFactor = 2;
    [blockBlob uploadFromStream:(NSInputStream *)sourceStream accessCondition:nil requestOptions:nil operationContext:nil completionHandler:^(NSError * error) {
        XCTAssertNil(error, @"Error in uploading blob.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
        
        AZSByteValidationStream *targetStream =[[AZSByteValidationStream alloc]initWithRandomSeed:randSeed totalBlobSize:blobSize isUpload:NO];
        
        [blockBlob downloadToStream:((NSOutputStream *)targetStream) accessCondition:nil requestOptions:nil operationContext:nil completionHandler:^(NSError * error) {
            XCTAssertNil(error, @"Error in downloading blob.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
            XCTAssert(targetStream.totalBytes == blobSize, @"Downloaded blob is wrong size.  Size = %ld, expected size = %ld", (unsigned long)targetStream.totalBytes, (unsigned long)(blobSize));
            XCTAssertFalse(targetStream.dataCorrupt, @"Downloaded blob is corrupt.  Error count = %ld, first few errors = sample\nsample%@", (unsigned long)targetStream.errorCount, targetStream.errors);
            
            if ((error != nil) || (targetStream.totalBytes != blobSize) || (targetStream.dataCorrupt))
            {
                testFailedInDownload = YES;
            }
            
            [semaphore signal];
        }];
    }];
    [semaphore wait];
    return testFailedInDownload;
}

-(void)testFromToStreamIterate
{
    int failures = 0;
    for (int i = 0; i < 2; i++)
    {
        @autoreleasepool {
            if ([self runTestUploadFromStreamWithBlobSize:20000000])
            {
                failures++;
            }
        }
    }
    XCTAssertTrue(0 == failures, @"%d failure(s) detected.", failures);
}

@end