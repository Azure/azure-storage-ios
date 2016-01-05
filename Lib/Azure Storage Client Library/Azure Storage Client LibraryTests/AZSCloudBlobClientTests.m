// -----------------------------------------------------------------------------------------
// <copyright file="AZSCloudBlobClientTests.m" company="Microsoft">
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
#import "AZSConstants.h"
#import "AZSBlobTestBase.h"
#import "AZSTestSemaphore.h"
#import "Azure_Storage_Client_Library.h"

@interface AZSCloudBlobClientTests : AZSBlobTestBase

@property NSMutableArray *containerNames;

@end

@implementation AZSCloudBlobClientTests

- (void)setUp
{
    [super setUp];
    self.containerNames = [NSMutableArray arrayWithCapacity:5];
    // Put setup code here; it will be run once, before the first test case.
}

- (void)tearDown
{
    AZSTestSemaphore *semaphore = [[AZSTestSemaphore alloc] init];

    // Put teardown code here; it will be run once, after the last test case.
    [self deleteContainersWithContainerNames:self.containerNames completionHandler:^() {
        [semaphore signal];
    }];
    [semaphore wait];

    [super tearDown];
}

-(void)deleteContainersWithContainerNames:(NSMutableArray *)containerNames completionHandler:(void (^)())completionHandler
{
    if (containerNames.count <= 0)
    {
        completionHandler();
    }
    else
    {
        AZSCloudBlobContainer *container = [self.blobClient containerReferenceFromName:[containerNames lastObject]];
        [containerNames removeLastObject];
        [container deleteContainerWithCompletionHandler:^(NSError * error) {
            [self deleteContainersWithContainerNames:containerNames completionHandler:completionHandler];
        }];
    }
}

-(void)createContainersWithPrefix:(NSString *)prefix numberToCreate:(NSInteger)numberToCreate arrayToPopulate:(NSMutableArray *)arrayToPopulate completionHandler:(void (^)(NSError *))completionHandler
{
    NSString *containerName = [prefix stringByAppendingString:[NSString stringWithFormat:@"%ld", (long)numberToCreate]];
    [self.containerNames addObject:containerName];
    AZSCloudBlobContainer *container = [self.blobClient containerReferenceFromName:containerName];
    [arrayToPopulate addObject:container];
    [container createContainerWithCompletionHandler:^(NSError * error) {
        if (error)
        {
            completionHandler(error);
        }
        else
        {
            if (numberToCreate == 1)
            {
                completionHandler(nil);
            }
            else
            {
                [self createContainersWithPrefix:prefix numberToCreate:numberToCreate-1 arrayToPopulate:arrayToPopulate completionHandler:completionHandler];
            }
        }
    }];
}

-(void)listAllContainersWithPrefix:(NSString *)prefix arrayToPopulate:(NSMutableArray *)arrayToPopulate containerListingDetails:(AZSContainerListingDetails)containerListingDetails maxResults:(NSInteger)maxResults continuationToken:(AZSContinuationToken *)continuationToken completionHandler:(void (^)(NSError *))completionHandler
{
    [self.blobClient listContainersSegmentedWithContinuationToken:continuationToken prefix:prefix containerListingDetails:containerListingDetails maxResults:maxResults completionHandler:^(NSError *error, AZSContainerResultSegment *results) {
        if (error)
        {
            completionHandler(error);
        }
        else
        {
            [arrayToPopulate addObjectsFromArray:results.results];
            if (results.continuationToken)
            {
                [self listAllContainersWithPrefix:prefix arrayToPopulate:arrayToPopulate containerListingDetails:containerListingDetails maxResults:maxResults continuationToken:results.continuationToken completionHandler:completionHandler];
            }
            else
            {
                completionHandler(nil);
            }
        }
    }];
}

-(void)assertContainerPropertiesWithContainer:(AZSCloudBlobContainer *)container
{
    XCTAssertNotNil(container.properties.eTag, @"Etag property not parsed correctly.");
    XCTAssertNotNil(container.properties.lastModified, @"LastModified property not parsed correctly.");
}

- (void)testListContainersSegmentedPrefixDetailsNone
{
    AZSTestSemaphore *semaphore = [[AZSTestSemaphore alloc] init];

    // Prefix, max results, containerListingDetails, continuation token.
    NSString *containerNamePrefix = [[NSString stringWithFormat:@"sampleioscontainer%@", [[[NSUUID UUID] UUIDString] stringByReplacingOccurrencesOfString:@"-" withString:AZSCEmptyString]] lowercaseString];
    NSInteger numberContainersToCreate = 5;
    __block NSMutableArray *containerArray = [NSMutableArray arrayWithCapacity:numberContainersToCreate];
    [self createContainersWithPrefix:containerNamePrefix numberToCreate:numberContainersToCreate arrayToPopulate:containerArray completionHandler:^(NSError *error) {
        XCTAssertNil(error, @"Error in creating containers.");
        
        NSMutableArray *reversedContainerArray = [NSMutableArray arrayWithCapacity:numberContainersToCreate];
        NSEnumerator *enumerator = [containerArray reverseObjectEnumerator];
        for (id container in enumerator)
        {
            [reversedContainerArray addObject:container];
        }
        containerArray = reversedContainerArray;
        
        ((AZSCloudBlobContainer*)containerArray[0]).metadata[@"sampleMetadataKey"] = @"sampleMetadataValue";
        [(AZSCloudBlobContainer*)containerArray[0] uploadMetadataWithCompletionHandler:^(NSError *error) {
            XCTAssertNil(error, @"Error in uploading container metadata.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
            
            NSMutableArray *containerResultArray = [NSMutableArray arrayWithCapacity:numberContainersToCreate];
            [self listAllContainersWithPrefix:containerNamePrefix arrayToPopulate:containerResultArray containerListingDetails:AZSContainerListingDetailsNone maxResults:15 continuationToken:nil completionHandler:^(NSError *error) {
                XCTAssertNil(error, @"Error in listing containers.");
                
                XCTAssertTrue(containerResultArray.count == numberContainersToCreate, @"Incorrect number of containers returned.");
                
                for (int i = 0; i < containerResultArray.count; i++)
                {
                    AZSCloudBlobContainer* containerResult = (AZSCloudBlobContainer*)containerResultArray[i];
                    XCTAssertTrue([containerResult.name isEqualToString:((AZSCloudBlobContainer*)containerArray[i]).name], @"Incorrect container results.");
                    XCTAssertTrue(containerResult.metadata.count == 0, @"Metadata returned where there should be none.");
                    [self assertContainerPropertiesWithContainer:containerResult];
                }
                
                [semaphore signal];
            }];
        }];
    }];
    [semaphore wait];
}

- (void)testListContainersSegmentedPrefixDetailsAll
{
    AZSTestSemaphore *semaphore = [[AZSTestSemaphore alloc] init];
    
    // Prefix, max results, containerListingDetails, continuation token.
    NSString *containerNamePrefix = [[NSString stringWithFormat:@"sampleioscontainer%@", [[[NSUUID UUID] UUIDString] stringByReplacingOccurrencesOfString:@"-" withString:AZSCEmptyString]] lowercaseString];
    NSInteger numberContainersToCreate = 5;
    __block NSMutableArray *containerArray = [NSMutableArray arrayWithCapacity:numberContainersToCreate];
    [self createContainersWithPrefix:containerNamePrefix numberToCreate:numberContainersToCreate arrayToPopulate:containerArray completionHandler:^(NSError *error) {
        XCTAssertNil(error, @"Error in creating containers.");
        
        NSMutableArray *reversedContainerArray = [NSMutableArray arrayWithCapacity:numberContainersToCreate];
        NSEnumerator *enumerator = [containerArray reverseObjectEnumerator];
        for (id container in enumerator)
        {
            [reversedContainerArray addObject:container];
        }
        containerArray = reversedContainerArray;
        
        ((AZSCloudBlobContainer*)containerArray[0]).metadata[@"sampleMetadataKey"] = @"sampleMetadataValue";
        [(AZSCloudBlobContainer*)containerArray[0] uploadMetadataWithCompletionHandler:^(NSError *error) {
            XCTAssertNil(error, @"Error in uploading container metadata.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
            
            NSMutableArray *containerResultArray = [NSMutableArray arrayWithCapacity:numberContainersToCreate];
            [self listAllContainersWithPrefix:containerNamePrefix arrayToPopulate:containerResultArray containerListingDetails:AZSContainerListingDetailsAll maxResults:15 continuationToken:nil completionHandler:^(NSError *error) {
                XCTAssertNil(error, @"Error in listing containers.");
                
                XCTAssertTrue(containerResultArray.count == numberContainersToCreate, @"Incorrect number of containers returned.");
                XCTAssertTrue([((AZSCloudBlobContainer*)containerResultArray[0]).metadata[@"sampleMetadataKey"] isEqualToString:((AZSCloudBlobContainer*)containerArray[0]).metadata[@"sampleMetadataKey"]], @"Metadata not parsed correctly.");
                
                for (int i = 0; i < containerResultArray.count; i++)
                {
                    AZSCloudBlobContainer* containerResult = (AZSCloudBlobContainer*)containerResultArray[i];
                    XCTAssertTrue([containerResult.name isEqualToString:((AZSCloudBlobContainer*)containerArray[i]).name], @"Incorrect container results.");
                    if (i != 0)
                    {
                        XCTAssertTrue(containerResult.metadata.count == 0, @"Metadata returned where there should be none.");
                    }
                    [self assertContainerPropertiesWithContainer:containerResult];
                }
                
                [semaphore signal];
            }];
        }];
    }];
    [semaphore wait];
}

- (void)testListContainersSegmentedPrefixDetailsMetadata
{
    AZSTestSemaphore *semaphore = [[AZSTestSemaphore alloc] init];
    
    // Prefix, max results, containerListingDetails, continuation token.
    NSString *containerNamePrefix = [[NSString stringWithFormat:@"sampleioscontainer%@", [[[NSUUID UUID] UUIDString] stringByReplacingOccurrencesOfString:@"-" withString:AZSCEmptyString]] lowercaseString];
    NSInteger numberContainersToCreate = 5;
    __block NSMutableArray *containerArray = [NSMutableArray arrayWithCapacity:numberContainersToCreate];
    [self createContainersWithPrefix:containerNamePrefix numberToCreate:numberContainersToCreate arrayToPopulate:containerArray completionHandler:^(NSError *error) {
        XCTAssertNil(error, @"Error in creating containers.");
        
        NSMutableArray *reversedContainerArray = [NSMutableArray arrayWithCapacity:numberContainersToCreate];
        NSEnumerator *enumerator = [containerArray reverseObjectEnumerator];
        for (id container in enumerator)
        {
            [reversedContainerArray addObject:container];
        }
        containerArray = reversedContainerArray;
        
        ((AZSCloudBlobContainer*)containerArray[0]).metadata[@"sampleMetadataKey"] = @"sampleMetadataValue";
        [(AZSCloudBlobContainer*)containerArray[0] uploadMetadataWithCompletionHandler:^(NSError *error) {
            XCTAssertNil(error, @"Error in uploading container metadata.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
            
            NSMutableArray *containerResultArray = [NSMutableArray arrayWithCapacity:numberContainersToCreate];
            [self listAllContainersWithPrefix:containerNamePrefix arrayToPopulate:containerResultArray containerListingDetails:AZSContainerListingDetailsMetadata maxResults:15 continuationToken:nil completionHandler:^(NSError *error) {
                XCTAssertNil(error, @"Error in listing containers.");
                
                XCTAssertTrue(containerResultArray.count == numberContainersToCreate, @"Incorrect number of containers returned.");
                XCTAssertTrue([((AZSCloudBlobContainer*)containerResultArray[0]).metadata[@"sampleMetadataKey"] isEqualToString:((AZSCloudBlobContainer*)containerArray[0]).metadata[@"sampleMetadataKey"]], @"Metadata not parsed correctly.");
                
                for (int i = 0; i < containerResultArray.count; i++)
                {
                    AZSCloudBlobContainer* containerResult = (AZSCloudBlobContainer*)containerResultArray[i];
                    XCTAssertTrue([containerResult.name isEqualToString:((AZSCloudBlobContainer*)containerArray[i]).name], @"Incorrect container results.");
                    if (i != 0)
                    {
                        XCTAssertTrue(containerResult.metadata.count == 0, @"Metadata returned where there should be none.");
                    }
                    [self assertContainerPropertiesWithContainer:containerResult];
                }
                
                [semaphore signal];
            }];
        }];
    }];
    [semaphore wait];
}

- (void)testListContainersSegmentedMaxResultsAndContinuationToken
{
    AZSTestSemaphore *semaphore = [[AZSTestSemaphore alloc] init];
    
    // Prefix, max results, containerListingDetails, continuation token.
    NSString *containerNamePrefix = [[NSString stringWithFormat:@"sampleioscontainer%@", [[[NSUUID UUID] UUIDString] stringByReplacingOccurrencesOfString:@"-" withString:AZSCEmptyString]] lowercaseString];
    NSInteger numberContainersToCreate = 5;
    __block NSMutableArray *containerArray = [NSMutableArray arrayWithCapacity:numberContainersToCreate];
    [self createContainersWithPrefix:containerNamePrefix numberToCreate:numberContainersToCreate arrayToPopulate:containerArray completionHandler:^(NSError *error) {
        XCTAssertNil(error, @"Error in creating containers.");
        
        NSMutableArray *reversedContainerArray = [NSMutableArray arrayWithCapacity:numberContainersToCreate];
        NSEnumerator *enumerator = [containerArray reverseObjectEnumerator];
        for (id container in enumerator)
        {
            [reversedContainerArray addObject:container];
        }
        containerArray = reversedContainerArray;
        
        ((AZSCloudBlobContainer*)containerArray[0]).metadata[@"sampleMetadataKey"] = @"sampleMetadataValue";
        [(AZSCloudBlobContainer*)containerArray[0] uploadMetadataWithCompletionHandler:^(NSError *error) {
            XCTAssertNil(error, @"Error in uploading container metadata.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
            
            NSMutableArray *containerResultArray = [NSMutableArray arrayWithCapacity:numberContainersToCreate];
            [self listAllContainersWithPrefix:containerNamePrefix arrayToPopulate:containerResultArray containerListingDetails:AZSContainerListingDetailsAll maxResults:1 continuationToken:nil completionHandler:^(NSError *error) {
                XCTAssertNil(error, @"Error in listing containers.");
                
                XCTAssertTrue(containerResultArray.count == numberContainersToCreate, @"Incorrect number of containers returned.");
                XCTAssertTrue([((AZSCloudBlobContainer*)containerResultArray[0]).metadata[@"sampleMetadataKey"] isEqualToString:((AZSCloudBlobContainer*)containerArray[0]).metadata[@"sampleMetadataKey"]], @"Metadata not parsed correctly.");
                
                for (int i = 0; i < containerResultArray.count; i++)
                {
                    AZSCloudBlobContainer* containerResult = (AZSCloudBlobContainer*)containerResultArray[i];
                    XCTAssertTrue([containerResult.name isEqualToString:((AZSCloudBlobContainer*)containerArray[i]).name], @"Incorrect container results.");
                    if (i != 0)
                    {
                        XCTAssertTrue(containerResult.metadata.count == 0, @"Metadata returned where there should be none.");
                    }
                    [self assertContainerPropertiesWithContainer:containerResult];
                }
                
                [semaphore signal];
            }];
            
        }];
        
    }];
    [semaphore wait];
}

@end