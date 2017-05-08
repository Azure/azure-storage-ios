 // -----------------------------------------------------------------------------------------
// <copyright file="AZSServicePropertiesTests.m" company="Microsoft">
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
#import "AZSServiceProperties.h"
#import "AZSCorsRule.h"
#import "AZSLoggingProperties.h"
#import "AZSMetricsProperties.h"
#import "AZSTestSemaphore.h"
#import "AZSBlobTestBase.h"
#import "AZSTestHelpers.h"
#import "AZSClient.h"

@interface AZSServicePropertiesTests : AZSBlobTestBase

@property (strong) AZSServiceProperties* sp;

@end

@implementation AZSServicePropertiesTests



- (void)setUp {
    [super setUp];
    _sp = [[AZSServiceProperties alloc] init];
    _sp.logging = [[AZSLoggingProperties alloc] init];
    _sp.logging.logOperationTypes = AZSLoggingOperationNone;
    _sp.logging.retentionIntervalInDays = nil;
    _sp.logging.version = @"1.0";

    _sp.hourMetrics = [[AZSMetricsProperties alloc] init];
    _sp.hourMetrics.metricsLevel = AZSMetricsLevelDisabled;
    _sp.hourMetrics.version = @"1.0";

    _sp.minuteMetrics = [[AZSMetricsProperties alloc] init];
    _sp.minuteMetrics.metricsLevel = AZSMetricsLevelDisabled;
    _sp.minuteMetrics.version = @"1.0";

    _sp.corsRules = [[NSMutableArray alloc] init];

    _sp.defaultServiceVersion = AZSCTargetStorageVersion;
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)checkEqualityOfServiceProperties:(AZSServiceProperties *)properties otherProperties:(AZSServiceProperties *)otherProperties
{
    if (properties == nil && otherProperties == nil)
    {
        return;

    }
    else
    {
        XCTAssertNotNil(properties);
        XCTAssertNotNil(otherProperties);
    }

    if (properties.logging != nil && otherProperties.logging != nil)
    {
        XCTAssertEqual(properties.logging.logOperationTypes, otherProperties.logging.logOperationTypes);
        if (properties.logging.retentionIntervalInDays != nil && otherProperties.logging.retentionIntervalInDays != nil)
        {
            XCTAssertEqual(properties.logging.retentionIntervalInDays, otherProperties.logging.retentionIntervalInDays);
        }
        else
        {
            XCTAssertNil(properties.logging.retentionIntervalInDays);
            XCTAssertNil(otherProperties.logging.retentionIntervalInDays);
        }

        XCTAssertEqualObjects(properties.logging.version, otherProperties.logging.version);
    }
    else
    {
        XCTAssertNil(properties.logging);
        XCTAssertNil(otherProperties.logging);
    }

    if (properties.hourMetrics != nil && otherProperties.hourMetrics != nil)
    {
        XCTAssertEqual(properties.hourMetrics.metricsLevel, otherProperties.hourMetrics.metricsLevel);
        XCTAssertEqual(properties.hourMetrics.version, otherProperties.hourMetrics.version);
        if (properties.hourMetrics.retentionIntervalInDays != nil && otherProperties.hourMetrics.retentionIntervalInDays != nil)
        {
            XCTAssertEqual(properties.hourMetrics.retentionIntervalInDays, otherProperties.hourMetrics.retentionIntervalInDays);
        }
        else
        {
            XCTAssertNil(properties.hourMetrics.retentionIntervalInDays);
            XCTAssertNil(otherProperties.hourMetrics.retentionIntervalInDays);
        }
    }
    else
    {
        XCTAssertNil(properties.hourMetrics);
        XCTAssertNil(otherProperties.hourMetrics);
    }

    if (properties.minuteMetrics != nil && otherProperties.minuteMetrics != nil)
    {
        XCTAssertEqual(properties.minuteMetrics.metricsLevel, otherProperties.minuteMetrics.metricsLevel);
        XCTAssertEqual(properties.minuteMetrics.version, otherProperties.minuteMetrics.version);
        if (properties.minuteMetrics.retentionIntervalInDays != nil && otherProperties.minuteMetrics.retentionIntervalInDays != nil)
        {
            XCTAssertEqual(properties.minuteMetrics.retentionIntervalInDays, otherProperties.minuteMetrics.retentionIntervalInDays);
        }
        else
        {
            XCTAssertNil(properties.minuteMetrics.retentionIntervalInDays);
            XCTAssertNil(otherProperties.minuteMetrics.retentionIntervalInDays);
        }
    }
    else
    {
        XCTAssertNil(properties.minuteMetrics);
        XCTAssertNil(otherProperties.minuteMetrics);
    }

    if (properties.defaultServiceVersion != nil && otherProperties.defaultServiceVersion != nil)
    {
        XCTAssertEqualObjects(properties.defaultServiceVersion, otherProperties.defaultServiceVersion);
    }
    else
    {
        XCTAssertNil(properties.defaultServiceVersion);
        XCTAssertNil(otherProperties.defaultServiceVersion);
    }

    if (properties.corsRules != nil && otherProperties.corsRules != nil)
    {
        XCTAssertEqual(properties.corsRules.count, otherProperties.corsRules.count);
        for (int i = 0; i < properties.corsRules.count; i++)
        {
            AZSCorsRule *corsRule = properties.corsRules[i];
            AZSCorsRule *otherCorsRule = otherProperties.corsRules[i];
            XCTAssertEqual(corsRule.allowedOrigins.count, otherCorsRule.allowedOrigins.count);
            for (int j = 0; j < corsRule.allowedOrigins.count; j++)
            {
                XCTAssertTrue([corsRule.allowedOrigins containsObject: otherCorsRule.allowedOrigins[j]]);
            }

            XCTAssertEqual(corsRule.exposedHeaders.count, otherCorsRule.exposedHeaders.count);
            for (int j = 0; j < corsRule.exposedHeaders.count; j++)
            {
                XCTAssertTrue([corsRule.exposedHeaders containsObject: otherCorsRule.exposedHeaders[j]]);
            }

            XCTAssertEqual(corsRule.allowedHeaders.count, otherCorsRule.allowedHeaders.count);
            for (int j = 0; j < corsRule.allowedHeaders.count; j++)
            {
                XCTAssertTrue([corsRule.allowedHeaders containsObject: otherCorsRule.allowedHeaders[j]]);
            }

            XCTAssertEqual(corsRule.allowedHttpMethods, otherCorsRule.allowedHttpMethods);

            XCTAssertEqual(corsRule.maxAgeInSeconds, otherCorsRule.maxAgeInSeconds);
        }
    }
    else
    {
        XCTAssertNil(properties.corsRules);
        XCTAssertNil(otherProperties.corsRules);
    }
}

- (void)testServicePropertiesAnalyticsDisabled
{
    // Set all properties to disabled
    AZSServiceProperties *sp = [[AZSServiceProperties alloc] init];
    AZSTestSemaphore *semaphore = [[AZSTestSemaphore alloc] init];
    sp.defaultServiceVersion = AZSCTargetStorageVersion;
    sp.logging = [[AZSLoggingProperties alloc] init];
    sp.logging.version = @"1.0";
    sp.logging.retentionIntervalInDays = nil;

    sp.hourMetrics = [[AZSMetricsProperties alloc] init];
    sp.hourMetrics.metricsLevel = AZSMetricsLevelDisabled;
    sp.hourMetrics.retentionIntervalInDays = nil;
    sp.hourMetrics.version = @"1.0";

    sp.minuteMetrics = [[AZSMetricsProperties alloc] init];
    sp.minuteMetrics.metricsLevel = AZSMetricsLevelDisabled;
    sp.minuteMetrics.retentionIntervalInDays = nil;
    sp.minuteMetrics.version = @"1.0";

    sp.corsRules = [[NSMutableArray alloc] init];

    [self.blobClient uploadServicePropertiesWithServiceProperties:sp completionHandler:^(NSError *err) {
        [self checkPassageOfError:err expectToPass:YES expectedHttpErrorCode:-1 message:@"Upload service properties"];

        //[NSThread sleepForTimeInterval:30];
        [self.blobClient downloadServicePropertiesWithCompletionHandler:^(NSError *error, AZSServiceProperties *storedServiceProperties) {
            [self checkPassageOfError:error expectToPass:YES expectedHttpErrorCode:-1 message:@"Download service properties"];
            [self checkEqualityOfServiceProperties:sp otherProperties:storedServiceProperties];

            [semaphore signal];
        }];
    }];
    [semaphore wait];
}

- (void)testServicePropertiesDefaultServiceVersion
{
    // Set default service version to old version
    AZSTestSemaphore *semaphore = [[AZSTestSemaphore alloc] init];
    _sp.defaultServiceVersion = @"2009-09-19";

    [self.blobClient uploadServicePropertiesWithServiceProperties:_sp completionHandler:^(NSError *err) {
        [self checkPassageOfError:err expectToPass:YES expectedHttpErrorCode:-1 message:@"Upload service properties"];

        //[NSThread sleepForTimeInterval:30];
        [self.blobClient downloadServicePropertiesWithCompletionHandler:^(NSError *error, AZSServiceProperties *storedServiceProperties) {
            [self checkPassageOfError:error expectToPass:YES expectedHttpErrorCode:-1 message:@"Download service properties"];
            [self checkEqualityOfServiceProperties:_sp otherProperties:storedServiceProperties];

            // set default service version to current version
            _sp.defaultServiceVersion = AZSCTargetStorageVersion;
            [self.blobClient uploadServicePropertiesWithServiceProperties:_sp completionHandler:^(NSError *err) {
                [self checkPassageOfError:err expectToPass:YES expectedHttpErrorCode:-1 message:@"Upload service properties"];

                //[NSThread sleepForTimeInterval:30];
                [self.blobClient downloadServicePropertiesWithCompletionHandler:^(NSError *error, AZSServiceProperties *storedServiceProperties) {
                    [self checkPassageOfError:error expectToPass:YES expectedHttpErrorCode:-1 message:@"Download service properties"];
                    [self checkEqualityOfServiceProperties:_sp otherProperties:storedServiceProperties];

                    [semaphore signal];
                }];
            }];
        }];
    }];
    [semaphore wait];
}

- (void)testServicePropertiesLoggingOperations
{
    // logging disabled
    AZSTestSemaphore *semaphore = [[AZSTestSemaphore alloc] init];
    _sp.defaultServiceVersion = AZSCTargetStorageVersion;
    _sp.logging = [[AZSLoggingProperties alloc] init];
    _sp.logging.version = @"1.0";
    _sp.logging.logOperationTypes = AZSLoggingOperationNone;
    _sp.logging.retentionIntervalInDays = nil;

    [self.blobClient uploadServicePropertiesWithServiceProperties:_sp completionHandler:^(NSError *err) {
        [self checkPassageOfError:err expectToPass:YES expectedHttpErrorCode:-1 message:@"Upload service properties"];

        //[NSThread sleepForTimeInterval:30];
        [self.blobClient downloadServicePropertiesWithCompletionHandler:^(NSError *error, AZSServiceProperties *storedServiceProperties) {
            [self checkPassageOfError:error expectToPass:YES expectedHttpErrorCode:-1 message:@"Download service properties"];
            [self checkEqualityOfServiceProperties:_sp otherProperties:storedServiceProperties];

            // all logging enabled
            _sp.logging.logOperationTypes = AZSLoggingOperationRead | AZSLoggingOperationWrite | AZSLoggingOperationDelete;
            [self.blobClient uploadServicePropertiesWithServiceProperties:_sp completionHandler:^(NSError *err) {
                [self checkPassageOfError:err expectToPass:YES expectedHttpErrorCode:-1 message:@"Upload service properties"];

                //[NSThread sleepForTimeInterval:30];
                [self.blobClient downloadServicePropertiesWithCompletionHandler:^(NSError *error, AZSServiceProperties *storedServiceProperties) {
                    [self checkPassageOfError:error expectToPass:YES expectedHttpErrorCode:-1 message:@"Download service properties"];
                    [self checkEqualityOfServiceProperties:_sp otherProperties:storedServiceProperties];

                    [semaphore signal];
                }];
            }];
        }];
    }];
    [semaphore wait];
}

- (void)testServicePropertiesHourMetrics
{
    AZSTestSemaphore *semaphore = [[AZSTestSemaphore alloc] init];
    _sp.defaultServiceVersion = AZSCTargetStorageVersion;
    _sp.hourMetrics = [[AZSMetricsProperties alloc] init];
    _sp.hourMetrics.metricsLevel = AZSMetricsLevelDisabled;
    _sp.hourMetrics.retentionIntervalInDays = nil;
    _sp.hourMetrics.version = @"1.0";

    [self.blobClient uploadServicePropertiesWithServiceProperties:_sp completionHandler:^(NSError *err) {
        [self checkPassageOfError:err expectToPass:YES expectedHttpErrorCode:-1 message:@"Upload service properties"];

        //[NSThread sleepForTimeInterval:30];
        [self.blobClient downloadServicePropertiesWithCompletionHandler:^(NSError *error, AZSServiceProperties *storedServiceProperties) {
            [self checkPassageOfError:error expectToPass:YES expectedHttpErrorCode:-1 message:@"Download service properties"];
            [self checkEqualityOfServiceProperties:_sp otherProperties:storedServiceProperties];

            // service
            _sp.hourMetrics.metricsLevel = AZSMetricsLevelService;
            [self.blobClient uploadServicePropertiesWithServiceProperties:_sp completionHandler:^(NSError *err) {
                [self checkPassageOfError:err expectToPass:YES expectedHttpErrorCode:-1 message:@"Upload service properties"];

                //[NSThread sleepForTimeInterval:30];
                [self.blobClient downloadServicePropertiesWithCompletionHandler:^(NSError *error, AZSServiceProperties *storedServiceProperties) {
                    [self checkPassageOfError:error expectToPass:YES expectedHttpErrorCode:-1 message:@"Download service properties"];
                    [self checkEqualityOfServiceProperties:_sp otherProperties:storedServiceProperties];

                    // service and API
                    _sp.hourMetrics.metricsLevel = AZSMetricsLevelServiceAndAPI;
                    [self.blobClient uploadServicePropertiesWithServiceProperties:_sp completionHandler:^(NSError *err) {
                        [self checkPassageOfError:err expectToPass:YES expectedHttpErrorCode:-1 message:@"Upload service properties"];

                        //[NSThread sleepForTimeInterval:30];
                        [self.blobClient downloadServicePropertiesWithCompletionHandler:^(NSError *error, AZSServiceProperties *storedServiceProperties) {
                            [self checkPassageOfError:error expectToPass:YES expectedHttpErrorCode:-1 message:@"Download service properties"];
                            [self checkEqualityOfServiceProperties:_sp otherProperties:storedServiceProperties];

                            [semaphore signal];
                        }];
                    }];
                }];
            }];
        }];
    }];
    [semaphore wait];
}

- (void)testServicePropertiesMinuteMetrics
{
    // Metrics disabled
    AZSTestSemaphore *semaphore = [[AZSTestSemaphore alloc] init];
    _sp.defaultServiceVersion = AZSCTargetStorageVersion;
    _sp.minuteMetrics = [[AZSMetricsProperties alloc] init];
    _sp.minuteMetrics.metricsLevel = AZSMetricsLevelDisabled;
    _sp.minuteMetrics.retentionIntervalInDays = nil;
    _sp.minuteMetrics.version = @"1.0";

    [self.blobClient uploadServicePropertiesWithServiceProperties:_sp completionHandler:^(NSError *err) {
        [self checkPassageOfError:err expectToPass:YES expectedHttpErrorCode:-1 message:@"Upload service properties"];

        //[NSThread sleepForTimeInterval:30];
        [self.blobClient downloadServicePropertiesWithCompletionHandler:^(NSError *error, AZSServiceProperties *storedServiceProperties) {
            [self checkPassageOfError:error expectToPass:YES expectedHttpErrorCode:-1 message:@"Download service properties"];
            [self checkEqualityOfServiceProperties:_sp otherProperties:storedServiceProperties];

            // Service metrics
            _sp.minuteMetrics.metricsLevel = AZSMetricsLevelService;
            [self.blobClient uploadServicePropertiesWithServiceProperties:_sp completionHandler:^(NSError *err) {
                [self checkPassageOfError:err expectToPass:YES expectedHttpErrorCode:-1 message:@"Upload service properties"];

                //[NSThread sleepForTimeInterval:30];
                [self.blobClient downloadServicePropertiesWithCompletionHandler:^(NSError *error, AZSServiceProperties *storedServiceProperties) {
                    [self checkPassageOfError:error expectToPass:YES expectedHttpErrorCode:-1 message:@"Download service properties"];
                    [self checkEqualityOfServiceProperties:_sp otherProperties:storedServiceProperties];

                    // Service and API metrics
                    _sp.minuteMetrics.metricsLevel = AZSMetricsLevelServiceAndAPI;
                    [self.blobClient uploadServicePropertiesWithServiceProperties:_sp completionHandler:^(NSError *err) {
                        [self checkPassageOfError:err expectToPass:YES expectedHttpErrorCode:-1 message:@"Upload service properties"];

                        //[NSThread sleepForTimeInterval:30];
                        [self.blobClient downloadServicePropertiesWithCompletionHandler:^(NSError *error, AZSServiceProperties *storedServiceProperties) {
                            [self checkPassageOfError:error expectToPass:YES expectedHttpErrorCode:-1 message:@"Download service properties"];
                            [self checkEqualityOfServiceProperties:_sp otherProperties:storedServiceProperties];

                            [semaphore signal];
                        }];
                    }];
                }];
            }];
        }];
    }];
    [semaphore wait];
}

- (void)testServicePropertiesRetentionPolicies
{
    // Set retention policy to nil with metrics disabled
    AZSTestSemaphore *semaphore = [[AZSTestSemaphore alloc] init];
    _sp.defaultServiceVersion = AZSCTargetStorageVersion;
    _sp.minuteMetrics = [[AZSMetricsProperties alloc] init];
    _sp.minuteMetrics.metricsLevel = AZSMetricsLevelDisabled;
    _sp.minuteMetrics.retentionIntervalInDays = nil;
    _sp.hourMetrics = [[AZSMetricsProperties alloc] init];
    _sp.hourMetrics.metricsLevel = AZSMetricsLevelDisabled;
    _sp.hourMetrics.retentionIntervalInDays = nil;

    [self.blobClient uploadServicePropertiesWithServiceProperties:_sp completionHandler:^(NSError *err) {
        [self checkPassageOfError:err expectToPass:YES expectedHttpErrorCode:-1 message:@"Upload service properties"];

        //[NSThread sleepForTimeInterval:30];
        [self.blobClient downloadServicePropertiesWithCompletionHandler:^(NSError *error, AZSServiceProperties *storedServiceProperties) {
            [self checkPassageOfError:error expectToPass:YES expectedHttpErrorCode:-1 message:@"Download service properties"];
            [self checkEqualityOfServiceProperties:_sp otherProperties:storedServiceProperties];

            // Enable retention policy with service metrics enabled
            _sp.minuteMetrics.metricsLevel = AZSMetricsLevelService;
            _sp.minuteMetrics.retentionIntervalInDays = [NSNumber numberWithInteger:1];
            _sp.hourMetrics.metricsLevel = AZSMetricsLevelService;
            _sp.hourMetrics.retentionIntervalInDays = [NSNumber numberWithInteger:1];

            [self.blobClient uploadServicePropertiesWithServiceProperties:_sp completionHandler:^(NSError *err) {
                [self checkPassageOfError:err expectToPass:YES expectedHttpErrorCode:-1 message:@"Upload service properties"];

                //[NSThread sleepForTimeInterval:30];
                [self.blobClient downloadServicePropertiesWithCompletionHandler:^(NSError *error, AZSServiceProperties *storedServiceProperties) {
                    [self checkPassageOfError:error expectToPass:YES expectedHttpErrorCode:-1 message:@"Download service properties"];
                    [self checkEqualityOfServiceProperties:_sp otherProperties:storedServiceProperties];

                    // Enable retention policy with service and API metrics enabled
                    _sp.minuteMetrics.metricsLevel = AZSMetricsLevelServiceAndAPI;
                    _sp.minuteMetrics.retentionIntervalInDays = [NSNumber numberWithInteger:2];
                    _sp.hourMetrics.metricsLevel = AZSMetricsLevelServiceAndAPI;
                    _sp.hourMetrics.retentionIntervalInDays = [NSNumber numberWithInteger:2];

                    [self.blobClient uploadServicePropertiesWithServiceProperties:_sp completionHandler:^(NSError *err) {
                        [self checkPassageOfError:err expectToPass:YES expectedHttpErrorCode:-1 message:@"Upload service properties"];

                        //[NSThread sleepForTimeInterval:30];
                        [self.blobClient downloadServicePropertiesWithCompletionHandler:^(NSError *error, AZSServiceProperties *storedServiceProperties) {
                            [self checkPassageOfError:error expectToPass:YES expectedHttpErrorCode:-1 message:@"Download service properties"];
                            [self checkEqualityOfServiceProperties:_sp otherProperties:storedServiceProperties];

                            // Set retention policy nil with logging disabled.
                            _sp.logging = [[AZSLoggingProperties alloc] init];
                            _sp.logging.retentionIntervalInDays = nil;
                            _sp.logging.logOperationTypes = AZSLoggingOperationNone;
                            [self.blobClient uploadServicePropertiesWithServiceProperties:_sp completionHandler:^(NSError *err) {
                                [self checkPassageOfError:err expectToPass:YES expectedHttpErrorCode:-1 message:@"Upload service properties"];

                                //[NSThread sleepForTimeInterval:30];
                                [self.blobClient downloadServicePropertiesWithCompletionHandler:^(NSError *error, AZSServiceProperties *storedServiceProperties) {
                                    [self checkPassageOfError:error expectToPass:YES expectedHttpErrorCode:-1 message:@"Download service properties"];
                                    [self checkEqualityOfServiceProperties:_sp otherProperties:storedServiceProperties];

                                    // Set retention policy not nil with logging disabled.
                                    _sp.logging.retentionIntervalInDays = [NSNumber numberWithInteger:3];
                                    _sp.logging.logOperationTypes = AZSLoggingOperationNone;
                                    [self.blobClient uploadServicePropertiesWithServiceProperties:_sp completionHandler:^(NSError *err) {
                                        [self checkPassageOfError:err expectToPass:YES expectedHttpErrorCode:-1 message:@"Upload service properties"];

                                        //[NSThread sleepForTimeInterval:30];
                                        [self.blobClient downloadServicePropertiesWithCompletionHandler:^(NSError *error, AZSServiceProperties *storedServiceProperties) {
                                            [self checkPassageOfError:error expectToPass:YES expectedHttpErrorCode:-1 message:@"Download service properties"];
                                            [self checkEqualityOfServiceProperties:_sp otherProperties:storedServiceProperties];

                                            // Set retention policy nil with logging enabled
                                            _sp.logging.retentionIntervalInDays = nil;
                                            _sp.logging.logOperationTypes = AZSLoggingOperationRead | AZSLoggingOperationWrite | AZSLoggingOperationDelete;
                                            [self.blobClient uploadServicePropertiesWithServiceProperties:_sp completionHandler:^(NSError *err) {
                                                [self checkPassageOfError:err expectToPass:YES expectedHttpErrorCode:-1 message:@"Upload service properties"];

                                                //[NSThread sleepForTimeInterval:30];
                                                [self.blobClient downloadServicePropertiesWithCompletionHandler:^(NSError *error, AZSServiceProperties *storedServiceProperties) {
                                                    [self checkPassageOfError:error expectToPass:YES expectedHttpErrorCode:-1 message:@"Download service properties"];
                                                    [self checkEqualityOfServiceProperties:_sp otherProperties:storedServiceProperties];

                                                    // Set retention policy not nil with logging enabled
                                                    _sp.logging.retentionIntervalInDays = [NSNumber numberWithInteger:4];
                                                    [self.blobClient uploadServicePropertiesWithServiceProperties:_sp completionHandler:^(NSError *err) {
                                                        [self checkPassageOfError:err expectToPass:YES expectedHttpErrorCode:-1 message:@"Upload service properties"];

                                                        //[NSThread sleepForTimeInterval:30];
                                                        [self.blobClient downloadServicePropertiesWithCompletionHandler:^(NSError *error, AZSServiceProperties *storedServiceProperties) {
                                                            [self checkPassageOfError:error expectToPass:YES expectedHttpErrorCode:-1 message:@"Download service properties"];
                                                            [self checkEqualityOfServiceProperties:_sp otherProperties:storedServiceProperties];
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
    [semaphore wait];
}

- (void)testCorsRule:(AZSCorsRule *)corsRule
{
    AZSTestSemaphore *semaphore = [[AZSTestSemaphore alloc] init];
    _sp.corsRules = [[NSMutableArray alloc] init];
    [_sp.corsRules addObject:corsRule];

    [self.blobClient uploadServicePropertiesWithServiceProperties:_sp completionHandler:^(NSError *err) {
        [self checkPassageOfError:err expectToPass:YES expectedHttpErrorCode:-1 message:@"Upload service properties"];

        //[NSThread sleepForTimeInterval:30];
        [self.blobClient downloadServicePropertiesWithCompletionHandler:^(NSError *error, AZSServiceProperties *storedServiceProperties) {
            [self checkPassageOfError:error expectToPass:YES expectedHttpErrorCode:-1 message:@"Download service properties"];
            [self checkEqualityOfServiceProperties:_sp otherProperties:storedServiceProperties];

            [semaphore signal];
        }];
    }];
    [semaphore wait];
}

- (void)testCorsRules:(NSMutableArray *)corsRules
{
    AZSTestSemaphore *semaphore = [[AZSTestSemaphore alloc] init];
    [_sp.corsRules removeAllObjects];

    for (AZSCorsRule *corsRule in corsRules)
    {
        [_sp.corsRules addObject:corsRule];
    }

    [self.blobClient uploadServicePropertiesWithServiceProperties:_sp completionHandler:^(NSError *err) {
        [self checkPassageOfError:err expectToPass:YES expectedHttpErrorCode:-1 message:@"Upload service properties"];

        //[NSThread sleepForTimeInterval:30];
        [self.blobClient downloadServicePropertiesWithCompletionHandler:^(NSError *error, AZSServiceProperties *storedServiceProperties) {
            [self checkPassageOfError:error expectToPass:YES expectedHttpErrorCode:-1 message:@"Download service properties"];
            [self checkEqualityOfServiceProperties:_sp otherProperties:storedServiceProperties];

            [semaphore signal];
        }];
    }];
    [semaphore wait];
}

- (void)testServicePropertiesValidCorsRules
{
    AZSCorsRule *ruleMinRequired = [[AZSCorsRule alloc] init];
    ruleMinRequired.allowedOrigins = [[NSMutableArray alloc] init];
    [ruleMinRequired.allowedOrigins addObject:@"www.xyz.com"];
    ruleMinRequired.allowedHttpMethods = AZSCorsHttpMethodGet;
    [self testCorsRule:ruleMinRequired];

    AZSCorsRule *ruleBasic = [[AZSCorsRule alloc] init];
    ruleBasic.allowedOrigins = [[NSMutableArray alloc] init];
    [ruleBasic.allowedOrigins addObject:@"www.ab.com"];
    [ruleBasic.allowedOrigins addObject:@"www.bc.com"];
    ruleBasic.allowedHttpMethods = AZSCorsHttpMethodGet | AZSCorsHttpMethodPut;
    ruleBasic.allowedHeaders = [[NSMutableArray alloc] init];
    [ruleBasic.allowedHeaders addObjectsFromArray: @[@"x-ms-meta-data*", @"x-ms-meta-target*", @"x-ms-meta-xyz", @"x-ms-meta-foo"]];
    ruleBasic.exposedHeaders = [[NSMutableArray alloc] init];
    [ruleBasic.exposedHeaders addObjectsFromArray: @[@"x-ms-meta-data*", @"x-ms-meta-source*", @"x-ms-meta-abc", @"x-ms-meta-bcd"]];
    ruleBasic.maxAgeInSeconds = 500;
    [self testCorsRule:ruleBasic];

    AZSCorsRule *ruleAllMethods = [[AZSCorsRule alloc] init];
    ruleAllMethods.allowedOrigins = [[NSMutableArray alloc] init];
    [ruleAllMethods.allowedOrigins addObject:@"www.ab.com"];
    [ruleAllMethods.allowedOrigins addObject:@"www.bc.com"];
    ruleAllMethods.allowedHttpMethods = AZSCorsHttpMethodGet |AZSCorsHttpMethodHead | AZSCorsHttpMethodPost | AZSCorsHttpMethodPut | AZSCorsHttpMethodDelete | AZSCorsHttpMethodTrace | AZSCorsHttpMethodOptions | AZSCorsHttpMethodConnect | AZSCorsHttpMethodMerge;
    [self testCorsRule:ruleAllMethods];

    AZSCorsRule *ruleSingleExposedHeader = [[AZSCorsRule alloc] init];
    ruleSingleExposedHeader.allowedOrigins = [[NSMutableArray alloc] init];
    [ruleSingleExposedHeader.allowedOrigins addObject:@"www.ab.com"];
    ruleSingleExposedHeader.allowedHttpMethods = AZSCorsHttpMethodGet;
    ruleSingleExposedHeader.exposedHeaders = [[NSMutableArray alloc] init];
    [ruleSingleExposedHeader.exposedHeaders addObject:@"x-ms-meta-bcd"];
    [self testCorsRule:ruleSingleExposedHeader];

    AZSCorsRule *ruleSingleExposedPrefixHeader = [[AZSCorsRule alloc] init];
    ruleSingleExposedPrefixHeader.allowedOrigins = [[NSMutableArray alloc] init];
    [ruleSingleExposedPrefixHeader.allowedOrigins addObject:@"www.ab.com"];
    ruleSingleExposedPrefixHeader.allowedHttpMethods = AZSCorsHttpMethodGet;
    ruleSingleExposedPrefixHeader.exposedHeaders = [[NSMutableArray alloc] init];
    [ruleSingleExposedPrefixHeader.exposedHeaders addObject:@"x-ms-meta-bcd"];
    [self testCorsRule:ruleSingleExposedPrefixHeader];

    AZSCorsRule *ruleSingleAllowedHeader = [[AZSCorsRule alloc] init];
    ruleSingleAllowedHeader.allowedOrigins = [[NSMutableArray alloc] init];
    [ruleSingleAllowedHeader.allowedOrigins addObject:@"www.ab.com"];
    ruleSingleAllowedHeader.allowedHttpMethods = AZSCorsHttpMethodGet;
    ruleSingleAllowedHeader.allowedHeaders = [[NSMutableArray alloc] init];
    [ruleSingleAllowedHeader.allowedHeaders addObject:@"x-ms-meta-xyz"];
    [self testCorsRule:ruleSingleAllowedHeader];

    AZSCorsRule *ruleSingleAllowedPrefixHeader = [[AZSCorsRule alloc] init];
    ruleSingleAllowedPrefixHeader.allowedOrigins = [[NSMutableArray alloc] init];
    [ruleSingleAllowedPrefixHeader.allowedOrigins addObject:@"www.ab.com"];
    ruleSingleAllowedPrefixHeader.allowedHttpMethods = AZSCorsHttpMethodGet;
    ruleSingleAllowedPrefixHeader.allowedHeaders = [[NSMutableArray alloc] init];
    [ruleSingleAllowedPrefixHeader.allowedHeaders addObject:@"x-ms-meta-xyz"];
    [self testCorsRule:ruleSingleAllowedPrefixHeader];

    AZSCorsRule *ruleAllowAll = [[AZSCorsRule alloc] init];
    ruleAllowAll.allowedOrigins = [[NSMutableArray alloc] init];
    [ruleAllowAll.allowedOrigins addObject:@"*"];
    ruleAllowAll.allowedHttpMethods = AZSCorsHttpMethodGet;
    ruleAllowAll.allowedHeaders = [[NSMutableArray alloc] init];
    [ruleAllowAll.allowedHeaders addObject:@"*"];
    ruleAllowAll.exposedHeaders = [[NSMutableArray alloc] init];
    [ruleAllowAll.exposedHeaders addObject:@"*"];
    [self testCorsRule:ruleAllowAll];

    NSMutableArray *testRules = [[NSMutableArray alloc] init];

    // Empty rule set should delete all rules
    [self testCorsRules:testRules];
    
    // Duplicate rules
    [testRules addObject:ruleBasic];
    [testRules addObject:ruleBasic];
    [self testCorsRules:testRules];
    
    // Test max number of rules (five)
    [testRules removeAllObjects];
    [testRules addObject:ruleBasic];
    [testRules addObject:ruleMinRequired];
    [testRules addObject:ruleAllMethods];
    [testRules addObject:ruleSingleExposedHeader];
    [testRules addObject:ruleSingleExposedPrefixHeader];
    [self testCorsRules:testRules];
    
    // Test over max number of rules (six)
    [_sp.corsRules addObject:ruleSingleAllowedHeader];
    AZSTestSemaphore *semaphore = [[AZSTestSemaphore alloc] init];

    [self.blobClient uploadServicePropertiesWithServiceProperties:_sp completionHandler:^(NSError *err) {
        [self checkPassageOfError:err expectToPass:NO expectedHttpErrorCode:400 message:@"Upload service properties"];
        [semaphore signal];
    }];
    [semaphore wait];

}

@end
