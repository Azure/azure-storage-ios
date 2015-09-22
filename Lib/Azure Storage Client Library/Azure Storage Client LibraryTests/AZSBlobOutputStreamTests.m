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
#import "AZSBlobTestBase.h"
#import "Azure_Storage_Client_Library.h"
#import "AZSTestHelpers.h"


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
    self.containerName = [[NSString stringWithFormat:@"sampleioscontainer%@",[[[NSUUID UUID] UUIDString] stringByReplacingOccurrencesOfString:@"-" withString:@""]] lowercaseString];
    self.blobContainer = [self.blobClient containerReferenceFromName:self.containerName];
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    [self.blobContainer createContainerWithCompletionHandler:^(NSError * error) {
        dispatch_semaphore_signal(semaphore);
    }];
    
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    
    // Put setup code here; it will be run once, before the first test case.
}

- (void)tearDown
{
    // Put teardown code here; it will be run once, after the last test case.
    AZSCloudBlobContainer *blobContainer = [self.blobClient containerReferenceFromName:self.containerName];
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    @try {
        // Best-effort cleanup
        // TODO: Change to delete if exists once that's implemented.
        
        [blobContainer deleteContainerWithCompletionHandler:^(NSError * error) {
            dispatch_semaphore_signal(semaphore);
        }];
    }
    @catch (NSException *exception) {
        
    }
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    [super tearDown];
}



- (BOOL)runInternalTestOutputStreamWithBlobSize:(NSUInteger)blobSize
{
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    NSString *blobName = @"blobName";
    unsigned int __block randSeed = (unsigned int)time(NULL);
//    NSUInteger __block randSeedCopy = randSeed;
    
    AZSUIntegerHolder *randSeedHolder = [[AZSUIntegerHolder alloc]initWithNumber:randSeed];
    AZSUIntegerHolder *randSeedHolderCopy = [[AZSUIntegerHolder alloc]initWithNumber:randSeed];
    NSLog(@"Randseed = %ld", (unsigned long)randSeed);
    NSUInteger writeSize = 10000;
    NSUInteger __block bytesWritten = 0;
    BOOL __block uploadFailed = NO;
    BOOL __block testFailedInDownload = NO;
    
//    NSMutableData *allData = [NSMutableData dataWithLength:blobSize];
//    Byte *allBytes = [allData mutableBytes];
    
    AZSBlobUploadTestDelegate *uploadDelegate = [[AZSBlobUploadTestDelegate alloc] initWithBlock:^(NSStream *stream, NSStreamEvent eventCode) {
        NSOutputStream *outputStream = (NSOutputStream *)stream;
        switch (eventCode) {
            case NSStreamEventHasSpaceAvailable:
            {
//                NSMutableData *blockData = [NSMutableData dataWithLength:writeSize];
                
//                Byte* bytes = [blockData mutableBytes];
                
                uint8_t buf[writeSize];
                int i = 0;
                for (i = 0; i < writeSize && bytesWritten < blobSize; i++)
                {
                    NSUInteger byteval = rand_r(&(randSeedHolderCopy->number)) % 256;
                    buf[i] = byteval;
//                    allBytes[bytesWritten] = byteval;
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
    
    NSLog(@"About to upload data.");
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
    
    NSLog(@"Finished uploading, about to download.");
    AZSByteValidationStream *targetStream = [[AZSByteValidationStream alloc]initWithRandomSeed:randSeed totalBlobSize:blobSize isUpload:NO];
    
    [blockBlob downloadToStream:((NSOutputStream *)targetStream) accessCondition:nil requestOptions:nil operationContext:nil completionHandler:^(NSError * error) {
        XCTAssertNil(error, @"Error in downloading blob.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
        
        NSLog(@"RandseedHolder = %ld", (unsigned long)randSeedHolder->number);
        NSLog(@"RandseedHolderCopy = %ld", (unsigned long)randSeedHolderCopy->number);
        
        
        XCTAssert(targetStream.totalBytes == blobSize, @"Downloaded blob is wrong size.  Size = %ld, expected size = %ld", (unsigned long)targetStream.totalBytes, (unsigned long)(blobSize));
        XCTAssertFalse(targetStream.dataCorrupt, @"Downloaded blob is corrupt.  Error count = %ld, first few errors = sample\nsample%@", (unsigned long)targetStream.errorCount, targetStream.errors);
        
        if ((error != nil) || (targetStream.totalBytes != blobSize) || (targetStream.dataCorrupt))
        {
            testFailedInDownload = YES;
        }
        
        dispatch_semaphore_signal(semaphore);
    }];
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
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
        NSLog(@"Test %d finished.", i);
    }
    XCTAssertTrue(0 == failures, @"%d failure(s) detected.", failures);
}

-(BOOL)runTestUploadFromStreamWithBlobSize:(NSUInteger)blobSize
{
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    NSString *blobName = @"blobName";
    unsigned int __block randSeed = (unsigned int)time(NULL);

    NSLog(@"Randseed = %ld", (unsigned long)randSeed);
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
            
            dispatch_semaphore_signal(semaphore);

        }];
    }];
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
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
        NSLog(@"Test %d finished.", i);
    }
    XCTAssertTrue(0 == failures, @"%d failure(s) detected.", failures);
}


@end
