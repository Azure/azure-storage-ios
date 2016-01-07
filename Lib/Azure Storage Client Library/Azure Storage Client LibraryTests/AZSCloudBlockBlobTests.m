// -----------------------------------------------------------------------------------------
// <copyright file="AZSCloudBlockBlobTests.m" company="Microsoft">
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
#import <CommonCrypto/CommonDigest.h>
#import "Azure_Storage_Client_Library.h"
#import "AZSBlobTestBase.h"
#import "AZSConstants.h"
#import "AZSTestHelpers.h"
#import "AZSTestSemaphore.h"

@interface AZSCloudBlockBlobTests : AZSBlobTestBase
@property NSString *containerName;
@property AZSCloudBlobContainer *blobContainer;
@end

@implementation AZSCloudBlockBlobTests

- (void)setUp
{
    [super setUp];
    AZSTestSemaphore *semaphore = [[AZSTestSemaphore alloc] init];
    self.containerName = [NSString stringWithFormat:@"sampleioscontainer%@", [AZSTestHelpers uniqueName]];
    
    self.blobContainer = [self.blobClient containerReferenceFromName:self.containerName];
    [self.blobContainer createContainerIfNotExistsWithCompletionHandler:^(NSError *error, BOOL exists) {
        XCTAssertNil(error, @"Error in test setup, in creating container.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
        [semaphore signal];
    }];
    [semaphore wait];
    
    // Put setup code here; it will be run once, before the first test case.
}

- (void)tearDown
{
    // Put teardown code here; it will be run once, after the last test case.
    AZSTestSemaphore *semaphore = [[AZSTestSemaphore alloc] init];

    AZSCloudBlobContainer *blobContainer = [self.blobClient containerReferenceFromName:self.containerName];
    [blobContainer deleteContainerIfExistsWithCompletionHandler:^(NSError * error, BOOL exists) {
        [semaphore signal];
    }];
    [semaphore wait];
    [super tearDown];
}

-(NSString *)generateRandomBlockID
{
    return [[[NSString stringWithFormat:@"blockid%@", [AZSTestHelpers uniqueName]] dataUsingEncoding:NSUTF8StringEncoding] base64EncodedStringWithOptions:0];
}

- (void)testUploadDownload
{
    // Test uploading a blob in one shot (put blob / UploadFromData) and downloading to a stream.
    AZSTestSemaphore *semaphore = [[AZSTestSemaphore alloc] init];
    
    NSString *blobName = [NSString stringWithFormat:@"sampleblob%@", [AZSTestHelpers uniqueName]];
    NSString *blobText = @"sampleBlobText";
    
    AZSCloudBlockBlob *blockBlob = [self.blobContainer blockBlobReferenceFromName:blobName];
    [blockBlob uploadFromData:[blobText dataUsingEncoding:NSUTF8StringEncoding] accessCondition:nil requestOptions:nil operationContext:nil completionHandler:^(NSError * error) {
        XCTAssertNil(error, @"Error in uploading blob.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
        
        NSOutputStream *targetStream = [NSOutputStream outputStreamToMemory];
        [targetStream open];
        
        [blockBlob downloadToStream:targetStream accessCondition:nil requestOptions:nil operationContext:nil completionHandler:^(NSError * error) {
            XCTAssertNil(error, @"Error in downloading blob.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
            
            NSString *endingBlobText = [[NSString alloc] initWithData:[targetStream propertyForKey:NSStreamDataWrittenToMemoryStreamKey] encoding:NSUTF8StringEncoding];
            
            XCTAssertTrue([blobText isEqualToString:endingBlobText], @"String text does not match");
            
            [blockBlob deleteWithSnapshotsOption:AZSDeleteSnapshotsOptionNone accessCondition:nil requestOptions:nil operationContext:nil completionHandler:^(NSError * error) {
                XCTAssertNil(error, @"Error in deleting blob.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
                
                [semaphore signal];
            }];
        }];
    }];
    [semaphore wait];
}

- (void)testUploadDownloadNonASCII
{
    // Test uploading a blob in one shot (put blob / UploadFromData) and downloading to a stream.
    AZSTestSemaphore *semaphore = [[AZSTestSemaphore alloc] init];
    
    NSString *blobName = [NSString stringWithFormat:@"sampleblob%@\u03b2%%@", [AZSTestHelpers uniqueName]];
    NSString *blobText = @"sampleBlobText";
    
    AZSCloudBlockBlob *blockBlob = [self.blobContainer blockBlobReferenceFromName:blobName];
    [blockBlob uploadFromData:[blobText dataUsingEncoding:NSUTF8StringEncoding] accessCondition:nil requestOptions:nil operationContext:nil completionHandler:^(NSError * error) {
        XCTAssertNil(error, @"Error in uploading blob.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
        
        NSOutputStream *targetStream = [NSOutputStream outputStreamToMemory];
        [targetStream open];
        
        [blockBlob downloadToStream:targetStream accessCondition:nil requestOptions:nil operationContext:nil completionHandler:^(NSError * error) {
            XCTAssertNil(error, @"Error in downloading blob.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
            
            NSString *endingBlobText = [[NSString alloc] initWithData:[targetStream propertyForKey:NSStreamDataWrittenToMemoryStreamKey] encoding:NSUTF8StringEncoding];
            
            XCTAssertTrue([blobText isEqualToString:endingBlobText], @"String text does not match");
            
            [blockBlob deleteWithSnapshotsOption:AZSDeleteSnapshotsOptionNone accessCondition:nil requestOptions:nil operationContext:nil completionHandler:^(NSError * error) {
                XCTAssertNil(error, @"Error in deleting blob.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
                
                [semaphore signal];
            }];
        }];
    }];
    [semaphore wait];
}

-(void)testBlobError
{
    AZSTestSemaphore *semaphore = [[AZSTestSemaphore alloc] init];
    NSString *blobName = [NSString stringWithFormat:@"sampleblob%@", [AZSTestHelpers uniqueName]];
    AZSCloudBlockBlob *blockBlob = [self.blobContainer blockBlobReferenceFromName:blobName];

    NSOutputStream *targetStream = [NSOutputStream outputStreamToMemory];
    [targetStream open];
    
    [blockBlob downloadToStream:targetStream accessCondition:nil requestOptions:nil operationContext:nil completionHandler:^(NSError * error) {
        XCTAssertNotNil(error, @"No error in downloading non-existant blob.");
        [semaphore signal];
    }];
    [semaphore wait];
}

// Note that this removes the blocks from the list.
-(void)uploadAllBlocksToBlob:(AZSCloudBlockBlob *)blob blockIDs:(NSMutableArray *)blockIDs blockDataArray:(NSMutableArray *)blockDataArray completionHandler:(void (^)(NSError *))completionHandler
{
    if ([blockIDs count] <= 0)
    {
        completionHandler(nil);
    }
    else
    {
        NSString *blockID = [blockIDs lastObject];
        [blockIDs removeLastObject];
        NSData *blockData = [blockDataArray lastObject];
        [blockDataArray removeLastObject];
        
        [blob uploadBlockFromData:blockData blockID:blockID contentMD5:nil accessCondition:nil requestOptions:nil operationContext:nil completionHandler:^(NSError * error) {
            if (error)
            {
                completionHandler(error);
            }
            else
            {
                [self uploadAllBlocksToBlob:blob blockIDs:blockIDs blockDataArray:blockDataArray completionHandler:completionHandler];
            }
        }];
    }
}

- (void)validateGetBlockListOperationsWithExpectedBlockList:(NSArray *)expectedBlockList blockBlob:(AZSCloudBlockBlob *)blockBlob completionHandler:(void (^)(NSError *))completionHandler
{
    [blockBlob downloadBlockListFromFilter:AZSBlockListFilterAll accessCondition:nil requestOptions:nil operationContext:nil completionHandler:^(NSError * error, NSArray * actual) {
        if (error)
        {
            completionHandler(error);
        }
        else
        {
            int expectedIndex = 0;
            int actualIndex = 0;
            while (expectedIndex < expectedBlockList.count)
            {
                AZSBlockListItem *currentExpectedItem = expectedBlockList[expectedIndex];
                AZSBlockListItem *currentActualItem = actual[actualIndex];
                
                XCTAssertTrue([currentExpectedItem.blockID isEqualToString:currentActualItem.blockID], @"Block IDs do not match.");
                XCTAssertTrue(currentExpectedItem.blockListMode == currentActualItem.blockListMode, @"BlockListMode does not match.");
                XCTAssertTrue(currentExpectedItem.size == currentActualItem.size, @"size does not match.");
                actualIndex++;
                expectedIndex++;
            }
            
            XCTAssertTrue(actualIndex == actual.count, @"Incorrect number of blocks found.");
            
            [blockBlob downloadBlockListFromFilter:AZSBlockListFilterCommitted accessCondition:nil requestOptions:nil operationContext:nil completionHandler:^(NSError * error, NSArray * actual) {
                if (error)
                {
                    completionHandler(error);
                }
                else
                {
                    int expectedIndex = 0;
                    int actualIndex = 0;
                    while (expectedIndex < expectedBlockList.count)
                    {
                        AZSBlockListItem *currentExpectedItem = expectedBlockList[expectedIndex];
                        if (currentExpectedItem.blockListMode == AZSBlockListModeCommitted)
                        {
                            AZSBlockListItem *currentActualItem = actual[actualIndex];
                            XCTAssertTrue([currentExpectedItem.blockID isEqualToString:currentActualItem.blockID], @"Block IDs do not match.");
                            XCTAssertTrue(currentExpectedItem.blockListMode == currentActualItem.blockListMode, @"BlockListMode does not match.");
                            XCTAssertTrue(currentExpectedItem.size == currentActualItem.size, @"size does not match.");
                            actualIndex++;
                        }
                        expectedIndex++;
                    }
                    XCTAssertTrue(actualIndex == actual.count, @"Incorrect number of blocks found.");
                    
                    [blockBlob downloadBlockListFromFilter:AZSBlockListFilterUncommitted accessCondition:nil requestOptions:nil operationContext:nil completionHandler:^(NSError * error, NSArray * actual) {
                        if (error)
                        {
                            completionHandler(error);
                        }
                        else
                        {
                            XCTAssertNil(error, @"Error in downloading blocklist.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
                            int expectedIndex = 0;
                            int actualIndex = 0;
                            while (expectedIndex < expectedBlockList.count)
                            {
                                AZSBlockListItem *currentExpectedItem = expectedBlockList[expectedIndex];
                                if (currentExpectedItem.blockListMode == AZSBlockListModeUncommitted)
                                {
                                    AZSBlockListItem *currentActualItem = actual[actualIndex];
                                    XCTAssertTrue([currentExpectedItem.blockID isEqualToString:currentActualItem.blockID], @"Block IDs do not match.");
                                    XCTAssertTrue(currentExpectedItem.blockListMode == currentActualItem.blockListMode, @"BlockListMode does not match.");
                                    XCTAssertTrue(currentExpectedItem.size == currentActualItem.size, @"size does not match.");
                                    actualIndex++;
                                }
                                expectedIndex++;
                            }
                            XCTAssertTrue(actualIndex == actual.count, @"Incorrect number of blocks found.");
                            
                            completionHandler(nil);
                        }
                    }];
                }
            }];
        }
    }];
}


- (void)testBlocksBlockList
{
    // Test uploading a blob in blocks and calling put block list.
    // Test various block IDs, committed vs uncommitted, etc.
    // Test block list download, with various AZSBlockListFilter.
    // Download and validate actual data.
    
    AZSTestSemaphore *semaphore = [[AZSTestSemaphore alloc] init];
    
    NSString *blobName = [NSString stringWithFormat:@"sampleblob%@", [AZSTestHelpers uniqueName]];
    NSString *blockIDPrefix = @"blockIDPrefix";
    NSString *blockDataPrefix = @"blockDataPrefix";
    
    NSMutableArray __block *blockIDs = [NSMutableArray arrayWithCapacity:5];
    NSMutableArray __block *blockDataArray = [NSMutableArray arrayWithCapacity:5];
    NSMutableArray __block *blockArray = [NSMutableArray arrayWithCapacity:5];
    
    // Add five blocks, numbered 0-4.
    for (int i = 0; i < 5; i++)
    {
        NSString *blockID = [[[blockIDPrefix stringByAppendingFormat:@"%d", i] dataUsingEncoding:NSUTF8StringEncoding] base64EncodedStringWithOptions:0];
        NSData *blockData = [[blockDataPrefix stringByAppendingFormat:@"%d", i] dataUsingEncoding:NSUTF8StringEncoding];
        [blockIDs addObject:blockID];
        [blockArray addObject:[[AZSBlockListItem alloc] initWithBlockID:blockID blockListMode:AZSBlockListModeLatest size:blockData.length]];
        [blockDataArray addObject:blockData];
    }
    
    AZSCloudBlockBlob *blockBlob = [self.blobContainer blockBlobReferenceFromName:blobName];
    [self uploadAllBlocksToBlob:blockBlob blockIDs:blockIDs blockDataArray:blockDataArray completionHandler:^(NSError * error) {
        XCTAssertNil(error, @"Error in uploading blocks.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
        
        [blockBlob uploadBlockListFromArray:blockArray accessCondition:nil requestOptions:nil operationContext:nil completionHandler:^(NSError * error) {
            XCTAssertNil(error, @"Error in uploading block list.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
            
            for (AZSBlockListItem *blockListItem in blockArray)
            {
                blockListItem.blockListMode = AZSBlockListModeCommitted;
            }
            
            // Check that the downloaded block list is correct.
            [self validateGetBlockListOperationsWithExpectedBlockList:blockArray blockBlob:blockBlob completionHandler:^(NSError * error) {
                XCTAssertNil(error, @"Error in downloading block list.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
                blockIDs = [NSMutableArray arrayWithCapacity:5];
                blockDataArray = [NSMutableArray arrayWithCapacity:5];
                
                NSString *blockIDtwo = [[[blockIDPrefix stringByAppendingFormat:@"%d", 2] dataUsingEncoding:NSUTF8StringEncoding] base64EncodedStringWithOptions:0];
                NSData *blockDatatwo = [[blockDataPrefix stringByAppendingFormat:@"%@", @"two"] dataUsingEncoding:NSUTF8StringEncoding];
                [blockIDs addObject:blockIDtwo];
                [blockArray addObject:[[AZSBlockListItem alloc] initWithBlockID:blockIDtwo blockListMode:AZSBlockListModeUncommitted size:blockDatatwo.length]];
                [blockDataArray addObject:blockDatatwo];
                
                NSString *blockIDthree = [[[blockIDPrefix stringByAppendingFormat:@"%d", 3] dataUsingEncoding:NSUTF8StringEncoding] base64EncodedStringWithOptions:0];
                NSData *blockDatathree = [[blockDataPrefix stringByAppendingFormat:@"%@", @"three"] dataUsingEncoding:NSUTF8StringEncoding];
                [blockIDs addObject:blockIDthree];
                [blockArray addObject:[[AZSBlockListItem alloc] initWithBlockID:blockIDthree blockListMode:AZSBlockListModeUncommitted size:blockDatathree.length]];
                [blockDataArray addObject:blockDatathree];
                
                for (int i = 5; i < 8; i++)
                {
                    NSString *blockID = [[[blockIDPrefix stringByAppendingFormat:@"%d", i] dataUsingEncoding:NSUTF8StringEncoding] base64EncodedStringWithOptions:0];
                    NSData *blockData = [[blockDataPrefix stringByAppendingFormat:@"%d", i] dataUsingEncoding:NSUTF8StringEncoding];
                    [blockIDs addObject:blockID];
                    [blockArray addObject:[[AZSBlockListItem alloc] initWithBlockID:blockID blockListMode:AZSBlockListModeUncommitted size:blockData.length]];
                    [blockDataArray addObject:blockData];
                }
                
                // Add additional, uncommitted blocks, including two (blocks 2 and 3) that are both committed and uncommitted.
                [self uploadAllBlocksToBlob:blockBlob blockIDs:blockIDs blockDataArray:blockDataArray completionHandler:^(NSError * error) {
                    XCTAssertNil(error, @"Error in uploading blocks.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
                    
                    // Check that the downloaded block list is correct.
                    [self validateGetBlockListOperationsWithExpectedBlockList:blockArray blockBlob:blockBlob completionHandler:^(NSError * error) {
                        XCTAssertNil(error, @"Error in downloading block list.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
                        
                        // Shuffle the blocks around with another uploadBlockList.  Include block 2 from uncommitted and 3 from committed.
                        NSMutableArray *newblockArray = [NSMutableArray arrayWithCapacity:4];
                        long initialDataLength = [[blockDataPrefix stringByAppendingFormat:@"%d", 1] dataUsingEncoding:NSUTF8StringEncoding].length;
                        [newblockArray addObject:[[AZSBlockListItem alloc] initWithBlockID:[[[blockIDPrefix stringByAppendingFormat:@"%d", 7] dataUsingEncoding:NSUTF8StringEncoding] base64EncodedStringWithOptions:0] blockListMode:AZSBlockListModeUncommitted size:initialDataLength]];
                        [newblockArray addObject:[[AZSBlockListItem alloc] initWithBlockID:[[[blockIDPrefix stringByAppendingFormat:@"%d", 2] dataUsingEncoding:NSUTF8StringEncoding] base64EncodedStringWithOptions:0] blockListMode:AZSBlockListModeUncommitted size:blockDatatwo.length]];
                        [newblockArray addObject:[[AZSBlockListItem alloc] initWithBlockID:[[[blockIDPrefix stringByAppendingFormat:@"%d", 3] dataUsingEncoding:NSUTF8StringEncoding] base64EncodedStringWithOptions:0] blockListMode:AZSBlockListModeCommitted size:initialDataLength]];
                        [newblockArray addObject:[[AZSBlockListItem alloc] initWithBlockID:[[[blockIDPrefix stringByAppendingFormat:@"%d", 1] dataUsingEncoding:NSUTF8StringEncoding] base64EncodedStringWithOptions:0] blockListMode:AZSBlockListModeCommitted size:initialDataLength]];
                        
                        [blockBlob uploadBlockListFromArray:newblockArray accessCondition:nil requestOptions:nil operationContext:nil completionHandler:^(NSError * error) {
                            XCTAssertNil(error, @"Error in uploading block list.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
                            
                            for (AZSBlockListItem *blockListItem in newblockArray)
                            {
                                blockListItem.blockListMode = AZSBlockListModeCommitted;
                            }
                            
                            [self validateGetBlockListOperationsWithExpectedBlockList:newblockArray blockBlob:blockBlob completionHandler:^(NSError * error) {
                                XCTAssertNil(error, @"Error in downloading block list.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
                                
                                NSOutputStream *targetStream = [NSOutputStream outputStreamToMemory];
                                [targetStream open];
                                
                                [blockBlob downloadToStream:targetStream accessCondition:nil requestOptions:nil operationContext:nil completionHandler:^(NSError * error) {
                                    XCTAssertNil(error, @"Error in downloading blob.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
                                    
                                    NSString *endingBlobText = [[NSString alloc] initWithData:[targetStream propertyForKey:NSStreamDataWrittenToMemoryStreamKey] encoding:NSUTF8StringEncoding];
                                    NSString *expectedBlobText = @"blockDataPrefix7blockDataPrefixtwoblockDataPrefix3blockDataPrefix1";
                                    
                                    XCTAssertTrue([expectedBlobText isEqualToString:endingBlobText], @"String text does not match");
                                    
                                    [blockBlob deleteWithSnapshotsOption:AZSDeleteSnapshotsOptionNone accessCondition:nil requestOptions:nil operationContext:nil completionHandler:^(NSError * error) {
                                        XCTAssertNil(error, @"Error in deleting blob.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
                                        
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
    [semaphore wait];
}

-(void)runBlobDeleteSnapshotTestWithSnapshotOption:(AZSDeleteSnapshotsOption)deleteSnapshotsOption completionHandler:(void (^)(NSError *, NSError *, NSError *, NSError *, NSError *))completionHandler;
{
    NSString *blobName1 = [NSString stringWithFormat:@"sampleblob%@", [AZSTestHelpers uniqueName]];
    NSString *blobName2 = [NSString stringWithFormat:@"sampleblob%@", [AZSTestHelpers uniqueName]];
    NSString *blobText = @"sampleBlobText";
    AZSCloudBlockBlob *blockBlob1 = [self.blobContainer blockBlobReferenceFromName:blobName1];
    AZSCloudBlockBlob *blockBlob2 = [self.blobContainer blockBlobReferenceFromName:blobName2];
    [blockBlob1 uploadFromText:blobText completionHandler:^(NSError *error) {
        XCTAssertNil(error, @"Error in uploading blob.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
        [blockBlob2 uploadFromText:blobText completionHandler:^(NSError *error) {
            XCTAssertNil(error, @"Error in uploading blob.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
            [blockBlob2 snapshotBlobWithMetadata:nil completionHandler:^(NSError *error, AZSCloudBlob *snapshottedBlob) {
                XCTAssertNil(error, @"Error in snapshotting blob.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
                
                [blockBlob1 deleteWithSnapshotsOption:deleteSnapshotsOption completionHandler:^(NSError *blob1DeleteError) {
                    [blockBlob1 downloadToTextWithCompletionHandler:^(NSError *blob1DownloadError, NSString *downloadedBlobText1) {
                        [blockBlob2 deleteWithSnapshotsOption:deleteSnapshotsOption completionHandler:^(NSError *blob2DeleteError) {
                            [blockBlob2 downloadToTextWithCompletionHandler:^(NSError *blob2DownloadError, NSString *downloadedBlobText2) {
                                [snapshottedBlob downloadToTextWithCompletionHandler:^(NSError *blob2SnapshotDownloadError, NSString *downloadedBlobText2Snapshot) {
                                    completionHandler(blob1DeleteError, blob1DownloadError, blob2DeleteError, blob2DownloadError, blob2SnapshotDownloadError);
                                }];
                            }];
                        }];
                    }];
                }];
            }];
        }];
    }];
}

- (void)testBlobDeleteOptionNone
{
    AZSTestSemaphore *semaphore = [[AZSTestSemaphore alloc] init];
    [self runBlobDeleteSnapshotTestWithSnapshotOption:AZSDeleteSnapshotsOptionNone completionHandler:^(NSError *blob1DeleteError, NSError *blob1DownloadError, NSError *blob2DeleteError, NSError *blob2DownloadError, NSError *blob2SnapshotDownloadError) {
        XCTAssertNil(blob1DeleteError, @"Error in deleting blob with no snapshots.  Error code = %ld, error domain = %@, error userinfo = %@", (long)blob1DeleteError.code, blob1DeleteError.domain, blob1DeleteError.userInfo);

        XCTAssertNotNil(blob1DownloadError, @"Expected error in blob download did not occur.");
        int blob1DownloadStatusCode = ((NSNumber *)blob1DownloadError.userInfo[AZSCHttpStatusCode]).intValue;
        XCTAssertTrue(blob1DownloadStatusCode == 404, @"Blob download failed with an incorrect error code.  Intended to be a 404, actually is a %d", blob1DownloadStatusCode);

        XCTAssertNotNil(blob2DeleteError, @"Expected error in blob delete did not occur.");
        int blob2DeleteStatusCode = ((NSNumber *)blob2DeleteError.userInfo[AZSCHttpStatusCode]).intValue;
        XCTAssertTrue(blob2DeleteStatusCode == 409, @"Blob download failed with an incorrect error code.  Intended to be a 409, actually is a %d", blob1DownloadStatusCode);

        XCTAssertNil(blob2DownloadError, @"Error in fetching blob content.  Error code = %ld, error domain = %@, error userinfo = %@", (long)blob2DownloadError.code, blob2DownloadError.domain, blob2DownloadError.userInfo);
        
        XCTAssertNil(blob2SnapshotDownloadError, @"Error in fetching blob snapshot content.  Error code = %ld, error domain = %@, error userinfo = %@", (long)blob2SnapshotDownloadError.code, blob2SnapshotDownloadError.domain, blob2SnapshotDownloadError.userInfo);
        
        [semaphore signal];
    }];
    
    [semaphore wait];
}

-(void)testBlobDeleteOptionIncludeSnapshots
{
    AZSTestSemaphore *semaphore = [[AZSTestSemaphore alloc] init];
    [self runBlobDeleteSnapshotTestWithSnapshotOption:AZSDeleteSnapshotsOptionIncludeSnapshots completionHandler:^(NSError *blob1DeleteError, NSError *blob1DownloadError, NSError *blob2DeleteError, NSError *blob2DownloadError, NSError *blob2SnapshotDownloadError) {
        XCTAssertNil(blob1DeleteError, @"Error in deleting blob with no snapshots.  Error code = %ld, error domain = %@, error userinfo = %@", (long)blob1DeleteError.code, blob1DeleteError.domain, blob1DeleteError.userInfo);
        
        XCTAssertNotNil(blob1DownloadError, @"Expected error in blob download did not occur.");
        int blob1DownloadStatusCode = ((NSNumber *)blob1DownloadError.userInfo[AZSCHttpStatusCode]).intValue;
        XCTAssertTrue(blob1DownloadStatusCode == 404, @"Blob download failed with an incorrect error code.  Intended to be a 404, actually is a %d", blob1DownloadStatusCode);
        
        XCTAssertNil(blob2DeleteError, @"Error in deleting blob with no snapshots.  Error code = %ld, error domain = %@, error userinfo = %@", (long)blob2DeleteError.code, blob2DeleteError.domain, blob2DeleteError.userInfo);
        
        XCTAssertNotNil(blob2DownloadError, @"Expected error in blob download did not occur.");
        int blob2DownloadStatusCode = ((NSNumber *)blob2DownloadError.userInfo[AZSCHttpStatusCode]).intValue;
        XCTAssertTrue(blob2DownloadStatusCode == 404, @"Blob download failed with an incorrect error code.  Intended to be a 404, actually is a %d", blob2DownloadStatusCode);
        
        XCTAssertNotNil(blob2SnapshotDownloadError, @"Expected error in blob download did not occur.");
        int blob2SnapshotDownloadStatusCode = ((NSNumber *)blob2SnapshotDownloadError.userInfo[AZSCHttpStatusCode]).intValue;
        XCTAssertTrue(blob2SnapshotDownloadStatusCode == 404, @"Blob download failed with an incorrect error code.  Intended to be a 404, actually is a %d", blob2SnapshotDownloadStatusCode);
        
        [semaphore signal];
    }];
    [semaphore wait];
}

-(void)testBlobDeleteOptionSnapshotsOnly
{
    AZSTestSemaphore *semaphore = [[AZSTestSemaphore alloc] init];
    [self runBlobDeleteSnapshotTestWithSnapshotOption:AZSDeleteSnapshotsOptionDeleteSnapshotsOnly completionHandler:^(NSError *blob1DeleteError, NSError *blob1DownloadError, NSError *blob2DeleteError, NSError *blob2DownloadError, NSError *blob2SnapshotDownloadError) {
        XCTAssertNotNil(blob1DeleteError, @"Expected error in blob delete did not occur.");
        int blob1DeleteStatusCode = ((NSNumber *)blob1DeleteError.userInfo[AZSCHttpStatusCode]).intValue;
        XCTAssertTrue(blob1DeleteStatusCode == 404, @"Blob delete failed with an incorrect error code.  Intended to be a 404, actually is a %d", blob1DeleteStatusCode);
        
        XCTAssertNil(blob1DownloadError, @"Error in fetching blob content.  Error code = %ld, error domain = %@, error userinfo = %@", (long)blob1DownloadError.code, blob1DownloadError.domain, blob1DownloadError.userInfo);
        
        XCTAssertNil(blob2DeleteError, @"Error in deleting blob with no snapshots.  Error code = %ld, error domain = %@, error userinfo = %@", (long)blob2DeleteError.code, blob2DeleteError.domain, blob2DeleteError.userInfo);
        
        XCTAssertNil(blob2DownloadError, @"Error in fetching blob content.  Error code = %ld, error domain = %@, error userinfo = %@", (long)blob2DownloadError.code, blob2DownloadError.domain, blob2DownloadError.userInfo);
        
        XCTAssertNotNil(blob2SnapshotDownloadError, @"Expected error in blob download did not occur.");
        int blob2SnapshotDownloadStatusCode = ((NSNumber *)blob2SnapshotDownloadError.userInfo[AZSCHttpStatusCode]).intValue;
        XCTAssertTrue(blob2SnapshotDownloadStatusCode == 404, @"Blob download failed with an incorrect error code.  Intended to be a 404, actually is a %d", blob2SnapshotDownloadStatusCode);
        
        [semaphore signal];
    }];
    [semaphore wait];
}

-(void)testBlobDeleteSnapshot
{
    AZSTestSemaphore *semaphore = [[AZSTestSemaphore alloc] init];

    NSString *blobName = [NSString stringWithFormat:@"sampleblob%@", [AZSTestHelpers uniqueName]];
    NSString *blobText = @"sampleBlobText";
    AZSCloudBlockBlob *blockBlob = [self.blobContainer blockBlobReferenceFromName:blobName];
    
    [blockBlob uploadFromText:blobText completionHandler:^(NSError *error) {
        XCTAssertNil(error, @"Error in uploading blob.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
        [blockBlob snapshotBlobWithMetadata:nil completionHandler:^(NSError *error, AZSCloudBlob *blockBlobSnapshot) {
            XCTAssertNil(error, @"Error in snapshotting blob.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
            [blockBlobSnapshot deleteWithSnapshotsOption:AZSDeleteSnapshotsOptionDeleteSnapshotsOnly completionHandler:^(NSError *error) {
                XCTAssertNotNil(error, @"Expected error in blob delete did not occur.");
                int statusCode = ((NSNumber *)error.userInfo[AZSCHttpStatusCode]).intValue;
                XCTAssertTrue(statusCode == 400, @"Blob delete failed with an incorrect error code.  Intended to be a 400, actually is a %d", statusCode);
                
                [blockBlobSnapshot deleteWithSnapshotsOption:AZSDeleteSnapshotsOptionIncludeSnapshots completionHandler:^(NSError *error) {
                    XCTAssertNotNil(error, @"Expected error in blob delete did not occur.");
                    int statusCode = ((NSNumber *)error.userInfo[AZSCHttpStatusCode]).intValue;
                    XCTAssertTrue(statusCode == 400, @"Blob delete failed with an incorrect error code.  Intended to be a 400, actually is a %d", statusCode);

                    [blockBlobSnapshot deleteWithSnapshotsOption:AZSDeleteSnapshotsOptionNone completionHandler:^(NSError *error) {
                        XCTAssertNil(error, @"Error in snapshotting blob.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
                        
                        [blockBlobSnapshot downloadToTextWithCompletionHandler:^(NSError *error, NSString *downloadedText) {
                            XCTAssertNotNil(error, @"Expected error in blob snapshot download did not occur.");
                            int statusCode = ((NSNumber *)error.userInfo[AZSCHttpStatusCode]).intValue;
                            XCTAssertTrue(statusCode == 404, @"Blob snapshot download failed with an incorrect error code.  Intended to be a 404, actually is a %d", statusCode);
                            
                            [blockBlob downloadToTextWithCompletionHandler:^(NSError *error, NSString *downloadedText) {
                                XCTAssertNil(error, @"Error in downloading blob.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
                                XCTAssertTrue([blobText isEqualToString:downloadedText], @"Blob text incorrect.");
                                [semaphore signal];
                            }];
                        }];
                    }];
                }];
            }];
        }];
    }];
    [semaphore wait];
}

- (void)testBlobExists
{
    AZSTestSemaphore *semaphore = [[AZSTestSemaphore alloc] init];
    
    NSString *blobName = [NSString stringWithFormat:@"sampleblob%@", [AZSTestHelpers uniqueName]];
    
    NSString *blobText = @"sampleBlobText";
    
    AZSCloudBlockBlob *blockBlob = [self.blobContainer blockBlobReferenceFromName:blobName];
    
    [blockBlob existsWithAccessCondition:nil requestOptions:nil operationContext:nil completionHandler:^(NSError *error, BOOL existsResult) {
        XCTAssertNil(error, @"Error in blob existence check.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
        XCTAssertFalse(existsResult, @"Blob exists when it should not.");
        
        [blockBlob uploadFromData:[blobText dataUsingEncoding:NSUTF8StringEncoding] accessCondition:nil requestOptions:nil operationContext:nil completionHandler:^(NSError * error) {
            XCTAssertNil(error, @"Error in uploading blob.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
            
            [blockBlob existsWithAccessCondition:nil requestOptions:nil operationContext:nil completionHandler:^(NSError *error, BOOL existsResult) {
                XCTAssertNil(error, @"Error in blob existence check.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
                XCTAssertTrue(existsResult, @"Blob does not exist when it should.");

                [semaphore signal];
            }];
        }];
    }];
    [semaphore wait];
}

- (void)testBlobSnapshot
{
    // TODO: Test snapshot metadata.
    
    AZSTestSemaphore *semaphore = [[AZSTestSemaphore alloc] init];
    
    NSString *blobName = [NSString stringWithFormat:@"sampleblob%@", [AZSTestHelpers uniqueName]];
    
    NSString *blobText = @"sampleBlobText";
    NSString *blobTextafter1 = @"sampleBlobTextafter1";
    NSString *blobTextafter2 = @"sampleBlobTextafter2";
    
    // Upload a blob, snapshot it, upload it again, snapshot it again, upload it a third time, and check that everything works properly.
    AZSCloudBlockBlob *blockBlob = [self.blobContainer blockBlobReferenceFromName:blobName];
    [blockBlob uploadFromData:[blobText dataUsingEncoding:NSUTF8StringEncoding] accessCondition:nil requestOptions:nil operationContext:nil completionHandler:^(NSError * error) {
        XCTAssertNil(error, @"Error in uploading blob.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
        
        [blockBlob snapshotBlobWithMetadata:nil accessCondition:nil requestOptions:nil operationContext:nil completionHandler:^(NSError *error , AZSCloudBlob * snapshot1) {
            XCTAssertNil(error, @"Error in snapshotting blob.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
            
            [blockBlob uploadFromData:[blobTextafter1 dataUsingEncoding:NSUTF8StringEncoding] accessCondition:nil requestOptions:nil operationContext:nil completionHandler:^(NSError * error) {
                XCTAssertNil(error, @"Error in uploading blob.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
                
                [blockBlob snapshotBlobWithMetadata:nil accessCondition:nil requestOptions:nil operationContext:nil completionHandler:^(NSError * error, AZSCloudBlob *snapshot2) {
                    XCTAssertNil(error, @"Error in snapshotting blob.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
                    
                    [blockBlob uploadFromData:[blobTextafter2 dataUsingEncoding:NSUTF8StringEncoding] accessCondition:nil requestOptions:nil operationContext:nil completionHandler:^(NSError * error) {
                        XCTAssertNil(error, @"Error in uploading blob.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
                        
                        NSOutputStream *targetStream = [NSOutputStream outputStreamToMemory];
                        
                        [blockBlob downloadToStream:targetStream accessCondition:nil requestOptions:nil operationContext:nil completionHandler:^(NSError * error) {
                            XCTAssertNil(error, @"Error in downloading blob.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
                            
                            NSString *endingBlobText = [[NSString alloc] initWithData:[targetStream propertyForKey:NSStreamDataWrittenToMemoryStreamKey] encoding:NSUTF8StringEncoding];
                            
                            XCTAssertTrue([blobTextafter2 isEqualToString:endingBlobText], @"String text does not match");
                            
                            NSOutputStream *targetStream = [NSOutputStream outputStreamToMemory];
                            
                            [snapshot2 downloadToStream:targetStream accessCondition:nil requestOptions:nil operationContext:nil completionHandler:^(NSError * error) {
                                XCTAssertNil(error, @"Error in downloading blob.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
                                
                                NSString *endingBlobText = [[NSString alloc] initWithData:[targetStream propertyForKey:NSStreamDataWrittenToMemoryStreamKey] encoding:NSUTF8StringEncoding];
                                
                                XCTAssertTrue([blobTextafter1 isEqualToString:endingBlobText], @"String text does not match");

                                NSOutputStream *targetStream = [NSOutputStream outputStreamToMemory];
                                [snapshot1 downloadToStream:targetStream accessCondition:nil requestOptions:nil operationContext:nil completionHandler:^(NSError * error) {
                                    XCTAssertNil(error, @"Error in downloading blob.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
                                    
                                    NSString *endingBlobText = [[NSString alloc] initWithData:[targetStream propertyForKey:NSStreamDataWrittenToMemoryStreamKey] encoding:NSUTF8StringEncoding];
                                    
                                    XCTAssertTrue([blobText isEqualToString:endingBlobText], @"String text does not match");
                                    
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

-(void)testDownloadAttributes
{
    AZSTestSemaphore *semaphore = [[AZSTestSemaphore alloc] init];
    AZSCloudBlockBlob *blob = [self.blobContainer blockBlobReferenceFromName:AZSCBlob];
    blob.properties.cacheControl = @"no-cache";
    
    [blob uploadFromText:@"text" completionHandler:^(NSError *err) {
        XCTAssertNil(err, @"Error in blob creation.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
        
        blob.properties.cacheControl = @"cache";
        [blob downloadAttributesWithCompletionHandler:^(NSError * err) {
            XCTAssertNil(err, @"Error in downloading attributes.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
            XCTAssertEqualObjects(blob.properties.cacheControl, @"no-cache");
            
            blob.properties.cacheControl = @"cache";
            [blob downloadAttributesWithAccessCondition:[[AZSAccessCondition alloc] initWithIfMatchCondition:blob.properties.eTag] requestOptions:nil operationContext:nil completionHandler:^(NSError * err) {
                XCTAssertNil(err, @"Error in downloading attributes with access condition.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
                XCTAssertEqualObjects(blob.properties.cacheControl, @"no-cache");
            
                AZSBlobRequestOptions *bro = [[AZSBlobRequestOptions alloc] init];
                bro.storeBlobContentMD5 = YES;
                bro.disableContentMD5Validation = NO;
                [blob downloadAttributesWithAccessCondition:nil requestOptions:bro operationContext:nil completionHandler:^(NSError *error) {
                    XCTAssertNil(error, @"Error in downloading attributes with request options.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
                    XCTAssertEqualObjects(blob.properties.cacheControl, @"no-cache");

                    blob.properties.cacheControl = @"cache";
                            
                    AZSOperationContext *context = [[AZSOperationContext alloc] init];
                    __block BOOL opContextFlag = NO;
                    void (^testOp)(NSMutableURLRequest *, AZSOperationContext *) = ^(NSMutableURLRequest *request, AZSOperationContext *sendingOpContext) {
                        XCTAssertFalse(opContextFlag);
                        XCTAssertEqualObjects(blob.properties.cacheControl, @"cache");
                        opContextFlag = YES;
                    };
                    context.sendingRequest = testOp;
                            
                    [blob downloadAttributesWithAccessCondition:nil requestOptions:nil operationContext:context completionHandler:^(NSError *error) {
                        XCTAssertNil(error, @"Error in downloading attributes with operation context.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
                        XCTAssertEqualObjects(blob.properties.cacheControl, @"no-cache");
                        XCTAssertTrue(opContextFlag);
                                
                        [semaphore signal];
                    }];
                }];
            }];
        }];
    }];
    [semaphore wait];
}

-(void)testLargeBlobDownload
{
    AZSTestSemaphore *semaphore = [[AZSTestSemaphore alloc] init];
    //   TODO:  Change all tests to use XCTestExpectation when we switch to XCode 6

    NSString *blobName = [NSString stringWithFormat:@"sampleblob%@", [AZSTestHelpers uniqueName]];

    NSMutableArray __block *blockIDs = [NSMutableArray arrayWithCapacity:5];
    NSMutableArray __block *blockDataArray = [NSMutableArray arrayWithCapacity:5];
    NSMutableArray __block *blockArray = [NSMutableArray arrayWithCapacity:5];
    
    unsigned int randSeed = (unsigned int)time(NULL);
    unsigned int randSeedCopy = randSeed;
    
    NSUInteger blockSize = 10000;
    NSUInteger blockCount = 20;
    
    for (int i = 0; i < blockCount; i++)
    {
        NSString *blockID = [self generateRandomBlockID];
        NSMutableData *blockData = [NSMutableData dataWithLength:blockSize];
        
        Byte* bytes = [blockData mutableBytes];
        
        for (int i = 0; i < blockSize; i++)
        {
            bytes[i] = rand_r(&randSeedCopy) % 256;
        }
        
        [blockIDs addObject:blockID];
        [blockArray addObject:[[AZSBlockListItem alloc] initWithBlockID:blockID blockListMode:AZSBlockListModeLatest size:blockData.length]];
        [blockDataArray addObject:blockData];
    }
    
    AZSCloudBlockBlob *blockBlob = [self.blobContainer blockBlobReferenceFromName:blobName];
    [self uploadAllBlocksToBlob:blockBlob blockIDs:blockIDs blockDataArray:blockDataArray completionHandler:^(NSError * error) {
        XCTAssertNil(error, @"Error in uploading blocks.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
        
        [blockBlob uploadBlockListFromArray:blockArray accessCondition:nil requestOptions:nil operationContext:nil completionHandler:^(NSError * error) {
            XCTAssertNil(error, @"Error in uploading block list.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
        
            AZSByteValidationStream *targetStream = [[AZSByteValidationStream alloc]initWithRandomSeed:randSeed totalBlobSize:blockSize*blockCount isUpload:NO];
            AZSBlobRequestOptions *requestOptions = [[AZSBlobRequestOptions alloc] init];
            
            [blockBlob downloadToStream:(NSOutputStream *)targetStream accessCondition:nil requestOptions:requestOptions operationContext:nil completionHandler:^(NSError * error) {
                
                XCTAssertNil(error, @"Error in downloading blob.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
                XCTAssert(targetStream.totalBytes == blockSize*blockCount, @"Downloaded blob is wrong size.  Size = %ld, expected size = %ld", (unsigned long)targetStream.totalBytes, (unsigned long)(blockSize*blockCount));
                XCTAssertFalse(targetStream.dataCorrupt, @"Downloaded blob is corrupt.");

                [semaphore signal];
            }];
        }];
    }];
    [semaphore wait];
}

-(void)testUseTransactionalMD5
{
    AZSTestSemaphore *semaphore = [[AZSTestSemaphore alloc] init];
    NSString *blobName = [NSString stringWithFormat:@"sampleblob%@", [AZSTestHelpers uniqueName]];
    AZSCloudBlockBlob *blockBlob = [self.blobContainer blockBlobReferenceFromName:blobName];
    
    NSString *blockDataString = @"SampleBlockData";
    NSData *blockData = [blockDataString dataUsingEncoding:NSUTF8StringEncoding];
    
    unsigned char md5Bytes[CC_MD5_DIGEST_LENGTH];
    CC_MD5(blockData.bytes, (unsigned int) blockData.length, md5Bytes);
    NSData *dataTemp = [[NSData alloc] initWithBytes:md5Bytes length:CC_MD5_DIGEST_LENGTH];
    NSString *actualContentMD5 = [dataTemp base64EncodedStringWithOptions:0];
    
    AZSBlobRequestOptions *bro = [[AZSBlobRequestOptions alloc] init];
    bro.useTransactionalMD5 = YES;
    
    
    void (^validateSendingContentMD5)(NSMutableURLRequest *, AZSOperationContext *) = ^(NSMutableURLRequest *request, AZSOperationContext *sendingOpContext)
    {
        if (![request.URL.absoluteString hasSuffix:[AZSCXmlBlockList lowercaseString]])
        {
            XCTAssert([[request allHTTPHeaderFields][AZSCXmlContentMd5] compare:actualContentMD5 options:NSLiteralSearch] == NSOrderedSame, @"Incorrect content-MD5 calculated by the library.");
        }
    };
    
    __block AZSOperationContext *opContext = [[AZSOperationContext alloc] init];
    opContext.sendingRequest = validateSendingContentMD5;
    
    [blockBlob uploadBlockFromData:blockData blockID:[self generateRandomBlockID] contentMD5:nil accessCondition:nil requestOptions:bro operationContext:opContext completionHandler:^(NSError * error) {
        XCTAssertNil(error, @"Error in uploading block.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
        
        opContext = [[AZSOperationContext alloc] init];
        opContext.sendingRequest = validateSendingContentMD5;
        
        [blockBlob uploadBlockFromData:blockData blockID:[self generateRandomBlockID] contentMD5:actualContentMD5 accessCondition:nil requestOptions:bro operationContext:opContext completionHandler:^(NSError * error) {
            XCTAssertNil(error, @"Error in uploading block.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
            
            // The following content-MD5 is incorrect.
            [blockBlob uploadBlockFromData:blockData blockID:[self generateRandomBlockID] contentMD5:@"iNX9DiosUqV6hiRD8hLdPw==" accessCondition:nil requestOptions:bro operationContext:nil completionHandler:^(NSError * error) {
                XCTAssertNotNil(error, @"Expected error in uploading block did not occur.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
                
                opContext = [[AZSOperationContext alloc] init];
                opContext.sendingRequest = validateSendingContentMD5;
                bro.disableContentMD5Validation = NO;
                bro.storeBlobContentMD5 = NO;
                
                [blockBlob uploadFromData:blockData accessCondition:nil requestOptions:bro operationContext:opContext completionHandler:^(NSError *error) {
                    XCTAssertNil(error, @"Error in uploading blob.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
                    
                    NSOutputStream *targetStream = [[NSOutputStream alloc] initToMemory];
                    [blockBlob downloadToStream:targetStream accessCondition:nil requestOptions:bro operationContext:nil completionHandler:^(NSError *error) {
                        XCTAssertNotNil(error, @"Expected error in downloading blob not occur.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
                        [semaphore signal];
                    }];
                }];
            }];
        }];
    }];
    [semaphore wait];
}

-(void)testStoreBlobContentMD5
{
    // TODO: Improve this test to test auto-calculation of the MD5 of a much longer input blob.
    
    AZSTestSemaphore *semaphore = [[AZSTestSemaphore alloc] init];
    NSString *blobName = [NSString stringWithFormat:@"sampleblob%@", [AZSTestHelpers uniqueName]];
    AZSCloudBlockBlob *blockBlob = [self.blobContainer blockBlobReferenceFromName:blobName];

    NSString *blockDataString = @"SampleBlockData";
    NSData *blockData = [blockDataString dataUsingEncoding:NSUTF8StringEncoding];
    
    unsigned char md5Bytes[CC_MD5_DIGEST_LENGTH];
    CC_MD5(blockData.bytes, (unsigned int) blockData.length, md5Bytes);
    NSData *dataTemp = [[NSData alloc] initWithBytes:md5Bytes length:CC_MD5_DIGEST_LENGTH];
    NSString *actualContentMD5 = [dataTemp base64EncodedStringWithOptions:0];
    NSString *blockID = [self generateRandomBlockID];
    
    AZSBlobRequestOptions *bro = [[AZSBlobRequestOptions alloc] init];
    bro.storeBlobContentMD5 = YES;
    bro.disableContentMD5Validation = YES;
    
    NSArray *blocks = [NSArray arrayWithObject:[[AZSBlockListItem alloc] initWithBlockID:blockID blockListMode:AZSBlockListModeLatest size:0]];

    blockBlob.properties.contentMD5 = actualContentMD5;
    
    [blockBlob uploadBlockFromData:blockData blockID:blockID contentMD5:nil accessCondition:nil requestOptions:bro operationContext:nil completionHandler:^(NSError *error) {
        XCTAssertNil(error, @"Error in uploading block.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
        
        [blockBlob uploadBlockListFromArray:blocks accessCondition:nil requestOptions:bro operationContext:nil completionHandler:^(NSError *error) {
            XCTAssertNil(error, @"Error in uploading block list.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
        
            AZSCloudBlockBlob *blockBlob2 = [self.blobContainer blockBlobReferenceFromName:blobName];
            NSOutputStream *targetStream2 = [[NSOutputStream alloc] initToMemory];
            [blockBlob2 downloadToStream:targetStream2 accessCondition:nil requestOptions:bro operationContext:nil completionHandler:^(NSError *error) {
                XCTAssertNil(error, @"Error in downloading blob.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
                XCTAssertTrue([actualContentMD5 compare:blockBlob2.properties.contentMD5 options:NSLiteralSearch] == NSOrderedSame, @"Blob download did not properly set contentMD5.");
            
                AZSCloudBlockBlob *blockBlob3 = [self.blobContainer blockBlobReferenceFromName:blobName];
                NSInputStream *sourceStream = [[NSInputStream alloc] initWithData:blockData];
                [blockBlob3 uploadFromStream:sourceStream accessCondition:nil requestOptions:bro operationContext:nil completionHandler:^(NSError *error) {
                    XCTAssertNil(error, @"Error in uploading blob from stream.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);

                    AZSCloudBlockBlob *blockBlob4 = [self.blobContainer blockBlobReferenceFromName:blobName];
                    NSOutputStream *targetStream4 = [[NSOutputStream alloc] initToMemory];
                    
                    [blockBlob4 downloadToStream:targetStream4 accessCondition:nil requestOptions:bro operationContext:nil completionHandler:^(NSError *error) {
                        XCTAssertNil(error, @"Error in downloading blob.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
                        XCTAssertTrue([actualContentMD5 compare:blockBlob4.properties.contentMD5 options:NSLiteralSearch] == NSOrderedSame, @"Blob download did not properly set contentMD5.");
                        [semaphore signal];
                    }];
                }];
            }];
        }];
    }];
    [semaphore wait];
}

-(void)testDisableContentMD5ValidationIncorrectCase
{
    AZSTestSemaphore *semaphore = [[AZSTestSemaphore alloc] init];
    NSString *blobName = [NSString stringWithFormat:@"sampleblob%@", [AZSTestHelpers uniqueName]];
    AZSCloudBlockBlob *blockBlob = [self.blobContainer blockBlobReferenceFromName:blobName];

    NSString *blockDataString = @"SampleBlockData";
    NSData *blockData = [blockDataString dataUsingEncoding:NSUTF8StringEncoding];
    
    unsigned char md5Bytes[CC_MD5_DIGEST_LENGTH];
    CC_MD5(blockData.bytes, (unsigned int) blockData.length, md5Bytes);
    // NSData *dataTemp = [[NSData alloc] initWithBytes:md5Bytes length:CC_MD5_DIGEST_LENGTH];
    // NSString *actualContentMD5 = [dataTemp base64EncodedStringWithOptions:0];
    NSString *blockID = [self generateRandomBlockID];
    AZSBlobRequestOptions *bro = [[AZSBlobRequestOptions alloc] init];
    bro.storeBlobContentMD5 = YES;
    bro.disableContentMD5Validation = YES;
    NSString *incorrectContentMD5 = @"iNX9DiosUqV6hiRD8hLdPw==";
    
    NSArray *blocks = [NSArray arrayWithObject:[[AZSBlockListItem alloc] initWithBlockID:blockID blockListMode:AZSBlockListModeLatest size:0]];
    
    blockBlob.properties.contentMD5 = incorrectContentMD5;

    [blockBlob uploadBlockFromData:blockData blockID:blockID completionHandler:^(NSError *error) {
        XCTAssertNil(error, @"Error in uploading block.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
        [blockBlob uploadBlockListFromArray:blocks accessCondition:nil requestOptions:bro operationContext:nil completionHandler:^(NSError *error) {
            XCTAssertNil(error, @"Error in uploading block list.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
            NSOutputStream *targetStream = [[NSOutputStream alloc] initToMemory];
            [blockBlob downloadToStream:targetStream accessCondition:nil requestOptions:bro operationContext:nil completionHandler:^(NSError *error) {
                XCTAssertNil(error, @"Error in downloading blob.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);

                NSOutputStream *targetStream2 = [[NSOutputStream alloc] initToMemory];
                bro.disableContentMD5Validation = NO;
                [blockBlob downloadToStream:targetStream2 accessCondition:nil requestOptions:bro operationContext:nil completionHandler:^(NSError *error) {
                    XCTAssertNotNil(error, @"Expected error while downloading did not occur.");
                    XCTAssertTrue(error.code == AZSEMD5Mismatch, @"Incorrect error code set.");
                    [semaphore signal];
                }];
            }];
        }];
    }];
    [semaphore wait];
}

-(void)testDisableContentMD5ValidationCorrectCase
{
    AZSTestSemaphore *semaphore = [[AZSTestSemaphore alloc] init];
    NSString *blobName = [NSString stringWithFormat:@"sampleblob%@", [AZSTestHelpers uniqueName]];
    AZSCloudBlockBlob *blockBlob = [self.blobContainer blockBlobReferenceFromName:blobName];
    
    NSString *blockDataString = @"SampleBlockData";
    NSData *blockData = [blockDataString dataUsingEncoding:NSUTF8StringEncoding];
    
    unsigned char md5Bytes[CC_MD5_DIGEST_LENGTH];
    CC_MD5(blockData.bytes, (unsigned int) blockData.length, md5Bytes);
    NSData *dataTemp = [[NSData alloc] initWithBytes:md5Bytes length:CC_MD5_DIGEST_LENGTH];
    NSString *actualContentMD5 = [dataTemp base64EncodedStringWithOptions:0];
    NSString *blockID = [self generateRandomBlockID];
    AZSBlobRequestOptions *bro = [[AZSBlobRequestOptions alloc] init];
    bro.storeBlobContentMD5 = YES;
    bro.disableContentMD5Validation = YES;
    
    NSArray *blocks = [NSArray arrayWithObject:[[AZSBlockListItem alloc] initWithBlockID:blockID blockListMode:AZSBlockListModeLatest size:0]];
    
    blockBlob.properties.contentMD5 = actualContentMD5;
    
    [blockBlob uploadBlockFromData:blockData blockID:blockID completionHandler:^(NSError *error) {
        XCTAssertNil(error, @"Error in uploading block.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
        [blockBlob uploadBlockListFromArray:blocks accessCondition:nil requestOptions:bro operationContext:nil completionHandler:^(NSError *error) {
            XCTAssertNil(error, @"Error in uploading block list.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
            NSOutputStream *targetStream = [[NSOutputStream alloc] initToMemory];
            [blockBlob downloadToStream:targetStream accessCondition:nil requestOptions:bro operationContext:nil completionHandler:^(NSError *error) {
                XCTAssertNil(error, @"Error in downloading blob.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
                
                NSOutputStream *targetStream2 = [[NSOutputStream alloc] initToMemory];
                bro.disableContentMD5Validation = NO;
                [blockBlob downloadToStream:targetStream2 accessCondition:nil requestOptions:bro operationContext:nil completionHandler:^(NSError *error) {
                    XCTAssertNil(error, @"Error in downloading blob.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
                    [semaphore signal];
                }];
            }];
        }];
    }];
    [semaphore wait];
}

-(void)testUploadDownloadData
{
    AZSTestSemaphore *semaphore = [[AZSTestSemaphore alloc] init];
    NSString *initialText = @"Some Sample text to roundtrip.";
    NSData *initialData = [initialText dataUsingEncoding:NSUTF8StringEncoding];
    NSString *blobName = [NSString stringWithFormat:@"sampleblob%@", [AZSTestHelpers uniqueName]];
    AZSCloudBlockBlob *blockBlob = [self.blobContainer blockBlobReferenceFromName:blobName];
    
    [blockBlob uploadFromData:initialData completionHandler:^(NSError *error) {
        XCTAssertNil(error, @"Error in uploading data to a blob.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
        [blockBlob downloadToDataWithCompletionHandler:^(NSError *error, NSData *finalData) {
            XCTAssertNil(error, @"Error in downloading data from a blob.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
            
            XCTAssertTrue([initialData isEqualToData:finalData], @"Data strings do not match.");
            [semaphore signal];
        }];
    }];
    [semaphore wait];
}

-(void)testUploadDownloadTextIterate
{
    for (int i = 0; i < 20; i++)
    {
        [self runTestUploadDownloadText];
    }
}


-(void)runTestUploadDownloadText
{
    @autoreleasepool {
        AZSTestSemaphore *semaphore = [[AZSTestSemaphore alloc] init];
        NSString *initialText = @"Some Sample text to roundtrip.";

        NSString *blobName = [NSString stringWithFormat:@"sampleblob%@", [AZSTestHelpers uniqueName]];
        AZSCloudBlockBlob *blockBlob = [self.blobContainer blockBlobReferenceFromName:blobName];

        [blockBlob uploadFromText:initialText completionHandler:^(NSError *error) {
            XCTAssertNil(error, @"Error in uploading text to a blob.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
            [blockBlob downloadToTextWithCompletionHandler:^(NSError *error, NSString *finalText) {
                XCTAssertNil(error, @"Error in downloading text from a blob.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
                XCTAssertTrue([initialText compare:finalText options:NSLiteralSearch] == NSOrderedSame, @"Text strings do not match.");
                [semaphore signal];
            }];
        }];
        [semaphore wait];
    }
}

-(void)testUploadDownloadFileWithPathIterate
{
    for (int i = 0; i < 30; i++)
    {
        [self runTestUploadDownloadFileWithPath];
    }
}


-(void)runTestUploadDownloadFileWithPath
{
    AZSTestSemaphore *semaphore = [[AZSTestSemaphore alloc] init];
    
    NSString *fileName = [[NSUUID UUID] UUIDString];
    NSString *filePath = [[NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:fileName]] path];
    NSString *targetFileName = [[NSUUID UUID] UUIDString];
    NSString *targetFilePath = [[NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:targetFileName]] path];
    
    NSString *fileText = @"Some Sample file text.";
    
    NSError *error = nil;
    [fileText writeToFile:filePath atomically:YES encoding:NSUTF8StringEncoding error:&error];
    XCTAssertNil(error, @"Error in writing initial file.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
    
    NSString *blobName = [NSString stringWithFormat:@"sampleblob%@", [AZSTestHelpers uniqueName]];
    AZSCloudBlockBlob *blockBlob = [self.blobContainer blockBlobReferenceFromName:blobName];
    
    [blockBlob uploadFromFileWithPath:filePath completionHandler:^(NSError *error) {
        XCTAssertNil(error, @"Error in uploading file to a blob.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
        
        [blockBlob downloadToFileWithPath:targetFilePath append:YES completionHandler:^(NSError *error) {
            XCTAssertNil(error, @"Error in downloading blob to a file.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
            
            NSError *fileError = nil;
            NSString *finalText = [NSString stringWithContentsOfFile:targetFilePath encoding:NSUTF8StringEncoding error:&fileError];
            XCTAssertNil(fileError, @"Error in reading target file.  Error code = %ld, error domain = %@, error userinfo = %@", (long)fileError.code, fileError.domain, fileError.userInfo);
            
            XCTAssertTrue([fileText compare:finalText options:NSLiteralSearch] == NSOrderedSame, @"File contents do not match.");
            
            [[NSFileManager defaultManager] removeItemAtPath:filePath error:&fileError];
            XCTAssertNil(fileError, @"Error in deleting initial file.  Error code = %ld, error domain = %@, error userinfo = %@", (long)fileError.code, fileError.domain, fileError.userInfo);
            [[NSFileManager defaultManager] removeItemAtPath:targetFilePath error:&fileError];
            XCTAssertNil(fileError, @"Error in deleting target file.  Error code = %ld, error domain = %@, error userinfo = %@", (long)fileError.code, fileError.domain, fileError.userInfo);
            
            [semaphore signal];
        }];
    }];
    [semaphore wait];
}

-(void)testUploadDownloadFileWithURL
{
    AZSTestSemaphore *semaphore = [[AZSTestSemaphore alloc] init];
    
    NSString *fileName = [[NSUUID UUID] UUIDString];
    NSURL *fileURL = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:fileName]];
    NSString *targetFileName = [[NSUUID UUID] UUIDString];
    NSURL *targetFileURL = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:targetFileName]];

    NSString *fileText = @"Some Sample file text.";
    
    NSError *error = nil;
    [fileText writeToURL:fileURL atomically:YES encoding:NSUTF8StringEncoding error:&error];
    XCTAssertNil(error, @"Error in writing initial file.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
    
    NSString *blobName = [NSString stringWithFormat:@"sampleblob%@", [AZSTestHelpers uniqueName]];
    AZSCloudBlockBlob *blockBlob = [self.blobContainer blockBlobReferenceFromName:blobName];

    [blockBlob uploadFromFileWithURL:fileURL completionHandler:^(NSError *error) {
        XCTAssertNil(error, @"Error in uploading file to a blob.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
        
        [blockBlob downloadToFileWithURL:targetFileURL append:YES completionHandler:^(NSError *error) {
            XCTAssertNil(error, @"Error in downloading blob to a file.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
            
            NSError *fileError = nil;
            NSString *finalText = [NSString stringWithContentsOfURL:targetFileURL encoding:NSUTF8StringEncoding error:&fileError];
            XCTAssertNil(fileError, @"Error in reading target file.  Error code = %ld, error domain = %@, error userinfo = %@", (long)fileError.code, fileError.domain, fileError.userInfo);
            
            XCTAssertTrue([fileText compare:finalText options:NSLiteralSearch] == NSOrderedSame, @"File contents do not match.");

            [[NSFileManager defaultManager] removeItemAtURL:fileURL error:&fileError];
            XCTAssertNil(fileError, @"Error in deleting initial file.  Error code = %ld, error domain = %@, error userinfo = %@", (long)fileError.code, fileError.domain, fileError.userInfo);
            [[NSFileManager defaultManager] removeItemAtURL:targetFileURL error:&fileError];
            XCTAssertNil(fileError, @"Error in deleting target file.  Error code = %ld, error domain = %@, error userinfo = %@", (long)fileError.code, fileError.domain, fileError.userInfo);

            [semaphore signal];
        }];
    }];
    [semaphore wait];
}


-(void)testStartCopyFromBlob
{
    AZSTestSemaphore *semaphore = [[AZSTestSemaphore alloc] init];
    NSString *sourceBlobName = [NSString stringWithFormat:@"sampleblob%@", [AZSTestHelpers uniqueName]];
    AZSCloudBlockBlob *sourceBlob = [self.blobContainer blockBlobReferenceFromName:sourceBlobName];

    NSString *targetBlobName = [NSString stringWithFormat:@"sampleblob%@", [AZSTestHelpers uniqueName]];
    AZSCloudBlockBlob *targetBlob = [self.blobContainer blockBlobReferenceFromName:targetBlobName];

    NSString *blobDataString = @"SampleBlockData";
    
    [sourceBlob uploadFromText:blobDataString completionHandler:^(NSError *error) {
        XCTAssertNil(error, @"Error in uploading text to a blob.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
        
        [targetBlob startAsyncCopyFromBlob:sourceBlob completionHandler:^(NSError *error, NSString *copyID) {
            XCTAssertNil(error, @"Error in starting copy from a blob.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
            
            [self waitForCopyToCompleteWithBlob:targetBlob completionHandler:^(NSError *error, BOOL copySucceeded) {
                XCTAssertNil(error, @"Error in monitoring blob copy.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
                XCTAssertTrue(copySucceeded, @"Copy operation did not succeed.");

                [targetBlob abortAsyncCopyWithCopyId:copyID completionHandler:^(NSError *error) {
                    XCTAssertNotNil(error, @"Abort copy did not fail as expected.");
                    int statusCode = ((NSNumber *)error.userInfo[AZSCHttpStatusCode]).intValue;
                    XCTAssertTrue(statusCode == 409, @"Abort copy failed with an incorrect error code.  Intended to be a 409, actually is a %d", statusCode);
                    
                    [targetBlob downloadToTextWithCompletionHandler:^(NSError *error, NSString *destinationText) {
                        XCTAssertNil(error, @"Error in downloading destination blob text.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
                        XCTAssertTrue([blobDataString isEqualToString:destinationText], @"Blob text strings do not match.");
                        [semaphore signal];
                    }];
                }];
            }];
        }];
    }];
    [semaphore wait];
}

-(void)testStartCopyFromURL
{
    AZSTestSemaphore *semaphore = [[AZSTestSemaphore alloc] init];
    NSString *sourceBlobName = [NSString stringWithFormat:@"sampleblob%@", [AZSTestHelpers uniqueName]];
    AZSCloudBlockBlob *sourceBlob = [self.blobContainer blockBlobReferenceFromName:sourceBlobName];
    
    NSString *targetBlobName = [NSString stringWithFormat:@"sampleblob%@", [AZSTestHelpers uniqueName]];
    AZSCloudBlockBlob *targetBlob = [self.blobContainer blockBlobReferenceFromName:targetBlobName];
    
    
    NSString *blobDataString = @"SampleBlockData";
    
    [sourceBlob uploadFromText:blobDataString completionHandler:^(NSError *error) {
        XCTAssertNil(error, @"Error in uploading text to a blob.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
        
        [targetBlob startAsyncCopyFromURL:sourceBlob.storageUri.primaryUri completionHandler:^(NSError *error, NSString *copyID) {
            XCTAssertNil(error, @"Error in starting copy from a blob.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
            
            [self waitForCopyToCompleteWithBlob:targetBlob completionHandler:^(NSError *error, BOOL copySucceeded) {
                XCTAssertNil(error, @"Error in monitoring blob copy.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
                XCTAssertTrue(copySucceeded, @"Copy operation did not succeed.");
                
                [targetBlob abortAsyncCopyWithCopyId:copyID completionHandler:^(NSError *error) {
                    XCTAssertNotNil(error, @"Abort copy did not fail as expected.");
                    int statusCode = ((NSNumber *)error.userInfo[AZSCHttpStatusCode]).intValue;
                    XCTAssertTrue(statusCode == 409, @"Abort copy failed with an incorrect error code.  Intended to be a 409, actually is a %d", statusCode);

                    [targetBlob downloadToTextWithCompletionHandler:^(NSError *error, NSString *destinationText) {
                        XCTAssertNil(error, @"Error in downloading destination blob text.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
                        XCTAssertTrue([blobDataString isEqualToString:destinationText], @"Blob text strings do not match.");
                        [semaphore signal];
                    }];
                }];
            }];
        }];
    }];
    [semaphore wait];
}

-(void)runAccessConditionTestWithBlob:(AZSCloudBlob *)blob expectedBlobText:(NSString *)expectedBlobText accessConditions:(NSArray *)accessConditions expectedHTTPCodes:(NSArray *)expectedHTTPCodes currentRunCount:(int)currentRunCount completionHandler:(void (^)())completionHandler
{
    if (currentRunCount >= accessConditions.count)
    {
        completionHandler();
    }
    else
    {
        [blob downloadToTextWithAccessCondition:[accessConditions objectAtIndex:currentRunCount] requestOptions:nil operationContext:nil completionHandler:^(NSError *error, NSString *actualBlobText) {
            if (((NSNumber *)[expectedHTTPCodes objectAtIndex:currentRunCount]).intValue == 200)
            {
                XCTAssertNil(error, @"Error in downloading blob.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
            }
            else
            {
                XCTAssertNotNil(error, @"Expected error in blob downlaod did not occur.");
                XCTAssertTrue(((NSNumber *)error.userInfo[AZSCHttpStatusCode]).integerValue == ((NSNumber *)[expectedHTTPCodes objectAtIndex:currentRunCount]).intValue, @"Incorrect HTTP Status code found.");
            }
            
            [self runAccessConditionTestWithBlob:blob expectedBlobText:expectedBlobText accessConditions:accessConditions expectedHTTPCodes:expectedHTTPCodes currentRunCount:(currentRunCount + 1) completionHandler:completionHandler];
        }];
    }
}

-(void)testAccessConditions
{
    AZSTestSemaphore *semaphore = [[AZSTestSemaphore alloc] init];
    NSString *sourceBlobName = [NSString stringWithFormat:@"sampleblob%@", [AZSTestHelpers uniqueName]];
    AZSCloudBlockBlob *sourceBlob = [self.blobContainer blockBlobReferenceFromName:sourceBlobName];
    NSString *blobDataString = @"SampleBlockData";

    [sourceBlob uploadFromText:blobDataString completionHandler:^(NSError *error) {
        XCTAssertNil(error, @"Error in uploading blob.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
        
        NSString *validEtag = sourceBlob.properties.eTag;
        NSString *invalidEtag = @"\"0x8D29EA01E8ACCE4\"";
        
        NSDate *actualLastModified = sourceBlob.properties.lastModified;
        NSDate *dateInPast = [actualLastModified dateByAddingTimeInterval:(-1*60*60*24)];
        NSDate *dateInFuture = [actualLastModified dateByAddingTimeInterval:(1*60*60*24)];
        
        NSMutableArray *accessConditionsToTest = [NSMutableArray arrayWithCapacity:10];
        NSMutableArray *expectedHTTPCodes = [NSMutableArray arrayWithCapacity:10];
        
        [accessConditionsToTest addObject:[[AZSAccessCondition alloc] initWithIfMatchCondition:validEtag]];
        [expectedHTTPCodes addObject:[NSNumber numberWithInt:200]];
        [accessConditionsToTest addObject:[[AZSAccessCondition alloc] initWithIfMatchCondition:invalidEtag]];
        [expectedHTTPCodes addObject:[NSNumber numberWithInt:412]];

        [accessConditionsToTest addObject:[[AZSAccessCondition alloc] initWithIfNoneMatchCondition:validEtag]];
        [expectedHTTPCodes addObject:[NSNumber numberWithInt:304]];
        [accessConditionsToTest addObject:[[AZSAccessCondition alloc] initWithIfNoneMatchCondition:invalidEtag]];
        [expectedHTTPCodes addObject:[NSNumber numberWithInt:200]];
        
        [accessConditionsToTest addObject:[[AZSAccessCondition alloc] initWithIfModifiedSinceCondition:dateInPast]];
        [expectedHTTPCodes addObject:[NSNumber numberWithInt:200]];
        [accessConditionsToTest addObject:[[AZSAccessCondition alloc] initWithIfModifiedSinceCondition:actualLastModified]];
        [expectedHTTPCodes addObject:[NSNumber numberWithInt:304]];
        [accessConditionsToTest addObject:[[AZSAccessCondition alloc] initWithIfModifiedSinceCondition:dateInFuture]];
        [expectedHTTPCodes addObject:[NSNumber numberWithInt:304]];

        [accessConditionsToTest addObject:[[AZSAccessCondition alloc] initWithIfNotModifiedSinceCondition:dateInPast]];
        [expectedHTTPCodes addObject:[NSNumber numberWithInt:412]];
        [accessConditionsToTest addObject:[[AZSAccessCondition alloc] initWithIfNotModifiedSinceCondition:actualLastModified]];
        [expectedHTTPCodes addObject:[NSNumber numberWithInt:200]];
        [accessConditionsToTest addObject:[[AZSAccessCondition alloc] initWithIfNotModifiedSinceCondition:dateInFuture]];
        [expectedHTTPCodes addObject:[NSNumber numberWithInt:200]];

        [self runAccessConditionTestWithBlob:sourceBlob expectedBlobText:blobDataString accessConditions:accessConditionsToTest expectedHTTPCodes:expectedHTTPCodes currentRunCount:0 completionHandler:^{
            [semaphore signal];
        }];
    }];
    [semaphore wait];
}

@end