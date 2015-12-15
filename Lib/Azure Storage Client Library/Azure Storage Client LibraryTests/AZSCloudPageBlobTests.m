// -----------------------------------------------------------------------------------------
// <copyright file="AZSCloudPageBlobTests.m" company="Microsoft">
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
#import "AZSBlobTestBase.h"
#import "Azure_Storage_Client_Library.h"
#import "AZSTestHelpers.h"
#import "AZSTestSemaphore.h"
#import "AZSUtil.h"

@interface AZSCloudPageBlobTests : AZSBlobTestBase
@property NSString *containerName;
@property AZSCloudBlobContainer *blobContainer;
@property int pageSize;
@end

@implementation AZSCloudPageBlobTests

- (void)setUp
{
    [super setUp];
    self.containerName = [[NSString stringWithFormat:@"sampleioscontainer%@",[[[NSUUID UUID] UUIDString] stringByReplacingOccurrencesOfString:@"-" withString:@""]] lowercaseString];
    self.blobContainer = [self.blobClient containerReferenceFromName:self.containerName];
    self.pageSize = 512;
    AZSTestSemaphore *semaphore = [[AZSTestSemaphore alloc] init];
    
    [self.blobContainer createContainerWithCompletionHandler:^(NSError * error) {
        XCTAssertNil(error, @"Error in test setup, in creating container.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
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
    
    @try {
        // Best-effort cleanup
        // TODO: Change to delete if exists once that's implemented.
        
        [blobContainer deleteContainerWithCompletionHandler:^(NSError * error) {
            [semaphore signal];
        }];
    }
    @catch (NSException *exception) {
        
    }
    [semaphore wait];
    [super tearDown];
}

-(void)testCreate
{
    AZSTestSemaphore *semaphore = [[AZSTestSemaphore alloc] init];

    AZSCloudPageBlob *pageBlob = [self.blobContainer pageBlobReferenceFromName:@"pageBlob"];
    
    [pageBlob existsWithCompletionHandler:^(NSError *error, BOOL existsResult) {
        XCTAssertNil(error, @"Error in blob exists.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
        XCTAssertFalse(existsResult, @"Blob exists when it should not.");
        
        NSNumber *blobSize = [NSNumber numberWithInt:1000*512];
        [pageBlob createWithSize:blobSize completionHandler:^(NSError *error) {
            XCTAssertNil(error, @"Error in blob creation.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
            
            AZSCloudPageBlob *newPageBlob = [self.blobContainer pageBlobReferenceFromName:@"pageBlob"];
            [newPageBlob existsWithCompletionHandler:^(NSError *error, BOOL existsResult) {
                XCTAssertNil(error, @"Error in blob exists.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
                XCTAssertTrue(existsResult, @"Blob does not exist when it should.");
                XCTAssertEqualObjects(newPageBlob.properties.length, blobSize, @"Blob size not correctly returned.");
                
                [semaphore signal];
            }];
        }];
    }];
    
    [semaphore wait];
}

-(void)testCreateIfNotExists
{
    AZSTestSemaphore *semaphore = [[AZSTestSemaphore alloc] init];
    
    AZSCloudPageBlob *pageBlob = [self.blobContainer pageBlobReferenceFromName:@"pageBlob"];
    
    [pageBlob existsWithCompletionHandler:^(NSError *error, BOOL existsResult) {
        XCTAssertNil(error, @"Error in blob exists.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
        XCTAssertFalse(existsResult, @"Blob exists when it should not.");
        
        NSNumber *blobSize = [NSNumber numberWithInt:1000*512];
        [pageBlob createIfNotExistsWithSize:blobSize completionHandler:^(NSError *error, BOOL created) {
            XCTAssertNil(error, @"Error in blob creation.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
            XCTAssertTrue(created, @"Blob creation incorrectly returned.");
            
            [pageBlob createIfNotExistsWithSize:blobSize completionHandler:^(NSError *error, BOOL created) {
                XCTAssertNil(error, @"Error in blob creation.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
                XCTAssertFalse(created, @"Blob creation incorrectly returned.");

                AZSCloudPageBlob *newPageBlob = [self.blobContainer pageBlobReferenceFromName:@"pageBlob"];
                [newPageBlob existsWithCompletionHandler:^(NSError *error, BOOL existsResult) {
                    XCTAssertNil(error, @"Error in blob exists.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
                    XCTAssertTrue(existsResult, @"Blob does not exist when it should.");
                    XCTAssertEqualObjects(newPageBlob.properties.length, blobSize, @"Blob size not correctly returned.");
                
                    [semaphore signal];
                }];
            }];
        }];
    }];
    
    [semaphore wait];
}

-(void)testCreateWithSequenceNumber
{
    AZSTestSemaphore *semaphore = [[AZSTestSemaphore alloc] init];
    
    AZSCloudPageBlob *pageBlob = [self.blobContainer pageBlobReferenceFromName:@"pageBlob"];
    
    [pageBlob existsWithCompletionHandler:^(NSError *error, BOOL existsResult) {
        XCTAssertNil(error, @"Error in blob exists.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
        XCTAssertFalse(existsResult, @"Blob exists when it should not.");
        
        NSNumber *blobSize = [NSNumber numberWithInt:1000*512];
        [pageBlob createWithSize:blobSize sequenceNumber:[NSNumber numberWithInt:394] completionHandler:^(NSError *error) {
            XCTAssertNil(error, @"Error in blob creation.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
            XCTAssertEqual(394, pageBlob.properties.sequenceNumber.intValue, @"Incorrect sequence number returned.");
            XCTAssertEqualObjects(pageBlob.properties.length, blobSize, @"Blob size not correctly returned.");

            AZSCloudPageBlob *newPageBlob = [self.blobContainer pageBlobReferenceFromName:@"pageBlob"];
            [newPageBlob existsWithCompletionHandler:^(NSError *error, BOOL existsResult) {
                XCTAssertNil(error, @"Error in blob exists.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
                XCTAssertTrue(existsResult, @"Blob does not exist when it should.");
                XCTAssertEqualObjects(newPageBlob.properties.length, blobSize, @"Blob size not correctly returned.");
                XCTAssertEqual(394, newPageBlob.properties.sequenceNumber.intValue, @"Incorrect sequence number returned.");
                
                [semaphore signal];
            }];
        }];
    }];
    
    [semaphore wait];
}

-(void)uploadPageRangesToBlob:(AZSCloudPageBlob *)blob dataArrays:(NSArray *)dataArrays offsets:(NSArray *)offsets index:(int)index completionHandler:(void (^)(NSError *))completionHandler
{
    if (index < 0)
    {
        completionHandler(nil);
    }
    else
    {
        [blob uploadPagesWithData:dataArrays[index] startOffset:offsets[index] contentMD5:nil completionHandler:^(NSError *error) {
            if (error)
            {
                completionHandler(error);
            }
            else
            {
                [self uploadPageRangesToBlob:blob dataArrays:dataArrays offsets:offsets index:(index - 1) completionHandler:completionHandler];
            }
        }];
    }
}

// This creates random data in pages 3-6 and 9-10
-(void)createSamplePageDataWithDataArrays:(NSMutableArray *)dataArrays offsets:(NSMutableArray *)offsets
{
    unsigned int randSeed = (unsigned int)time(NULL);
    NSNumber *firstRangeOffset = [NSNumber numberWithUnsignedLongLong:3*self.pageSize];
    
    NSMutableData *firstRangeData = [AZSTestHelpers generateSampleDataWithSeed:&randSeed length:4*self.pageSize];
    [dataArrays addObject:firstRangeData];
    [offsets addObject:firstRangeOffset];
    
    NSNumber *secondRangeOffset = [NSNumber numberWithUnsignedLongLong:9*self.pageSize];
    NSMutableData *secondRangeData = [AZSTestHelpers generateSampleDataWithSeed:&randSeed length:2*self.pageSize];
    [dataArrays addObject:secondRangeData];
    [offsets addObject:secondRangeOffset];
}

-(void)testUploadPages
{
    AZSTestSemaphore *semaphore = [[AZSTestSemaphore alloc] init];
    
    NSNumber *totalBlobSize = [NSNumber numberWithInt:100*self.pageSize];
    
    NSMutableArray *dataArrays = [NSMutableArray arrayWithCapacity:2];
    NSMutableArray *offsets = [NSMutableArray arrayWithCapacity:2];
    
    [self createSamplePageDataWithDataArrays:dataArrays offsets:offsets];
    
    AZSCloudPageBlob *pageBlob = [self.blobContainer pageBlobReferenceFromName:@"pageBlob"];
    [pageBlob createWithSize:totalBlobSize completionHandler:^(NSError *error) {
        XCTAssertNil(error, @"Error in blob creation.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);

        [self uploadPageRangesToBlob:pageBlob dataArrays:dataArrays offsets:offsets index:1 completionHandler:^(NSError *error) {
            XCTAssertNil(error, @"Error in uploading pages.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
            [pageBlob downloadToDataWithCompletionHandler:^(NSError *error, NSData *blobData) {
                XCTAssertNil(error, @"Error in uploading pages.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
                
                int i = 0;
                const Byte* resultBytes = [blobData bytes];
                
                for (; i < ((NSNumber *)offsets[0]).unsignedLongLongValue; i++)
                {
                    XCTAssertEqual(0, resultBytes[i], @"Blob data does not match.");
                }
                
                const Byte* expectedFirstBytes = [((NSMutableData *)(dataArrays[0])) bytes];
                for (; i < ((NSNumber *)offsets[0]).unsignedLongLongValue + ((NSMutableData *)dataArrays[0]).length; i++)
                {
                    Byte expected = expectedFirstBytes[i - ((NSNumber *)offsets[0]).unsignedLongLongValue];
                    XCTAssertEqual(expected, resultBytes[i], @"Blob data does not match.");
                }
                
                for (; i < ((NSNumber *)offsets[1]).unsignedLongLongValue; i++)
                {
                    XCTAssertEqual(0, resultBytes[i], @"Blob data does not match.");
                }
                
                const Byte* expectedSecondBytes = [((NSMutableData *)(dataArrays[1])) bytes];
                for (; i < ((NSNumber *)offsets[1]).unsignedLongLongValue + ((NSMutableData *)dataArrays[1]).length; i++)
                {
                    Byte expected = expectedSecondBytes[i - ((NSNumber *)offsets[1]).unsignedLongLongValue];
                    XCTAssertEqual(expected, resultBytes[i], @"Blob data does not match.");
                }
                
                for (; i < totalBlobSize.unsignedLongLongValue; i++)
                {
                    XCTAssertEqual(0, resultBytes[i], @"Blob data does not match.");
                }
                
                [semaphore signal];
            }];
        }];
    }];
    [semaphore wait];
}

-(void)testClearPages
{
    AZSTestSemaphore *semaphore = [[AZSTestSemaphore alloc] init];
    
    NSNumber *totalBlobSize = [NSNumber numberWithInt:100*self.pageSize];
    
    NSMutableArray *dataArrays = [NSMutableArray arrayWithCapacity:2];
    NSMutableArray *offsets = [NSMutableArray arrayWithCapacity:2];
    
    [self createSamplePageDataWithDataArrays:dataArrays offsets:offsets];
    
    AZSCloudPageBlob *pageBlob = [self.blobContainer pageBlobReferenceFromName:@"pageBlob"];
    [pageBlob createWithSize:totalBlobSize completionHandler:^(NSError *error) {
        XCTAssertNil(error, @"Error in blob creation.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
        
        [self uploadPageRangesToBlob:pageBlob dataArrays:dataArrays offsets:offsets index:1 completionHandler:^(NSError *error) {
            XCTAssertNil(error, @"Error in uploading pages.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
            
            // Current pages with data are 3-6 and 9-10.  Try clearing 4-5.
            
            [pageBlob clearPagesWithRange:(NSMakeRange(4*self.pageSize, 2*self.pageSize)) completionHandler:^(NSError *error) {
                XCTAssertNil(error, @"Error in clearing pages.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
                
                [pageBlob downloadToDataWithCompletionHandler:^(NSError *error, NSData *blobData) {
                    XCTAssertNil(error, @"Error in uploading pages.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
                    
                    int i = 0;
                    const Byte* resultBytes = [blobData bytes];
                    
                    for (; i < ((NSNumber *)offsets[0]).unsignedLongLongValue; i++)
                    {
                        XCTAssertEqual(0, resultBytes[i], @"Blob data does not match.");
                    }
                    
                    const Byte* expectedFirstBytes = [((NSMutableData *)(dataArrays[0])) bytes];
                    for (; i < ((NSNumber *)offsets[0]).unsignedLongLongValue + self.pageSize; i++)
                    {
                        Byte expected = expectedFirstBytes[i - ((NSNumber *)offsets[0]).unsignedLongLongValue];
                        XCTAssertEqual(expected, resultBytes[i], @"Blob data does not match.");
                    }
                    
                    for (; i < ((NSNumber *)offsets[0]).unsignedLongLongValue + 3*self.pageSize; i++)
                    {
                        XCTAssertEqual(0, resultBytes[i], @"Blob data does not match.");
                    }

                    for (; i < ((NSNumber *)offsets[0]).unsignedLongLongValue + ((NSMutableData *)dataArrays[0]).length; i++)
                    {
                        Byte expected = expectedFirstBytes[i - ((NSNumber *)offsets[0]).unsignedLongLongValue];
                        XCTAssertEqual(expected, resultBytes[i], @"Blob data does not match.");
                    }

                    for (; i < ((NSNumber *)offsets[1]).unsignedLongLongValue; i++)
                    {
                        XCTAssertEqual(0, resultBytes[i], @"Blob data does not match.");
                    }
                    
                    const Byte* expectedSecondBytes = [((NSMutableData *)(dataArrays[1])) bytes];
                    for (; i < ((NSNumber *)offsets[1]).unsignedLongLongValue + ((NSMutableData *)dataArrays[1]).length; i++)
                    {
                        Byte expected = expectedSecondBytes[i - ((NSNumber *)offsets[1]).unsignedLongLongValue];
                        XCTAssertEqual(expected, resultBytes[i], @"Blob data does not match.");
                    }
                    
                    for (; i < totalBlobSize.unsignedLongLongValue; i++)
                    {
                        XCTAssertEqual(0, resultBytes[i], @"Blob data does not match.");
                    }
                    
                    [semaphore signal];
                }];
            }];
        }];
    }];
    [semaphore wait];
}

-(void)testDownloadPageRanges
{
    AZSTestSemaphore *semaphore = [[AZSTestSemaphore alloc] init];
    
    NSNumber *totalBlobSize = [NSNumber numberWithInt:100*self.pageSize];
    
    NSMutableArray *dataArrays = [NSMutableArray arrayWithCapacity:2];
    NSMutableArray *offsets = [NSMutableArray arrayWithCapacity:2];
    
    [self createSamplePageDataWithDataArrays:dataArrays offsets:offsets];
    
    AZSCloudPageBlob *pageBlob = [self.blobContainer pageBlobReferenceFromName:@"pageBlob"];
    [pageBlob createWithSize:totalBlobSize completionHandler:^(NSError *error) {
        XCTAssertNil(error, @"Error in blob creation.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
        
        [self uploadPageRangesToBlob:pageBlob dataArrays:dataArrays offsets:offsets index:1 completionHandler:^(NSError *error) {
            XCTAssertNil(error, @"Error in uploading pages.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
            
            [pageBlob clearPagesWithRange:(NSMakeRange(4*self.pageSize, 2*self.pageSize))  completionHandler:^(NSError *error) {
                XCTAssertNil(error, @"Error in clearing pages.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);

                [pageBlob downloadPageRangesWithCompletionHandler:^(NSError *error, NSArray *results) {
                    XCTAssertNil(error, @"Error in downloading page ranges.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
                
                    XCTAssertEqual(3, results.count, @"Incorrect number of page ranges downloaded.");
                
                    // Expected ranges are 3, 6, and 9-10
                    XCTAssertEqual(3*self.pageSize, (((NSValue *)results[0]).rangeValue).location, @"Incorrect page range returned.");
                    XCTAssertEqual(1*self.pageSize, (((NSValue *)results[0]).rangeValue).length, @"Incorrect page range returned.");

                    XCTAssertEqual(6*self.pageSize, (((NSValue *)results[1]).rangeValue).location, @"Incorrect page range returned.");
                    XCTAssertEqual(1*self.pageSize, (((NSValue *)results[1]).rangeValue).length, @"Incorrect page range returned.");

                    XCTAssertEqual(9*self.pageSize, (((NSValue *)results[2]).rangeValue).location, @"Incorrect page range returned.");
                    XCTAssertEqual(2*self.pageSize, (((NSValue *)results[2]).rangeValue).length, @"Incorrect page range returned.");
                
                    [pageBlob downloadPageRangesWithRange:(NSMakeRange(5*self.pageSize, 10*self.pageSize)) completionHandler:^(NSError *error, NSArray *results) {
                        XCTAssertNil(error, @"Error in downloading page ranges.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
                    
                        XCTAssertEqual(2, results.count, @"Incorrect number of page ranges downloaded.");

                        XCTAssertEqual(6*self.pageSize, (((NSValue *)results[0]).rangeValue).location, @"Incorrect page range returned.");
                        XCTAssertEqual(1*self.pageSize, (((NSValue *)results[0]).rangeValue).length, @"Incorrect page range returned.");
                    
                        XCTAssertEqual(9*self.pageSize, (((NSValue *)results[1]).rangeValue).location, @"Incorrect page range returned.");
                        XCTAssertEqual(2*self.pageSize, (((NSValue *)results[1]).rangeValue).length, @"Incorrect page range returned.");
                    
                        [semaphore signal];
                    }];
                }];
            }];
        }];
    }];
    [semaphore wait];
}

-(void)testResize
{
    AZSTestSemaphore *semaphore = [[AZSTestSemaphore alloc] init];
    
    NSNumber *totalBlobSize = [NSNumber numberWithInt:100*self.pageSize];
    
    NSMutableArray *dataArrays = [NSMutableArray arrayWithCapacity:2];
    NSMutableArray *offsets = [NSMutableArray arrayWithCapacity:2];
    
    [self createSamplePageDataWithDataArrays:dataArrays offsets:offsets];
    
    AZSCloudPageBlob *pageBlob = [self.blobContainer pageBlobReferenceFromName:@"pageBlob"];
    [pageBlob createWithSize:totalBlobSize completionHandler:^(NSError *error) {
        XCTAssertNil(error, @"Error in blob creation.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
        [pageBlob resizeWithSize:[NSNumber numberWithInt:1024] completionHandler:^(NSError *error) {
            XCTAssertNil(error, @"Error in blob resizing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
            XCTAssertEqual(1024, pageBlob.properties.length.intValue, @"Incorrect blob size fetched.");
            
            AZSCloudPageBlob *newPageBlob = [self.blobContainer pageBlobReferenceFromName:@"pageBlob"];
            
            [newPageBlob downloadAttributesWithCompletionHandler:^(NSError *error) {
                XCTAssertNil(error, @"Error in blob fetch attributes.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
                XCTAssertEqual(1024, newPageBlob.properties.length.intValue, @"Incorrect blob size fetched.");
                [semaphore signal];
            }];
        }];
    }];
    [semaphore wait];
}

-(void)testConditionalUpdateWithSequenceNumber
{
    AZSTestSemaphore *semaphore = [[AZSTestSemaphore alloc] init];
    
    NSNumber *totalBlobSize = [NSNumber numberWithInt:100*self.pageSize];
    
    NSMutableArray *dataArrays = [NSMutableArray arrayWithCapacity:2];
    NSMutableArray *offsets = [NSMutableArray arrayWithCapacity:2];
    
    [self createSamplePageDataWithDataArrays:dataArrays offsets:offsets];
    
    AZSCloudPageBlob *pageBlob = [self.blobContainer pageBlobReferenceFromName:@"pageBlob"];
    [pageBlob createWithSize:totalBlobSize sequenceNumber:[NSNumber numberWithInt:20] completionHandler:^(NSError *error) {
        XCTAssertNil(error, @"Error in blob creation.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
        
        [self uploadPageRangesToBlob:pageBlob dataArrays:dataArrays offsets:offsets index:1 completionHandler:^(NSError *error) {
            XCTAssertNil(error, @"Error in uploading pages.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
            
            unsigned int randSeed = (unsigned int)time(NULL);
            NSMutableData *sampleData = [AZSTestHelpers generateSampleDataWithSeed:&randSeed length:self.pageSize];

            [pageBlob uploadPagesWithData:sampleData startOffset:[NSNumber numberWithInt:11*self.pageSize] contentMD5:nil accessCondition:[[AZSAccessCondition alloc] initWithIfSequenceNumberLessThanOrEqualTo:[NSNumber numberWithUnsignedLongLong:(pageBlob.properties.sequenceNumber.unsignedLongLongValue + 5)]] requestOptions:nil operationContext:nil completionHandler:^(NSError *error) {
                XCTAssertNil(error, @"Error in uploading pages with accurate sequence number.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
                
                [pageBlob uploadPagesWithData:sampleData startOffset:[NSNumber numberWithInt:12*self.pageSize] contentMD5:nil accessCondition:[[AZSAccessCondition alloc] initWithIfSequenceNumberLessThanOrEqualTo:pageBlob.properties.sequenceNumber] requestOptions:nil operationContext:nil completionHandler:^(NSError *error) {
                    XCTAssertNil(error, @"Error in uploading pages with accurate sequence number.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);

                    [pageBlob uploadPagesWithData:sampleData startOffset:[NSNumber numberWithInt:13*self.pageSize] contentMD5:nil accessCondition:[[AZSAccessCondition alloc] initWithIfSequenceNumberLessThanOrEqualTo:[NSNumber numberWithUnsignedLongLong:(pageBlob.properties.sequenceNumber.unsignedLongLongValue - 5)]] requestOptions:nil operationContext:nil completionHandler:^(NSError *error) {
                        XCTAssertNotNil(error, @"No error returned when error expected with invalid sequence number in access condition.");
                        XCTAssertEqual(412, ((NSNumber *)error.userInfo[@"HTTP Status Code"]).intValue, @"Incorrect HTTP statuc code reported.");
                        
                        [pageBlob uploadPagesWithData:sampleData startOffset:[NSNumber numberWithInt:14*self.pageSize] contentMD5:nil accessCondition:[[AZSAccessCondition alloc] initWithIfSequenceNumberLessThan:[NSNumber numberWithUnsignedLongLong:(pageBlob.properties.sequenceNumber.unsignedLongLongValue + 5)]] requestOptions:nil operationContext:nil completionHandler:^(NSError *error) {
                            XCTAssertNil(error, @"Error in uploading pages with accurate sequence number.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);

                            [pageBlob uploadPagesWithData:sampleData startOffset:[NSNumber numberWithInt:15*self.pageSize] contentMD5:nil accessCondition:[[AZSAccessCondition alloc] initWithIfSequenceNumberLessThan:pageBlob.properties.sequenceNumber] requestOptions:nil operationContext:nil completionHandler:^(NSError *error) {
                                XCTAssertNotNil(error, @"No error returned when error expected with invalid sequence number in access condition.");
                                XCTAssertEqual(412, ((NSNumber *)error.userInfo[@"HTTP Status Code"]).intValue, @"Incorrect HTTP statuc code reported.");

                                [pageBlob uploadPagesWithData:sampleData startOffset:[NSNumber numberWithInt:16*self.pageSize] contentMD5:nil accessCondition:[[AZSAccessCondition alloc] initWithIfSequenceNumberLessThan:[NSNumber numberWithUnsignedLongLong:(pageBlob.properties.sequenceNumber.unsignedLongLongValue - 5)]] requestOptions:nil operationContext:nil completionHandler:^(NSError *error) {
                                    XCTAssertNotNil(error, @"No error returned when error expected with invalid sequence number in access condition.");
                                    XCTAssertEqual(412, ((NSNumber *)error.userInfo[@"HTTP Status Code"]).intValue, @"Incorrect HTTP statuc code reported.");

                                    [pageBlob uploadPagesWithData:sampleData startOffset:[NSNumber numberWithInt:17*self.pageSize] contentMD5:nil accessCondition:[[AZSAccessCondition alloc] initWithIfSequenceNumberEqualTo:[NSNumber numberWithUnsignedLongLong:(pageBlob.properties.sequenceNumber.unsignedLongLongValue + 5)]] requestOptions:nil operationContext:nil completionHandler:^(NSError *error) {
                                        XCTAssertNotNil(error, @"No error returned when error expected with invalid sequence number in access condition.");
                                        XCTAssertEqual(412, ((NSNumber *)error.userInfo[@"HTTP Status Code"]).intValue, @"Incorrect HTTP statuc code reported.");

                                        [pageBlob uploadPagesWithData:sampleData startOffset:[NSNumber numberWithInt:18*self.pageSize] contentMD5:nil accessCondition:[[AZSAccessCondition alloc] initWithIfSequenceNumberEqualTo:pageBlob.properties.sequenceNumber] requestOptions:nil operationContext:nil completionHandler:^(NSError *error) {
                                            XCTAssertNil(error, @"Error in uploading pages with accurate sequence number.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);

                                            [pageBlob uploadPagesWithData:sampleData startOffset:[NSNumber numberWithInt:19*self.pageSize] contentMD5:nil accessCondition:[[AZSAccessCondition alloc] initWithIfSequenceNumberEqualTo:[NSNumber numberWithUnsignedLongLong:(pageBlob.properties.sequenceNumber.unsignedLongLongValue - 5)]] requestOptions:nil operationContext:nil completionHandler:^(NSError *error) {
                                                XCTAssertNotNil(error, @"No error returned when error expected with invalid sequence number in access condition.");
                                                XCTAssertEqual(412, ((NSNumber *)error.userInfo[@"HTTP Status Code"]).intValue, @"Incorrect HTTP statuc code reported.");

                                                [semaphore signal];
                                            }];
                                        }];
                                    }];
                                }];
                            }];
                        }];
                    }];
                }];
            }];
        }];
    }];
    [semaphore wait];
}

-(void)testSetSequenceNumber
{
    AZSTestSemaphore *semaphore = [[AZSTestSemaphore alloc] init];
    
    NSNumber *totalBlobSize = [NSNumber numberWithInt:100*self.pageSize];
    
    NSMutableArray *dataArrays = [NSMutableArray arrayWithCapacity:2];
    NSMutableArray *offsets = [NSMutableArray arrayWithCapacity:2];
    
    [self createSamplePageDataWithDataArrays:dataArrays offsets:offsets];
    
    AZSCloudPageBlob *pageBlob = [self.blobContainer pageBlobReferenceFromName:@"pageBlob"];
    [pageBlob createWithSize:totalBlobSize completionHandler:^(NSError *error) {
        XCTAssertNil(error, @"Error in blob creation.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
        
        [self uploadPageRangesToBlob:pageBlob dataArrays:dataArrays offsets:offsets index:1 completionHandler:^(NSError *error) {
            XCTAssertNil(error, @"Error in uploading pages.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
            
            [pageBlob setSequenceNumberWithNumber:[NSNumber numberWithInt:1234] useMaximum:NO completionHandler:^(NSError *error) {
                XCTAssertNil(error, @"Error in setting sequence number.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
                XCTAssertEqual(1234, pageBlob.properties.sequenceNumber.intValue, @"Incorrect sequence number set.");
                
                AZSCloudPageBlob *newPageBlob = [self.blobContainer pageBlobReferenceFromName:@"pageBlob"];
                [newPageBlob downloadAttributesWithCompletionHandler:^(NSError *error) {
                    XCTAssertNil(error, @"Error in fetching attributes.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
                    XCTAssertEqual(1234, newPageBlob.properties.sequenceNumber.intValue, @"Incorrect sequence number set.");
                    
                    [pageBlob setSequenceNumberWithNumber:[NSNumber numberWithInt:1000] useMaximum:NO completionHandler:^(NSError *error) {
                        XCTAssertNil(error, @"Error in setting sequence number.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
                        XCTAssertEqual(1000, pageBlob.properties.sequenceNumber.intValue, @"Incorrect sequence number set.");

                        [newPageBlob downloadAttributesWithCompletionHandler:^(NSError *error) {
                            XCTAssertNil(error, @"Error in fetching attributes.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
                            XCTAssertEqual(1000, newPageBlob.properties.sequenceNumber.intValue, @"Incorrect sequence number set.");

                            [pageBlob setSequenceNumberWithNumber:[NSNumber numberWithInt:1234] useMaximum:YES completionHandler:^(NSError *error) {
                                XCTAssertNil(error, @"Error in setting sequence number.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
                                XCTAssertEqual(1234, pageBlob.properties.sequenceNumber.intValue, @"Incorrect sequence number set.");
                                
                                AZSCloudPageBlob *newPageBlob = [self.blobContainer pageBlobReferenceFromName:@"pageBlob"];
                                [newPageBlob downloadAttributesWithCompletionHandler:^(NSError *error) {
                                    XCTAssertNil(error, @"Error in fetching attributes.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
                                    XCTAssertEqual(1234, newPageBlob.properties.sequenceNumber.intValue, @"Incorrect sequence number set.");
                                    
                                    [pageBlob setSequenceNumberWithNumber:[NSNumber numberWithInt:1000] useMaximum:YES completionHandler:^(NSError *error) {
                                        XCTAssertNil(error, @"Error in setting sequence number.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
                                        XCTAssertEqual(1234, pageBlob.properties.sequenceNumber.intValue, @"Incorrect sequence number set.");
                                        
                                        [newPageBlob downloadAttributesWithCompletionHandler:^(NSError *error) {
                                            XCTAssertNil(error, @"Error in fetching attributes.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
                                            XCTAssertEqual(1234, newPageBlob.properties.sequenceNumber.intValue, @"Incorrect sequence number set.");

                                            [semaphore signal];
                                        }];
                                    }];
                                }];
                            }];
                        }];
                    }];
                }];
            }];
        }];
    }];
    
    [semaphore wait];
}

-(void)testIncrementSequenceNumber
{
    AZSTestSemaphore *semaphore = [[AZSTestSemaphore alloc] init];
    
    NSNumber *totalBlobSize = [NSNumber numberWithInt:100*self.pageSize];
    
    NSMutableArray *dataArrays = [NSMutableArray arrayWithCapacity:2];
    NSMutableArray *offsets = [NSMutableArray arrayWithCapacity:2];
    
    [self createSamplePageDataWithDataArrays:dataArrays offsets:offsets];
    
    AZSCloudPageBlob *pageBlob = [self.blobContainer pageBlobReferenceFromName:@"pageBlob"];
    [pageBlob createWithSize:totalBlobSize sequenceNumber:[NSNumber numberWithInt:1234] completionHandler:^(NSError *error) {
        XCTAssertNil(error, @"Error in blob creation.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
        
        [self uploadPageRangesToBlob:pageBlob dataArrays:dataArrays offsets:offsets index:1 completionHandler:^(NSError *error) {
            XCTAssertNil(error, @"Error in uploading pages.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
            
            [pageBlob incrementSequenceNumberWithCompletionHandler:^(NSError *error) {
                XCTAssertNil(error, @"Error in fetching attributes.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
                XCTAssertEqual(1235, pageBlob.properties.sequenceNumber.intValue, @"Incorrect sequence number set.");
                
                AZSCloudPageBlob *newPageBlob = [self.blobContainer pageBlobReferenceFromName:@"pageBlob"];
                [newPageBlob downloadAttributesWithCompletionHandler:^(NSError *error) {
                    XCTAssertNil(error, @"Error in fetching attributes.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
                    XCTAssertEqual(1235, newPageBlob.properties.sequenceNumber.intValue, @"Incorrect sequence number set.");
                    
                    [semaphore signal];
                }];
            }];
        }];
    }];

    [semaphore wait];
}

-(void)testContentMD5
{
    // Check that: if we provide a correct Content-MD5, we're good.  If we provide a bad one, we fail.  If we don't provide but require, the library will calc for us.  If we don't provide and don't require, the library will not.
    AZSTestSemaphore *semaphore = [[AZSTestSemaphore alloc] init];
    
    NSNumber *totalBlobSize = [NSNumber numberWithInt:100*self.pageSize];

    unsigned int randSeed = (unsigned int)time(NULL);
    NSMutableData *sampleData = [AZSTestHelpers generateSampleDataWithSeed:&randSeed length:self.pageSize];
    
    NSString *contentMD5 = [AZSUtil calculateMD5FromData:sampleData];
    NSString *badContentMD5 = @"Sgb7ewkGDTH0lshZ0Kwh/w==";  // This should be syntactically valid, but it's for a random input data.
    
    AZSCloudPageBlob *pageBlob = [self.blobContainer pageBlobReferenceFromName:@"pageBlob"];
    [pageBlob createWithSize:totalBlobSize completionHandler:^(NSError *error) {
        XCTAssertNil(error, @"Error in blob creation.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
        
        [pageBlob uploadPagesWithData:sampleData startOffset:[NSNumber numberWithInt:0] contentMD5:contentMD5 completionHandler:^(NSError *error) {
            XCTAssertNil(error, @"Error in uploading pages with correct Content-MD5.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
            [pageBlob uploadPagesWithData:sampleData startOffset:[NSNumber numberWithInt:0] contentMD5:badContentMD5 completionHandler:^(NSError *error) {
                XCTAssertNotNil(error, @"No error given when expected with a bad Content-MD5.");
                XCTAssertEqual(400, ((NSNumber *)error.userInfo[@"HTTP Status Code"]).intValue, @"Incorrect HTTP status code.");
                
                __block BOOL sendingRequestCalled = NO;
                
                AZSOperationContext *opContext = [[AZSOperationContext alloc] init];
                opContext.sendingRequest = ^(NSMutableURLRequest *request, AZSOperationContext *sendingOpContext) {
                    sendingRequestCalled = YES;
                    XCTAssertEqualObjects(contentMD5, request.allHTTPHeaderFields[@"Content-MD5"], @"Invalid Content-MD5 generated.");
                };
            
                AZSBlobRequestOptions *options = [[AZSBlobRequestOptions alloc] init];
                [options setUseTransactionalMD5:YES];
                
                [pageBlob uploadPagesWithData:sampleData startOffset:[NSNumber numberWithInt:0] contentMD5:nil accessCondition:nil requestOptions:options operationContext:opContext completionHandler:^(NSError *error) {
                    XCTAssertNil(error, @"Error in uploading pages with correct Content-MD5.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
                    XCTAssertTrue(sendingRequestCalled, @"Validation on Content-MD5 not performed.");

                    sendingRequestCalled = NO;
                    opContext.sendingRequest = ^(NSMutableURLRequest *request, AZSOperationContext *sendingOpContext) {
                        sendingRequestCalled = YES;
                        XCTAssertNil(request.allHTTPHeaderFields[@"Content-MD5"], @"Content-MD5 should not have been generated.");
                    };
                    
                    [options setUseTransactionalMD5:NO];
                    
                    [pageBlob uploadPagesWithData:sampleData startOffset:[NSNumber numberWithInt:0] contentMD5:nil accessCondition:nil requestOptions:options operationContext:opContext completionHandler:^(NSError *error) {
                        XCTAssertNil(error, @"Error in uploading pages with no Content-MD5.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
                        XCTAssertTrue(sendingRequestCalled, @"Validation on Content-MD5 not performed.");

                        [semaphore signal];
                    }];
                }];
            }];
        }];
    }];

    [semaphore wait];
}

@end
