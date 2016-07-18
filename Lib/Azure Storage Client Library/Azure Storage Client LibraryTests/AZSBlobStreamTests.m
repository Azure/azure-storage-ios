// -----------------------------------------------------------------------------------------
// <copyright file="AZSBlobStreamTests.m" company="Microsoft">
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
#import "AZSBlobInputStream.h"
#import "AZSBlobTestBase.h"
#import "AZSStreamDownloadBuffer.h"
#import "AZSTestHelpers.h"
#import "AZSTestSemaphore.h"
#import "AZSClient.h"

@interface AZSBlobStreamTests : AZSBlobTestBase

@property NSString *containerName;
@property AZSCloudBlobContainer *blobContainer;

@end


@implementation AZSBlobStreamTests

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

- (int)runInternalTestStreamWithBlobSize:(const NSUInteger)blobSize blobToUpload:(AZSCloudBlob *)blob runloop:(NSRunLoop *)runloop createOutputStreamCall:(AZSBlobOutputStream *(^)(AZSAccessCondition *, AZSBlobRequestOptions *, AZSOperationContext *))createOutputStreamCall
{
    int __block testsFailedInDownload = 0;
    unsigned int randSeed = (unsigned int)time(NULL);
    BOOL useCurrentRunloop = !runloop;
    runloop = runloop ?: [NSRunLoop currentRunLoop];
    
    // Upload
    AZSByteValidationStream *uploadDelegate = [[AZSByteValidationStream alloc] initWithRandomSeed:randSeed totalBlobSize:blobSize isUpload:NO failBlock:^(NSString *message) {
        XCTAssertTrue(NO, @"%@", message);
    }];
    AZSBlobRequestOptions *options = [[AZSBlobRequestOptions alloc] init];
    options.absorbConditionalErrorsOnRetry = YES;

    AZSBlobOutputStream *blobOutputStream = createOutputStreamCall(nil, options, nil);
    [blobOutputStream scheduleInRunLoop:runloop forMode:NSDefaultRunLoopMode];
    [blobOutputStream setDelegate:uploadDelegate];
    [blobOutputStream open];
    
    BOOL loopSuccess = YES;
    while (loopSuccess && (!uploadDelegate.streamFailed) && (uploadDelegate.bytesWritten < blobSize)) {
        if (useCurrentRunloop) {
            loopSuccess = [runloop runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:2]];
        }
        else {
            [NSThread sleepForTimeInterval:.25];
        }
    }
    
    [blobOutputStream close];
    
    loopSuccess = YES;
    while (loopSuccess && blobOutputStream.streamStatus != NSStreamStatusClosed)
    {
        if (useCurrentRunloop) {
            loopSuccess = [runloop runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:2]];
        }
        else {
            [NSThread sleepForTimeInterval:.25];
        }
    }
    [blobOutputStream removeFromRunLoop:runloop forMode:NSDefaultRunLoopMode];
    
    // Download to Input Stream
    AZSByteValidationStream *downloadDelegate = [[AZSByteValidationStream alloc] initWithRandomSeed:randSeed totalBlobSize:blobSize isUpload:NO failBlock:^(NSString *message) {
        XCTAssertTrue(NO, @"%@", message);
    }];
    
    options.runLoopForDownload = runloop;
    AZSBlobInputStream *readStream = [blob createInputStreamWithAccessCondition:nil requestOptions:options operationContext:nil];
    
    [readStream scheduleInRunLoop:runloop forMode:NSDefaultRunLoopMode];
    [readStream setDelegate:downloadDelegate];
    [readStream open];
    
    loopSuccess = YES;
    while (loopSuccess && !downloadDelegate.streamFailed && !readStream.downloadBuffer.downloadComplete) {
        if (useCurrentRunloop) {
            loopSuccess = [runloop runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:2]];
        }
        else {
            [NSThread sleepForTimeInterval:.25];
        }
    }
    
    [readStream close];
    [readStream removeFromRunLoop:runloop forMode:NSDefaultRunLoopMode];
    
    // Download to Output Stream
    AZSByteValidationStream *downloadStream = [[AZSByteValidationStream alloc] initWithRandomSeed:randSeed totalBlobSize:blobSize isUpload:NO failBlock:^(NSString *message) {
        XCTAssertTrue(NO, @"%@", message);
    }];
    
    AZSTestSemaphore *semaphore = [[AZSTestSemaphore alloc] init];
    [blob downloadToStream:((NSOutputStream *) downloadStream) accessCondition:nil requestOptions:nil operationContext:nil completionHandler:^(NSError * error) {
        XCTAssertNil(error, @"Error in downloading blob.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
        XCTAssertEqual(downloadStream.totalBytes, blobSize, @"Downloaded blob is wrong size.  Size = %ld, expected size = %ld", (unsigned long)downloadStream.totalBytes, (unsigned long)blobSize);
        XCTAssertFalse(downloadStream.dataCorrupt, @"Downloaded blob is corrupt.  Error count = %ld, first few errors = sample\nsample%@", (unsigned long)downloadStream.errorCount, downloadStream.errors);
        
        if ((error != nil) || (downloadStream.totalBytes != blobSize) || downloadStream.dataCorrupt) {
            testsFailedInDownload++;
        }
        
        [semaphore signal];
    }];
    [semaphore wait];
    
    return testsFailedInDownload;
}

-(void)testBlockBlobStreamError
{
    AZSCloudBlockBlob *blob = [[AZSCloudBlockBlob alloc] initWithContainer:self.blobContainer name:[AZSTestHelpers uniqueName]];
    
    // Test InputStream
    AZSBlobInputStream *inputStream = [blob createInputStream];
    __block BOOL downloadFailed = NO;
    
    AZSByteValidationStream *downloadDelegate = [[AZSByteValidationStream alloc] initWithRandomSeed:(unsigned int)time(NULL) totalBlobSize:0 isUpload:NO failBlock:^(NSString *message) {
        [self checkPassageOfError:inputStream.streamError expectToPass:NO expectedHttpErrorCode:404 message:@"Blob unexpectedly found."];
        downloadFailed = YES;
    }];
    
    AZSTestSemaphore *semaphore = [[AZSTestSemaphore alloc] init];
    NSRunLoop *runloop = [self runloopWithSemaphore:semaphore];
    
    [inputStream scheduleInRunLoop:runloop forMode:NSDefaultRunLoopMode];
    [inputStream setDelegate:downloadDelegate];
    [inputStream open];
    
    while (!downloadDelegate.streamFailed && !downloadDelegate.downloadComplete) {
        // TODO: Reduce when error handling is fixed.
        [NSThread sleepForTimeInterval:2];
    }
    
    [semaphore signal];
    [inputStream close];
    
    XCTAssertTrue(downloadFailed, @"Download unexpectedly succeeded.");
    XCTAssertEqual(0, downloadDelegate.totalBytes);
    
    // Test OutputStream
    semaphore = [[AZSTestSemaphore alloc] init];
    NSData *data = [NSData dataWithBytesNoCopy:calloc(8, sizeof(uint8_t)) length:8 freeWhenDone:YES];
    NSOutputStream *outputStream = [NSOutputStream outputStreamToBuffer:(uint8_t*)data.bytes capacity:8];
    
    [blob downloadToStream:outputStream completionHandler:^(NSError * error) {
        [self checkPassageOfError:error expectToPass:NO expectedHttpErrorCode:404 message:@"Blob unexpectedly found."];
        [semaphore signal];
    }];
    [semaphore wait];
    
    for (int i = 0; i < data.length; i++) {
        XCTAssertEqual(0, ((uint8_t*) data.bytes)[i]);
    }
}

// Note: This test works with ~200 MB blobs (you can watch memory consumption, it doesn't rise that far),
// but it takes a while.
-(void)testBlockBlobStreamIterate
{
    int failures = 0;
    NSRunLoop *runloop = nil;
    AZSTestSemaphore *semaphore = [[AZSTestSemaphore alloc] init];
    
    for (int i = 0; i < 2; i++)
    {
        @autoreleasepool {
            NSString *blobName = @"blobName";
            AZSCloudBlockBlob *blob = [self.blobContainer blockBlobReferenceFromName:blobName];
            failures += [self runInternalTestStreamWithBlobSize:20000000 blobToUpload:blob runloop:runloop createOutputStreamCall:^AZSBlobOutputStream *(AZSAccessCondition *accessCondition, AZSBlobRequestOptions *requestOptions, AZSOperationContext *operationContext) {
                return [blob createOutputStreamWithAccessCondition:accessCondition requestOptions:requestOptions operationContext:operationContext];
            }];
        }
        
        runloop = runloop ?: [self runloopWithSemaphore:semaphore];
    }
    
    [semaphore signal];
    XCTAssertEqual(0, failures, @"%d failure(s) detected.", failures);
}

// Note: This test works with ~200 MB blobs (you can watch memory consumption, it doesn't rise that far),
// but it takes a while.
-(void)testPageBlobStreamCreateNewIterate
{
    int blobSize = 512*40000;
    int failures = 0;
    NSRunLoop *runloop = nil;
    AZSTestSemaphore *semaphore = [[AZSTestSemaphore alloc] init];
    
    for (int i = 0; i < 2; i++)
    {
        @autoreleasepool {
            NSString *blobName = @"blobName";
            AZSCloudPageBlob *blob = [self.blobContainer pageBlobReferenceFromName:blobName];
            failures += [self runInternalTestStreamWithBlobSize:blobSize blobToUpload:blob runloop:runloop createOutputStreamCall:^AZSBlobOutputStream *(AZSAccessCondition *accessCondition, AZSBlobRequestOptions *requestOptions, AZSOperationContext *operationContext) {
                return [blob createOutputStreamWithSize:[NSNumber numberWithInt:blobSize] sequenceNumber:[NSNumber numberWithInt:100] accessCondition:accessCondition requestOptions:requestOptions operationContext:operationContext];
            }];
        }
        
        runloop = [self runloopWithSemaphore:semaphore];
    }
    
    [semaphore signal];
    XCTAssertEqual(0, failures, @"%d failure(s) detected.", failures);
}

// Note: This test works with ~200 MB blobs (you can watch memory consumption, it doesn't rise that far),
// but it takes a while.
-(void)testPageBlobStreamExistingIterate
{
    int blobSize = 512*40000;
    __block int failures = 0;
    NSRunLoop *runloop = nil;
    AZSTestSemaphore *runloopSemaphore = [[AZSTestSemaphore alloc] init];
    
    for (int i = 0; i < 2; i++)
    {
        @autoreleasepool {
            AZSTestSemaphore *semaphore = [[AZSTestSemaphore alloc] init];
            NSString *blobName = @"blobName";
            AZSCloudPageBlob *blob = [self.blobContainer pageBlobReferenceFromName:blobName];
            [blob createWithSize:[NSNumber numberWithInt:blobSize] completionHandler:^(NSError * __AZSNullable error) {
                XCTAssertNil(error, @"Error in creating blob.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
                failures += [self runInternalTestStreamWithBlobSize:blobSize blobToUpload:blob runloop:runloop createOutputStreamCall:^AZSBlobOutputStream *(AZSAccessCondition *accessCondition, AZSBlobRequestOptions *requestOptions, AZSOperationContext *operationContext) {
                    return [blob createOutputStreamWithAccessCondition:accessCondition requestOptions:requestOptions operationContext:operationContext];
                }];
                
                [semaphore signal];
            }];
            
            [semaphore wait];
        }
        
        runloop = [self runloopWithSemaphore:runloopSemaphore];
    }
    
    [runloopSemaphore signal];
    XCTAssertEqual(0, failures, @"%d failure(s) detected.", failures);
}


// Note: This test works with ~200 MB blobs (you can watch memory consumption, it doesn't rise that far),
// but it takes a while.
-(void)testAppendBlobStreamCreateNewIterate
{
    int failures = 0;
    NSRunLoop *runloop = nil;
    AZSTestSemaphore *semaphore = [[AZSTestSemaphore alloc] init];
    
    for (int i = 0; i < 2; i++)
    {
        @autoreleasepool {
            NSString *blobName = @"blobName";
            AZSCloudAppendBlob *blob = [self.blobContainer appendBlobReferenceFromName:blobName];
            failures += [self runInternalTestStreamWithBlobSize:20000000 blobToUpload:blob runloop:runloop createOutputStreamCall:^AZSBlobOutputStream *(AZSAccessCondition *accessCondition, AZSBlobRequestOptions *requestOptions, AZSOperationContext *operationContext) {
                return [blob createOutputStreamWithCreateNew:YES accessCondition:accessCondition requestOptions:requestOptions operationContext:operationContext];
            }];
        }
        
        runloop = [self runloopWithSemaphore:semaphore];
    }
    
    [semaphore signal];
    XCTAssertEqual(0, failures, @"%d failure(s) detected.", failures);
}

// Note: This test works with ~200 MB blobs (you can watch memory consumption, it doesn't rise that far),
// but it takes a while.
-(void)testAppendBlobStreamUseExistingIterate
{
    __block int failures = 0;
    NSRunLoop *runloop = nil;
    AZSTestSemaphore *runloopSemaphore = [[AZSTestSemaphore alloc] init];
    
    for (int i = 0; i < 2; i++)
    {
        @autoreleasepool {
            AZSTestSemaphore *semaphore = [[AZSTestSemaphore alloc] init];
            NSString *blobName = @"blobName";
            AZSCloudAppendBlob *blob = [self.blobContainer appendBlobReferenceFromName:blobName];
            
            [blob createWithCompletionHandler:^(NSError * __AZSNullable error) {
                XCTAssertNil(error, @"Error in creating blob.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
                failures += [self runInternalTestStreamWithBlobSize:20000000 blobToUpload:blob runloop:runloop createOutputStreamCall:^AZSBlobOutputStream *(AZSAccessCondition *accessCondition, AZSBlobRequestOptions *requestOptions, AZSOperationContext *operationContext) {
                    return [blob createOutputStreamWithCreateNew:NO accessCondition:accessCondition requestOptions:requestOptions operationContext:operationContext];
                }];
                
                [semaphore signal];
            }];
            [semaphore wait];
        }
        
        runloop = [self runloopWithSemaphore:runloopSemaphore];
    }
    
    [runloopSemaphore signal];
    XCTAssertEqual(0, failures, @"%d failure(s) detected.", failures);
}

-(int)runTestUploadFromStreamWithBlobSize:(const NSUInteger)blobSize blobToUpload:(AZSCloudBlob *)blob uploadCall:(void (^)(NSInputStream * , AZSAccessCondition *, AZSBlobRequestOptions *, AZSOperationContext *, void(^)(NSError * error)))uploadCall
{
    AZSTestSemaphore *semaphore = [[AZSTestSemaphore alloc] init];
    unsigned int __block randSeed = (unsigned int)time(NULL);
    int __block testsFailedInDownload = 0;
    
    AZSByteValidationStream *sourceStream = [[AZSByteValidationStream alloc]initWithRandomSeed:randSeed totalBlobSize:blobSize isUpload:YES failBlock:^(NSString *message) {
        XCTAssertTrue(NO, @"%@", message);
    }];
    AZSBlobRequestOptions *options = [[AZSBlobRequestOptions alloc] init];
    options.parallelismFactor = 2;
    options.absorbConditionalErrorsOnRetry = YES;
    
    uploadCall((NSInputStream *)sourceStream, nil, options, nil, ^(NSError * error) {
        XCTAssertNil(error, @"Error in uploading blob.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
        
        AZSByteValidationStream *targetStream =[[AZSByteValidationStream alloc]initWithRandomSeed:randSeed totalBlobSize:blobSize isUpload:NO failBlock:^(NSString *message) {
            XCTAssertTrue(NO, @"%@", message);
        }];
        
        AZSBlobInputStream *readStream = [blob createInputStream];
        
        AZSBlobTestSpinWrapper *wrapper = [[AZSBlobTestSpinWrapper alloc] init];
        wrapper.stream = readStream;
        wrapper.delegate = targetStream;
        
        wrapper.completionHandler = ^() {
            AZSByteValidationStream *newTargetStream = [[AZSByteValidationStream alloc] initWithRandomSeed:randSeed totalBlobSize:blobSize isUpload:NO failBlock:^(NSString *message) {
                XCTAssertTrue(NO, @"%@", message);
            }];
            
            [blob downloadToStream:((NSOutputStream *)newTargetStream) accessCondition:nil requestOptions:options operationContext:nil completionHandler:^(NSError * error) {
                XCTAssertNil(error, @"Error in downloading blob.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
                XCTAssert(newTargetStream.totalBytes == blobSize, @"Downloaded blob is wrong size.  Size = %ld, expected size = %ld", (unsigned long)newTargetStream.totalBytes, (unsigned long)(blobSize));
                XCTAssertFalse(newTargetStream.dataCorrupt, @"Downloaded blob is corrupt.  Error count = %ld, first few errors = sample\nsample%@", (unsigned long)newTargetStream.errorCount, newTargetStream.errors);
                
                if ((error != nil) || (newTargetStream.totalBytes != blobSize) || (newTargetStream.dataCorrupt))
                {
                    testsFailedInDownload++;
                }
                
                [semaphore signal];
            }];
        };
        
        [NSThread detachNewThreadSelector:@selector(scheduleStreamInNewThreaAndRunWithWrapper:) toTarget:self withObject:wrapper];
    });
    
    [semaphore wait];
    return testsFailedInDownload;
}

-(void)testBlockBlobFromToStreamIterate
{
    int failures = 0;
    for (int i = 0; i < 2; i++)
    {
        @autoreleasepool {
            
            NSString *blobName = @"blobName";
            AZSCloudBlockBlob *blob = [self.blobContainer blockBlobReferenceFromName:blobName];
            
            failures += [self runTestUploadFromStreamWithBlobSize:20000000 blobToUpload:blob uploadCall:^(NSInputStream *sourceStream, AZSAccessCondition *accessCondition, AZSBlobRequestOptions *blobRequestOptions, AZSOperationContext *operationContext, void(^completionHandler)(NSError * error)) {
                [blob uploadFromStream:sourceStream accessCondition:accessCondition requestOptions:blobRequestOptions operationContext:operationContext completionHandler:completionHandler];
            }];
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
            
            [blob createWithSize:[NSNumber numberWithInt:blobSize] completionHandler:^(NSError * __AZSNullable error) {
                XCTAssertNil(error, @"Error in creating blob.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
                failures += [self runTestUploadFromStreamWithBlobSize:blobSize blobToUpload:blob uploadCall:^(NSInputStream *sourceStream, AZSAccessCondition *accessCondition, AZSBlobRequestOptions *blobRequestOptions, AZSOperationContext *operationContext, void(^completionHandler)(NSError * error)) {
                    [blob uploadFromStream:sourceStream accessCondition:accessCondition requestOptions:blobRequestOptions operationContext:operationContext completionHandler:completionHandler];
                }];
                
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
            
            failures += [self runTestUploadFromStreamWithBlobSize:blobSize blobToUpload:blob uploadCall:^(NSInputStream *sourceStream, AZSAccessCondition *accessCondition, AZSBlobRequestOptions *blobRequestOptions, AZSOperationContext *operationContext, void(^completionHandler)(NSError * error)) {
                [blob uploadFromStream:sourceStream size:[NSNumber numberWithInt:blobSize] initialSequenceNumber:[NSNumber numberWithInt:100] accessCondition:accessCondition requestOptions:blobRequestOptions operationContext:operationContext completionHandler:completionHandler];
            }];
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
            
            [blob createWithCompletionHandler:^(NSError * __AZSNullable error) {
                XCTAssertNil(error, @"Error in creating blob.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
                failures += [self runTestUploadFromStreamWithBlobSize:blobSize blobToUpload:blob uploadCall:^(NSInputStream *sourceStream, AZSAccessCondition *accessCondition, AZSBlobRequestOptions *blobRequestOptions, AZSOperationContext *operationContext, void(^completionHandler)(NSError * error)) {
                    [blob uploadFromStream:sourceStream createNew:NO accessCondition:accessCondition requestOptions:blobRequestOptions operationContext:operationContext completionHandler:completionHandler];
                }];
                
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
            
            failures += [self runTestUploadFromStreamWithBlobSize:blobSize blobToUpload:blob uploadCall:^(NSInputStream *sourceStream, AZSAccessCondition *accessCondition, AZSBlobRequestOptions *blobRequestOptions, AZSOperationContext *operationContext, void(^completionHandler)(NSError * error)) {
                [blob uploadFromStream:sourceStream createNew:YES accessCondition:accessCondition requestOptions:blobRequestOptions operationContext:operationContext completionHandler:completionHandler];
            }];
        }
    }
    XCTAssertEqual(0, failures, @"%d failure(s) detected.", failures);
}

@end