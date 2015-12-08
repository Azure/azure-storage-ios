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
#import "AZSTestHelpers.h"

@interface AZSLeaseTests : AZSBlobTestBase
@property NSString *containerName;
@property AZSCloudBlobContainer *blobContainer;

@end

@implementation AZSLeaseTests

- (void)setUp
{
    [super setUp];
    
    // Put setup code here; it will be run once, before the first test case.
    self.containerName = [[NSString stringWithFormat:@"sampleioscontainer%@",[[[NSUUID UUID] UUIDString] stringByReplacingOccurrencesOfString:@"-" withString:@""]] lowercaseString];
    self.blobContainer = [self.blobClient containerReferenceFromName:self.containerName];
    [self createContainerIfNotExists:self.blobContainer];
}

- (void)tearDown
{
    // Put teardown code here; it will be run once, after the last test case.
    AZSCloudBlobContainer *blobContainer = [self.blobClient containerReferenceFromName:self.containerName];
    [self deleteContainerIfExists:blobContainer];
    
    [super tearDown];
}

- (void) atomicOnLock:(NSCondition*)lock donePtr:(BOOL*)donePtr operation:(void(^)())operation
{
    XCTAssertFalse(*donePtr);
    [lock lock];
    if (operation) {
        operation();
    }
    (*donePtr) = YES;
    [lock signal];
    [lock unlock];
}

- (void) barrierOnLock:(NSCondition*)lock donePtr:(BOOL*)donePtr
{
    [lock lock];
    while (!(*donePtr)) {
        [lock wait];
    }
    (*donePtr) = NO;
    [lock unlock];
}

- (void)createContainerIfNotExists:(AZSCloudBlobContainer*)blobContainer
{
    NSCondition *lock = [[NSCondition alloc] init];
    __block BOOL done = NO;
    @try {
        // Best-effort
        // TODO: Change to create if not exists once that's implemented.
        
        [blobContainer createContainerWithCompletionHandler:^(NSError * error) {
            [self atomicOnLock:lock donePtr:&done operation:nil];
        }];
    }
    @catch (NSException *exception) {
    }
    
    [self barrierOnLock:lock donePtr:&done];
}

- (void)deleteContainerIfExists:(AZSCloudBlobContainer*)blobContainer
{
    NSCondition *lock = [[NSCondition alloc] init];
    __block BOOL done = NO;
    @try {
        // Best-effort cleanup
        // TODO: Change to delete if exists once that's implemented.
        
        [blobContainer deleteContainerWithCompletionHandler:^(NSError * error) {
            [self atomicOnLock:lock donePtr:&done operation:nil];
        }];
    }
    @catch (NSException *exception) {
    }
    
    [self barrierOnLock:lock donePtr:&done];
}

- (void)testContainerLeaseInvalidParams
{
    NSCondition *lock = [[NSCondition alloc] init];
    __block BOOL done = NO;
    
    [self.blobContainer acquireLeaseWithLeaseTime:[[NSNumber alloc] initWithInt:100] proposedLeaseId:nil completionHandler:^(NSError* err, NSString* leaseID){
        [self atomicOnLock:lock donePtr:&done operation:^{
            XCTAssertTrue(err != nil, @"Error in leasing.");
            NSString *erd = [err.localizedDescription componentsSeparatedByString:@"."][0];

            XCTAssertTrue([erd isEqualToString:@"The operation couldn’t be completed"]);
        }];
    }];
    
    [self barrierOnLock:lock donePtr:&done];
    
    [self.blobContainer breakLeaseWithBreakPeriod:[[NSNumber alloc] initWithInt:100] completionHandler:^(NSError* err, NSNumber* leaseEndTime){
        [self atomicOnLock:lock donePtr:&done operation:^void{
            XCTAssertTrue(err != nil, @"Error in leasing.");
            NSString *erd = [err.localizedDescription componentsSeparatedByString:@"."][0];
            XCTAssertTrue([erd isEqualToString:@"The operation couldn’t be completed"]);
        }];
    }];
    [self barrierOnLock:lock donePtr:&done];
}

- (void)testBlobLeaseInvalidParams
{
    NSCondition *lock = [[NSCondition alloc] init];
    __block BOOL done = NO;
    
    AZSCloudBlockBlob *blob = [self.blobContainer blockBlobReferenceFromName:@"blob"];
    [blob uploadFromText:@"sampleText" completionHandler:^(NSError *error) {
        [self atomicOnLock:lock donePtr:&done operation:^{
            XCTAssertTrue(error == nil, @"Error in blob creation.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
        }];
    }];
    [self barrierOnLock:lock donePtr:&done];
    
    [blob acquireLeaseWithLeaseTime:[[NSNumber alloc] initWithInt:100] proposedLeaseId:nil completionHandler:^(NSError* err, NSString* leaseID){
        [self atomicOnLock:lock donePtr:&done operation:^{
            XCTAssertTrue(err != nil, @"Error in leasing.");
            NSString *erd = [err.localizedDescription componentsSeparatedByString:@"."][0];
            
            XCTAssertTrue([erd isEqualToString:@"The operation couldn’t be completed"]);
        }];
    }];
    
    [self barrierOnLock:lock donePtr:&done];
    
    [blob breakLeaseWithBreakPeriod:[[NSNumber alloc] initWithInt:100] completionHandler:^(NSError* err, NSNumber* leaseEndTime){
        [self atomicOnLock:lock donePtr:&done operation:^void{
            XCTAssertTrue(err != nil, @"Error in leasing.");
            NSString *erd = [err.localizedDescription componentsSeparatedByString:@"."][0];
            XCTAssertTrue([erd isEqualToString:@"The operation couldn’t be completed"]);
        }];
    }];
    [self barrierOnLock:lock donePtr:&done];
}

- (void)testContainerAcquireLease
{
    // Test acquiring a container lease
    __block NSString *leaseID = [[NSUUID UUID] UUIDString];
    NSCondition *lock = [[NSCondition alloc] init];
    __block BOOL done = NO;
    NSString *containerName = [[NSString stringWithFormat:@"sampleioscontainer%@",[[[NSUUID UUID] UUIDString] stringByReplacingOccurrencesOfString:@"-" withString:@""]] lowercaseString];
    AZSCloudBlobContainer *blobContainer = [self.blobClient containerReferenceFromName:containerName];
    [self createContainerIfNotExists:blobContainer];
    
    // 15 seconds
    AZSOperationContext *opCtxt = [[AZSOperationContext alloc] init];
    [blobContainer acquireLeaseWithLeaseTime:[[NSNumber alloc] initWithInt:15] proposedLeaseId:leaseID accessCondition:nil requestOptions:nil operationContext:opCtxt completionHandler:^(NSError* err, NSString* resultLeaseID){
        [self atomicOnLock:lock donePtr:&done operation:^void{
            XCTAssertTrue(err == nil, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
            leaseID = resultLeaseID;
        }];
    }];
    [self barrierOnLock:lock donePtr:&done];
    
    AZSRequestResult *result = (AZSRequestResult *)[[opCtxt requestResults] lastObject];
    XCTAssertTrue([result response].statusCode == 201);
    
    [blobContainer deleteContainerWithCompletionHandler:^(NSError *error) {
        [self atomicOnLock:lock donePtr:&done operation:^void{
            XCTAssertTrue(error != nil, @"Error in leasing.  Delete call did not fail when it should have.");
            XCTAssertTrue(((NSNumber *)(error.userInfo[@"HTTP Status Code"])).integerValue == 412, @"Error in leasing, incorrect return code.");
        }];
    }];
    [self barrierOnLock:lock donePtr:&done];
    
    AZSAccessCondition *condition = [[AZSAccessCondition alloc] initWithLeaseId:leaseID];
    [blobContainer releaseLeaseWithAccessCondition:condition requestOptions:nil operationContext:opCtxt completionHandler:^(NSError* err){
        [self atomicOnLock:lock donePtr:&done operation:^void{
            XCTAssertTrue(err == nil, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
        }];
    }];
    [self barrierOnLock:lock donePtr:&done];
    [self deleteContainerIfExists:blobContainer];
    
    // Infinite
    __block NSString *leaseID2 = [[NSUUID UUID] UUIDString];
    containerName = [[NSString stringWithFormat:@"sampleioscontainer%@",[[[NSUUID UUID] UUIDString] stringByReplacingOccurrencesOfString:@"-" withString:@""]] lowercaseString];
    blobContainer = [self.blobClient containerReferenceFromName:containerName];
    [self createContainerIfNotExists:blobContainer];
    opCtxt = [[AZSOperationContext alloc] init];
    [blobContainer acquireLeaseWithLeaseTime:nil proposedLeaseId:leaseID2 accessCondition:nil requestOptions:nil operationContext:opCtxt completionHandler:^(NSError* err, NSString* resultLeaseID){
        [self atomicOnLock:lock donePtr:&done operation:^void{
            XCTAssertTrue(err == nil, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
            leaseID = resultLeaseID;
        }];
    }];
    [self barrierOnLock:lock donePtr:&done];
    result = (AZSRequestResult *)[[opCtxt requestResults] lastObject];
    XCTAssertTrue([result response].statusCode == 201);
    
    [blobContainer deleteContainerWithCompletionHandler:^(NSError *error) {
        [self atomicOnLock:lock donePtr:&done operation:^void{
            XCTAssertTrue(error != nil, @"Error in leasing.  Delete call did not fail when it should have.");
            XCTAssertTrue(((NSNumber *)(error.userInfo[@"HTTP Status Code"])).integerValue == 412, @"Error in leasing, incorrect return code.");
        }];
    }];
    [self barrierOnLock:lock donePtr:&done];
    
    [self createContainerIfNotExists:blobContainer];
    [blobContainer acquireLeaseWithLeaseTime:nil proposedLeaseId:leaseID2 completionHandler:^(NSError* err, NSString* resultLeaseID){
        [self atomicOnLock:lock donePtr:&done operation:^void{
            XCTAssertTrue(err == nil, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
            leaseID2 = resultLeaseID;
        }];
    }];
    [self barrierOnLock:lock donePtr:&done];
    XCTAssertTrue([leaseID isEqualToString:leaseID2]);
    
    // Cleanup
    condition = [[AZSAccessCondition alloc] initWithLeaseId:leaseID];
    [blobContainer releaseLeaseWithAccessCondition:condition completionHandler:^void(NSError* err){
        [self atomicOnLock:lock donePtr:&done operation:^void{
            XCTAssertTrue(err == nil, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
        }];
    }];
    [self deleteContainerIfExists:blobContainer];
}

- (void)testBlobAcquireLease
{
    AZSCloudBlockBlob *blob = [self.blobContainer blockBlobReferenceFromName:@"blob"];
    // Test acquiring a blob lease
    __block NSString *leaseID = [[NSUUID UUID] UUIDString];
    NSCondition *lock = [[NSCondition alloc] init];
    __block BOOL done = NO;
    
    [blob uploadFromText:@"text" completionHandler:^(NSError *err) {
        [self atomicOnLock:lock donePtr:&done operation:^void{
            XCTAssertTrue(err == nil, @"Error in blob creation.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
        }];
    }];
    [self barrierOnLock:lock donePtr:&done];

    // 15 seconds
    AZSOperationContext *opCtxt = [[AZSOperationContext alloc] init];
    [blob acquireLeaseWithLeaseTime:[[NSNumber alloc] initWithInt:15] proposedLeaseId:leaseID accessCondition:nil requestOptions:nil operationContext:opCtxt completionHandler:^(NSError* err, NSString* resultLeaseID){
        [self atomicOnLock:lock donePtr:&done operation:^void{
            XCTAssertTrue(err == nil, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
            leaseID = resultLeaseID;
        }];
    }];
    [self barrierOnLock:lock donePtr:&done];
    
    AZSRequestResult *result = (AZSRequestResult *)[[opCtxt requestResults] lastObject];
    XCTAssertTrue([result response].statusCode == 201);
    
    [blob deleteWithCompletionHandler:^(NSError *error) {
        [self atomicOnLock:lock donePtr:&done operation:^void{
            XCTAssertTrue(error != nil, @"Error in leasing.  Delete call did not fail when it should have.");
            XCTAssertTrue(((NSNumber *)(error.userInfo[@"HTTP Status Code"])).integerValue == 412, @"Error in leasing, incorrect return code.");
        }];
    }];
    [self barrierOnLock:lock donePtr:&done];
    
    AZSAccessCondition *condition = [[AZSAccessCondition alloc] initWithLeaseId:leaseID];
    [blob releaseLeaseWithAccessCondition:condition requestOptions:nil operationContext:opCtxt completionHandler:^(NSError* err){
        [self atomicOnLock:lock donePtr:&done operation:^void{
            XCTAssertTrue(err == nil, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
        }];
    }];
    [self barrierOnLock:lock donePtr:&done];
    
    [blob deleteWithCompletionHandler:^(NSError *err) {
        [self atomicOnLock:lock donePtr:&done operation:^void{
            XCTAssertTrue(err == nil, @"Error in blob deletion.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
        }];
    }];
    [self barrierOnLock:lock donePtr:&done];
    
    // Infinite
    __block NSString *leaseID2 = [[NSUUID UUID] UUIDString];

    [blob uploadFromText:@"text" completionHandler:^(NSError *err) {
        [self atomicOnLock:lock donePtr:&done operation:^void{
            XCTAssertTrue(err == nil, @"Error in blob creation.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
        }];
    }];
    [self barrierOnLock:lock donePtr:&done];

    opCtxt = [[AZSOperationContext alloc] init];
    [blob acquireLeaseWithLeaseTime:nil proposedLeaseId:leaseID2 accessCondition:nil requestOptions:nil operationContext:opCtxt completionHandler:^(NSError* err, NSString* resultLeaseID){
        [self atomicOnLock:lock donePtr:&done operation:^void{
            XCTAssertTrue(err == nil, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
            leaseID = resultLeaseID;
        }];
    }];
    [self barrierOnLock:lock donePtr:&done];
    result = (AZSRequestResult *)[[opCtxt requestResults] lastObject];
    XCTAssertTrue([result response].statusCode == 201);
    
    [blob deleteWithCompletionHandler:^(NSError *error) {
        [self atomicOnLock:lock donePtr:&done operation:^void{
            XCTAssertTrue(error != nil, @"Error in leasing.  Delete call did not fail when it should have.");
            XCTAssertTrue(((NSNumber *)(error.userInfo[@"HTTP Status Code"])).integerValue == 412, @"Error in leasing, incorrect return code.");
        }];
    }];
    [self barrierOnLock:lock donePtr:&done];
    
    [blob acquireLeaseWithLeaseTime:nil proposedLeaseId:leaseID2 completionHandler:^(NSError* err, NSString* resultLeaseID){
        [self atomicOnLock:lock donePtr:&done operation:^void{
            XCTAssertTrue(err == nil, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
            leaseID2 = resultLeaseID;
        }];
    }];
    [self barrierOnLock:lock donePtr:&done];
    XCTAssertTrue([leaseID isEqualToString:leaseID2]);
    
    // Cleanup
    condition = [[AZSAccessCondition alloc] initWithLeaseId:leaseID];
    [blob releaseLeaseWithAccessCondition:condition completionHandler:^void(NSError* err){
        [self atomicOnLock:lock donePtr:&done operation:^void{
            XCTAssertTrue(err == nil, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
        }];
    }];
}


- (void)testContainerReleaseLease
{
    // Test releasing a container lease.
    __block NSString *leaseID = [[NSUUID UUID] UUIDString];
    NSCondition *lock = [[NSCondition alloc] init];
    __block BOOL done = NO;
    
    // 15 seconds
    [self.blobContainer acquireLeaseWithLeaseTime:[[NSNumber alloc] initWithInt:15] proposedLeaseId:leaseID completionHandler:^(NSError* err, NSString* resultLeaseID){
        [self atomicOnLock:lock donePtr:&done operation:^void{
            XCTAssertTrue(err == nil, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
            leaseID = resultLeaseID;
        }];
    }];
    [self barrierOnLock:lock donePtr:&done];
    
    AZSAccessCondition *condition = [[AZSAccessCondition alloc] initWithLeaseId:leaseID];
    AZSOperationContext *opCtxt = [[AZSOperationContext alloc] init];
    [self.blobContainer releaseLeaseWithAccessCondition:condition requestOptions:nil operationContext:opCtxt completionHandler:^(NSError* err){
        [self atomicOnLock:lock donePtr:&done operation:^void{
            XCTAssertTrue(err == nil, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
        }];
    }];
    [self barrierOnLock:lock donePtr:&done];
    AZSRequestResult *result = (AZSRequestResult *)[[opCtxt requestResults] lastObject];
    XCTAssertTrue([result response].statusCode == 200);
    
    // Unlimited
    [self.blobContainer acquireLeaseWithLeaseTime:nil proposedLeaseId:leaseID completionHandler:^(NSError* err, NSString* resultLeaseID){
        [self atomicOnLock:lock donePtr:&done operation:^void{
            XCTAssertTrue(err == nil, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
            leaseID = resultLeaseID;
        }];
    }];
    [self barrierOnLock:lock donePtr:&done];
    
    condition = [[AZSAccessCondition alloc] initWithLeaseId:leaseID];
    opCtxt = [[AZSOperationContext alloc] init];
    [self.blobContainer releaseLeaseWithAccessCondition:condition requestOptions:nil operationContext:opCtxt completionHandler:^(NSError* err){
        [self atomicOnLock:lock donePtr:&done operation:^void{
            XCTAssertTrue(err == nil, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
        }];
    }];
    [self barrierOnLock:lock donePtr:&done];
    result = (AZSRequestResult *)[[opCtxt requestResults] lastObject];
    NSLog(@"%ld", (long)[result response].statusCode);
    XCTAssertTrue([result response].statusCode == 200);
}


- (void)testBlobReleaseLease
{
    // Test releasing a container lease.
    __block NSString *leaseID = [[NSUUID UUID] UUIDString];
    NSCondition *lock = [[NSCondition alloc] init];
    __block BOOL done = NO;
    
    AZSCloudBlockBlob *blob = [self.blobContainer blockBlobReferenceFromName:@"blob"];
    [blob uploadFromText:@"text" completionHandler:^(NSError *err) {
        [self atomicOnLock:lock donePtr:&done operation:^void{
            XCTAssertTrue(err == nil, @"Error in blob creation.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
        }];
    }];
    [self barrierOnLock:lock donePtr:&done];
    
    // 15 seconds
    [blob acquireLeaseWithLeaseTime:[[NSNumber alloc] initWithInt:15] proposedLeaseId:leaseID completionHandler:^(NSError* err, NSString* resultLeaseID){
        [self atomicOnLock:lock donePtr:&done operation:^void{
            XCTAssertTrue(err == nil, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
            leaseID = resultLeaseID;
        }];
    }];
    [self barrierOnLock:lock donePtr:&done];
    
    AZSAccessCondition *condition = [[AZSAccessCondition alloc] initWithLeaseId:leaseID];
    AZSOperationContext *opCtxt = [[AZSOperationContext alloc] init];
    [blob releaseLeaseWithAccessCondition:condition requestOptions:nil operationContext:opCtxt completionHandler:^(NSError* err){
        [self atomicOnLock:lock donePtr:&done operation:^void{
            XCTAssertTrue(err == nil, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
        }];
    }];
    [self barrierOnLock:lock donePtr:&done];
    AZSRequestResult *result = (AZSRequestResult *)[[opCtxt requestResults] lastObject];
    XCTAssertTrue([result response].statusCode == 200);
    
    // Unlimited
    [blob acquireLeaseWithLeaseTime:nil proposedLeaseId:leaseID completionHandler:^(NSError* err, NSString* resultLeaseID){
        [self atomicOnLock:lock donePtr:&done operation:^void{
            XCTAssertTrue(err == nil, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
            leaseID = resultLeaseID;
        }];
    }];
    [self barrierOnLock:lock donePtr:&done];
    
    condition = [[AZSAccessCondition alloc] initWithLeaseId:leaseID];
    opCtxt = [[AZSOperationContext alloc] init];
    [blob releaseLeaseWithAccessCondition:condition requestOptions:nil operationContext:opCtxt completionHandler:^(NSError* err){
        [self atomicOnLock:lock donePtr:&done operation:^void{
            XCTAssertTrue(err == nil, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
        }];
    }];
    [self barrierOnLock:lock donePtr:&done];
    result = (AZSRequestResult *)[[opCtxt requestResults] lastObject];
    NSLog(@"%ld", (long)[result response].statusCode);
    XCTAssertTrue([result response].statusCode == 200);
}

- (void)testContainerBreakLease
{
    // Test breaking a container lease
    __block NSString *leaseID = [[NSUUID UUID] UUIDString];
    NSCondition *lock = [[NSCondition alloc] init];
    __block BOOL done = NO;
    
    // 15 seconds
    [self.blobContainer acquireLeaseWithLeaseTime:[[NSNumber alloc] initWithInt:15] proposedLeaseId:leaseID completionHandler:^(NSError* err, NSString* resultLeaseID){
        [self atomicOnLock:lock donePtr:&done operation:^void{
            XCTAssertTrue(err == nil, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
            leaseID = resultLeaseID;
        }];
    }];
    [self barrierOnLock:lock donePtr:&done];
    
    AZSAccessCondition *condition = [[AZSAccessCondition alloc] initWithLeaseId:leaseID];
    AZSOperationContext *opCtxt = [[AZSOperationContext alloc] init];
    [self.blobContainer breakLeaseWithBreakPeriod:[[NSNumber alloc] initWithInt:0] accessCondition:condition requestOptions:nil operationContext:opCtxt completionHandler:^(NSError* err, NSNumber* leaseBreakTime){
        [self atomicOnLock:lock donePtr:&done operation:^void{
            XCTAssertTrue(err == nil, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
        }];
    }];
    [self barrierOnLock:lock donePtr:&done];
    AZSRequestResult *result = (AZSRequestResult *)[[opCtxt requestResults] lastObject];
    XCTAssertTrue([result response].statusCode == 202);
    [NSThread sleepForTimeInterval:15];
    
    // Infinite
    [self.blobContainer acquireLeaseWithLeaseTime:nil proposedLeaseId:leaseID completionHandler:^(NSError* err, NSString* resultLeaseID){
        [self atomicOnLock:lock donePtr:&done operation:^void{
            XCTAssertTrue(err == nil, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
            leaseID = resultLeaseID;
        }];
    }];
    [self barrierOnLock:lock donePtr:&done];
    
    condition = [[AZSAccessCondition alloc] initWithLeaseId:leaseID];
    opCtxt = [[AZSOperationContext alloc] init];
    [self.blobContainer breakLeaseWithBreakPeriod:[[NSNumber alloc] initWithInt:0] accessCondition:condition requestOptions:nil operationContext:opCtxt completionHandler:^(NSError* err, NSNumber* leaseBreakTime){
        [self atomicOnLock:lock donePtr:&done operation:^void{
            XCTAssertTrue(err == nil, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
        }];
    }];
    [self barrierOnLock:lock donePtr:&done];
    result = (AZSRequestResult *)[[opCtxt requestResults] lastObject];
    XCTAssertTrue([result response].statusCode == 202);
    
    // Cleanup
    condition = [[AZSAccessCondition alloc] initWithLeaseId:leaseID];
    [self.blobContainer releaseLeaseWithAccessCondition:condition completionHandler:^void(NSError* err){
        [self atomicOnLock:lock donePtr:&done operation:^void{
            XCTAssertTrue(err == nil, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
        }];
    }];
    [self barrierOnLock:lock donePtr:&done];
}

- (void)testBlobBreakLease
{
    // Test breaking a container lease
    __block NSString *leaseID = [[NSUUID UUID] UUIDString];
    NSCondition *lock = [[NSCondition alloc] init];
    __block BOOL done = NO;
    
    AZSCloudBlockBlob *blob = [self.blobContainer blockBlobReferenceFromName:@"blob"];
    [blob uploadFromText:@"text" completionHandler:^(NSError *err) {
        [self atomicOnLock:lock donePtr:&done operation:^void{
            XCTAssertTrue(err == nil, @"Error in blob creation.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
        }];
    }];
    [self barrierOnLock:lock donePtr:&done];
    
    // 15 seconds
    [blob acquireLeaseWithLeaseTime:[[NSNumber alloc] initWithInt:15] proposedLeaseId:leaseID completionHandler:^(NSError* err, NSString* resultLeaseID){
        [self atomicOnLock:lock donePtr:&done operation:^void{
            XCTAssertTrue(err == nil, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
            leaseID = resultLeaseID;
        }];
    }];
    [self barrierOnLock:lock donePtr:&done];
    
    AZSAccessCondition *condition = [[AZSAccessCondition alloc] initWithLeaseId:leaseID];
    AZSOperationContext *opCtxt = [[AZSOperationContext alloc] init];
    [blob breakLeaseWithBreakPeriod:[[NSNumber alloc] initWithInt:0] accessCondition:condition requestOptions:nil operationContext:opCtxt completionHandler:^(NSError* err, NSNumber* leaseBreakTime){
        [self atomicOnLock:lock donePtr:&done operation:^void{
            XCTAssertTrue(err == nil, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
        }];
    }];
    [self barrierOnLock:lock donePtr:&done];
    AZSRequestResult *result = (AZSRequestResult *)[[opCtxt requestResults] lastObject];
    XCTAssertTrue([result response].statusCode == 202);
    [NSThread sleepForTimeInterval:15];
    
    // Infinite
    [blob acquireLeaseWithLeaseTime:nil proposedLeaseId:leaseID completionHandler:^(NSError* err, NSString* resultLeaseID){
        [self atomicOnLock:lock donePtr:&done operation:^void{
            XCTAssertTrue(err == nil, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
            leaseID = resultLeaseID;
        }];
    }];
    [self barrierOnLock:lock donePtr:&done];
    
    condition = [[AZSAccessCondition alloc] initWithLeaseId:leaseID];
    opCtxt = [[AZSOperationContext alloc] init];
    [blob breakLeaseWithBreakPeriod:[[NSNumber alloc] initWithInt:0] accessCondition:condition requestOptions:nil operationContext:opCtxt completionHandler:^(NSError* err, NSNumber* leaseBreakTime){
        [self atomicOnLock:lock donePtr:&done operation:^void{
            XCTAssertTrue(err == nil, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
        }];
    }];
    [self barrierOnLock:lock donePtr:&done];
    result = (AZSRequestResult *)[[opCtxt requestResults] lastObject];
    XCTAssertTrue([result response].statusCode == 202);
    
    // Cleanup
    condition = [[AZSAccessCondition alloc] initWithLeaseId:leaseID];
    [blob releaseLeaseWithAccessCondition:condition completionHandler:^void(NSError* err){
        [self atomicOnLock:lock donePtr:&done operation:^void{
            XCTAssertTrue(err == nil, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
        }];
    }];
    [self barrierOnLock:lock donePtr:&done];
}

- (void)testContainerRenewLease
{
    // Test renewing a container lease
    __block NSString *leaseID = [[NSUUID UUID] UUIDString];
    NSCondition *lock = [[NSCondition alloc] init];
    __block BOOL done = NO;
    
    // 15 seconds
    [self.blobContainer acquireLeaseWithLeaseTime:[[NSNumber alloc] initWithInt:15] proposedLeaseId:leaseID completionHandler:^(NSError* err, NSString* resultLeaseID){
        [self atomicOnLock:lock donePtr:&done operation:^void{
            XCTAssertTrue(err == nil, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
            leaseID = resultLeaseID;
        }];
    }];
    [self barrierOnLock:lock donePtr:&done];
    
    AZSAccessCondition *condition = [[AZSAccessCondition alloc] initWithLeaseId:leaseID];
    AZSOperationContext *opCtxt = [[AZSOperationContext alloc] init];
    [self.blobContainer renewLeaseWithAccessCondition:condition requestOptions:nil operationContext:opCtxt completionHandler:^(NSError* err){
        [self atomicOnLock:lock donePtr:&done operation:^(void){
            XCTAssertTrue(err == nil, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
        }];
    }];
    [self barrierOnLock:lock donePtr:&done];
    AZSRequestResult *result = (AZSRequestResult *)[[opCtxt requestResults] lastObject];
    XCTAssertTrue([result response].statusCode == 200);
    
    [self.blobContainer releaseLeaseWithAccessCondition:condition completionHandler:^(NSError* err){
        [self atomicOnLock:lock donePtr:&done operation:^(void){
            XCTAssertTrue(err == nil, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
        }];
    }];
    [self barrierOnLock:lock donePtr:&done];
    
    // Infinite
    [self.blobContainer acquireLeaseWithLeaseTime:nil proposedLeaseId:leaseID completionHandler:^(NSError* err, NSString* resultLeaseID){
        [self atomicOnLock:lock donePtr:&done operation:^void{
            XCTAssertTrue(err == nil, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
            leaseID = resultLeaseID;
        }];
    }];
    [self barrierOnLock:lock donePtr:&done];
    
    condition = [[AZSAccessCondition alloc] initWithLeaseId:leaseID];
    opCtxt = [[AZSOperationContext alloc] init];
    [self.blobContainer renewLeaseWithAccessCondition:condition requestOptions:nil operationContext:opCtxt completionHandler:^(NSError* err){
        [self atomicOnLock:lock donePtr:&done operation:^(void){
            XCTAssertTrue(err == nil, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
        }];
    }];
    [self barrierOnLock:lock donePtr:&done];
    result = (AZSRequestResult *)[[opCtxt requestResults] lastObject];
    XCTAssertTrue([result response].statusCode == 200);
    
    // Cleanup
    condition = [[AZSAccessCondition alloc] initWithLeaseId:leaseID];
    [self.blobContainer releaseLeaseWithAccessCondition:condition completionHandler:^void(NSError* err){
        [self atomicOnLock:lock donePtr:&done operation:^void{
            XCTAssertTrue(err == nil, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
        }];
    }];
    [self barrierOnLock:lock donePtr:&done];
}

- (void)testBlobRenewLease
{
    // Test renewing a container lease
    __block NSString *leaseID = [[NSUUID UUID] UUIDString];
    NSCondition *lock = [[NSCondition alloc] init];
    __block BOOL done = NO;
    
    AZSCloudBlockBlob *blob = [self.blobContainer blockBlobReferenceFromName:@"blob"];
    [blob uploadFromText:@"text" completionHandler:^(NSError *err) {
        [self atomicOnLock:lock donePtr:&done operation:^void{
            XCTAssertTrue(err == nil, @"Error in blob creation.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
        }];
    }];
    [self barrierOnLock:lock donePtr:&done];
    
    // 15 seconds
    [blob acquireLeaseWithLeaseTime:[[NSNumber alloc] initWithInt:15] proposedLeaseId:leaseID completionHandler:^(NSError* err, NSString* resultLeaseID){
        [self atomicOnLock:lock donePtr:&done operation:^void{
            XCTAssertTrue(err == nil, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
            leaseID = resultLeaseID;
        }];
    }];
    [self barrierOnLock:lock donePtr:&done];
    
    AZSAccessCondition *condition = [[AZSAccessCondition alloc] initWithLeaseId:leaseID];
    AZSOperationContext *opCtxt = [[AZSOperationContext alloc] init];
    [blob renewLeaseWithAccessCondition:condition requestOptions:nil operationContext:opCtxt completionHandler:^(NSError* err){
        [self atomicOnLock:lock donePtr:&done operation:^(void){
            XCTAssertTrue(err == nil, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
        }];
    }];
    [self barrierOnLock:lock donePtr:&done];
    AZSRequestResult *result = (AZSRequestResult *)[[opCtxt requestResults] lastObject];
    XCTAssertTrue([result response].statusCode == 200);
    
    [blob releaseLeaseWithAccessCondition:condition completionHandler:^(NSError* err){
        [self atomicOnLock:lock donePtr:&done operation:^(void){
            XCTAssertTrue(err == nil, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
        }];
    }];
    [self barrierOnLock:lock donePtr:&done];
    
    // Infinite
    [blob acquireLeaseWithLeaseTime:nil proposedLeaseId:leaseID completionHandler:^(NSError* err, NSString* resultLeaseID){
        [self atomicOnLock:lock donePtr:&done operation:^void{
            XCTAssertTrue(err == nil, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
            leaseID = resultLeaseID;
        }];
    }];
    [self barrierOnLock:lock donePtr:&done];
    
    condition = [[AZSAccessCondition alloc] initWithLeaseId:leaseID];
    opCtxt = [[AZSOperationContext alloc] init];
    [blob renewLeaseWithAccessCondition:condition requestOptions:nil operationContext:opCtxt completionHandler:^(NSError* err){
        [self atomicOnLock:lock donePtr:&done operation:^(void){
            XCTAssertTrue(err == nil, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
        }];
    }];
    [self barrierOnLock:lock donePtr:&done];
    result = (AZSRequestResult *)[[opCtxt requestResults] lastObject];
    XCTAssertTrue([result response].statusCode == 200);
    
    // Cleanup
    condition = [[AZSAccessCondition alloc] initWithLeaseId:leaseID];
    [blob releaseLeaseWithAccessCondition:condition completionHandler:^void(NSError* err){
        [self atomicOnLock:lock donePtr:&done operation:^void{
            XCTAssertTrue(err == nil, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
        }];
    }];
    [self barrierOnLock:lock donePtr:&done];
}

- (void)testChangeContainerLease
{
    NSCondition *lock = [[NSCondition alloc] init];
    __block BOOL done = NO;
    __block NSString *leaseID1;
    __block NSString *leaseID2;
    AZSOperationContext *opCtxt = [[AZSOperationContext alloc] init];
    
    // Get Lease
    [self.blobContainer acquireLeaseWithLeaseTime:nil /* Infinite Lease */ proposedLeaseId:nil accessCondition:nil requestOptions:nil operationContext:opCtxt completionHandler:^(NSError* err, NSString* resultLeaseID){
        [self atomicOnLock:lock donePtr:&done operation:^void{
            XCTAssertTrue(err == nil, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
            leaseID1 = resultLeaseID;
        }];
    }];
    [self barrierOnLock:lock donePtr:&done];
    AZSRequestResult *result = (AZSRequestResult *)[[opCtxt requestResults] lastObject];
    XCTAssertTrue([result response].statusCode == 201);
    
    //Change leased state with idempotent change
    NSString *proposedLeaseID1 = [[NSUUID UUID] UUIDString];
    AZSAccessCondition *condition = [[AZSAccessCondition alloc] initWithLeaseId:leaseID1];
    [self.blobContainer changeLeaseWithProposedLeaseId:proposedLeaseID1 accessCondition:condition completionHandler:^(NSError * err, NSString *resultLeaseID){
        [self atomicOnLock:lock donePtr:&done operation:^(void){
            XCTAssertTrue(err == nil, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
            leaseID2 = resultLeaseID;
        }];
    }];
    
    [self barrierOnLock:lock donePtr:&done];
    [self.blobContainer changeLeaseWithProposedLeaseId:proposedLeaseID1 accessCondition:condition completionHandler:^(NSError * err, NSString *resultLeaseID){
        [self atomicOnLock:lock donePtr:&done operation:^(void){
            XCTAssertTrue(err == nil, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
            leaseID2 = resultLeaseID;
        }];
    }];
    [self barrierOnLock:lock donePtr:&done];
    
    //Change lease state with same proposed ID but different lease ID
    condition = [[AZSAccessCondition alloc] initWithLeaseId:leaseID2];
    [self.blobContainer changeLeaseWithProposedLeaseId:proposedLeaseID1 accessCondition:condition completionHandler:^(NSError * err, NSString *resultLeaseID){
        [self atomicOnLock:lock donePtr:&done operation:^(void){
            XCTAssertTrue(err == nil, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
            leaseID2 = resultLeaseID;
        }];
    }];
    [self barrierOnLock:lock donePtr:&done];
    
    condition = [[AZSAccessCondition alloc] initWithLeaseId:leaseID1];
    [self.blobContainer changeLeaseWithProposedLeaseId:proposedLeaseID1 accessCondition:condition completionHandler:^(NSError * err, NSString *resultLeaseID){
        [self atomicOnLock:lock donePtr:&done operation:^(void){
            XCTAssertTrue(err == nil, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
            leaseID2 = resultLeaseID;
        }];
    }];
    [self barrierOnLock:lock donePtr:&done];
    
    //Change lease (wrong lease ID specified)
    NSString *proposedLeaseID2 = [[NSUUID UUID] UUIDString];
    condition = [[AZSAccessCondition alloc] initWithLeaseId:leaseID2];
    [self.blobContainer changeLeaseWithProposedLeaseId:proposedLeaseID2 accessCondition:condition completionHandler:^(NSError * err, NSString *resultLeaseID){
        [self atomicOnLock:lock donePtr:&done operation:^(void){
            XCTAssertTrue(err == nil, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
            leaseID2 = resultLeaseID;
        }];
    }];
    [self barrierOnLock:lock donePtr:&done];
    
    condition = [[AZSAccessCondition alloc] initWithLeaseId:leaseID1];
    [self.blobContainer changeLeaseWithProposedLeaseId:proposedLeaseID1 accessCondition:condition requestOptions:nil operationContext:opCtxt completionHandler:^(NSError * err, NSString *resultLeaseID){
        [self atomicOnLock:lock donePtr:&done operation:^(void){
            XCTAssertTrue(err != nil, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
        }];
    }];
    [self barrierOnLock:lock donePtr:&done];
    result = (AZSRequestResult *)[[opCtxt requestResults] lastObject];
    XCTAssertTrue([result response].statusCode == 409);
    
    // Change released lease
    condition = [[AZSAccessCondition alloc] initWithLeaseId:leaseID2];
    [self.blobContainer releaseLeaseWithAccessCondition:condition completionHandler:^void(NSError* err){
        [self atomicOnLock:lock donePtr:&done operation:^void{
            XCTAssertTrue(err == nil, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
        }];
    }];
    [self barrierOnLock:lock donePtr:&done];
    
    condition = [[AZSAccessCondition alloc] initWithLeaseId:leaseID2];
    [self.blobContainer changeLeaseWithProposedLeaseId:proposedLeaseID2 accessCondition:condition requestOptions:nil operationContext:opCtxt completionHandler:^(NSError * err, NSString *resultLeaseID){
        [self atomicOnLock:lock donePtr:&done operation:^(void){
            XCTAssertTrue(err != nil, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
        }];
    }];
    [self barrierOnLock:lock donePtr:&done];
    result = (AZSRequestResult *)[[opCtxt requestResults] lastObject];
    XCTAssertTrue([result response].statusCode == 409);
    
    // Change a breaking lease (same ID)
    [self.blobContainer acquireLeaseWithLeaseTime:nil /* Infinite Lease */ proposedLeaseId:nil completionHandler:^(NSError* err, NSString* resultLeaseID){
        [self atomicOnLock:lock donePtr:&done operation:^void{
            XCTAssertTrue(err == nil, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
            leaseID1 = resultLeaseID;
        }];
    }];
    [self barrierOnLock:lock donePtr:&done];
    
    [self.blobContainer breakLeaseWithBreakPeriod:[[NSNumber alloc] initWithInt:60] completionHandler:^(NSError *err, NSNumber *leaseBreakTime) {
        [self atomicOnLock:lock donePtr:&done operation:^(void){
            XCTAssertTrue(err == nil, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
        }];
    }];
    [self barrierOnLock:lock donePtr:&done];
    
    condition = [[AZSAccessCondition alloc] initWithLeaseId:leaseID1];
    [self.blobContainer changeLeaseWithProposedLeaseId:proposedLeaseID1 accessCondition:condition requestOptions:nil operationContext:opCtxt completionHandler:^(NSError * err, NSString *resultLeaseID){
        [self atomicOnLock:lock donePtr:&done operation:^(void){
            XCTAssertTrue(err != nil, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
        }];
    }];
    [self barrierOnLock:lock donePtr:&done];
    result = (AZSRequestResult *)[[opCtxt requestResults] lastObject];
    XCTAssertTrue([result response].statusCode == 409);
    
    // Change broken lease
    [self.blobContainer breakLeaseWithBreakPeriod:[[NSNumber alloc] initWithInt:0] completionHandler:^(NSError *err, NSNumber *leaseBreakTimw) {
        [self atomicOnLock:lock donePtr:&done operation:^(void){
            XCTAssertTrue(err == nil, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
        }];
    }];
    [self barrierOnLock:lock donePtr:&done];
    
    condition = [[AZSAccessCondition alloc] initWithLeaseId:leaseID1];
    [self.blobContainer changeLeaseWithProposedLeaseId:proposedLeaseID1 accessCondition:condition requestOptions:nil operationContext:opCtxt completionHandler:^(NSError * err, NSString *resultLeaseID){
        [self atomicOnLock:lock donePtr:&done operation:^(void){
            XCTAssertTrue(err != nil, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
        }];
    }];
    [self barrierOnLock:lock donePtr:&done];
    result = (AZSRequestResult *)[[opCtxt requestResults] lastObject];
    XCTAssertTrue([result response].statusCode == 409);
    
    // Change broken lease (to previous lease)
    [self.blobContainer acquireLeaseWithLeaseTime:nil /* Infinite Lease */ proposedLeaseId:nil completionHandler:^(NSError* err, NSString* resultLeaseID){
        [self atomicOnLock:lock donePtr:&done operation:^void{
            XCTAssertTrue(err == nil, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
            leaseID1 = resultLeaseID;
        }];
    }];
    [self barrierOnLock:lock donePtr:&done];
    
    [self.blobContainer breakLeaseWithBreakPeriod:[[NSNumber alloc] initWithInt:0] completionHandler:^(NSError *err, NSNumber *leaseBreakTime) {
        [self atomicOnLock:lock donePtr:&done operation:^(void){
            XCTAssertTrue(err == nil, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
        }];
    }];
    [self barrierOnLock:lock donePtr:&done];
    
    condition = [[AZSAccessCondition alloc] initWithLeaseId:leaseID1];
    [self.blobContainer changeLeaseWithProposedLeaseId:leaseID1 accessCondition:condition requestOptions:nil operationContext:opCtxt completionHandler:^(NSError * err, NSString *resultLeaseID){
        [self atomicOnLock:lock donePtr:&done operation:^(void){
            XCTAssertTrue(err != nil, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
        }];
    }];
    [self barrierOnLock:lock donePtr:&done];
    result = (AZSRequestResult *)[[opCtxt requestResults] lastObject];
    XCTAssertTrue([result response].statusCode == 409);
}

- (void)testChangeBlobLease
{
    NSCondition *lock = [[NSCondition alloc] init];
    __block BOOL done = NO;
    __block NSString *leaseID1;
    __block NSString *leaseID2;
    AZSOperationContext *opCtxt = [[AZSOperationContext alloc] init];
    
    AZSCloudBlockBlob *blob = [self.blobContainer blockBlobReferenceFromName:@"blob"];
    [blob uploadFromText:@"text" completionHandler:^(NSError *err) {
        [self atomicOnLock:lock donePtr:&done operation:^void{
            XCTAssertTrue(err == nil, @"Error in blob creation.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
        }];
    }];
    [self barrierOnLock:lock donePtr:&done];
    
    // Get Lease
    [blob acquireLeaseWithLeaseTime:nil /* Infinite Lease */ proposedLeaseId:nil accessCondition:nil requestOptions:nil operationContext:opCtxt completionHandler:^(NSError* err, NSString* resultLeaseID){
        [self atomicOnLock:lock donePtr:&done operation:^void{
            XCTAssertTrue(err == nil, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
            leaseID1 = resultLeaseID;
        }];
    }];
    [self barrierOnLock:lock donePtr:&done];
    AZSRequestResult *result = (AZSRequestResult *)[[opCtxt requestResults] lastObject];
    XCTAssertTrue([result response].statusCode == 201);
    
    //Change leased state with idempotent change
    NSString *proposedLeaseID1 = [[NSUUID UUID] UUIDString];
    AZSAccessCondition *condition = [[AZSAccessCondition alloc] initWithLeaseId:leaseID1];
    [blob changeLeaseWithProposedLeaseId:proposedLeaseID1 accessCondition:condition completionHandler:^(NSError * err, NSString *resultLeaseID){
        [self atomicOnLock:lock donePtr:&done operation:^(void){
            XCTAssertTrue(err == nil, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
            leaseID2 = resultLeaseID;
        }];
    }];
    
    [self barrierOnLock:lock donePtr:&done];
    [blob changeLeaseWithProposedLeaseId:proposedLeaseID1 accessCondition:condition completionHandler:^(NSError * err, NSString *resultLeaseID){
        [self atomicOnLock:lock donePtr:&done operation:^(void){
            XCTAssertTrue(err == nil, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
            leaseID2 = resultLeaseID;
        }];
    }];
    [self barrierOnLock:lock donePtr:&done];
    
    //Change lease state with same proposed ID but different lease ID
    condition = [[AZSAccessCondition alloc] initWithLeaseId:leaseID2];
    [blob changeLeaseWithProposedLeaseId:proposedLeaseID1 accessCondition:condition completionHandler:^(NSError * err, NSString *resultLeaseID){
        [self atomicOnLock:lock donePtr:&done operation:^(void){
            XCTAssertTrue(err == nil, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
            leaseID2 = resultLeaseID;
        }];
    }];
    [self barrierOnLock:lock donePtr:&done];
    
    condition = [[AZSAccessCondition alloc] initWithLeaseId:leaseID1];
    [blob changeLeaseWithProposedLeaseId:proposedLeaseID1 accessCondition:condition completionHandler:^(NSError * err, NSString *resultLeaseID){
        [self atomicOnLock:lock donePtr:&done operation:^(void){
            XCTAssertTrue(err == nil, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
            leaseID2 = resultLeaseID;
        }];
    }];
    [self barrierOnLock:lock donePtr:&done];
    
    //Change lease (wrong lease ID specified)
    NSString *proposedLeaseID2 = [[NSUUID UUID] UUIDString];
    condition = [[AZSAccessCondition alloc] initWithLeaseId:leaseID2];
    [blob changeLeaseWithProposedLeaseId:proposedLeaseID2 accessCondition:condition completionHandler:^(NSError * err, NSString *resultLeaseID){
        [self atomicOnLock:lock donePtr:&done operation:^(void){
            XCTAssertTrue(err == nil, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
            leaseID2 = resultLeaseID;
        }];
    }];
    [self barrierOnLock:lock donePtr:&done];
    
    condition = [[AZSAccessCondition alloc] initWithLeaseId:leaseID1];
    [blob changeLeaseWithProposedLeaseId:proposedLeaseID1 accessCondition:condition requestOptions:nil operationContext:opCtxt completionHandler:^(NSError * err, NSString *resultLeaseID){
        [self atomicOnLock:lock donePtr:&done operation:^(void){
            XCTAssertTrue(err != nil, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
        }];
    }];
    [self barrierOnLock:lock donePtr:&done];
    result = (AZSRequestResult *)[[opCtxt requestResults] lastObject];
    XCTAssertTrue([result response].statusCode == 409);
    
    // Change released lease
    condition = [[AZSAccessCondition alloc] initWithLeaseId:leaseID2];
    [blob releaseLeaseWithAccessCondition:condition completionHandler:^void(NSError* err){
        [self atomicOnLock:lock donePtr:&done operation:^void{
            XCTAssertTrue(err == nil, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
        }];
    }];
    [self barrierOnLock:lock donePtr:&done];
    
    condition = [[AZSAccessCondition alloc] initWithLeaseId:leaseID2];
    [blob changeLeaseWithProposedLeaseId:proposedLeaseID2 accessCondition:condition requestOptions:nil operationContext:opCtxt completionHandler:^(NSError * err, NSString *resultLeaseID){
        [self atomicOnLock:lock donePtr:&done operation:^(void){
            XCTAssertTrue(err != nil, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
        }];
    }];
    [self barrierOnLock:lock donePtr:&done];
    result = (AZSRequestResult *)[[opCtxt requestResults] lastObject];
    XCTAssertTrue([result response].statusCode == 409);
    
    // Change a breaking lease (same ID)
    [blob acquireLeaseWithLeaseTime:nil /* Infinite Lease */ proposedLeaseId:nil completionHandler:^(NSError* err, NSString* resultLeaseID){
        [self atomicOnLock:lock donePtr:&done operation:^void{
            XCTAssertTrue(err == nil, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
            leaseID1 = resultLeaseID;
        }];
    }];
    [self barrierOnLock:lock donePtr:&done];
    
    [blob breakLeaseWithBreakPeriod:[[NSNumber alloc] initWithInt:60] completionHandler:^(NSError *err, NSNumber *leaseBreakTime) {
        [self atomicOnLock:lock donePtr:&done operation:^(void){
            XCTAssertTrue(err == nil, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
        }];
    }];
    [self barrierOnLock:lock donePtr:&done];
    
    condition = [[AZSAccessCondition alloc] initWithLeaseId:leaseID1];
    [blob changeLeaseWithProposedLeaseId:proposedLeaseID1 accessCondition:condition requestOptions:nil operationContext:opCtxt completionHandler:^(NSError * err, NSString *resultLeaseID){
        [self atomicOnLock:lock donePtr:&done operation:^(void){
            XCTAssertTrue(err != nil, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
        }];
    }];
    [self barrierOnLock:lock donePtr:&done];
    result = (AZSRequestResult *)[[opCtxt requestResults] lastObject];
    XCTAssertTrue([result response].statusCode == 409);
    
    // Change broken lease
    [blob breakLeaseWithBreakPeriod:[[NSNumber alloc] initWithInt:0] completionHandler:^(NSError *err, NSNumber *leaseBreakTimw) {
        [self atomicOnLock:lock donePtr:&done operation:^(void){
            XCTAssertTrue(err == nil, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
        }];
    }];
    [self barrierOnLock:lock donePtr:&done];
    
    condition = [[AZSAccessCondition alloc] initWithLeaseId:leaseID1];
    [blob changeLeaseWithProposedLeaseId:proposedLeaseID1 accessCondition:condition requestOptions:nil operationContext:opCtxt completionHandler:^(NSError * err, NSString *resultLeaseID){
        [self atomicOnLock:lock donePtr:&done operation:^(void){
            XCTAssertTrue(err != nil, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
        }];
    }];
    [self barrierOnLock:lock donePtr:&done];
    result = (AZSRequestResult *)[[opCtxt requestResults] lastObject];
    XCTAssertTrue([result response].statusCode == 409);
    
    // Change broken lease (to previous lease)
    [blob acquireLeaseWithLeaseTime:nil /* Infinite Lease */ proposedLeaseId:nil completionHandler:^(NSError* err, NSString* resultLeaseID){
        [self atomicOnLock:lock donePtr:&done operation:^void{
            XCTAssertTrue(err == nil, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
            leaseID1 = resultLeaseID;
        }];
    }];
    [self barrierOnLock:lock donePtr:&done];
    
    [blob breakLeaseWithBreakPeriod:[[NSNumber alloc] initWithInt:0] completionHandler:^(NSError *err, NSNumber *leaseBreakTime) {
        [self atomicOnLock:lock donePtr:&done operation:^(void){
            XCTAssertTrue(err == nil, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
        }];
    }];
    [self barrierOnLock:lock donePtr:&done];
    
    condition = [[AZSAccessCondition alloc] initWithLeaseId:leaseID1];
    [blob changeLeaseWithProposedLeaseId:leaseID1 accessCondition:condition requestOptions:nil operationContext:opCtxt completionHandler:^(NSError * err, NSString *resultLeaseID){
        [self atomicOnLock:lock donePtr:&done operation:^(void){
            XCTAssertTrue(err != nil, @"Error in leasing.  Error code = %ld, error domain = %@, error userinfo = %@", (long)err.code, err.domain, err.userInfo);
        }];
    }];
    [self barrierOnLock:lock donePtr:&done];
    result = (AZSRequestResult *)[[opCtxt requestResults] lastObject];
    XCTAssertTrue([result response].statusCode == 409);
}

@end
