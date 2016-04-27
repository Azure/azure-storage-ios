//
//  AZSReadFromSecondaryTest.m
//  Azure Storage Client Library
//
//  Created by Adam on 1/11/16.
//  Copyright © 2016 Microsoft. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "AZSClient.h"
#import "AZSBlobTestBase.h"
#import "AZSTestHelpers.h"
#import "AZSTestSemaphore.h"

// TODO: Figure out a way to not have to document this.  Unfortunately, it will show up in the exported documentation.
/** A retry policy, used for testing only.  Reserved for internal use. */
@interface AZSRetryPolicyForTestAlwaysRetry : NSObject <AZSRetryPolicy>

@property NSArray *expectedRetryContextList;
@property NSArray *retryInfoList;
@property int retryCount;
@property (copy) void(^failMethod)(NSString *);


-(instancetype) initWithExpectedRetryContextList:(NSArray *)expectedRetryContextList retryInfoList:(NSArray *)retryInfoList failMethod:(void (^)(NSString *))failMethod;
@end

@implementation AZSRetryPolicyForTestAlwaysRetry

-(AZSRetryInfo *) evaluateRetryContext:(AZSRetryContext *)retryContext withOperationContext:(AZSOperationContext *)operationContext
{
    self.retryCount++;
    if (retryContext.currentRetryCount != self.retryCount) self.failMethod(@"Incorrect retry count.");
    if (retryContext.currentRetryCount > self.expectedRetryContextList.count) self.failMethod(@"Too many retries requested.");
    if (retryContext.currentLocationMode != ((AZSRetryContext *)self.expectedRetryContextList[self.retryCount - 1]).currentLocationMode) self.failMethod(@"Incorrect current location mode.");
    if (retryContext.nextLocation != ((AZSRetryContext *)self.expectedRetryContextList[self.retryCount - 1]).nextLocation) self.failMethod(@"Incorrect next location.");
    
    if (self.retryCount <= self.retryInfoList.count)
    {
        return self.retryInfoList[self.retryCount - 1];
    }
    else
    {
        return [[AZSRetryInfo alloc] initDontRetry];
    }
}

-(id<AZSRetryPolicy>)clone
{
    return [[AZSRetryPolicyForTestAlwaysRetry alloc] initWithExpectedRetryContextList:self.expectedRetryContextList retryInfoList:self.retryInfoList failMethod:self.failMethod];
}

-(instancetype) initWithExpectedRetryContextList:(NSArray *)expectedRetryContextList retryInfoList:(NSArray *)retryInfoList failMethod:(void (^)(NSString *))failMethod
{
    self = [super init];
    if (self)
    {
        if (expectedRetryContextList.count != retryInfoList.count + 1)
        {
            return nil;
        }
        _expectedRetryContextList = expectedRetryContextList;
        _retryInfoList = retryInfoList;
        _failMethod = failMethod;
        _retryCount = 0;
    }
    return self;
}

@end


@interface AZSReadFromSecondaryTest : AZSBlobTestBase
@property NSString *containerName;
@property AZSCloudBlobContainer *blobContainer;
@end

@implementation AZSReadFromSecondaryTest

- (void)setUp {
    [super setUp];
    self.containerName = [NSString stringWithFormat:@"sampleioscontainer%@", [AZSTestHelpers uniqueName]];
    self.blobContainer = [self.blobClient containerReferenceFromName:self.containerName];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}


- (void)runLocationsTestWithStartingStorageLocationMode:(AZSStorageLocationMode)storageLocationMode expectedInitialLocation:(AZSStorageLocation)expectedInitialLocation expectedRetryContextList:(NSArray *)expectedRetryContextList retryInfoList:(NSArray *)retryInfoList
{
    AZSTestSemaphore *semaphore = [[AZSTestSemaphore alloc] init];
   
    AZSRetryPolicyForTestAlwaysRetry *policy = [[AZSRetryPolicyForTestAlwaysRetry alloc] initWithExpectedRetryContextList:expectedRetryContextList retryInfoList:retryInfoList failMethod:^(NSString *errorString) {
        XCTFail(@"%@", errorString);
    }];
    AZSBlobRequestOptions *options = [[AZSBlobRequestOptions alloc] init];
    [options setStorageLocationMode:storageLocationMode];
    
    AZSOperationContext *opContext = [[AZSOperationContext alloc] init];
    [opContext setRetryPolicy:policy];
    
    __block BOOL errorfound = NO;
    __block int requestCount = 0;
    
    opContext.sendingRequest = ^(NSMutableURLRequest *request, AZSOperationContext *sendingOpContext) {
        if (!errorfound)
        {
            AZSStorageLocation location = requestCount == 0 ? expectedInitialLocation : ((AZSRetryInfo *)retryInfoList[requestCount - 1]).targetLocation;
            NSURL *url = [self.blobContainer.client.storageUri urlWithLocation:location];
            if (![url.host isEqualToString:request.URL.host])
            {
                XCTFail(@"URLs do not match in sending request");
                errorfound = YES;
            }
        }
        requestCount++;
    };
    
    [self.blobContainer downloadAttributesWithAccessCondition:nil requestOptions:options operationContext:opContext completionHandler:^(NSError * _Nullable error) {
        
        XCTAssertNotNil(error, @"Operation did not fail as expected.");
        XCTAssertEqual(expectedInitialLocation, ((AZSRequestResult *)opContext.requestResults[0]).targetLocation, @"Incorrect target location for operation.");
        XCTAssertEqual(retryInfoList.count + 1, opContext.requestResults.count, @"Incorrect number of requests made.");
        
        for (int i = 0; i < retryInfoList.count; i++)
        {
            XCTAssertEqual(((AZSRetryInfo *)retryInfoList[i]).targetLocation, ((AZSRequestResult *)opContext.requestResults[i + 1]).targetLocation, @"Incorrect target location for operation.");
            NSTimeInterval interval = [((AZSRequestResult *)opContext.requestResults[i + 1]).startTime timeIntervalSinceDate:((AZSRequestResult *)opContext.requestResults[i]).endTime];
            XCTAssertTrue(fabs(interval - ((AZSRetryInfo *)retryInfoList[i]).retryInterval) < 0.1, @"Incorrect amount of time waited.");
        }
        [semaphore signal];
    }];
    
    [semaphore wait];
}

-(void)testPrimaryOnlyNoRetry {
    NSMutableArray *expectedRetryContextList = [NSMutableArray arrayWithCapacity:1];
    NSMutableArray *retryInfoList = [NSMutableArray arrayWithCapacity:0];
    
    [expectedRetryContextList addObject:[[AZSRetryContext alloc] initWithCurrentRetryCount:0 lastRequestResult:(AZSRequestResult *)[[NSObject alloc] init] nextLocation:AZSStorageLocationPrimary currentLocationMode:AZSStorageLocationModePrimaryOnly]];
    
    [self runLocationsTestWithStartingStorageLocationMode:AZSStorageLocationModePrimaryOnly expectedInitialLocation:AZSStorageLocationPrimary expectedRetryContextList:expectedRetryContextList retryInfoList:retryInfoList];
}

-(void)testSecondaryOnlyNoRetry {
    NSMutableArray *expectedRetryContextList = [NSMutableArray arrayWithCapacity:1];
    NSMutableArray *retryInfoList = [NSMutableArray arrayWithCapacity:0];
    
    [expectedRetryContextList addObject:[[AZSRetryContext alloc] initWithCurrentRetryCount:0 lastRequestResult:(AZSRequestResult *)[[NSObject alloc] init] nextLocation:AZSStorageLocationSecondary currentLocationMode:AZSStorageLocationModeSecondaryOnly]];
    
    [self runLocationsTestWithStartingStorageLocationMode:AZSStorageLocationModeSecondaryOnly expectedInitialLocation:AZSStorageLocationSecondary expectedRetryContextList:expectedRetryContextList retryInfoList:retryInfoList];
}

-(void)testPrimaryThenSecondaryNoRetry {
    NSMutableArray *expectedRetryContextList = [NSMutableArray arrayWithCapacity:1];
    NSMutableArray *retryInfoList = [NSMutableArray arrayWithCapacity:0];
    
    [expectedRetryContextList addObject:[[AZSRetryContext alloc] initWithCurrentRetryCount:0 lastRequestResult:(AZSRequestResult *)[[NSObject alloc] init] nextLocation:AZSStorageLocationSecondary currentLocationMode:AZSStorageLocationModePrimaryThenSecondary]];
    
    [self runLocationsTestWithStartingStorageLocationMode:AZSStorageLocationModePrimaryThenSecondary expectedInitialLocation:AZSStorageLocationPrimary expectedRetryContextList:expectedRetryContextList retryInfoList:retryInfoList];
}

-(void)testSecondaryThenPrimaryPrimaryNoRetry {
    NSMutableArray *expectedRetryContextList = [NSMutableArray arrayWithCapacity:1];
    NSMutableArray *retryInfoList = [NSMutableArray arrayWithCapacity:0];
    
    [expectedRetryContextList addObject:[[AZSRetryContext alloc] initWithCurrentRetryCount:0 lastRequestResult:(AZSRequestResult *)[[NSObject alloc] init] nextLocation:AZSStorageLocationPrimary currentLocationMode:AZSStorageLocationModeSecondaryThenPrimary]];
    
    [self runLocationsTestWithStartingStorageLocationMode:AZSStorageLocationModeSecondaryThenPrimary expectedInitialLocation:AZSStorageLocationSecondary expectedRetryContextList:expectedRetryContextList retryInfoList:retryInfoList];
}

-(void)addUpdatedLocationModeListWithExpectedRetryContextList:(NSMutableArray *)expectedRetryContextList retryInfoList:(NSMutableArray *)retryInfoList
{
    [retryInfoList addObject:[[AZSRetryInfo alloc] initWithShouldRetry:YES targetLocation:AZSStorageLocationPrimary updatedLocationMode:AZSStorageLocationModePrimaryOnly retryInterval:1]];
    [expectedRetryContextList addObject:[[AZSRetryContext alloc] initWithCurrentRetryCount:0 lastRequestResult:(AZSRequestResult *)[[NSObject alloc] init] nextLocation:AZSStorageLocationPrimary currentLocationMode:AZSStorageLocationModePrimaryOnly]];

    [retryInfoList addObject:[[AZSRetryInfo alloc] initWithShouldRetry:YES targetLocation:AZSStorageLocationPrimary updatedLocationMode:AZSStorageLocationModeSecondaryOnly retryInterval:1]];
    [expectedRetryContextList addObject:[[AZSRetryContext alloc] initWithCurrentRetryCount:0 lastRequestResult:(AZSRequestResult *)[[NSObject alloc] init] nextLocation:AZSStorageLocationSecondary currentLocationMode:AZSStorageLocationModeSecondaryOnly]];

    [retryInfoList addObject:[[AZSRetryInfo alloc] initWithShouldRetry:YES targetLocation:AZSStorageLocationPrimary updatedLocationMode:AZSStorageLocationModePrimaryThenSecondary retryInterval:1]];
    [expectedRetryContextList addObject:[[AZSRetryContext alloc] initWithCurrentRetryCount:0 lastRequestResult:(AZSRequestResult *)[[NSObject alloc] init] nextLocation:AZSStorageLocationSecondary currentLocationMode:AZSStorageLocationModePrimaryThenSecondary]];

    [retryInfoList addObject:[[AZSRetryInfo alloc] initWithShouldRetry:YES targetLocation:AZSStorageLocationPrimary updatedLocationMode:AZSStorageLocationModeSecondaryThenPrimary retryInterval:1]];
    [expectedRetryContextList addObject:[[AZSRetryContext alloc] initWithCurrentRetryCount:0 lastRequestResult:(AZSRequestResult *)[[NSObject alloc] init] nextLocation:AZSStorageLocationSecondary currentLocationMode:AZSStorageLocationModeSecondaryThenPrimary]];

    
    [retryInfoList addObject:[[AZSRetryInfo alloc] initWithShouldRetry:YES targetLocation:AZSStorageLocationSecondary updatedLocationMode:AZSStorageLocationModePrimaryOnly retryInterval:1]];
    [expectedRetryContextList addObject:[[AZSRetryContext alloc] initWithCurrentRetryCount:0 lastRequestResult:(AZSRequestResult *)[[NSObject alloc] init] nextLocation:AZSStorageLocationPrimary currentLocationMode:AZSStorageLocationModePrimaryOnly]];
    
    [retryInfoList addObject:[[AZSRetryInfo alloc] initWithShouldRetry:YES targetLocation:AZSStorageLocationSecondary updatedLocationMode:AZSStorageLocationModeSecondaryOnly retryInterval:1]];
    [expectedRetryContextList addObject:[[AZSRetryContext alloc] initWithCurrentRetryCount:0 lastRequestResult:(AZSRequestResult *)[[NSObject alloc] init] nextLocation:AZSStorageLocationSecondary currentLocationMode:AZSStorageLocationModeSecondaryOnly]];
    
    [retryInfoList addObject:[[AZSRetryInfo alloc] initWithShouldRetry:YES targetLocation:AZSStorageLocationSecondary updatedLocationMode:AZSStorageLocationModePrimaryThenSecondary retryInterval:1]];
    [expectedRetryContextList addObject:[[AZSRetryContext alloc] initWithCurrentRetryCount:0 lastRequestResult:(AZSRequestResult *)[[NSObject alloc] init] nextLocation:AZSStorageLocationPrimary currentLocationMode:AZSStorageLocationModePrimaryThenSecondary]];
    
    [retryInfoList addObject:[[AZSRetryInfo alloc] initWithShouldRetry:YES targetLocation:AZSStorageLocationSecondary updatedLocationMode:AZSStorageLocationModeSecondaryThenPrimary retryInterval:1]];
    [expectedRetryContextList addObject:[[AZSRetryContext alloc] initWithCurrentRetryCount:0 lastRequestResult:(AZSRequestResult *)[[NSObject alloc] init] nextLocation:AZSStorageLocationPrimary currentLocationMode:AZSStorageLocationModeSecondaryThenPrimary]];
}

-(void)testPrimaryOnlySeveralRetries
{
    NSMutableArray *expectedRetryContextList = [NSMutableArray arrayWithCapacity:11];
    NSMutableArray *retryInfoList = [NSMutableArray arrayWithCapacity:10];

    [expectedRetryContextList addObject:[[AZSRetryContext alloc] initWithCurrentRetryCount:0 lastRequestResult:(AZSRequestResult *)[[NSObject alloc] init] nextLocation:AZSStorageLocationPrimary currentLocationMode:AZSStorageLocationModePrimaryOnly]];
    
    [retryInfoList addObject:[[AZSRetryInfo alloc] initWithShouldRetry:YES targetLocation:AZSStorageLocationPrimary updatedLocationMode:AZSStorageLocationModePrimaryOnly retryInterval:6]];
    [expectedRetryContextList addObject:[[AZSRetryContext alloc] initWithCurrentRetryCount:0 lastRequestResult:(AZSRequestResult *)[[NSObject alloc] init] nextLocation:AZSStorageLocationPrimary currentLocationMode:AZSStorageLocationModePrimaryOnly]];

    [retryInfoList addObject:[[AZSRetryInfo alloc] initWithShouldRetry:YES targetLocation:AZSStorageLocationPrimary updatedLocationMode:AZSStorageLocationModePrimaryOnly retryInterval:1]];
    [expectedRetryContextList addObject:[[AZSRetryContext alloc] initWithCurrentRetryCount:0 lastRequestResult:(AZSRequestResult *)[[NSObject alloc] init] nextLocation:AZSStorageLocationPrimary currentLocationMode:AZSStorageLocationModePrimaryOnly]];

    [self addUpdatedLocationModeListWithExpectedRetryContextList:expectedRetryContextList retryInfoList:retryInfoList];
    [self runLocationsTestWithStartingStorageLocationMode:AZSStorageLocationModePrimaryOnly expectedInitialLocation:AZSStorageLocationPrimary expectedRetryContextList:expectedRetryContextList retryInfoList:retryInfoList];
}

-(void)testSecondaryOnlySeveralRetries
{
    NSMutableArray *expectedRetryContextList = [NSMutableArray arrayWithCapacity:11];
    NSMutableArray *retryInfoList = [NSMutableArray arrayWithCapacity:10];
    
    [expectedRetryContextList addObject:[[AZSRetryContext alloc] initWithCurrentRetryCount:0 lastRequestResult:(AZSRequestResult *)[[NSObject alloc] init] nextLocation:AZSStorageLocationSecondary currentLocationMode:AZSStorageLocationModeSecondaryOnly]];
    
    [retryInfoList addObject:[[AZSRetryInfo alloc] initWithShouldRetry:YES targetLocation:AZSStorageLocationSecondary updatedLocationMode:AZSStorageLocationModeSecondaryOnly retryInterval:6]];
    [expectedRetryContextList addObject:[[AZSRetryContext alloc] initWithCurrentRetryCount:0 lastRequestResult:(AZSRequestResult *)[[NSObject alloc] init] nextLocation:AZSStorageLocationSecondary currentLocationMode:AZSStorageLocationModeSecondaryOnly]];
    
    [retryInfoList addObject:[[AZSRetryInfo alloc] initWithShouldRetry:YES targetLocation:AZSStorageLocationSecondary updatedLocationMode:AZSStorageLocationModeSecondaryOnly retryInterval:1]];
    [expectedRetryContextList addObject:[[AZSRetryContext alloc] initWithCurrentRetryCount:0 lastRequestResult:(AZSRequestResult *)[[NSObject alloc] init] nextLocation:AZSStorageLocationSecondary currentLocationMode:AZSStorageLocationModeSecondaryOnly]];
    
    [self addUpdatedLocationModeListWithExpectedRetryContextList:expectedRetryContextList retryInfoList:retryInfoList];
    [self runLocationsTestWithStartingStorageLocationMode:AZSStorageLocationModeSecondaryOnly expectedInitialLocation:AZSStorageLocationSecondary expectedRetryContextList:expectedRetryContextList retryInfoList:retryInfoList];
}

-(void)testPrimaryThenSecondarySeveralRetries
{
    NSMutableArray *expectedRetryContextList = [NSMutableArray arrayWithCapacity:11];
    NSMutableArray *retryInfoList = [NSMutableArray arrayWithCapacity:10];
    
    [expectedRetryContextList addObject:[[AZSRetryContext alloc] initWithCurrentRetryCount:0 lastRequestResult:(AZSRequestResult *)[[NSObject alloc] init] nextLocation:AZSStorageLocationSecondary currentLocationMode:AZSStorageLocationModePrimaryThenSecondary]];
    
    [retryInfoList addObject:[[AZSRetryInfo alloc] initWithShouldRetry:YES targetLocation:AZSStorageLocationSecondary updatedLocationMode:AZSStorageLocationModePrimaryThenSecondary retryInterval:6]];
    [expectedRetryContextList addObject:[[AZSRetryContext alloc] initWithCurrentRetryCount:0 lastRequestResult:(AZSRequestResult *)[[NSObject alloc] init] nextLocation:AZSStorageLocationPrimary currentLocationMode:AZSStorageLocationModePrimaryThenSecondary]];
    
    [retryInfoList addObject:[[AZSRetryInfo alloc] initWithShouldRetry:YES targetLocation:AZSStorageLocationPrimary updatedLocationMode:AZSStorageLocationModePrimaryThenSecondary retryInterval:1]];
    [expectedRetryContextList addObject:[[AZSRetryContext alloc] initWithCurrentRetryCount:0 lastRequestResult:(AZSRequestResult *)[[NSObject alloc] init] nextLocation:AZSStorageLocationSecondary currentLocationMode:AZSStorageLocationModePrimaryThenSecondary]];
    
    [self addUpdatedLocationModeListWithExpectedRetryContextList:expectedRetryContextList retryInfoList:retryInfoList];
    [self runLocationsTestWithStartingStorageLocationMode:AZSStorageLocationModePrimaryThenSecondary expectedInitialLocation:AZSStorageLocationPrimary expectedRetryContextList:expectedRetryContextList retryInfoList:retryInfoList];
}

-(void)testSecondaryThenPrimarySeveralRetries
{
    NSMutableArray *expectedRetryContextList = [NSMutableArray arrayWithCapacity:11];
    NSMutableArray *retryInfoList = [NSMutableArray arrayWithCapacity:10];
    
    [expectedRetryContextList addObject:[[AZSRetryContext alloc] initWithCurrentRetryCount:0 lastRequestResult:(AZSRequestResult *)[[NSObject alloc] init] nextLocation:AZSStorageLocationPrimary currentLocationMode:AZSStorageLocationModeSecondaryThenPrimary]];
    
    [retryInfoList addObject:[[AZSRetryInfo alloc] initWithShouldRetry:YES targetLocation:AZSStorageLocationPrimary updatedLocationMode:AZSStorageLocationModeSecondaryThenPrimary retryInterval:6]];
    [expectedRetryContextList addObject:[[AZSRetryContext alloc] initWithCurrentRetryCount:0 lastRequestResult:(AZSRequestResult *)[[NSObject alloc] init] nextLocation:AZSStorageLocationSecondary currentLocationMode:AZSStorageLocationModeSecondaryThenPrimary]];
    
    [retryInfoList addObject:[[AZSRetryInfo alloc] initWithShouldRetry:YES targetLocation:AZSStorageLocationSecondary updatedLocationMode:AZSStorageLocationModeSecondaryThenPrimary retryInterval:1]];
    [expectedRetryContextList addObject:[[AZSRetryContext alloc] initWithCurrentRetryCount:0 lastRequestResult:(AZSRequestResult *)[[NSObject alloc] init] nextLocation:AZSStorageLocationPrimary currentLocationMode:AZSStorageLocationModeSecondaryThenPrimary]];
    
    [self addUpdatedLocationModeListWithExpectedRetryContextList:expectedRetryContextList retryInfoList:retryInfoList];
    [self runLocationsTestWithStartingStorageLocationMode:AZSStorageLocationModeSecondaryThenPrimary expectedInitialLocation:AZSStorageLocationSecondary expectedRetryContextList:expectedRetryContextList retryInfoList:retryInfoList];
}
@end
