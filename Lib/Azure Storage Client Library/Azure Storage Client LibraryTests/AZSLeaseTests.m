// -----------------------------------------------------------------------------------------
// <copyright file="AZSLeaseTests" company="Microsoft">
//    Copyright 2015 Microsoft Corporation
//
//    Licensed under the Apache License, Version 2.0 (the "License");
//    you may not use this file except in compliance with the License.
//    You may obtain a copy of the License at
//      http://www.apache.org/licenses/LICENSE-2.0
//
//    Unless required by applicable law or agreed to in writing, software
//    distributed under the License is distributed on an "AS IS" BASIS,
//    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//    See the License for the specific language governing permissions and
//    limitations under the License.
// </copyright>
// -----------------------------------------------------------------------------------------

#import <XCTest/XCTest.h>
#import "Azure_Storage_Client_Library.h"
#import "AZSBlobTestBase.h"
#import "AZSConstants.h"
#import "AZSTestHelpers.h"
#import "AZSTestSemaphore.h"

@interface AZSLeaseTests : AZSBlobTestBase
@property NSString *containerName;
@property AZSCloudBlobContainer *blobContainer;
@end

@implementation AZSLeaseTests

- (void)setUp
{
    [super setUp];
    
    AZSTestSemaphore *semaphore = [[AZSTestSemaphore alloc] init];
    self.containerName = [[NSString stringWithFormat:@"sampleioscontainer%@", [[[NSUUID UUID] UUIDString] stringByReplacingOccurrencesOfString:@"-" withString:AZSCEmptyString]] lowercaseString];
    self.blobContainer = [self.blobClient containerReferenceFromName:self.containerName];

    [self.blobContainer createContainerIfNotExistsWithCompletionHandler:^(NSError *err, BOOL exists) {
        [semaphore signal];
    }];
    [semaphore wait];
    
    // Put setup code here; it will be run once, before the first test case.
}

- (void)tearDown
{
    // Put teardown code here; it will be run once, after the last test case.
    AZSTestSemaphore *semaphore = [[AZSTestSemaphore alloc] init];

    [self.blobContainer deleteContainerIfExistsWithCompletionHandler:^(NSError *err, BOOL exists) {
        [semaphore signal];
    }];
    [semaphore wait];
    
    [super tearDown];
}

- (void)testContainerLeaseInvalidParams
{
    AZSTestSemaphore *semaphore = [[AZSTestSemaphore alloc] init];
    
    [self.blobContainer acquireLeaseWithLeaseTime:[[NSNumber alloc] initWithInt:100] proposedLeaseId:nil completionHandler:^(NSError* err, NSString* leaseID) {
        XCTAssertNotNil(err, @"Error occurred in acquiring lease.");
        XCTAssertEqualObjects([err.localizedDescription componentsSeparatedByString:@"."][0], @"The operation couldn’t be completed");

        [self.blobContainer breakLeaseWithBreakPeriod:[[NSNumber alloc] initWithInt:100] completionHandler:^(NSError* err, NSNumber* leaseEndTime) {
            XCTAssertNotNil(err, @"Error occurred in breaking lease.");
            XCTAssertEqualObjects([err.localizedDescription componentsSeparatedByString:@"."][0], @"The operation couldn’t be completed");
            [semaphore signal];
        }];
    }];
    [semaphore wait];
}

- (void)testBlobLeaseInvalidParams
{
    AZSTestSemaphore *semaphore = [[AZSTestSemaphore alloc] init];
    AZSCloudBlockBlob *blob = [self.blobContainer blockBlobReferenceFromName:AZSCBlob];
    
    [blob uploadFromText:@"sampleText" completionHandler:^(NSError *error) {
        XCTAssertNil(error, @"Error in blob creation.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
        
        [blob acquireLeaseWithLeaseTime:[[NSNumber alloc] initWithInt:100] proposedLeaseId:nil completionHandler:^(NSError* err, NSString* leaseID) {
            XCTAssertNotNil(err, @"Error in leasing.");
            XCTAssertEqualObjects([err.localizedDescription componentsSeparatedByString:@"."][0], @"The operation couldn’t be completed");
            
            [blob breakLeaseWithBreakPeriod:[[NSNumber alloc] initWithInt:100] completionHandler:^(NSError* err, NSNumber* leaseEndTime) {
                XCTAssertNotNil(err, @"Error in leasing.");
                XCTAssertEqualObjects([err.localizedDescription componentsSeparatedByString:@"."][0], @"The operation couldn’t be completed");
                [semaphore signal];
            }];
        }];
    }];
    [semaphore wait];
}

- (void)testContainerAcquireLease
{
    // Test acquiring a container lease
    __block NSString *leaseID = [[NSUUID UUID] UUIDString];
    AZSTestSemaphore *semaphore = [[AZSTestSemaphore alloc] init];
    NSString *containerName = [[NSString stringWithFormat:@"sampleioscontainer%@", [[[NSUUID UUID] UUIDString] stringByReplacingOccurrencesOfString:@"-" withString:AZSCEmptyString]] lowercaseString];
    AZSCloudBlobContainer *blobContainer = [self.blobClient containerReferenceFromName:containerName];
    
    [blobContainer createContainerIfNotExistsWithCompletionHandler:^(NSError *err, BOOL exists) {
        // 15 seconds
        AZSOperationContext *opCtxt = [[AZSOperationContext alloc] init];
        [blobContainer acquireLeaseWithLeaseTime:[[NSNumber alloc] initWithInt:15] proposedLeaseId:leaseID accessCondition:nil requestOptions:nil operationContext:opCtxt completionHandler:^(NSError* err, NSString* resultLeaseID) {
            XCTAssertNil(err, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
            XCTAssertEqual([(AZSRequestResult *)[[opCtxt requestResults] lastObject] response].statusCode, 201);
            leaseID = resultLeaseID;

            [blobContainer deleteContainerWithCompletionHandler:^(NSError *error) {
                XCTAssertNotNil(error, @"Error in leasing.  Delete call did not fail when it should have.");
                XCTAssertEqual(((NSNumber *)(error.userInfo[AZSCHttpStatusCode])).integerValue, 412, @"Error in leasing, incorrect return code.");

                [blobContainer releaseLeaseWithAccessCondition:[[AZSAccessCondition alloc] initWithLeaseId:leaseID] requestOptions:nil operationContext:opCtxt completionHandler:^(NSError* err) {
                    XCTAssertNil(err, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);

                    [blobContainer deleteContainerIfExistsWithCompletionHandler:^(NSError *err, BOOL exists) {
                        // Infinite
                        NSString *leaseID2 = [[NSUUID UUID] UUIDString];
                        NSString *containerName = [[NSString stringWithFormat:@"sampleioscontainer%@", [[[NSUUID UUID] UUIDString] stringByReplacingOccurrencesOfString:@"-" withString:AZSCEmptyString]] lowercaseString];
                        AZSCloudBlobContainer *blobContainer = [self.blobClient containerReferenceFromName:containerName];
                        [blobContainer createContainerIfNotExistsWithCompletionHandler:^(NSError *err, BOOL exists) {

                            AZSOperationContext *opCtxt = [[AZSOperationContext alloc] init];
                            [blobContainer acquireLeaseWithLeaseTime:nil proposedLeaseId:leaseID2 accessCondition:nil requestOptions:nil operationContext:opCtxt completionHandler:^(NSError* err, NSString* resultLeaseID) {
                                XCTAssertNil(err, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
                                XCTAssertEqual([(AZSRequestResult *)[[opCtxt requestResults] lastObject] response].statusCode, 201);
                                leaseID = resultLeaseID;

                                [blobContainer deleteContainerWithCompletionHandler:^(NSError *error) {
                                    XCTAssertNotNil(error, @"Error in leasing.  Delete call did not fail when it should have.");
                                    XCTAssertEqual(((NSNumber *)(error.userInfo[AZSCHttpStatusCode])).integerValue, 412, @"Error in leasing, incorrect return code.");

                                    [blobContainer createContainerIfNotExistsWithCompletionHandler:^(NSError *err, BOOL exists) {
                                        [blobContainer acquireLeaseWithLeaseTime:nil proposedLeaseId:leaseID2 completionHandler:^(NSError* err, NSString* resultLeaseID) {
                                            XCTAssertNil(err, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
                                            XCTAssertEqualObjects(leaseID, resultLeaseID);

                                            // Cleanup
                                            [blobContainer releaseLeaseWithAccessCondition:[[AZSAccessCondition alloc] initWithLeaseId:leaseID] completionHandler:^void(NSError* err) {
                                                XCTAssertNil(err, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);

                                                [blobContainer deleteContainerIfExistsWithCompletionHandler:^(NSError *err, BOOL exists) {
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
    }];
    [semaphore wait];
}

- (void)testBlobAcquireLease
{
    // Test acquiring a blob lease
    AZSTestSemaphore *semaphore = [[AZSTestSemaphore alloc] init];
    AZSCloudBlockBlob *blob = [self.blobContainer blockBlobReferenceFromName:AZSCBlob];
    
    [blob uploadFromText:@"text" completionHandler:^(NSError *err) {
        XCTAssertNil(err, @"Error in blob creation.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
        
        // 15 seconds
        AZSOperationContext *opCtxt = [[AZSOperationContext alloc] init];
        [blob acquireLeaseWithLeaseTime:[[NSNumber alloc] initWithInt:15] proposedLeaseId:[[NSUUID UUID] UUIDString] accessCondition:nil requestOptions:nil operationContext:opCtxt completionHandler:^(NSError* err, NSString* resultLeaseID) {
            XCTAssertNil(err, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
            XCTAssertEqual([(AZSRequestResult *)[[opCtxt requestResults] lastObject] response].statusCode, 201);
            
            [blob deleteWithCompletionHandler:^(NSError *error) {
                XCTAssertNotNil(error, @"Error in leasing.  Delete call did not fail when it should have.");
                XCTAssertEqual(((NSNumber *)(error.userInfo[AZSCHttpStatusCode])).integerValue, 412, @"Error in leasing, incorrect return code.");
                
                [blob releaseLeaseWithAccessCondition:[[AZSAccessCondition alloc] initWithLeaseId:resultLeaseID] requestOptions:nil operationContext:opCtxt completionHandler:^(NSError* err) {
                    XCTAssertNil(err, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
                    
                    [blob deleteWithCompletionHandler:^(NSError *err) {
                        XCTAssertNil(err, @"Error in blob deletion.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
                        
                        // Infinite
                        NSString *proposedLeaseId = [[NSUUID UUID] UUIDString];
                        [blob uploadFromText:@"text" completionHandler:^(NSError *err) {
                            XCTAssertNil(err, @"Error in blob creation.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
                            
                            AZSOperationContext *opCtxt = [[AZSOperationContext alloc] init];
                            [blob acquireLeaseWithLeaseTime:nil proposedLeaseId:proposedLeaseId accessCondition:nil requestOptions:nil operationContext:opCtxt completionHandler:^(NSError* err, NSString* resultLeaseID) {
                                XCTAssertNil(err, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
                                XCTAssertEqual([(AZSRequestResult *)[[opCtxt requestResults] lastObject] response].statusCode, 201);
                                NSString *leaseID = resultLeaseID;
                                
                                [blob deleteWithCompletionHandler:^(NSError *error) {
                                    XCTAssertNotNil(error, @"Error in leasing.  Delete call did not fail when it should have.");
                                    XCTAssertEqual(((NSNumber *)(error.userInfo[AZSCHttpStatusCode])).integerValue, 412, @"Error in leasing, incorrect return code.");
                                    
                                    [blob acquireLeaseWithLeaseTime:nil proposedLeaseId:proposedLeaseId completionHandler:^(NSError* err, NSString* resultLeaseID) {
                                        XCTAssertNil(err, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
                                        XCTAssertEqualObjects(leaseID, resultLeaseID);
                                        
                                        // Cleanup
                                        [blob releaseLeaseWithAccessCondition:[[AZSAccessCondition alloc] initWithLeaseId:leaseID] completionHandler:^void(NSError* err) {
                                            XCTAssertNil(err, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
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


- (void)testContainerReleaseLease
{
    // Test releasing a container lease.
    AZSTestSemaphore *semaphore = [[AZSTestSemaphore alloc] init];
    
    // 15 seconds
    [self.blobContainer acquireLeaseWithLeaseTime:[[NSNumber alloc] initWithInt:15] proposedLeaseId:[[NSUUID UUID] UUIDString] completionHandler:^(NSError* err, NSString* resultLeaseID) {
        XCTAssertNil(err, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
        
        AZSOperationContext *opCtxt = [[AZSOperationContext alloc] init];
        [self.blobContainer releaseLeaseWithAccessCondition:[[AZSAccessCondition alloc] initWithLeaseId:resultLeaseID] requestOptions:nil operationContext:opCtxt completionHandler:^(NSError* err) {
            XCTAssertNil(err, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
            
            AZSRequestResult *result = (AZSRequestResult *)[[opCtxt requestResults] lastObject];
            XCTAssertEqual([result response].statusCode, 200);
            
            // Unlimited
            [self.blobContainer acquireLeaseWithLeaseTime:nil proposedLeaseId:resultLeaseID completionHandler:^(NSError* err, NSString* resultLeaseID) {
                XCTAssertNil(err, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
                
                AZSOperationContext *opCtxt = [[AZSOperationContext alloc] init];
                [self.blobContainer releaseLeaseWithAccessCondition:[[AZSAccessCondition alloc] initWithLeaseId:resultLeaseID] requestOptions:nil operationContext:opCtxt completionHandler:^(NSError* err) {
                    XCTAssertNil(err, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
                    XCTAssertEqual([(AZSRequestResult *)[[opCtxt requestResults] lastObject] response].statusCode, 200);
                    [semaphore signal];
                }];
            }];
        }];
    }];
    [semaphore wait];
}


- (void)testBlobReleaseLease
{
    // Test releasing a container lease.
    AZSTestSemaphore *semaphore = [[AZSTestSemaphore alloc] init];
    
    AZSCloudBlockBlob *blob = [self.blobContainer blockBlobReferenceFromName:AZSCBlob];
    [blob uploadFromText:@"text" completionHandler:^(NSError *err) {
        XCTAssertNil(err, @"Error in blob creation.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
        
        // 15 seconds
        [blob acquireLeaseWithLeaseTime:[[NSNumber alloc] initWithInt:15] proposedLeaseId:[[NSUUID UUID] UUIDString] completionHandler:^(NSError* err, NSString* resultLeaseID) {
            XCTAssertNil(err, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
            
            AZSOperationContext *opCtxt = [[AZSOperationContext alloc] init];
            [blob releaseLeaseWithAccessCondition:[[AZSAccessCondition alloc] initWithLeaseId:resultLeaseID] requestOptions:nil operationContext:opCtxt completionHandler:^(NSError* err) {
                XCTAssertNil(err, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
                
                AZSRequestResult *result = (AZSRequestResult *)[[opCtxt requestResults] lastObject];
                XCTAssertEqual([result response].statusCode, 200);
                
                // Unlimited
                [blob acquireLeaseWithLeaseTime:nil proposedLeaseId:resultLeaseID completionHandler:^(NSError* err, NSString* resultLeaseID) {
                    XCTAssertNil(err, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
                    
                    AZSOperationContext *opCtxt = [[AZSOperationContext alloc] init];
                    [blob releaseLeaseWithAccessCondition:[[AZSAccessCondition alloc] initWithLeaseId:resultLeaseID] requestOptions:nil operationContext:opCtxt completionHandler:^(NSError* err) {
                        XCTAssertNil(err, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
                        XCTAssertEqual([(AZSRequestResult *)[[opCtxt requestResults] lastObject] response].statusCode, 200);
                        [semaphore signal];
                    }];
                }];
            }];
        }];
    }];
    [semaphore wait];
}

- (void)testContainerBreakLease
{
    // Test breaking a container lease
    AZSTestSemaphore *semaphore = [[AZSTestSemaphore alloc] init];
    
    // 15 seconds
    [self.blobContainer acquireLeaseWithLeaseTime:[[NSNumber alloc] initWithInt:15] proposedLeaseId:[[NSUUID UUID] UUIDString] completionHandler:^(NSError* err, NSString* resultLeaseID) {
        XCTAssertNil(err, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
        
        AZSAccessCondition *condition = [[AZSAccessCondition alloc] initWithLeaseId:resultLeaseID];
        AZSOperationContext *opCtxt = [[AZSOperationContext alloc] init];
        [self.blobContainer breakLeaseWithBreakPeriod:[[NSNumber alloc] initWithInt:0] accessCondition:condition requestOptions:nil operationContext:opCtxt completionHandler:^(NSError* err, NSNumber* leaseBreakTime) {
            XCTAssertNil(err, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
            
            AZSRequestResult *result = (AZSRequestResult *)[[opCtxt requestResults] lastObject];
            XCTAssertEqual([result response].statusCode, 202);
            [NSThread sleepForTimeInterval:15];
            
            // Infinite
            [self.blobContainer acquireLeaseWithLeaseTime:nil proposedLeaseId:resultLeaseID completionHandler:^(NSError* err, NSString* resultLeaseID) {
                XCTAssertNil(err, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
                
                AZSOperationContext *opCtxt = [[AZSOperationContext alloc] init];
                [self.blobContainer breakLeaseWithBreakPeriod:[[NSNumber alloc] initWithInt:0] accessCondition:[[AZSAccessCondition alloc] initWithLeaseId:resultLeaseID] requestOptions:nil operationContext:opCtxt completionHandler:^(NSError* err, NSNumber* leaseBreakTime) {
                    XCTAssertNil(err, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
                    XCTAssertEqual([(AZSRequestResult *)[[opCtxt requestResults] lastObject] response].statusCode, 202);
                    
                    // Cleanup
                    [self.blobContainer releaseLeaseWithAccessCondition:[[AZSAccessCondition alloc] initWithLeaseId:resultLeaseID] completionHandler:^void(NSError* err) {
                        XCTAssertNil(err, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
                        [semaphore signal];
                    }];
                }];
            }];
        }];
    }];
    [semaphore wait];
}

- (void)testBlobBreakLease
{
    // Test breaking a container lease
    AZSTestSemaphore *semaphore = [[AZSTestSemaphore alloc] init];
    
    AZSCloudBlockBlob *blob = [self.blobContainer blockBlobReferenceFromName:AZSCBlob];
    [blob uploadFromText:@"text" completionHandler:^(NSError *err) {
        XCTAssertNil(err, @"Error in blob creation.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
        
        // 15 seconds
        [blob acquireLeaseWithLeaseTime:[[NSNumber alloc] initWithInt:15] proposedLeaseId:[[NSUUID UUID] UUIDString] completionHandler:^(NSError* err, NSString* resultLeaseID) {
            XCTAssertNil(err, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
            
            AZSAccessCondition *condition = [[AZSAccessCondition alloc] initWithLeaseId:resultLeaseID];
            AZSOperationContext *opCtxt = [[AZSOperationContext alloc] init];
            [blob breakLeaseWithBreakPeriod:[[NSNumber alloc] initWithInt:0] accessCondition:condition requestOptions:nil operationContext:opCtxt completionHandler:^(NSError* err, NSNumber* leaseBreakTime) {
                XCTAssertNil(err, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
                
                AZSRequestResult *result = (AZSRequestResult *)[[opCtxt requestResults] lastObject];
                XCTAssertEqual([result response].statusCode, 202);
                [NSThread sleepForTimeInterval:15];
                
                // Infinite
                [blob acquireLeaseWithLeaseTime:nil proposedLeaseId:resultLeaseID completionHandler:^(NSError* err, NSString* resultLeaseID) {
                    XCTAssertNil(err, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
                    
                    AZSOperationContext *opCtxt = [[AZSOperationContext alloc] init];
                    [blob breakLeaseWithBreakPeriod:[[NSNumber alloc] initWithInt:0] accessCondition:[[AZSAccessCondition alloc] initWithLeaseId:resultLeaseID] requestOptions:nil operationContext:opCtxt completionHandler:^(NSError* err, NSNumber* leaseBreakTime) {
                        XCTAssertNil(err, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
                        XCTAssertEqual([(AZSRequestResult *)[[opCtxt requestResults] lastObject] response].statusCode, 202);
                        
                        // Cleanup
                        [blob releaseLeaseWithAccessCondition:[[AZSAccessCondition alloc] initWithLeaseId:resultLeaseID] completionHandler:^void(NSError* err) {
                            XCTAssertNil(err, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
                            [semaphore signal];
                        }];
                    }];
                }];
            }];
        }];
    }];
    [semaphore wait];
}

- (void)testContainerRenewLease
{
    // Test renewing a container lease
    AZSTestSemaphore *semaphore = [[AZSTestSemaphore alloc] init];
    
    // 15 seconds
    [self.blobContainer acquireLeaseWithLeaseTime:[[NSNumber alloc] initWithInt:15] proposedLeaseId:[[NSUUID UUID] UUIDString] completionHandler:^(NSError* err, NSString* resultLeaseID) {
        XCTAssertNil(err, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
        
        AZSAccessCondition *condition = [[AZSAccessCondition alloc] initWithLeaseId:resultLeaseID];
        AZSOperationContext *opCtxt = [[AZSOperationContext alloc] init];
        [self.blobContainer renewLeaseWithAccessCondition:condition requestOptions:nil operationContext:opCtxt completionHandler:^(NSError* err) {
            XCTAssertNil(err, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
            
            AZSRequestResult *result = (AZSRequestResult *)[[opCtxt requestResults] lastObject];
            XCTAssertEqual([result response].statusCode, 200);
            
            [self.blobContainer releaseLeaseWithAccessCondition:condition completionHandler:^(NSError* err) {
                XCTAssertNil(err, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
                
                // Infinite
                [self.blobContainer acquireLeaseWithLeaseTime:nil proposedLeaseId:resultLeaseID completionHandler:^(NSError* err, NSString* resultLeaseID) {
                    XCTAssertNil(err, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
                    
                    AZSOperationContext *opCtxt = [[AZSOperationContext alloc] init];
                    [self.blobContainer renewLeaseWithAccessCondition:[[AZSAccessCondition alloc] initWithLeaseId:resultLeaseID] requestOptions:nil operationContext:opCtxt completionHandler:^(NSError* err) {
                        XCTAssertNil(err, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
                        XCTAssertEqual([(AZSRequestResult *)[[opCtxt requestResults] lastObject] response].statusCode, 200);
                        
                        // Cleanup
                        [self.blobContainer releaseLeaseWithAccessCondition:[[AZSAccessCondition alloc] initWithLeaseId:resultLeaseID] completionHandler:^void(NSError* err) {
                            XCTAssertNil(err, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
                            [semaphore signal];
                        }];
                    }];
                }];
            }];
        }];
    }];
    [semaphore wait];
}

- (void)testBlobRenewLease
{
    // Test renewing a container lease
    AZSTestSemaphore *semaphore = [[AZSTestSemaphore alloc] init];
    AZSCloudBlockBlob *blob = [self.blobContainer blockBlobReferenceFromName:AZSCBlob];
    [blob uploadFromText:@"text" completionHandler:^(NSError *err) {
        XCTAssertNil(err, @"Error in blob creation.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
        
        // 15 seconds
        [blob acquireLeaseWithLeaseTime:[[NSNumber alloc] initWithInt:15] proposedLeaseId:[[NSUUID UUID] UUIDString] completionHandler:^(NSError* err, NSString* resultLeaseID) {
            AZSCloudBlob *blobCopy = [self.blobContainer blockBlobReferenceFromName:AZSCBlob];
            [blobCopy fetchAttributesWithCompletionHandler:^(NSError * err) {
                XCTAssertNil(err, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
                XCTAssertEqual(blobCopy.properties.leaseDuration, AZSLeaseDurationFixed);
                
                AZSAccessCondition *condition = [[AZSAccessCondition alloc] initWithLeaseId:resultLeaseID];
                AZSOperationContext *opCtxt = [[AZSOperationContext alloc] init];
                [blob renewLeaseWithAccessCondition:condition requestOptions:nil operationContext:opCtxt completionHandler:^(NSError* err) {
                    XCTAssertNil(err, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
                    
                    AZSRequestResult *result = (AZSRequestResult *)[[opCtxt requestResults] lastObject];
                    XCTAssertEqual([result response].statusCode, 200);
                    
                    [blob releaseLeaseWithAccessCondition:condition completionHandler:^(NSError* err) {
                        XCTAssertNil(err, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
                        
                        // Infinite
                        [blob acquireLeaseWithLeaseTime:nil proposedLeaseId:resultLeaseID completionHandler:^(NSError* err, NSString* resultLeaseID) {
                            XCTAssertNil(err, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
                            
                            AZSOperationContext *opCtxt = [[AZSOperationContext alloc] init];
                            [blob renewLeaseWithAccessCondition:[[AZSAccessCondition alloc] initWithLeaseId:resultLeaseID] requestOptions:nil operationContext:opCtxt completionHandler:^(NSError* err) {
                                XCTAssertNil(err, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
                                XCTAssertEqual([(AZSRequestResult *)[[opCtxt requestResults] lastObject] response].statusCode, 200);
                                
                                // Cleanup
                                [blob releaseLeaseWithAccessCondition:[[AZSAccessCondition alloc] initWithLeaseId:resultLeaseID] completionHandler:^void(NSError* err) {
                                    XCTAssertNil(err, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
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

- (void)testChangeContainerLease
{
    AZSTestSemaphore *semaphore = [[AZSTestSemaphore alloc] init];
    AZSOperationContext *opCtxt = [[AZSOperationContext alloc] init];
    
    // Get Lease
    [self.blobContainer acquireLeaseWithLeaseTime:nil /* Infinite Lease */ proposedLeaseId:nil accessCondition:nil requestOptions:nil operationContext:opCtxt completionHandler:^(NSError* err, NSString* resultLeaseID) {
        XCTAssertNil(err, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
        NSString *leaseID1 = resultLeaseID;
        XCTAssertEqual([(AZSRequestResult *)[[opCtxt requestResults] lastObject] response].statusCode, 201);
        
        //Change leased state with idempotent change
        NSString *proposedLeaseID1 = [[NSUUID UUID] UUIDString];
        AZSAccessCondition *condition = [[AZSAccessCondition alloc] initWithLeaseId:resultLeaseID];
        [self.blobContainer changeLeaseWithProposedLeaseId:proposedLeaseID1 accessCondition:condition completionHandler:^(NSError * err, NSString *resultLeaseID) {
            XCTAssertNil(err, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
            XCTAssertEqual([(AZSRequestResult *)[[opCtxt requestResults] lastObject] response].statusCode, 201);
            
            [self.blobContainer changeLeaseWithProposedLeaseId:proposedLeaseID1 accessCondition:condition completionHandler:^(NSError * err, NSString *resultLeaseID) {
                XCTAssertNil(err, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
                XCTAssertEqual([(AZSRequestResult *)[[opCtxt requestResults] lastObject] response].statusCode, 201);
                
                //Change lease state with same proposed ID but different lease ID
                [self.blobContainer changeLeaseWithProposedLeaseId:proposedLeaseID1 accessCondition:[[AZSAccessCondition alloc] initWithLeaseId:resultLeaseID] completionHandler:^(NSError * err, NSString *resultLeaseID) {
                    XCTAssertNil(err, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
                    XCTAssertEqual([(AZSRequestResult *)[[opCtxt requestResults] lastObject] response].statusCode, 201);
                    
                    [self.blobContainer changeLeaseWithProposedLeaseId:proposedLeaseID1 accessCondition:[[AZSAccessCondition alloc] initWithLeaseId:leaseID1] completionHandler:^(NSError * err, NSString *resultLeaseID) {
                        XCTAssertNil(err, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
                        XCTAssertEqual([(AZSRequestResult *)[[opCtxt requestResults] lastObject] response].statusCode, 201);
                        
                        //Change lease (wrong lease ID specified)
                        NSString *proposedLeaseID2 = [[NSUUID UUID] UUIDString];
                        [self.blobContainer changeLeaseWithProposedLeaseId:proposedLeaseID2 accessCondition:[[AZSAccessCondition alloc] initWithLeaseId:resultLeaseID] completionHandler:^(NSError * err, NSString *resultLeaseID) {
                            XCTAssertNil(err, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
                            XCTAssertEqual([(AZSRequestResult *)[[opCtxt requestResults] lastObject] response].statusCode, 201);
                            NSString *leaseID2 = resultLeaseID;
                            
                            [self.blobContainer changeLeaseWithProposedLeaseId:proposedLeaseID1 accessCondition:[[AZSAccessCondition alloc] initWithLeaseId:leaseID1] requestOptions:nil operationContext:opCtxt completionHandler:^(NSError * err, NSString *resultLeaseID) {
                                XCTAssertNotNil(err, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
                                XCTAssertEqual([(AZSRequestResult *)[[opCtxt requestResults] lastObject] response].statusCode, 409);
                                
                                // Change released lease
                                [self.blobContainer releaseLeaseWithAccessCondition:[[AZSAccessCondition alloc] initWithLeaseId:leaseID2] completionHandler:^void(NSError* err) {
                                    XCTAssertNil(err, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
                                    
                                    [self.blobContainer changeLeaseWithProposedLeaseId:proposedLeaseID2 accessCondition:[[AZSAccessCondition alloc] initWithLeaseId:leaseID2] requestOptions:nil operationContext:opCtxt completionHandler:^(NSError * err, NSString *resultLeaseID) {
                                        XCTAssertNotNil(err, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
                                        XCTAssertEqual([(AZSRequestResult *)[[opCtxt requestResults] lastObject] response].statusCode, 409);
                                        
                                        // Change a breaking lease (same ID)
                                        [self.blobContainer acquireLeaseWithLeaseTime:nil /* Infinite Lease */ proposedLeaseId:nil completionHandler:^(NSError* err, NSString* resultLeaseID) {
                                            XCTAssertNil(err, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
                                            NSString *leaseID1 = resultLeaseID;
                                            
                                            [self.blobContainer breakLeaseWithBreakPeriod:[[NSNumber alloc] initWithInt:60] completionHandler:^(NSError *err, NSNumber *leaseBreakTime) {
                                                XCTAssertNil(err, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
                                                
                                                [self.blobContainer changeLeaseWithProposedLeaseId:proposedLeaseID1 accessCondition:[[AZSAccessCondition alloc] initWithLeaseId:leaseID1] requestOptions:nil operationContext:opCtxt completionHandler:^(NSError * err, NSString *resultLeaseID) {
                                                    XCTAssertNotNil(err, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
                                                    XCTAssertEqual([(AZSRequestResult *)[[opCtxt requestResults] lastObject] response].statusCode, 409);
                                                    
                                                    // Change broken lease
                                                    [self.blobContainer breakLeaseWithBreakPeriod:[[NSNumber alloc] initWithInt:0] completionHandler:^(NSError *err, NSNumber *leaseBreakTimw) {
                                                        XCTAssertNil(err, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
                                                        
                                                        [self.blobContainer changeLeaseWithProposedLeaseId:proposedLeaseID1 accessCondition:[[AZSAccessCondition alloc] initWithLeaseId:leaseID1] requestOptions:nil operationContext:opCtxt completionHandler:^(NSError * err, NSString *resultLeaseID) {
                                                            XCTAssertNotNil(err, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
                                                            XCTAssertEqual([(AZSRequestResult *)[[opCtxt requestResults] lastObject] response].statusCode, 409);
                                                            
                                                            // Change broken lease (to previous lease)
                                                            [self.blobContainer acquireLeaseWithLeaseTime:nil /* Infinite Lease */ proposedLeaseId:nil completionHandler:^(NSError* err, NSString* resultLeaseID) {
                                                                XCTAssertNil(err, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
                                                                
                                                                [self.blobContainer breakLeaseWithBreakPeriod:[[NSNumber alloc] initWithInt:0] completionHandler:^(NSError *err, NSNumber *leaseBreakTime) {
                                                                    XCTAssertNil(err, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
                                                                    
                                                                    [self.blobContainer changeLeaseWithProposedLeaseId:resultLeaseID accessCondition:[[AZSAccessCondition alloc] initWithLeaseId:resultLeaseID] requestOptions:nil operationContext:opCtxt completionHandler:^(NSError * err, NSString *resultLeaseID) {
                                                                        XCTAssertNotNil(err, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
                                                                        XCTAssertEqual([(AZSRequestResult *)[[opCtxt requestResults] lastObject] response].statusCode, 409);
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
                        }];
                    }];
                }];
            }];
        }];
    }];
    [semaphore wait];
}

- (void)testChangeBlobLease
{
    AZSTestSemaphore *semaphore = [[AZSTestSemaphore alloc] init];
    AZSOperationContext *opCtxt = [[AZSOperationContext alloc] init];
    __block NSString *leaseID1;
    __block NSString *leaseID2;
    
    AZSCloudBlockBlob *blob = [self.blobContainer blockBlobReferenceFromName:AZSCBlob];
    [blob uploadFromText:@"text" completionHandler:^(NSError *err) {
        XCTAssertTrue(err == nil, @"Error in blob creation.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
        
        // Get Lease
        [blob acquireLeaseWithLeaseTime:nil /* Infinite Lease */ proposedLeaseId:nil accessCondition:nil requestOptions:nil operationContext:opCtxt completionHandler:^(NSError* err, NSString* resultLeaseID) {
            XCTAssertTrue(err == nil, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
            XCTAssertTrue([(AZSRequestResult *)[[opCtxt requestResults] lastObject] response].statusCode == 201);
            leaseID1 = resultLeaseID;
            
            //Change leased state with idempotent change
            NSString *proposedLeaseID1 = [[NSUUID UUID] UUIDString];
            AZSAccessCondition *condition = [[AZSAccessCondition alloc] initWithLeaseId:leaseID1];
            [blob changeLeaseWithProposedLeaseId:proposedLeaseID1 accessCondition:condition completionHandler:^(NSError * err, NSString *resultLeaseID) {
                XCTAssertTrue(err == nil, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
                leaseID2 = resultLeaseID;
                
                [blob changeLeaseWithProposedLeaseId:proposedLeaseID1 accessCondition:condition completionHandler:^(NSError * err, NSString *resultLeaseID) {
                    XCTAssertTrue(err == nil, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
                    leaseID2 = resultLeaseID;
                    
                    //Change lease state with same proposed ID but different lease ID
                    [blob changeLeaseWithProposedLeaseId:proposedLeaseID1 accessCondition:[[AZSAccessCondition alloc] initWithLeaseId:leaseID2] completionHandler:^(NSError * err, NSString *resultLeaseID) {
                        XCTAssertTrue(err == nil, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
                        leaseID2 = resultLeaseID;
                        
                        [blob changeLeaseWithProposedLeaseId:proposedLeaseID1 accessCondition:[[AZSAccessCondition alloc] initWithLeaseId:leaseID1] completionHandler:^(NSError * err, NSString *resultLeaseID) {
                            XCTAssertTrue(err == nil, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
                            leaseID2 = resultLeaseID;
                            
                            // Change lease (wrong lease ID specified)
                            NSString *proposedLeaseID2 = [[NSUUID UUID] UUIDString];
                            [blob changeLeaseWithProposedLeaseId:proposedLeaseID2 accessCondition:[[AZSAccessCondition alloc] initWithLeaseId:leaseID2] completionHandler:^(NSError * err, NSString *resultLeaseID) {
                                XCTAssertTrue(err == nil, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
                                leaseID2 = resultLeaseID;
                                
                                [blob changeLeaseWithProposedLeaseId:proposedLeaseID1 accessCondition:[[AZSAccessCondition alloc] initWithLeaseId:leaseID1] requestOptions:nil operationContext:opCtxt completionHandler:^(NSError * err, NSString *resultLeaseID) {
                                    XCTAssertTrue(err != nil, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
                                    XCTAssertTrue([(AZSRequestResult *)[[opCtxt requestResults] lastObject] response].statusCode == 409);
                                    
                                    // Change released lease
                                    [blob releaseLeaseWithAccessCondition:[[AZSAccessCondition alloc] initWithLeaseId:leaseID2] completionHandler:^void(NSError* err) {
                                        XCTAssertTrue(err == nil, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
                                        
                                        [blob changeLeaseWithProposedLeaseId:proposedLeaseID2 accessCondition:[[AZSAccessCondition alloc] initWithLeaseId:leaseID2] requestOptions:nil operationContext:opCtxt completionHandler:^(NSError * err, NSString *resultLeaseID) {
                                            XCTAssertTrue(err != nil, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
                                            XCTAssertTrue([(AZSRequestResult *)[[opCtxt requestResults] lastObject] response].statusCode == 409);
                                            
                                            // Change a breaking lease (same ID)
                                            [blob acquireLeaseWithLeaseTime:nil /* Infinite Lease */ proposedLeaseId:nil completionHandler:^(NSError* err, NSString* resultLeaseID) {
                                                XCTAssertTrue(err == nil, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
                                                leaseID1 = resultLeaseID;
                                                
                                                [blob breakLeaseWithBreakPeriod:[[NSNumber alloc] initWithInt:60] completionHandler:^(NSError *err, NSNumber *leaseBreakTime) {
                                                    XCTAssertTrue(err == nil, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
                                                    
                                                    [blob changeLeaseWithProposedLeaseId:proposedLeaseID1 accessCondition:[[AZSAccessCondition alloc] initWithLeaseId:leaseID1] requestOptions:nil operationContext:opCtxt completionHandler:^(NSError * err, NSString *resultLeaseID) {
                                                        XCTAssertTrue(err != nil, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
                                                        XCTAssertTrue([(AZSRequestResult *)[[opCtxt requestResults] lastObject] response].statusCode == 409);
                                                        
                                                        // Change broken lease
                                                        [blob breakLeaseWithBreakPeriod:[[NSNumber alloc] initWithInt:0] completionHandler:^(NSError *err, NSNumber *leaseBreakTimw) {
                                                            XCTAssertTrue(err == nil, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
                                                            
                                                            [blob changeLeaseWithProposedLeaseId:proposedLeaseID1 accessCondition:[[AZSAccessCondition alloc] initWithLeaseId:leaseID1] requestOptions:nil operationContext:opCtxt completionHandler:^(NSError * err, NSString *resultLeaseID) {
                                                                XCTAssertTrue(err != nil, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
                                                                XCTAssertTrue([(AZSRequestResult *)[[opCtxt requestResults] lastObject] response].statusCode == 409);
                                                                
                                                                // Change broken lease (to previous lease)
                                                                [blob acquireLeaseWithLeaseTime:nil /* Infinite Lease */ proposedLeaseId:nil completionHandler:^(NSError* err, NSString* resultLeaseID) {
                                                                    XCTAssertTrue(err == nil, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
                                                                    leaseID1 = resultLeaseID;
                                                                    
                                                                    [blob breakLeaseWithBreakPeriod:[[NSNumber alloc] initWithInt:0] completionHandler:^(NSError *err, NSNumber *leaseBreakTime) {
                                                                        XCTAssertTrue(err == nil, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
                                                                        
                                                                        [blob changeLeaseWithProposedLeaseId:leaseID1 accessCondition:[[AZSAccessCondition alloc] initWithLeaseId:leaseID1] requestOptions:nil operationContext:opCtxt completionHandler:^(NSError * err, NSString *resultLeaseID) {
                                                                            XCTAssertTrue(err != nil, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
                                                                            XCTAssertTrue([(AZSRequestResult *)[[opCtxt requestResults] lastObject] response].statusCode == 409);
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
                            }];
                        }];
                    }];
                }];
            }];
        }];
    }];
    [semaphore wait];
}

@end