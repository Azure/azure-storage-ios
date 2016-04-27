// -----------------------------------------------------------------------------------------
// <copyright file="AZSTestRetry.m" company="Microsoft">
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
#import "AZSTestHelpers.h"
#import "AZSTestSemaphore.h"
#import "AZSClient.h"

// TODO: Figure out a way to not have to document this.  Unfortunately, it will show up in the exported documentation.
/** A retry policy, used for testing only.  Reserved for internal use. */
@interface AZSRetryPolicyForTest : NSObject <AZSRetryPolicy>
@property (copy) AZSRetryInfo *(^evaluateRetryContextMethod)(AZSRetryContext *retryContext, AZSOperationContext *operationContext);
@end

@implementation AZSRetryPolicyForTest

-(AZSRetryInfo *) evaluateRetryContext:(AZSRetryContext *)retryContext withOperationContext:(AZSOperationContext *)operationContext
{
    return self.evaluateRetryContextMethod(retryContext, operationContext);
}

-(id<AZSRetryPolicy>)clone
{
    return self;
}

@end

@interface AZSTestRetry : AZSBlobTestBase
@property NSString *containerName;
@property AZSCloudBlobContainer *blobContainer;
@end

@implementation AZSTestRetry

- (void)setUp
{
    [super setUp];
    self.containerName = [NSString stringWithFormat:@"sampleioscontainer%@", [AZSTestHelpers uniqueName]];
    self.blobContainer = [self.blobClient containerReferenceFromName:self.containerName];
    
    // Put setup code here; it will be run once, before the first test case.
}

- (void)tearDown
{
    // Put teardown code here; it will be run once, after the last test case.
    [super tearDown];
}

-(AZSRetryContext *)generateRetryContextWithCurrentRetryCount:(NSInteger)currentRetryCount statusCode:(NSInteger)statusCode
{
    return [[AZSRetryContext alloc] initWithCurrentRetryCount:currentRetryCount lastRequestResult:[[AZSRequestResult alloc] initWithStartTime:[[NSDate alloc] initWithTimeIntervalSinceNow:0] location:AZSStorageLocationPrimary response:[[NSHTTPURLResponse alloc] initWithURL:[[NSURL alloc] init] statusCode:statusCode HTTPVersion:nil headerFields:nil] error:nil] nextLocation:AZSStorageLocationPrimary currentLocationMode:AZSStorageLocationModePrimaryOnly];
}

-(void)runRetryTestWithRetryPolicy:(id<AZSRetryPolicy>)retryPolicy retryCount:(NSInteger)retryCount statusCode:(NSInteger)statusCode shouldSucceed:(BOOL)shouldSucceed validateRetryInterval:(BOOL (^)(double))validateRetryInterval
{
    AZSRetryContext *retryContext = [self generateRetryContextWithCurrentRetryCount:retryCount statusCode:statusCode];
    AZSRetryInfo *retryInfo = [retryPolicy evaluateRetryContext:retryContext withOperationContext:nil];
    
    if (shouldSucceed)
    {
        XCTAssertTrue(retryInfo.shouldRetry, @"Retry policy did not retry when it should have.  Status Code = %ldd",(long) (long) statusCode);
        XCTAssertTrue(retryInfo.targetLocation == AZSStorageLocationPrimary, @"Retry policy did not return the correct storage location.");
        XCTAssertTrue(retryInfo.updatedLocationMode == AZSStorageLocationModePrimaryOnly, @"Retry policy did not return the correct storage location mode.");
        NSLog(@"%f", retryInfo.retryInterval);
        XCTAssertTrue(validateRetryInterval(retryInfo.retryInterval), @"Retry policy did not return the correct time to wait.");
    }
    else
    {
        XCTAssertFalse(retryInfo.shouldRetry, @"Retry policy retried when it should not.");
    }
}

- (void)testLinearRetryPolicy
{
    int maxAttempts = 3;
    double waitTime = 4.0;
    id<AZSRetryPolicy> retryPolicy = [[AZSRetryPolicyLinear alloc] initWithMaxAttempts:maxAttempts waitTimeBetweenRetries:waitTime];
    
    [self runRetryTestWithRetryPolicy:retryPolicy retryCount:1 statusCode:304 shouldSucceed:NO validateRetryInterval:^BOOL(double retryInterval) {
        return (fabs((retryInterval - waitTime)) < 0.1);
    }];
    
    [self runRetryTestWithRetryPolicy:retryPolicy retryCount:1 statusCode:401 shouldSucceed:NO validateRetryInterval:^BOOL(double retryInterval) {
        return (fabs((retryInterval - waitTime)) < 0.1);
    }];
    
    [self runRetryTestWithRetryPolicy:retryPolicy retryCount:1 statusCode:403 shouldSucceed:NO validateRetryInterval:^BOOL(double retryInterval) {
        return (fabs((retryInterval - waitTime)) < 0.1);
    }];
    
    [self runRetryTestWithRetryPolicy:retryPolicy retryCount:1 statusCode:404 shouldSucceed:NO validateRetryInterval:^BOOL(double retryInterval) {
        return (fabs((retryInterval - waitTime)) < 0.1);
    }];
    
    [self runRetryTestWithRetryPolicy:retryPolicy retryCount:1 statusCode:408 shouldSucceed:YES validateRetryInterval:^BOOL(double retryInterval) {
        return (fabs((retryInterval - waitTime)) < 0.1);
    }];
    
    [self runRetryTestWithRetryPolicy:retryPolicy retryCount:1 statusCode:500 shouldSucceed:YES validateRetryInterval:^BOOL(double retryInterval) {
        return (fabs((retryInterval - waitTime)) < 0.1);
    }];
    [self runRetryTestWithRetryPolicy:retryPolicy retryCount:5 statusCode:500 shouldSucceed:NO validateRetryInterval:^BOOL(double retryInterval) {
        return (fabs((retryInterval - waitTime)) < 0.1);
    }];
    
    [self runRetryTestWithRetryPolicy:retryPolicy retryCount:1 statusCode:501 shouldSucceed:NO validateRetryInterval:^BOOL(double retryInterval) {
        return (fabs((retryInterval - waitTime)) < 0.1);
    }];
    
    [self runRetryTestWithRetryPolicy:retryPolicy retryCount:1 statusCode:503 shouldSucceed:YES validateRetryInterval:^BOOL(double retryInterval) {
        return (fabs((retryInterval - waitTime)) < 0.1);
    }];
    
    [self runRetryTestWithRetryPolicy:retryPolicy retryCount:1 statusCode:505 shouldSucceed:NO validateRetryInterval:^BOOL(double retryInterval) {
        return (fabs((retryInterval - waitTime)) < 0.1);
    }];
}

- (void)testExponentialRetryPolicy
{
    int maxAttempts = 3;
    double waitTime = 1.0;
    id<AZSRetryPolicy> retryPolicy = [[AZSRetryPolicyExponential alloc] initWithMaxAttempts:maxAttempts averageBackoffDelta:waitTime];
    
    // First: validate that the 'should succeed' logic works.
    [self runRetryTestWithRetryPolicy:retryPolicy retryCount:1 statusCode:304 shouldSucceed:NO validateRetryInterval:^BOOL(double retryInterval) {
        return YES;
    }];
    
    [self runRetryTestWithRetryPolicy:retryPolicy retryCount:1 statusCode:401 shouldSucceed:NO validateRetryInterval:^BOOL(double retryInterval) {
        return YES;
    }];
    
    [self runRetryTestWithRetryPolicy:retryPolicy retryCount:1 statusCode:403 shouldSucceed:NO validateRetryInterval:^BOOL(double retryInterval) {
        return YES;
    }];
    
    [self runRetryTestWithRetryPolicy:retryPolicy retryCount:1 statusCode:404 shouldSucceed:NO validateRetryInterval:^BOOL(double retryInterval) {
        return YES;
    }];
    
    [self runRetryTestWithRetryPolicy:retryPolicy retryCount:1 statusCode:408 shouldSucceed:YES validateRetryInterval:^BOOL(double retryInterval) {
        return YES;
    }];
    
    [self runRetryTestWithRetryPolicy:retryPolicy retryCount:1 statusCode:500 shouldSucceed:YES validateRetryInterval:^BOOL(double retryInterval) {
        return YES;
    }];
    [self runRetryTestWithRetryPolicy:retryPolicy retryCount:5 statusCode:500 shouldSucceed:NO validateRetryInterval:^BOOL(double retryInterval) {
        return YES;
    }];
    
    [self runRetryTestWithRetryPolicy:retryPolicy retryCount:1 statusCode:501 shouldSucceed:NO validateRetryInterval:^BOOL(double retryInterval) {
        return YES;
    }];
    
    [self runRetryTestWithRetryPolicy:retryPolicy retryCount:1 statusCode:503 shouldSucceed:YES validateRetryInterval:^BOOL(double retryInterval) {
        return YES;
    }];
    
    [self runRetryTestWithRetryPolicy:retryPolicy retryCount:1 statusCode:505 shouldSucceed:NO validateRetryInterval:^BOOL(double retryInterval) {
        return YES;
    }];
    
    // Second: validate that the retry interval calculation works.
    
    maxAttempts = 10;
    waitTime = 1.0;
    int retryCount = 0;
    double upperBoundRandomness = 1.2;
    double lowerBoundRandomness = 0.8;
    retryPolicy = [[AZSRetryPolicyExponential alloc] initWithMaxAttempts:maxAttempts averageBackoffDelta:waitTime];

    [self runRetryTestWithRetryPolicy:retryPolicy retryCount:retryCount statusCode:500 shouldSucceed:YES validateRetryInterval:^BOOL(double retryInterval) {
        return (fabs((retryInterval - 0.5)) < 0.1);
    }];
    
    retryCount = 1;
    [self runRetryTestWithRetryPolicy:retryPolicy retryCount:retryCount statusCode:500 shouldSucceed:YES validateRetryInterval:^BOOL(double retryInterval) {
        return ((retryInterval < (waitTime*upperBoundRandomness)) && (retryInterval > (waitTime*lowerBoundRandomness)));
    }];
    
    retryCount = 3;
    [self runRetryTestWithRetryPolicy:retryPolicy retryCount:retryCount statusCode:500 shouldSucceed:YES validateRetryInterval:^BOOL(double retryInterval) {
        return ((retryInterval < ((pow(2, retryCount) - 1)*waitTime*upperBoundRandomness)) && (retryInterval > ((pow(2, retryCount) - 1)*waitTime*lowerBoundRandomness)));
    }];

    retryCount = 6;
    [self runRetryTestWithRetryPolicy:retryPolicy retryCount:retryCount statusCode:500 shouldSucceed:YES validateRetryInterval:^BOOL(double retryInterval) {
        return ((retryInterval < ((pow(2, retryCount) - 1)*waitTime*upperBoundRandomness)) && (retryInterval > ((pow(2, retryCount) - 1)*waitTime*lowerBoundRandomness)));
    }];

    retryCount = 9;
    [self runRetryTestWithRetryPolicy:retryPolicy retryCount:retryCount statusCode:500 shouldSucceed:YES validateRetryInterval:^BOOL(double retryInterval) {
        return (fabs((retryInterval - 120)) < 0.1);
    }];

}

-(void)testRetryLogicInExecutor
{
    AZSTestSemaphore *semaphore = [[AZSTestSemaphore alloc] init];
    AZSRetryPolicyForTest *testRetryPolicy = [[AZSRetryPolicyForTest alloc] init];
    
    __block int currentRetryCount = 0;
    
    testRetryPolicy.evaluateRetryContextMethod = ^AZSRetryInfo *(AZSRetryContext *retryContext, AZSOperationContext *operationContext)
    {
        currentRetryCount++;
        if (currentRetryCount == 1)
        {
            return [[AZSRetryInfo alloc] initWithShouldRetry:YES targetLocation:AZSStorageLocationPrimary updatedLocationMode:AZSStorageLocationModePrimaryOnly retryInterval:10];
        }
        else if (currentRetryCount == 2)
        {
            return [[AZSRetryInfo alloc] initWithShouldRetry:YES targetLocation:AZSStorageLocationPrimary updatedLocationMode:AZSStorageLocationModePrimaryOnly retryInterval:15];
        }
        else if (currentRetryCount == 3)
        {
            return [[AZSRetryInfo alloc ]initDontRetry];
        }
        else
        {
            XCTFail(@"Executor Kept retrying when it should not.");
            return [[AZSRetryInfo alloc ]initDontRetry];
        }
    };
    
    AZSOperationContext *operationContext = [[AZSOperationContext alloc] init];
    operationContext.retryPolicy = testRetryPolicy;
    
    NSDate *testStart = [NSDate date];
    
    // Note that the blob doesn't exist, so this should always fail.
    [self.blobContainer downloadAttributesWithAccessCondition:nil requestOptions:nil operationContext:operationContext completionHandler:^(NSError *error) {
        NSDate *testEnd = [NSDate date];
        XCTAssertNotNil(error, @"Error not returned when it should have been.");
        XCTAssertTrue(currentRetryCount == 3, @"Incorrect number of retries attempted.");
        XCTAssertTrue(ABS([testEnd timeIntervalSinceDate:testStart] - 25.0) < 5.0, @"Incorrect amount of time waited in between retries.  Expected interval = 9.0.  Actual interval = %f", [testEnd timeIntervalSinceDate:testStart]);
        [semaphore signal];
    }];
    [semaphore wait];
}

@end