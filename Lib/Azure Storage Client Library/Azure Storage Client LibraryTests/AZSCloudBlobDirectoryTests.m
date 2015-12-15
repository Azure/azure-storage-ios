// -----------------------------------------------------------------------------------------
// <copyright file="AZSCloudBlobDirectoryTests.m" company="Microsoft">
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
#import "AZSCloudBlobContainer.h"
#import "AZSCloudBlobClient.h"
#import "AZSCloudBlobDirectory.h"
#import "AZSStorageUri.h"
#import "AZSBlobTestBase.h"
#import "AZSResultSegment.h"
#import "AZSCloudBlockBlob.h"
#import "AZSUtil.h"
#import "AZSTestSemaphore.h"
#import "AZSTestHelpers.h"

@interface AZSCloudBlobDirectoryTests : AZSBlobTestBase

@property NSString *containerName;
@property AZSCloudBlobContainer *blobContainer;

@end

@implementation AZSCloudBlobDirectoryTests

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
        [blobContainer deleteContainerIfExistsWithCompletionHandler:^(NSError * error, BOOL deleted) {
            [semaphore signal];
        }];
    }
    @catch (NSException *exception) {
        
    }
    [semaphore wait];
    [super tearDown];
}

- (void)testBlobDirectoryInit
{
    AZSCloudBlobDirectory *directory = [[AZSCloudBlobDirectory alloc] initWithDirectoryName:@"dirName" container:self.blobContainer];
    XCTAssertEqualObjects(@"dirName/", directory.name, @"Directory names do not match.");
    XCTAssertEqual(self.blobContainer, directory.blobContainer, @"Containers do not match.");
    XCTAssertEqual(self.blobClient, directory.client, @"Blob clients do not match.");
    XCTAssertEqualObjects(([self appendStringsAppendFinalDelimiter:YES withDelimiter:self.blobClient.directoryDelimiter strings:@[self.blobContainer.storageUri.primaryUri.absoluteString, @"dirName"]]), directory.storageUri.primaryUri.absoluteString, @"StorageURI does not match.");
    
    directory = [[AZSCloudBlobDirectory alloc] initWithDirectoryName:@"/" container:self.blobContainer];
    XCTAssertEqualObjects(@"/", directory.name, @"Directory names do not match.");
    XCTAssertEqual(self.blobContainer, directory.blobContainer, @"Containers do not match.");
    XCTAssertEqual(self.blobClient, directory.client, @"Blob clients do not match.");
    XCTAssertEqualObjects(([self appendStringsAppendFinalDelimiter:NO withDelimiter:self.blobClient.directoryDelimiter strings:@[self.blobContainer.storageUri.primaryUri.absoluteString, @"/"]]), directory.storageUri.primaryUri.absoluteString, @"StorageURI does not match.");
    
    directory = [[AZSCloudBlobDirectory alloc] initWithDirectoryName:AZSCEmptyString container:self.blobContainer];
    XCTAssertEqualObjects(@"", directory.name, @"Directory names do not match.");
    XCTAssertEqual(self.blobContainer, directory.blobContainer, @"Containers do not match.");
    XCTAssertEqual(self.blobClient, directory.client, @"Blob clients do not match.");
    XCTAssertEqualObjects(([self appendStringsAppendFinalDelimiter:YES withDelimiter:self.blobClient.directoryDelimiter strings:@[self.blobContainer.storageUri.primaryUri.absoluteString]]), directory.storageUri.primaryUri.absoluteString, @"StorageURI does not match.");
}

- (void)testBlobDirectoryNavigation
{
    AZSCloudBlobDirectory *directoryA = [self.blobContainer directoryReferenceFromName:@"a"];
    AZSCloudBlobDirectory *directoryB = [self.blobContainer directoryReferenceFromName:@"b"];
    AZSCloudBlobDirectory *directoryAC = [directoryA subdirectoryReferenceFromName:@"c"];
    AZSCloudBlobDirectory *directoryACD = [directoryAC subdirectoryReferenceFromName:@"d"];
    
    XCTAssertEqualObjects(@"a/", directoryA.name, @"Directory names do not match.");
    XCTAssertEqualObjects(([self appendStringsAppendFinalDelimiter:YES withDelimiter:self.blobClient.directoryDelimiter strings:@[self.blobContainer.storageUri.primaryUri.absoluteString, @"a"]]), directoryA.storageUri.primaryUri.absoluteString, @"StorageURI does not match.");
    XCTAssertEqualObjects(@"b/", directoryB.name, @"Directory names do not match.");
    XCTAssertEqualObjects(([self appendStringsAppendFinalDelimiter:YES withDelimiter:self.blobClient.directoryDelimiter strings:@[self.blobContainer.storageUri.primaryUri.absoluteString,@"b"]]), directoryB.storageUri.primaryUri.absoluteString, @"StorageURI does not match.");
    XCTAssertEqualObjects(@"a/c/", directoryAC.name, @"Directory names do not match.");
    XCTAssertEqualObjects(([self appendStringsAppendFinalDelimiter:YES withDelimiter:self.blobClient.directoryDelimiter strings:@[self.blobContainer.storageUri.primaryUri.absoluteString,@"a",@"c"]]), directoryAC.storageUri.primaryUri.absoluteString, @"StorageURI does not match.");
    XCTAssertEqualObjects(@"a/c/d/", directoryACD.name, @"Directory names do not match.");
    XCTAssertEqualObjects(([self appendStringsAppendFinalDelimiter:YES withDelimiter:self.blobClient.directoryDelimiter strings:@[self.blobContainer.storageUri.primaryUri.absoluteString,@"a",@"c",@"d"]]), directoryACD.storageUri.primaryUri.absoluteString, @"StorageURI does not match.");
    
    AZSCloudBlobDirectory *directoryACDParent = [directoryACD parentReference];
    AZSCloudBlobDirectory *directoryACDParentParent = [directoryACDParent parentReference];
    
    XCTAssertEqualObjects(@"a/c/", directoryACDParent.name, @"Directory names do not match.");
    XCTAssertEqualObjects(([self appendStringsAppendFinalDelimiter:YES withDelimiter:self.blobClient.directoryDelimiter strings:@[self.blobContainer.storageUri.primaryUri.absoluteString,@"a",@"c"]]), directoryACDParent.storageUri.primaryUri.absoluteString, @"StorageURI does not match.");
    XCTAssertEqualObjects(@"a/", directoryACDParentParent.name, @"Directory names do not match.");
    XCTAssertEqualObjects(([self appendStringsAppendFinalDelimiter:YES withDelimiter:self.blobClient.directoryDelimiter strings:@[self.blobContainer.storageUri.primaryUri.absoluteString,@"a"]]), directoryACDParentParent.storageUri.primaryUri.absoluteString, @"StorageURI does not match.");

    AZSCloudBlobDirectory *directoryAParent = [directoryA parentReference];
    AZSCloudBlobDirectory *directoryACDParentParentParent = [directoryACDParentParent parentReference];
    XCTAssertEqualObjects(@"", directoryAParent.name, @"Nonexistent directory non empty.");
    XCTAssertEqualObjects(@"", directoryACDParentParentParent.name, @"Nonexistent directory non empty.");

    XCTAssertEqual(self.blobContainer, directoryA.blobContainer, @"Incorrect blob container returned.");
    XCTAssertEqual(self.blobContainer, directoryB.blobContainer, @"Incorrect blob container returned.");
    XCTAssertEqual(self.blobContainer, directoryAC.blobContainer, @"Incorrect blob container returned.");
    XCTAssertEqual(self.blobContainer, directoryACD.blobContainer, @"Incorrect blob container returned.");
    XCTAssertEqual(self.blobContainer, directoryACDParent.blobContainer, @"Incorrect blob container returned.");
    XCTAssertEqual(self.blobContainer, directoryACDParentParent.blobContainer, @"Incorrect blob container returned.");
}

- (void)testFlatListingInDirectory
{
    AZSTestSemaphore *semaphore = [[AZSTestSemaphore alloc] init];

    AZSCloudBlobDirectory *directoryA = [self.blobContainer directoryReferenceFromName:@"a"];
    AZSCloudBlobDirectory *directoryB = [self.blobContainer directoryReferenceFromName:@"b"];
    AZSCloudBlobDirectory *directoryAC = [directoryA subdirectoryReferenceFromName:@"c"];
    AZSCloudBlobDirectory *directoryACD = [directoryAC subdirectoryReferenceFromName:@"d"];
    
    NSString *blobAShortName = @"bloba";
    NSString *blobBShortName = @"blobb";
    NSString *blobACShortName = @"blobac";
    NSString *blobACDShortName = @"blobacd";
    
    AZSCloudBlockBlob *blobA = [directoryA blockBlobReferenceFromName:blobAShortName];
    AZSCloudBlockBlob *blobB = [directoryB blockBlobReferenceFromName:blobBShortName];
    AZSCloudBlockBlob *blobAC = [directoryAC blockBlobReferenceFromName:blobACShortName];
    AZSCloudBlockBlob *blobACD = [directoryACD blockBlobReferenceFromName:blobACDShortName];
    
    [blobA uploadFromText:@"blobatext" completionHandler:^(NSError *error) {
        XCTAssertNil(error, @"Error in uploading blob.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
        [blobB uploadFromText:@"blobbtext:" completionHandler:^(NSError *error) {
            XCTAssertNil(error, @"Error in uploading blob.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
            [blobAC uploadFromText:@"blobactext:" completionHandler:^(NSError *error) {
                XCTAssertNil(error, @"Error in uploading blob.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
                [blobACD uploadFromText:@"blobacdtext:" completionHandler:^(NSError *error) {
                    XCTAssertNil(error, @"Error in uploading blob.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
                    
                    NSMutableArray *blobArray = [NSMutableArray arrayWithCapacity:3];
                    NSMutableArray *directoryArray = [NSMutableArray arrayWithCapacity:0];
                    [AZSTestHelpers listAllInDirectoryOrContainer:directoryA useFlatBlobListing:YES blobArrayToPopulate:blobArray directoryArrayToPopulate:directoryArray continuationToken:nil prefix:nil blobListingDetails:AZSBlobListingDetailsNone maxResults:5000 completionHandler:^(NSError *error) {
                        XCTAssertNil(error, @"Error in listing blobs.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
                        XCTAssertEqual(3, blobArray.count, @"Incorrect number of blobs listed.");
                        XCTAssertEqual(0, directoryArray.count, @"Incorrect number of directories listed.");
                        XCTAssertEqualObjects(([self appendStringsAppendFinalDelimiter:NO withDelimiter:self.blobClient.directoryDelimiter strings:@[@"a",blobAShortName]]), ((AZSCloudBlob *)blobArray[0]).blobName, @"Blob names do not match.");
                        XCTAssertEqualObjects(([self appendStringsAppendFinalDelimiter:NO withDelimiter:self.blobClient.directoryDelimiter strings:@[@"a",@"c",blobACShortName]]), ((AZSCloudBlob *)blobArray[1]).blobName, @"Blob names do not match.");
                        XCTAssertEqualObjects(([self appendStringsAppendFinalDelimiter:NO withDelimiter:self.blobClient.directoryDelimiter strings:@[@"a",@"c",@"d",blobACDShortName]]), ((AZSCloudBlob *)blobArray[2]).blobName, @"Blob names do not match.");
                        
                        [semaphore signal];
                    }];
                }];
            }];
        }];
    }];
    
    [semaphore wait];
}

- (void)testNonFlatListingInDirectory
{
    AZSTestSemaphore *semaphore = [[AZSTestSemaphore alloc] init];
    
    AZSCloudBlobDirectory *directoryA = [self.blobContainer directoryReferenceFromName:@"a"];
    AZSCloudBlobDirectory *directoryB = [self.blobContainer directoryReferenceFromName:@"b"];
    AZSCloudBlobDirectory *directoryAC = [directoryA subdirectoryReferenceFromName:@"c"];
    AZSCloudBlobDirectory *directoryACD = [directoryAC subdirectoryReferenceFromName:@"d"];
    
    NSString *blobAShortName = @"bloba";
    NSString *blobBShortName = @"blobb";
    NSString *blobACShortName = @"blobac";
    NSString *blobACDShortName = @"blobacd";
    
    AZSCloudBlockBlob *blobA = [directoryA blockBlobReferenceFromName:blobAShortName];
    AZSCloudBlockBlob *blobB = [directoryB blockBlobReferenceFromName:blobBShortName];
    AZSCloudBlockBlob *blobAC = [directoryAC blockBlobReferenceFromName:blobACShortName];
    AZSCloudBlockBlob *blobACD = [directoryACD blockBlobReferenceFromName:blobACDShortName];
    
    [blobA uploadFromText:@"blobatext" completionHandler:^(NSError *error) {
        XCTAssertNil(error, @"Error in uploading blob.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
        [blobB uploadFromText:@"blobbtext:" completionHandler:^(NSError *error) {
            XCTAssertNil(error, @"Error in uploading blob.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
            [blobAC uploadFromText:@"blobactext:" completionHandler:^(NSError *error) {
                XCTAssertNil(error, @"Error in uploading blob.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
                [blobACD uploadFromText:@"blobacdtext:" completionHandler:^(NSError *error) {
                    XCTAssertNil(error, @"Error in uploading blob.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
                    
                    NSMutableArray *blobArray = [NSMutableArray arrayWithCapacity:1];
                    NSMutableArray *directoryArray = [NSMutableArray arrayWithCapacity:1];
                    [AZSTestHelpers listAllInDirectoryOrContainer:directoryA useFlatBlobListing:NO blobArrayToPopulate:blobArray directoryArrayToPopulate:directoryArray continuationToken:nil prefix:nil blobListingDetails:AZSBlobListingDetailsNone maxResults:5000 completionHandler:^(NSError *error) {
                        XCTAssertNil(error, @"Error in listing blobs.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
                        XCTAssertEqual(1, blobArray.count, @"Incorrect number of blobs listed.");
                        XCTAssertEqual(1, directoryArray.count, @"Incorrect number of directories listed.");
                        XCTAssertEqualObjects(([self appendStringsAppendFinalDelimiter:NO withDelimiter:self.blobClient.directoryDelimiter strings:@[@"a",blobAShortName]]), ((AZSCloudBlob *)blobArray[0]).blobName, @"Blob names do not match.");
                        XCTAssertEqualObjects(([self appendStringsAppendFinalDelimiter:YES withDelimiter:self.blobClient.directoryDelimiter strings:@[@"a",@"c"]]), ((AZSCloudBlobDirectory *)directoryArray[0]).name, @"Directory names do not match.");
                        
                        [semaphore signal];
                    }];
                }];
            }];
        }];
    }];
    
    [semaphore wait];
}

- (void)testNonFlatListingInContainer
{
    AZSTestSemaphore *semaphore = [[AZSTestSemaphore alloc] init];
    
    AZSCloudBlobDirectory *directoryA = [self.blobContainer directoryReferenceFromName:@"a"];
    AZSCloudBlobDirectory *directoryB = [self.blobContainer directoryReferenceFromName:@"b"];
    AZSCloudBlobDirectory *directoryAC = [directoryA subdirectoryReferenceFromName:@"c"];
    AZSCloudBlobDirectory *directoryACD = [directoryAC subdirectoryReferenceFromName:@"d"];
    
    NSString *blobaShortName = @"bloba";
    NSString *blobbShortName = @"blobb";
    NSString *blobacShortName = @"blobac";
    NSString *blobacdShortName = @"blobacd";
    
    AZSCloudBlockBlob *blobA = [directoryA blockBlobReferenceFromName:blobaShortName];
    AZSCloudBlockBlob *blobB = [directoryB blockBlobReferenceFromName:blobbShortName];
    AZSCloudBlockBlob *blobAC = [directoryAC blockBlobReferenceFromName:blobacShortName];
    AZSCloudBlockBlob *blobACD = [directoryACD blockBlobReferenceFromName:blobacdShortName];
    
    [blobA uploadFromText:@"blobatext" completionHandler:^(NSError *error) {
        XCTAssertNil(error, @"Error in uploading blob.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
        [blobB uploadFromText:@"blobbtext:" completionHandler:^(NSError *error) {
            XCTAssertNil(error, @"Error in uploading blob.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
            [blobAC uploadFromText:@"blobactext:" completionHandler:^(NSError *error) {
                XCTAssertNil(error, @"Error in uploading blob.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
                [blobACD uploadFromText:@"blobacdtext:" completionHandler:^(NSError *error) {
                    XCTAssertNil(error, @"Error in uploading blob.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
                    
                    NSMutableArray *blobArray = [NSMutableArray arrayWithCapacity:0];
                    NSMutableArray *directoryArray = [NSMutableArray arrayWithCapacity:2];
                    [AZSTestHelpers listAllInDirectoryOrContainer:self.blobContainer useFlatBlobListing:NO blobArrayToPopulate:blobArray directoryArrayToPopulate:directoryArray continuationToken:nil prefix:nil blobListingDetails:AZSBlobListingDetailsNone maxResults:5000 completionHandler:^(NSError *error) {
                        XCTAssertNil(error, @"Error in listing blobs.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
                        XCTAssertEqual(0, blobArray.count, @"Incorrect number of blobs listed.");
                        XCTAssertEqual(2, directoryArray.count, @"Incorrect number of directories listed.");
                        XCTAssertEqualObjects(([self appendStringsAppendFinalDelimiter:YES withDelimiter:self.blobClient.directoryDelimiter strings:@[@"a"]]), ((AZSCloudBlobDirectory *)directoryArray[0]).name, @"Directory names do not match.");
                        XCTAssertEqualObjects(([self appendStringsAppendFinalDelimiter:YES withDelimiter:self.blobClient.directoryDelimiter strings:@[@"b"]]), ((AZSCloudBlobDirectory *)directoryArray[1]).name, @"Directory names do not match.");
                        
                        [semaphore signal];
                    }];
                }];
            }];
        }];
    }];
    
    [semaphore wait];
}

- (void)runTestCreatingBlobsInDirectoryWithDirectory:(AZSCloudBlobDirectory *)directory
{
    AZSTestSemaphore *semaphore = [[AZSTestSemaphore alloc] init];
    
    NSString *blobaShortName = @"bloba";
    AZSCloudBlockBlob *bloba = [directory blockBlobReferenceFromName:blobaShortName];
    NSString *blobText = @"blobText";
    
    [bloba uploadFromText:blobText completionHandler:^(NSError *error) {
        XCTAssertNil(error, @"Error in uploading blob.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
            
        AZSCloudBlockBlob *newBlobA = [self.blobContainer blockBlobReferenceFromName:[directory.name stringByAppendingString:blobaShortName]];
        [newBlobA downloadToTextWithCompletionHandler:^(NSError *error, NSString *newBlobText) {
            XCTAssertNil(error, @"Error in downloading blob.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
            XCTAssertEqualObjects(blobText, newBlobText, @"Blob text does not match.");
                
            NSString *blobbShortName = @"blobb";
            AZSCloudBlockBlob *blobb = [self.blobContainer blockBlobReferenceFromName:[directory.name stringByAppendingString:blobbShortName]];
            [blobb uploadFromText:blobText completionHandler:^(NSError *error) {
                XCTAssertNil(error, @"Error in uploading blob.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
                    
                AZSCloudBlockBlob *newBlobB = [directory blockBlobReferenceFromName:blobbShortName];
                [newBlobB downloadToTextWithCompletionHandler:^(NSError *error, NSString *newBlobText) {
                    XCTAssertNil(error, @"Error in downloading blob.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
                    XCTAssertEqualObjects(blobText, newBlobText, @"Blob text does not match.");
                        
                    [semaphore signal];
                }];
            }];
        }];
    }];
    
    [semaphore wait];
}

- (void)testDifferentDelimiters
{
    NSArray *delimiters = @[@"xyz", @"$", @"@", @"-", @"%", @"/", @"|", @"xyz@$-%/|?", @"", [NSNull null]];
    
    for (__strong NSString *delimiter in delimiters)
    {
        if (delimiter == (NSString *)[NSNull null])
        {
            delimiter = nil;
        }
        
        AZSCloudBlobClient *newClient = [[AZSCloudBlobClient alloc] initWithStorageUri:self.blobClient.storageUri credentials:self.blobClient.credentials];
        newClient.directoryDelimiter = delimiter;
        
        AZSCloudBlobContainer *container = [newClient containerReferenceFromName:self.containerName];
        AZSCloudBlobDirectory *directoryA = [container directoryReferenceFromName:@"a"];
        AZSCloudBlobDirectory *directoryADelimInName = [container directoryReferenceFromName:(delimiter ? [@"a" stringByAppendingString:delimiter] : @"a")];
        AZSCloudBlobDirectory *directoryAB = [directoryA subdirectoryReferenceFromName:@"b"];
        AZSCloudBlobDirectory *directoryABC = [directoryAB subdirectoryReferenceFromName:@"c"];
        AZSCloudBlobDirectory *directoryABCParent = [directoryABC parentReference];
        AZSCloudBlobDirectory *directoryABCParentParent = [directoryABCParent parentReference];
        AZSCloudBlobDirectory *directoryDelimInName = [container directoryReferenceFromName:delimiter];
        AZSCloudBlockBlob *blobABC = [directoryABC blockBlobReferenceFromName:@"blobabc"];
        
        NSString *actualDelimiter = delimiter;
        if (!delimiter.length)
        {
            actualDelimiter = @"/";
        }
    
        XCTAssertEqualObjects(([self appendStringsAppendFinalDelimiter:YES withDelimiter:actualDelimiter strings:@[@"a"]]), directoryA.name, @"Directory names do not match.");
        XCTAssertEqualObjects(([self appendStringsAppendFinalDelimiter:YES withDelimiter:actualDelimiter strings:@[@"a"]]), directoryADelimInName.name, @"Directory names do not match.");
        XCTAssertEqualObjects(([self appendStringsAppendFinalDelimiter:YES withDelimiter:actualDelimiter strings:@[@"a",@"b"]]), directoryAB.name, @"Directory names do not match.");
        XCTAssertEqualObjects(([self appendStringsAppendFinalDelimiter:YES withDelimiter:actualDelimiter strings:@[@"a",@"b",@"c"]]), directoryABC.name, @"Directory names do not match.");
        XCTAssertEqualObjects(([self appendStringsAppendFinalDelimiter:YES withDelimiter:actualDelimiter strings:@[@"a",@"b"]]), directoryABCParent.name, @"Directory names do not match.");
        XCTAssertEqualObjects(([self appendStringsAppendFinalDelimiter:YES withDelimiter:actualDelimiter strings:@[@"a"]]), directoryABCParentParent.name, @"Directory names do not match.");
        XCTAssertEqualObjects(([self appendStringsAppendFinalDelimiter:(delimiter.length ? YES : NO) withDelimiter:actualDelimiter strings:@[]]), directoryDelimInName.name, @"Directory names do not match.");

        XCTAssertEqualObjects(([self appendStringsAppendFinalDelimiter:NO withDelimiter:actualDelimiter strings:@[@"a",@"b",@"c",@"blobabc"]]), blobABC.blobName, @"Blob names do not match.");
    
        [self runTestCreatingBlobsInDirectoryWithDirectory:directoryABC];
    }
}

-(NSString *)appendStringsAppendFinalDelimiter:(BOOL)appendFinal withDelimiter:(NSString *)delimiter strings:(NSArray *)strings
{
    
    NSString *joinedString = [strings componentsJoinedByString:delimiter];
    NSLog(@"joinedString = %@", joinedString);
    if (appendFinal)
    {
        if (joinedString)
        {
            joinedString = [joinedString stringByAppendingString:delimiter];
        }
        else
        {
            joinedString = delimiter;
        }
    }
    return joinedString;
}

@end