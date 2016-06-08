// -----------------------------------------------------------------------------------------
// <copyright file=".m" company="Microsoft">
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

#include <asl.h>

#import "AZSErrors.h"
#import "AZSTestBase.h"
#import "AZSTestSemaphore.h"
#import "AZSUtil.h"
#import "AZSConstants.h"
#import "AZSCloudStorageAccount.h"
#import "AZSOperationContext.h"

@interface AZSTestBase()
{
    aslclient _logger;
}
@end

@implementation AZSTestBase

- (void)setUp
{
    [super setUp];
    
    // Open a logger that will log to STD_ERR
    // Just like NSLOG()
    _logger = asl_open("testLogger", "testFacility", ASL_OPT_STDERR);
    
    [AZSOperationContext setGlobalLogger:_logger];
    
/*    aslmsg message = asl_new(ASL_TYPE_MSG);

    
    [AZSOperationContext setGlobalLogFunction:^(AZSLogLevel logLevel, NSString *stringToLog) {
        ASL_PREFILTER_LOG(_logger, message, 7, "%s", [stringToLog cStringUsingEncoding:NSUTF8StringEncoding]);
    }];
 */

//    [AZSOperationContext setGlobalLogLevel:AZSLogLevelNoLogging];

    [AZSOperationContext setGlobalLogLevel:AZSLogLevelInfo];
//    [AZSOperationContext setGlobalLogLevel:AZSLogLevelDebug];
    
    NSString *path = [[NSBundle bundleForClass:[self class]] pathForResource:@"test_configurations" ofType:@"json"];
    NSInputStream *fileStream = [[NSInputStream alloc] initWithFileAtPath:path];
    [fileStream open];
    NSError *error;
    NSDictionary *json = (NSDictionary *)[NSJSONSerialization JSONObjectWithStream:fileStream options:0 error:&error];
    NSString *targetName = json[@"target"];
    NSString *connectionString = (NSString *)((NSArray *)(json[@"tenants"]))[[(NSArray *)(json[@"tenants"]) indexOfObjectPassingTest:^(id object, NSUInteger idx, BOOL *stop) {
        return [(NSString *)((NSDictionary *)object)[@"name"] isEqualToString:targetName];
    }]][@"connection_string"];
    
    self.account = [AZSCloudStorageAccount accountFromConnectionString:connectionString error:&error];
    
    // Put setup code here; it will be run once, before the first test case.
}

- (void)tearDown
{
    // Put teardown code here; it will be run once, after the last test case.
    NSLog(@"closing logger");
    asl_close(_logger);
    [super tearDown];
}

- (void)checkPassageOfError:(NSError *)err expectToPass:(BOOL)expected expectedHttpErrorCode:(int)code message:(NSString *)message
{
    int badCode = [err.userInfo[AZSCHttpStatusCode] intValue];
    if (expected) {
        XCTAssertNil(err, @"%@ failed.", message);
    }
    else {
        XCTAssertNotNil(err, @"%@ unexpectedly passed.", message);
        XCTAssertEqual(code, badCode);
    }
}

-(NSRunLoop *)runloopWithSemaphore:(AZSTestSemaphore *)semaphore
{
    __block volatile NSRunLoop *runloop = nil;
    AZSTestSemaphore *runloopSemaphore = [[AZSTestSemaphore alloc] init];
    
    [NSThread detachNewThreadSelector:@selector(executeBlock:) toTarget:self withObject:^() {
        runloop = [NSRunLoop currentRunLoop];
        [runloopSemaphore signal];
        
        while (!semaphore.done) {
            BOOL loopSuccess = [runloop runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:2]];
            if (!loopSuccess) {
                [[AZSUtil operationlessContext] logAtLevel:AZSLogLevelInfo withMessage:@"Runloop did not run."];
                [NSThread sleepForTimeInterval:.25];
            }
        }
    }];
    
    [runloopSemaphore wait];
    
    return (NSRunLoop *) runloop;
}

-(void)executeBlock:(void(^)())block
{
    block();
}

@end