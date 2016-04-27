// -----------------------------------------------------------------------------------------
// <copyright file="AZSCloudAppendBlobTests.m" company="Microsoft">
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
#import "AZSClient.h"
#import "AZSTestHelpers.h"
#import "AZSTestSemaphore.h"
#import "AZSUtil.h"

@interface AZSCloudAppendBlobTests : AZSBlobTestBase
@property NSString *containerName;
@property AZSCloudBlobContainer *blobContainer;
@end

@implementation AZSCloudAppendBlobTests

- (void)setUp
{
    [super setUp];
    self.containerName = [[NSString stringWithFormat:@"sampleioscontainer%@",[[[NSUUID UUID] UUIDString] stringByReplacingOccurrencesOfString:@"-" withString:@""]] lowercaseString];
    self.blobContainer = [self.blobClient containerReferenceFromName:self.containerName];
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
    
    AZSCloudAppendBlob *appendBlob = [self.blobContainer appendBlobReferenceFromName:@"appendBlob"];
    
    [appendBlob existsWithCompletionHandler:^(NSError *error, BOOL exists) {
        XCTAssertNil(error, @"Error in blob exists.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
        XCTAssertFalse(exists, @"Blob exists when it shouldn't.");
        [appendBlob createWithCompletionHandler:^(NSError *error) {
            XCTAssertNil(error, @"Error in blob creation.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
            
            [appendBlob existsWithCompletionHandler:^(NSError *error, BOOL exists) {
                XCTAssertNil(error, @"Error in blob exists.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
                XCTAssertTrue(exists, @"Blob doesn't exist when it should.");
                [semaphore signal];
            }];
        }];
    }];
    [semaphore wait];
}

-(void)testCreateIfNotExists
{
    AZSTestSemaphore *semaphore = [[AZSTestSemaphore alloc] init];
    
    AZSCloudAppendBlob *appendBlob = [self.blobContainer appendBlobReferenceFromName:@"appendBlob"];
    
    [appendBlob existsWithCompletionHandler:^(NSError *error, BOOL exists) {
        XCTAssertNil(error, @"Error in blob exists.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
        XCTAssertFalse(exists, @"Blob exists when it shouldn't.");
        [appendBlob createIfNotExistsWithCompletionHandler:^(NSError *error, BOOL created) {
            XCTAssertNil(error, @"Error in blob creation.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
            XCTAssertTrue(created, @"Blob creation incorrectly returned.");
            
            [appendBlob createIfNotExistsWithCompletionHandler:^(NSError *error, BOOL created) {
                XCTAssertNil(error, @"Error in blob creation.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
                XCTAssertFalse(created, @"Blob creation incorrectly returned.");

                [appendBlob existsWithCompletionHandler:^(NSError *error, BOOL exists) {
                    XCTAssertNil(error, @"Error in blob exists.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
                    XCTAssertTrue(exists, @"Blob doesn't exist when it should.");
                    [semaphore signal];
                }];
            }];
        }];
    }];
    [semaphore wait];
}

-(void)testAppendBlock
{
    AZSTestSemaphore *semaphore = [[AZSTestSemaphore alloc] init];
    
    AZSCloudAppendBlob *appendBlob = [self.blobContainer appendBlobReferenceFromName:@"appendBlob"];
    
    [appendBlob createWithCompletionHandler:^(NSError *error) {
        XCTAssertNil(error, @"Error in blob creation.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
        
        unsigned int randSeed = (unsigned int)time(NULL);
        NSMutableArray *sampleDataArray = [NSMutableArray arrayWithCapacity:3];
        [sampleDataArray addObject:[AZSTestHelpers generateSampleDataWithSeed:&randSeed length:1000]];
        [sampleDataArray addObject:[AZSTestHelpers generateSampleDataWithSeed:&randSeed length:1000]];
        [sampleDataArray addObject:[AZSTestHelpers generateSampleDataWithSeed:&randSeed length:1000]];
        
        [appendBlob appendBlockWithData:sampleDataArray[0] contentMD5:nil completionHandler:^(NSError *error, NSNumber *appendOffset) {
            XCTAssertNil(error, @"Error in appending block.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
            XCTAssertEqual(0, appendOffset.intValue, @"Incorrect append offset returned.");
            [appendBlob appendBlockWithData:sampleDataArray[1] contentMD5:nil completionHandler:^(NSError *error, NSNumber *appendOffset) {
                XCTAssertNil(error, @"Error in appending block.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
                XCTAssertEqual(1000, appendOffset.intValue, @"Incorrect append offset returned.");
                [appendBlob appendBlockWithData:sampleDataArray[2] contentMD5:nil completionHandler:^(NSError *error, NSNumber *appendOffset) {
                    XCTAssertNil(error, @"Error in appending block.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
                    XCTAssertEqual(2000, appendOffset.intValue, @"Incorrect append offset returned.");

                    [appendBlob downloadToDataWithCompletionHandler:^(NSError *error, NSData *blobData) {
                        XCTAssertNil(error, @"Error in downloading blob data.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
                        XCTAssertEqual(3000, appendBlob.properties.length.intValue, @"Incorrect blob length reported.");
                        XCTAssertEqual(3, appendBlob.properties.appendBlobCommittedBlockCount.intValue, @"Incorrect block count reported.");
                        
                        int i = 0;
                        const Byte* resultBytes = [blobData bytes];
                        
                        const Byte* expectedFirstBytes = [((NSMutableData *)(sampleDataArray[0])) bytes];
                        for (; i < 1000; i++)
                        {
                            XCTAssertEqual(expectedFirstBytes[i], resultBytes[i], @"Blob data does not match.");
                        }
                        
                        const Byte* expectedSecondBytes = [((NSMutableData *)(sampleDataArray[1])) bytes];
                        for (; i < 1000; i++)
                        {
                            XCTAssertEqual(expectedSecondBytes[i - 1000], resultBytes[i], @"Blob data does not match.");
                        }
                        
                        const Byte* expectedThirdBytes = [((NSMutableData *)(sampleDataArray[2])) bytes];
                        for (; i < 1000; i++)
                        {
                            XCTAssertEqual(expectedThirdBytes[i - 2000], resultBytes[i], @"Blob data does not match.");
                        }
                        
                        [semaphore signal];
                    }];
                }];
            }];
        }];
    }];
    [semaphore wait];
}

-(void)testAppendBlockAccessConditions
{
    AZSTestSemaphore *semaphore = [[AZSTestSemaphore alloc] init];
    
    AZSCloudAppendBlob *appendBlob = [self.blobContainer appendBlobReferenceFromName:@"appendBlob"];
    
    [appendBlob createWithCompletionHandler:^(NSError *error) {
        XCTAssertNil(error, @"Error in blob creation.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
        
        unsigned int randSeed = (unsigned int)time(NULL);
        NSMutableData *sampleData = [AZSTestHelpers generateSampleDataWithSeed:&randSeed length:1000];
        // Generate some sample data to give the blob a non-zero append position.
        [appendBlob appendBlockWithData:sampleData contentMD5:nil completionHandler:^(NSError *error, NSNumber *appendOffset) {
            XCTAssertNil(error, @"Error in appending block.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
            XCTAssertEqual(0, appendOffset.intValue, @"Incorrect append offset returned.");
            
            [appendBlob appendBlockWithData:sampleData contentMD5:nil accessCondition:[[AZSAccessCondition alloc] initWithIfMaxSizeLessThanOrEqualTo:[NSNumber numberWithInt:(appendBlob.properties.length.intValue + 999)]] requestOptions:nil operationContext:nil completionHandler:^(NSError *error, NSNumber *appendOffset) {
                XCTAssertNotNil(error, @"No error given with bad access condition.");
                [appendBlob appendBlockWithData:sampleData contentMD5:nil accessCondition:[[AZSAccessCondition alloc] initWithIfMaxSizeLessThanOrEqualTo:[NSNumber numberWithInt:(appendBlob.properties.length.intValue + 1000)]] requestOptions:nil operationContext:nil completionHandler:^(NSError *error, NSNumber *appendOffset) {
                    XCTAssertNil(error, @"Error in appending block.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
                    XCTAssertEqual(1000, appendOffset.intValue, @"Incorrect append offset returned.");
                    [appendBlob appendBlockWithData:sampleData contentMD5:nil accessCondition:[[AZSAccessCondition alloc] initWithIfMaxSizeLessThanOrEqualTo:[NSNumber numberWithInt:(appendBlob.properties.length.intValue + 1001)]] requestOptions:nil operationContext:nil completionHandler:^(NSError *error, NSNumber *appendOffset) {
                        XCTAssertNil(error, @"Error in appending block.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
                        XCTAssertEqual(2000, appendOffset.intValue, @"Incorrect append offset returned.");
                        [appendBlob appendBlockWithData:sampleData contentMD5:nil accessCondition:[[AZSAccessCondition alloc] initWithIfAppendPositionEqualTo:[NSNumber numberWithInt:3000]] requestOptions:nil operationContext:nil completionHandler:^(NSError *error, NSNumber *appendOffset) {
                            XCTAssertNil(error, @"Error in appending block.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
                            XCTAssertEqual(3000, appendOffset.intValue, @"Incorrect append offset returned.");
                            [appendBlob appendBlockWithData:sampleData contentMD5:nil accessCondition:[[AZSAccessCondition alloc] initWithIfAppendPositionEqualTo:[NSNumber numberWithInt:3999]] requestOptions:nil operationContext:nil completionHandler:^(NSError *error, NSNumber *appendOffset) {
                                XCTAssertNotNil(error, @"No error given with bad access condition.");
                                [appendBlob appendBlockWithData:sampleData contentMD5:nil accessCondition:[[AZSAccessCondition alloc] initWithIfAppendPositionEqualTo:[NSNumber numberWithInt:4001]] requestOptions:nil operationContext:nil completionHandler:^(NSError *error, NSNumber *appendOffset) {
                                    XCTAssertNotNil(error, @"No error given with bad access condition.");
                                    [semaphore signal];
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

-(void)testContentMD5
{
    // Check that: if we provide a correct Content-MD5, we're good.  If we provide a bad one, we fail.  If we don't provide but require, the library will calc for us.  If we don't provide and don't require, the library will not.
    AZSTestSemaphore *semaphore = [[AZSTestSemaphore alloc] init];
    
    unsigned int randSeed = (unsigned int)time(NULL);
    NSMutableData *sampleData = [AZSTestHelpers generateSampleDataWithSeed:&randSeed length:1000];
    
    NSString *contentMD5 = [AZSUtil calculateMD5FromData:sampleData];
    NSString *badContentMD5 = @"Sgb7ewkGDTH0lshZ0Kwh/w==";  // This should be syntactically valid, but it's for a random input data.
    
    AZSCloudAppendBlob *appendBlob = [self.blobContainer appendBlobReferenceFromName:@"appendBlob"];
    [appendBlob createWithCompletionHandler:^(NSError *error) {
        XCTAssertNil(error, @"Error in blob creation.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
        
        [appendBlob appendBlockWithData:sampleData contentMD5:contentMD5 completionHandler:^(NSError *error, NSNumber *appendOffset) {
            XCTAssertNil(error, @"Error in appending block with correct Content-MD5.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
            [appendBlob appendBlockWithData:sampleData contentMD5:badContentMD5 completionHandler:^(NSError *error, NSNumber *appendOffset) {
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
                
                [appendBlob appendBlockWithData:sampleData contentMD5:nil accessCondition:nil requestOptions:options operationContext:opContext completionHandler:^(NSError *error, NSNumber *appendOffset) {
                    XCTAssertNil(error, @"Error in appending block with correct Content-MD5.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
                    XCTAssertTrue(sendingRequestCalled, @"Validation on Content-MD5 not performed.");
                    
                    sendingRequestCalled = NO;
                    opContext.sendingRequest = ^(NSMutableURLRequest *request, AZSOperationContext *sendingOpContext) {
                        sendingRequestCalled = YES;
                        XCTAssertNil(request.allHTTPHeaderFields[@"Content-MD5"], @"Content-MD5 should not have been generated.");
                    };
                    
                    [options setUseTransactionalMD5:NO];
                    
                    [appendBlob appendBlockWithData:sampleData contentMD5:nil accessCondition:nil requestOptions:options operationContext:opContext completionHandler:^(NSError *error, NSNumber *appendOffset) {
                        XCTAssertNil(error, @"Error in appending block with no Content-MD5.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
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
