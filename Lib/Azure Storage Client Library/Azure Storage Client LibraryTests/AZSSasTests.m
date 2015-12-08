// -----------------------------------------------------------------------------------------
// <copyright file="AZSSasTests.m" company="Microsoft">
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
#import "AZSAccessCondition.h"
#import "AZSBlobRequestOptions.h"
#import "AZSBlobContainerPermissions.h"
#import "AZSBlobTestBase.h"
#import "AZSBlockListItem.h"
#import "AZSCloudBlob.h"
#import "AZSCloudBlobContainer.h"
#import "AZSCloudBlobClient.h"
#import "AZSCloudBlockBlob.h"
#import "AZSCloudStorageAccount.h"
#import "AZSContinuationToken.h"
#import "AZSOperationContext.h"
#import "AZSRequestResult.h"
#import "AZSResultSegment.h"
#import "AZSSharedAccessBlobParameters.h"
#import "AZSSharedAccessHeaders.h"
#import "AZSStorageCredentials.h"
#import "AZSStorageUri.h"
#import "AZSTestHelpers.h"
#import "AZSTestSemaphore.h"
#import "AZSUriQueryBuilder.h"

@interface AZSSasTests : AZSBlobTestBase
@property AZSCloudBlobContainer *blobContainer;
@property AZSCloudBlockBlob *blockBlob;

@end

@implementation AZSSasTests : AZSBlobTestBase

- (void)setUp
{
    [super setUp];
    
    // Put setup code here; it will be run once, before the first test case.
    AZSTestSemaphore *semaphore = [[AZSTestSemaphore alloc] init];
    NSString *containerName = [[NSString stringWithFormat:@"sampleioscontainer%@",[[[NSUUID UUID] UUIDString] stringByReplacingOccurrencesOfString:@"-" withString:@""]] lowercaseString];
    self.blobContainer = [self.blobClient containerReferenceFromName:containerName];
    
    [self.blobContainer createContainerIfNotExistsWithCompletionHandler:^(NSError* err, BOOL created) {
        self.blockBlob = [self.blobContainer blockBlobReferenceFromName:@"testBlockBlob"];
        [self.blockBlob  uploadFromText:@"test" completionHandler:^(NSError *err) {
            [semaphore signal];
        }];
    }];
    [semaphore wait];
}

- (void)tearDown
{
    // Put teardown code here; it will be run once, after the last test case.
    AZSTestSemaphore *semaphore= [[AZSTestSemaphore alloc] init];
    [self.blobContainer deleteContainerIfExistsWithCompletionHandler:^(NSError* err, BOOL created) {
        [semaphore signal];
    }];
    [semaphore wait];
    
    [super tearDown];
}

- (void) checkPassageOfError:(NSError *)err expectToPass:(BOOL)expected errorCode:(int)code message:(NSString *)message
{
    if (expected) {
        XCTAssertNil(err, @"%@ failed.  Error code = %ld, error domain = %@, error userinfo = %@", message, (long)err.code, err.domain, err.userInfo);
    }
    else {
        XCTAssertNotNil(err, @"%@ unexpectedly passed.", message);
        
        int status = [[err.userInfo objectForKey:@"HTTP Status Code"] intValue];
        XCTAssertEqual(code, status);
    }
}

-(AZSStorageUri *)addToQuery:(AZSStorageUri *)initialUri queryString:(NSString *)queryString
{
    XCTAssertFalse([[initialUri.primaryUri absoluteString] containsString:@"?"]);
    XCTAssertFalse([[initialUri.secondaryUri absoluteString] containsString:@"?"]);
    
    NSURL *primary = [[NSURL alloc] initWithString:[NSString stringWithFormat:@"%@?%@", initialUri.primaryUri.absoluteString, queryString]];
    AZSStorageUri *uri = [[AZSStorageUri alloc] initWithPrimaryUri:primary];
    if (initialUri.secondaryUri) {
        initialUri.secondaryUri = [[NSURL alloc] initWithString:[NSString stringWithFormat:@"%@?%@", initialUri.secondaryUri.absoluteString, queryString]];
    }
    
    return uri;
}

- (void)testApiVersion
{
    AZSTestSemaphore *semaphore= [[AZSTestSemaphore alloc] init];
    AZSSharedAccessBlobParameters *sp = [[AZSSharedAccessBlobParameters alloc] init];
    sp.permissions = AZSSharedAccessPermissionsRead|AZSSharedAccessPermissionsWrite|AZSSharedAccessPermissionsList|AZSSharedAccessPermissionsDelete;
    sp.sharedAccessExpiryTime = [[NSDate alloc] initWithTimeIntervalSinceNow:300];
    
    NSError *error = nil;
    NSString *sas = [self.blockBlob createSharedAccessSignatureWithParameters:sp error:&error];
    [self checkPassageOfError:error expectToPass:YES errorCode:-1 message:@"Create SAS token"];
    
    __block NSRange match = [sas rangeOfString:@"api-version"];
    XCTAssertTrue(match.location == NSNotFound);
    
    AZSOperationContext *context = [[AZSOperationContext alloc] init];
    context.responseReceived = ^void(NSMutableURLRequest *req, NSHTTPURLResponse *resp, AZSOperationContext *ctxt) {
        match = [[resp.URL absoluteString] rangeOfString:@"api-version"];
        XCTAssertFalse(match.location == NSNotFound);
    };
    
    AZSCloudBlockBlob *sasBlob = [[AZSCloudBlockBlob alloc] initWithStorageUri:[self addToQuery:self.blockBlob.storageUri queryString:sas]];
    [sasBlob uploadFromText:@"test" accessCondition:nil requestOptions:nil operationContext:context completionHandler:^(NSError *err) {
        [self checkPassageOfError:err expectToPass:YES errorCode:-1 message:@"Upload from text"];
        [semaphore signal];
    }];
    [semaphore wait];
}

- (void)testContainerSas
{
    // Test from stored policy
    // TODO: Uncomment
    /*AZSSharedAccessBlobParameters *sp = [[AZSSharedAccessBlobParameters alloc] init];
    sp.storedPolicyIdentifier = @"readlist";
    AZSTestSemaphore *lock = [[AZSTestSemaphore alloc] init];
    AZSSharedAccessPolicy *policy = [[AZSSharedAccessPolicy alloc] initWithIdentifier:sp.storedPolicyIdentifier];
    policy.permissions = AZSSharedAccessPermissionsRead|AZSSharedAccessPermissionsList;
    policy.sharedAccessExpiryTime = [[NSDate alloc] initWithTimeIntervalSinceNow:300];
    
    AZSBlobContainerPermissions *permissions = [[AZSBlobContainerPermissions alloc] init];
    [permissions.sharedAccessPolicies setObject:policy forKey:sp.storedPolicyIdentifier];
    [self.blobContainer uploadPermissions:permissions completionHandler:^(NSError *err) {
        [self checkPassageOfError:err expectToPass:YES errorCode:-1 message:@"Upload permissions"];
        [NSThread sleepForTimeInterval:30];
     
        [self testContainerSASWithParameters:sp completionHandler:^{
            [lock signal];
        }];
    }];*/
    
    // Test from local parameters
    AZSTestSemaphore *innerSemaphore = [[AZSTestSemaphore alloc] init];
    AZSSharedAccessBlobParameters *sp2 = [[AZSSharedAccessBlobParameters alloc] init];
    sp2.permissions = AZSSharedAccessPermissionsRead|AZSSharedAccessPermissionsList; //policy.permissions;
    sp2.sharedAccessExpiryTime = [[NSDate alloc] initWithTimeIntervalSinceNow:300]; //policy.sharedAccessExpiryTime;
    [self testContainerSASWithParameters:sp2 completionHandler:^(){
        [innerSemaphore signal];
    }];
    [innerSemaphore wait];
    // [lock wait];
}

- (void)testContainerSASWithParameters:(AZSSharedAccessBlobParameters *)sp completionHandler:(void(^)())completionHandler
{
    __block NSError *error = nil;
    NSString *containerReadListSAS = [self.blobContainer createSharedAccessSignatureWithParameters:sp error:&error];
    [self checkPassageOfError:error expectToPass:YES errorCode:-1 message:@"Create SAS token"];
    
    AZSCloudBlobContainer *readListContainer = [[AZSCloudBlobContainer alloc] initWithStorageUri:[self addToQuery:self.blobContainer.storageUri queryString:containerReadListSAS]];
    XCTAssertTrue([readListContainer.client.credentials isSAS]);
    
    AZSCloudBlockBlob *blobFromSasContainer = [readListContainer blockBlobReferenceFromName:self.blockBlob.blobName];
    [blobFromSasContainer downloadToStream:[[NSOutputStream alloc] initToMemory] accessCondition:nil requestOptions:nil operationContext:nil completionHandler:^(NSError * err) {
        [self checkPassageOfError:err expectToPass:YES errorCode:-1 message:@"Download blobFromSasContainer to stream"];
        
        // Withhold client and check new container's client has correct permissions
        AZSCloudBlobContainer *containerFromURI = [[AZSCloudBlobContainer alloc] initWithStorageUri:[self addToQuery:readListContainer.storageUri queryString:[self.blobContainer createSharedAccessSignatureWithParameters:sp error:&error]]];
        [self checkPassageOfError:error expectToPass:YES errorCode:-1 message:@"Create SAS token"];
        XCTAssertTrue([containerFromURI.client.credentials isSAS]);
        
        AZSCloudBlockBlob *blobFromUriContainer = [containerFromURI blockBlobReferenceFromName:self.blockBlob.blobName];
        [blobFromUriContainer downloadToStream:[[NSOutputStream alloc] initToMemory] accessCondition:nil requestOptions:nil operationContext:nil completionHandler:^(NSError * err) {
            [self checkPassageOfError:err expectToPass:YES errorCode:-1 message:@"Download blobFromUriContainer to stream"];
            
            // Generate credentials from SAS
            AZSStorageCredentials *creds = [[AZSStorageCredentials alloc] initWithSASToken:[self.blobContainer createSharedAccessSignatureWithParameters:sp error:&error]];
            [self checkPassageOfError:error expectToPass:YES errorCode:-1 message:@"Create SAS token"];
            
            AZSCloudBlobClient *bClient = [[AZSCloudBlobClient alloc] initWithStorageUri:self.blobContainer.client.storageUri credentials:creds];
            AZSCloudBlobContainer *containterFromClient = [bClient containerReferenceFromName:self.blobContainer.name];
            XCTAssertTrue([containterFromClient.client.credentials isSAS]);
            XCTAssertEqualObjects(bClient, containterFromClient.client);
            
            AZSCloudBlockBlob *blobFromClientContainer = [containerFromURI blockBlobReferenceFromName:self.blockBlob.blobName];
            [blobFromClientContainer downloadToStream:[[NSOutputStream alloc] initToMemory] accessCondition:nil requestOptions:nil operationContext:nil completionHandler:^(NSError * err) {
                [self checkPassageOfError:err expectToPass:YES errorCode:-1 message:@"Download blobFromClientContainer to stream"];
                
                completionHandler();
            }];
        }];
    }];
}

- (void)testContainerSasBlobHeaders
{
    
    AZSOperationContext *context = [[AZSOperationContext alloc] init];
    
    // Test with stored policy
    // TODO: Uncomment
    /*AZSTestSemaphore *lock = [[AZSTestSemaphore alloc] init];
    AZSSharedAccessBlobParameters *sp = [[AZSSharedAccessBlobParameters alloc] init];
    sp.storedPolicyIdentifier = @"readperm";
    
    AZSSharedAccessPolicy *policy = [[AZSSharedAccessPolicy alloc] initWithIdentifier:sp.storedPolicyIdentifier];
    policy.permissions = AZSSharedAccessPermissionsRead|AZSSharedAccessPermissionsWrite|AZSSharedAccessPermissionsList;
    policy.sharedAccessExpiryTime = [[NSDate alloc] initWithTimeIntervalSinceNow:300];
    
    AZSBlobContainerPermissions *permissions = [[AZSBlobContainerPermissions alloc] init];
    [permissions setValue:sp forKey:@"readperm"];
    [self.blobContainer uploadPermissions:permissions completionHandler:^(NSError * err) {
        [self checkPassageOfError:err expectToPass:YES errorCode:-1 message:@"Upload permissions"];
        
        [NSThread sleepForTimeInterval:30];
        
        [self testContainerSasBlobHeadersWithParameters:sp context:context completionHandler:^(){
            [lock signal];
        }];
    }];*/
    
    // Test with local parameters
    AZSTestSemaphore *innerSemaphore = [[AZSTestSemaphore alloc] init];
    AZSSharedAccessBlobParameters *sp2 = [[AZSSharedAccessBlobParameters alloc] init];
    sp2.permissions = AZSSharedAccessPermissionsRead|AZSSharedAccessPermissionsWrite|AZSSharedAccessPermissionsList; //policy.permissions;
    sp2.sharedAccessExpiryTime = [[NSDate alloc] initWithTimeIntervalSinceNow:300]; //policy.sharedAccessExpiryTime;
    
    [self testContainerSasBlobHeadersWithParameters:sp2 context:context completionHandler:^(){
        [innerSemaphore signal];
    }];
    [innerSemaphore wait];
    //[lock wait];
}

- (void)testContainerSasBlobHeadersWithParameters:(AZSSharedAccessBlobParameters *)sp context:(AZSOperationContext *)context completionHandler:(void(^)())completionHandler
{
    sp.headers = [[AZSSharedAccessHeaders alloc] init];
    sp.headers.cacheControl = @"no-cache";
    sp.headers.contentDisposition = @"attachment; filename=\"fname.ext\"";
    sp.headers.contentEncoding = @"gzip";
    sp.headers.contentLanguage = @"da";
    sp.headers.contentType = @"text/html; charset=utf-8";
    
    context.responseReceived = ^void(NSMutableURLRequest *req, NSHTTPURLResponse *resp, AZSOperationContext *ctxt) {
        XCTAssertTrue([@"no-cache" isEqualToString:[resp.allHeaderFields objectForKey:@"Cache-Control"]]);
        XCTAssertTrue([@"attachment; filename=\"fname.ext\"" isEqualToString:[resp.allHeaderFields objectForKey:@"Content-Disposition"]]);
        XCTAssertTrue([@"gzip" isEqualToString:[resp.allHeaderFields objectForKey:@"Content-Encoding"]]);
        XCTAssertTrue([@"da" isEqualToString:[resp.allHeaderFields objectForKey:@"Content-Language"]]);
        XCTAssertTrue([@"text/html; charset=utf-8" isEqualToString:[resp.allHeaderFields objectForKey:@"Content-Type"]]);
    };
    
    NSError *error = nil;
    AZSStorageCredentials *creds = [[AZSStorageCredentials alloc] initWithSASToken:[self.blobContainer createSharedAccessSignatureWithParameters:sp error:&error]];
    [self checkPassageOfError:error expectToPass:YES errorCode:-1 message:@"Create SAS token"];
    
    AZSCloudBlobContainer *cont = [[AZSCloudBlobContainer alloc] initWithStorageUri:self.blobContainer.storageUri credentials:creds];
    AZSCloudBlockBlob *sasBlob = [cont blockBlobReferenceFromName:self.blockBlob.blobName];
    
    [sasBlob downloadToStream:[[NSOutputStream alloc] initToMemory] accessCondition:nil requestOptions:nil operationContext:context completionHandler:^(NSError * err) {
        [self checkPassageOfError:err expectToPass:YES errorCode:-1 message:@"Download to stream"];

        completionHandler();
    }];
}

- (void)testContainerUpdateSas
{
    // Create a policy with read/write access and generate SAS
    AZSTestSemaphore *semaphore= [[AZSTestSemaphore alloc] init];

    // Test with stored policy
    // TODO: Uncomment
    /*AZSSharedAccessBlobParameters *sp = [[AZSSharedAccessBlobParameters alloc] init];
    sp.storedPolicyIdentifier = @"readlist";
    AZSSharedAccessBlobParameters *sp2 = [[AZSSharedAccessBlobParameters alloc] init];
    sp2.storedPolicyIdentifier = @"read";
    
    AZSSharedAccessPolicy *policy = [[AZSSharedAccessPolicy alloc] initWithIdentifier:sp.storedPolicyIdentifier];
    policy.permissions = AZSSharedAccessPermissionsRead|AZSSharedAccessPermissionsWrite;
    policy.sharedAccessExpiryTime = [[NSDate alloc] initWithTimeIntervalSinceNow:300];
    AZSSharedAccessPolicy *policy2 = [[AZSSharedAccessPolicy alloc] initWithIdentifier:sp2.storedPolicyIdentifier];
    policy2.permissions = AZSSharedAccessPermissionsRead;
    policy2.sharedAccessExpiryTime = policy.sharedAccessExpiryTime;
    
    AZSBlobContainerPermissions *permissions = [[AZSBlobContainerPermissions alloc] init];
    [permissions.sharedAccessPolicies setObject:policy forKey:sp.storedPolicyIdentifier];
    [permissions.sharedAccessPolicies setObject:policy2 forKey:sp2.storedPolicyIdentifier];
    
    [self.blobContainer uploadPermissions:permissions completionHandler:^(NSError *err) {
        [self checkPassageOfError:err expectToPass:YES errorCode:-1 message:@"Upload permissions"];
        
        [NSThread sleepForTimeInterval:30];
        
        [self testContainerUpdateSasWithParameters:sp otherParameters:sp2 completionHandler:^(){
            [lock signal];
        }];
    }];
    [lock wait];*/

    // Test with local parameters
    AZSSharedAccessBlobParameters *sp3 = [[AZSSharedAccessBlobParameters alloc] init];
    sp3.permissions = AZSSharedAccessPermissionsRead|AZSSharedAccessPermissionsWrite; //policy.permissions;
    sp3.sharedAccessExpiryTime = [[NSDate alloc] initWithTimeIntervalSinceNow:300]; //policy.sharedAccessExpiryTime;
    
    AZSSharedAccessBlobParameters *sp4 = [[AZSSharedAccessBlobParameters alloc] init];
    sp4.permissions = AZSSharedAccessPermissionsRead; //policy2.permissions;
    sp4.sharedAccessExpiryTime = [[NSDate alloc] initWithTimeIntervalSinceNow:300]; //policy2.sharedAccessExpiryTime;
    
    [self testContainerUpdateSasWithParameters:sp3 otherParameters:sp4 completionHandler:^(){
        [semaphore signal];
    }];
    [semaphore wait];
}

- (void)testContainerUpdateSasWithParameters:(AZSSharedAccessBlobParameters *)sprw otherParameters:(AZSSharedAccessBlobParameters *)spr completionHandler:(void(^)())completionHandler
{
    __block NSError *error = nil;
    NSString *sasToken = [self.blobContainer createSharedAccessSignatureWithParameters:sprw error:&error];
    [self checkPassageOfError:error expectToPass:YES errorCode:-1 message:@"Create SAS token"];
    
    __block AZSCloudBlockBlob *testBlob = [self.blobContainer blockBlobReferenceFromName:@"sasBlob"];
    [testBlob uploadFromText:@"test" completionHandler:^(NSError *err) {
        [self checkPassageOfError:err expectToPass:YES errorCode:-1 message:@"Upload from text"];
        
        [self testAccessWithSAS:sasToken permissions:AZSSharedAccessPermissionsRead|AZSSharedAccessPermissionsWrite container:self.blobContainer blob:testBlob completionHandler:^{
            // Change the policy to only read and update SAS.
            AZSSharedAccessBlobParameters *sp2 = [[AZSSharedAccessBlobParameters alloc] init];
            sp2.permissions = AZSSharedAccessPermissionsRead;
            sp2.sharedAccessExpiryTime = [[NSDate alloc] initWithTimeIntervalSinceNow:300];
            
            NSString *sasToken2 = [self.blobContainer createSharedAccessSignatureWithParameters:sp2 error:&error];
            [self checkPassageOfError:error expectToPass:YES errorCode:-1 message:@"Create SAS token"];
            
            AZSCloudBlobContainer *sasContainer = [[AZSCloudBlobContainer alloc] initWithStorageUri:[self addToQuery:self.blobContainer.storageUri queryString:sasToken2]];
            testBlob = [sasContainer blockBlobReferenceFromName:@"sasBlob2"];
            [testBlob uploadFromText:@"test" completionHandler:^(NSError *err) {
                [self checkPassageOfError:err expectToPass:NO errorCode:403 message:@"Upload from text"];
                
                completionHandler();
            }];
        }];
    }];
}

- (void)testContainerSasCombinations
{
    dispatch_semaphore_t counter = dispatch_semaphore_create(16);
    NSMutableArray *semaphores = [[NSMutableArray alloc] init];
    
    for (int i = AZSSharedAccessPermissionsRead; i <= AZSSharedAccessPermissionsBlobFull; i++) {
        // TODO: Remove
        if ((i & (AZSSharedAccessPermissionsAll ^ AZSSharedAccessPermissionsAdd ^ AZSSharedAccessPermissionsCreate)) == 0) {
            continue;
        }
        
        __block AZSTestSemaphore *semaphore= [[AZSTestSemaphore alloc] init];
        [semaphores addObject:semaphore];
        
        // Create random container and upload a test blob to it
        NSString *containerName = [[NSString stringWithFormat:@"sampleioscontainer%@",[[[NSUUID UUID] UUIDString] stringByReplacingOccurrencesOfString:@"-" withString:@""]] lowercaseString];
        AZSCloudBlobContainer *cont = [self.blobClient containerReferenceFromName:containerName];
        [cont createContainerIfNotExistsWithCompletionHandler:^(NSError* err, BOOL created) {
            [self checkPassageOfError:err expectToPass:YES errorCode:-1 message:@"Create container"];
            
            dispatch_semaphore_wait(counter, DISPATCH_TIME_FOREVER);
            AZSCloudBlockBlob *blob = [cont blockBlobReferenceFromName:@"sasBlob"];
            [blob uploadFromText:@"test" completionHandler:^(NSError *err) {
                [self checkPassageOfError:err expectToPass:YES errorCode:-1 message:@"Upload from text"];
                
                // Generate permissions from i
                AZSSharedAccessPermissions permissions = i & AZSSharedAccessPermissionsAll;
                AZSSharedAccessBlobParameters *sp = [[AZSSharedAccessBlobParameters alloc] init];
                sp.permissions = permissions;
                sp.sharedAccessExpiryTime = [[NSDate alloc] initWithTimeIntervalSinceNow:300];
                NSError *error = nil;
                
                // Test with stored policy
                // TODO: Uncomment
                /*AZSBlobContainerPermissions *contPerms = [[AZSBlobContainerPermissions alloc] init];
                [contPerms.sharedAccessPolicies setObject:policy forKey:[NSString stringWithFormat:@"readwrite%d", i]];
                AZSTestSemaphore *innerLock = [[AZSTestSemaphore alloc] init];
                 
                [self.blobContainer uploadPermissions:contPerms completionHandler:^(NSError *err) {
                    [self checkPassageOfError:error expectToPass:YES errorCode:-1 message:@"Upload permissions"];
                     
                    [NSThread sleepForTimeInterval:30];
                    // Generate SAS token and test access
                    NSError *error = nil;
                    NSString *sasToken = [cont createSharedAccessSignatureFromPolicy:policy error:&error];
                    [self checkPassageOfError:error expectToPass:YES errorCode:-1 message:@"Create SAS token"];
                    
                    [self testAccessWithSAS:sasToken permissions:permissions container:cont blob:blob completionHandler:^() {
                        dispatch_semaphore_signal(counter);
                        [innerLock signal];
                    }];
                    [innerLock signal];
                }];
                [lock wait];*/
                
                // Test with local parameters
                // Generate SAS token and test access
                NSString *sasToken = [cont createSharedAccessSignatureWithParameters:sp error:&error];
                [self checkPassageOfError:error expectToPass:YES errorCode:-1 message:@"Create SAS token"];
                
                [self testAccessWithSAS:sasToken permissions:permissions container:cont blob:blob completionHandler:^() {
                    dispatch_semaphore_signal(counter);
                    [semaphore signal];
                }];
            }];
        }];
    }
    [AZSTestSemaphore barrierOnSemaphores:semaphores];
}

- (void)testContainerPublicAccess
{
    AZSTestSemaphore *lock = [[AZSTestSemaphore alloc] init];
    AZSCloudBlockBlob *testBlob = [self.blobContainer blockBlobReferenceFromName:@"publicBlob"];
    [testBlob uploadFromText:@"test" completionHandler:^(NSError *err) {
        [self checkPassageOfError:err expectToPass:YES errorCode:-1 message:@"Upload from text"];
        [lock signal];
    }];
    [lock wait];
    
    AZSBlobContainerPermissions *permissions = [[AZSBlobContainerPermissions alloc] init];
    permissions.publicAccess = AZSContainerPublicAccessTypeContainer;
    [self.blobContainer uploadPermissions:permissions completionHandler:^(NSError * err) {
        [self checkPassageOfError:err expectToPass:YES errorCode:-1 message:@"Upload permissions"];
        [lock signal];
    }];
    [lock wait];
    [NSThread sleepForTimeInterval:35];
    
    [self testAccessWithSAS:nil permissions:AZSSharedAccessPermissionsList|AZSSharedAccessPermissionsRead container:self.blobContainer blob:testBlob completionHandler:^{
        permissions.publicAccess = AZSContainerPublicAccessTypeBlob;
        [self.blobContainer uploadPermissions:permissions completionHandler:^(NSError * err) {
            [self checkPassageOfError:err expectToPass:YES errorCode:-1 message:@"Upload Permissions"];
            
            [NSThread sleepForTimeInterval:30];
            [self testAccessWithSAS:nil permissions:AZSSharedAccessPermissionsRead container:self.blobContainer blob:testBlob completionHandler:^{
                [lock signal];
            }];
        }];
    }];
    [lock wait];
}

- (void) testBlockBlobSasCombinations
{
    NSMutableArray *semaphores = [[NSMutableArray alloc] init];
    dispatch_semaphore_t counter = dispatch_semaphore_create(8);
    
    for (AZSSharedAccessPermissions permissions = AZSSharedAccessPermissionsNone; permissions <= AZSSharedAccessPermissionsBlobFull; permissions++) {
        AZSTestSemaphore *semaphore = [[AZSTestSemaphore alloc] init];
        [semaphores addObject:semaphore];
        
        AZSCloudBlockBlob *blob = [self.blobContainer blockBlobReferenceFromName:[NSString stringWithFormat:@"testSasBlockBlob%ld", permissions]];
        [blob uploadFromText:@"test" completionHandler:^(NSError * err) {
            [self checkPassageOfError:err expectToPass:YES errorCode:-1 message:@"Upload from text"];
            dispatch_semaphore_wait(counter, DISPATCH_TIME_FOREVER);
            AZSSharedAccessBlobParameters *sp = [[AZSSharedAccessBlobParameters alloc] init];
            sp.permissions = permissions;
            sp.sharedAccessExpiryTime = [[NSDate alloc] initWithTimeIntervalSinceNow:300];
            
            NSError *error = nil;
            NSString *sasToken = [blob createSharedAccessSignatureWithParameters:sp error:&error];
            [self checkPassageOfError:error expectToPass:YES errorCode:-1 message:@"Create SAS token"];
            
            [self testAccessWithSAS:sasToken permissions:permissions container:nil blob:blob completionHandler:^{
                dispatch_semaphore_signal(counter);
                [semaphore signal];
            }];
        }];
    }
    [AZSTestSemaphore barrierOnSemaphores:semaphores];
}

- (void) testBlobSas
{
    // Test with stored policy
    // TODO: uncomment
    /*AZSTestSemaphore *lock = [[AZSTestSemaphore alloc] init];
    AZSSharedAccessBlobParameters *sp = [[AZSSharedAccessBlobParameters alloc] init];
    sp.storedPolicyIdentifier = @"readperm";
    
    AZSSharedAccessPolicy *policy = [[AZSSharedAccessPolicy alloc] initWithIdentifier:sp.storedPolicyIdentifier];
    policy.permissions = AZSSharedAccessPermissionsRead|AZSSharedAccessPermissionsList;
    policy.sharedAccessExpiryTime = [[NSDate alloc] initWithTimeIntervalSinceNow:300];
    AZSBlobContainerPermissions *permissions = [[AZSBlobContainerPermissions alloc] init];
    [permissions.sharedAccessPolicies setObject:policy forKey:sp.storedPolicyIdentifier];
    
    [self.blobContainer uploadPermissions:permissions completionHandler:^(NSError *err) {
        [self checkPassageOfError:err expectToPass:YES errorCode:-1 message:@"Upload Permissions"];
        
        [self testBlobSasWithParameters:sp completionHandler:^{
            [lock signal];
        }];
    }];
    [NSThread sleepForTimeInterval:30];*/
    
    // Test with local parameters
    AZSTestSemaphore *innerSemaphore = [[AZSTestSemaphore alloc] init];
    AZSSharedAccessBlobParameters *sp2 = [[AZSSharedAccessBlobParameters alloc] init];
    sp2.permissions = AZSSharedAccessPermissionsRead|AZSSharedAccessPermissionsList; //policy.permissions;
    sp2.sharedAccessExpiryTime = [[NSDate alloc] initWithTimeIntervalSinceNow:300]; //policy.sharedAccessExpiryTime;
    [self testBlobSasWithParameters:sp2 completionHandler:^(){
        [innerSemaphore signal];
    }];
    [innerSemaphore wait];
    //[lock wait];
}

- (void) testBlobSasWithParameters:(AZSSharedAccessBlobParameters *)sp completionHandler:(void(^)())completionHandler
{
    __block NSError *error = nil;
    NSString *blobURL = [NSString stringWithFormat:@"%@?%@", [[self.blockBlob.storageUri urlWithLocation:AZSStorageLocationPrimary] absoluteString], [self.blockBlob createSharedAccessSignatureWithParameters:sp error:&error]];
    [self checkPassageOfError:error expectToPass:YES errorCode:-1 message:@"Create SAS token"];
    
    AZSCloudBlockBlob *sasBlob = [[AZSCloudBlockBlob alloc] initWithUrl:[[NSURL alloc] initWithString:blobURL]];
    [sasBlob downloadToStream:[[NSOutputStream alloc] initToMemory] completionHandler:^(NSError * err) {
        [self checkPassageOfError:err expectToPass:YES errorCode:-1 message:@"Dowload to stream"];
        
        // Withhold the client and ensure the new blob's client still has SAS permissions
        AZSCloudBlockBlob *blobFromUri = [[AZSCloudBlockBlob alloc] initWithStorageUri:[self addToQuery:self.blockBlob.storageUri queryString:[self.blockBlob createSharedAccessSignatureWithParameters:sp error:&error]]];
        [self checkPassageOfError:error expectToPass:YES errorCode:-1 message:@"Create SAS token"];
        XCTAssertTrue([blobFromUri.client.credentials isSAS]);
        
        [blobFromUri downloadToStream:[[NSOutputStream alloc] initToMemory] accessCondition:nil requestOptions:nil operationContext:nil completionHandler:^(NSError * err){
            [self checkPassageOfError:err expectToPass:YES errorCode:-1 message:@"Dowload to stream"];
            
            // Generate credentials from SAS
            AZSStorageCredentials *creds = [[AZSStorageCredentials alloc] initWithSASToken:[self.blockBlob createSharedAccessSignatureWithParameters:sp error:&error]];
            [self checkPassageOfError:error expectToPass:YES errorCode:-1 message:@"Create SAS token"];
            
            AZSCloudBlobClient *bClient = [[AZSCloudBlobClient alloc] initWithStorageUri:sasBlob.client.storageUri credentials:creds];
            AZSCloudBlockBlob *blobFromClient = [[bClient containerReferenceFromName:self.blobContainer.name] blockBlobReferenceFromName:self.blockBlob.blobName];
            XCTAssertTrue([blobFromClient.client.credentials isSAS]);
            XCTAssertEqualObjects(bClient, blobFromClient.client);
            
            [blobFromClient downloadToStream:[[NSOutputStream alloc] initToMemory] accessCondition:nil requestOptions:nil operationContext:nil completionHandler:^(NSError *Err){
                [self checkPassageOfError:err expectToPass:YES errorCode:-1 message:@"Dowload to stream"];
                
                completionHandler();
            }];
        }];
    }];
}

- (void) testBlobSasSharedAccessBlobHeaders
{
    AZSOperationContext *context = [[AZSOperationContext alloc] init];
    
    // Test with stored policy
    // TODO: uncomment
    /*AZSTestSemaphore *lock = [[AZSTestSemaphore alloc] init];
    AZSSharedAccessBlobParameters *sp = [[AZSSharedAccessBlobParameters alloc] init];
    sp.storedPolicyIdentifier = @"readperm";
    
    AZSSharedAccessPolicy *policy = [[AZSSharedAccessPolicy alloc] initWithIdentifier:sp.storedPolicyIdentifier];
    policy.permissions = AZSSharedAccessPermissionsRead|AZSSharedAccessPermissionsWrite|AZSSharedAccessPermissionsList;
    policy.sharedAccessExpiryTime = [[NSDate alloc] initWithTimeIntervalSinceNow:300];
    AZSBlobContainerPermissions *permissions = [[AZSBlobContainerPermissions alloc] init];
    [permissions setValue:policy forKey:sp.storedPolicyIdentifier];
    [self.blobContainer uploadPermissions:permissions completionHandler:^(NSError * err) {
        [self checkPassageOfError:err expectToPass:YES errorCode:-1 message:@"Upload permissions"];
        
        [self testBlobSasSharedAccessBlobHeadersWithParameters:sp context:context completionHandler:^(){
            [lock signal];
        }];
    }];
    [NSThread sleepForTimeInterval:30];*/
    
    // Test with local parameters
    AZSTestSemaphore *innerSemaphore = [[AZSTestSemaphore alloc] init];
    AZSSharedAccessBlobParameters *sp2 = [[AZSSharedAccessBlobParameters alloc] init];
    sp2.permissions = AZSSharedAccessPermissionsRead|AZSSharedAccessPermissionsWrite|AZSSharedAccessPermissionsList; //policy.permissions;
    sp2.sharedAccessExpiryTime = [[NSDate alloc] initWithTimeIntervalSinceNow:300]; //policy.sharedAccessExpiryTime;
    [self testBlobSasSharedAccessBlobHeadersWithParameters:sp2 context:context completionHandler:^(){
        [innerSemaphore signal];
    }];
    [innerSemaphore wait];
    //[lock wait];
}

- (void) testBlobSasSharedAccessBlobHeadersWithParameters:(AZSSharedAccessBlobParameters *)sp context:(AZSOperationContext *)context completionHandler:(void(^)())completionHandler
{
    AZSSharedAccessHeaders *headers = [[AZSSharedAccessHeaders alloc] init];
    headers.cacheControl = @"no-cache";
    headers.contentDisposition = @"attachment; filename=\"fname.ext\"";
    headers.contentEncoding = @"gzip";
    headers.contentLanguage = @"da";
    headers.contentType = @"text/html; charset=utf-8";
    sp.headers = headers;
    
    NSError *error = nil;
    NSString *blobURL = [NSString stringWithFormat:@"%@?%@",
                         [[self.blockBlob.storageUri urlWithLocation:AZSStorageLocationPrimary] absoluteString],
                         [self.blockBlob createSharedAccessSignatureWithParameters:sp error:&error]];
    [self checkPassageOfError:error expectToPass:YES errorCode:-1 message:@"Create SAS token"];
    
    AZSCloudBlockBlob *sasBlob = [[AZSCloudBlockBlob alloc] initWithUrl:[[NSURL alloc] initWithString:blobURL]];
    
    context.responseReceived = ^void(NSMutableURLRequest *req, NSHTTPURLResponse *resp, AZSOperationContext *ctxt) {
        XCTAssertTrue([@"no-cache" isEqualToString:[resp.allHeaderFields objectForKey:@"Cache-Control"]]);
        XCTAssertTrue([@"attachment; filename=\"fname.ext\"" isEqualToString:[resp.allHeaderFields objectForKey:@"Content-Disposition"]]);
        XCTAssertTrue([@"gzip" isEqualToString:[resp.allHeaderFields objectForKey:@"Content-Encoding"]]);
        XCTAssertTrue([@"da" isEqualToString:[resp.allHeaderFields objectForKey:@"Content-Language"]]);
        XCTAssertTrue([@"text/html; charset=utf-8" isEqualToString:[resp.allHeaderFields objectForKey:@"Content-Type"]]);
    };
    [sasBlob downloadToStream:[[NSOutputStream alloc] initToMemory] accessCondition:nil requestOptions:nil operationContext:context completionHandler:^(NSError * err) {
        [self checkPassageOfError:err expectToPass:YES errorCode:-1 message:@"Download to stream"];
        
        completionHandler();
    }];
}

- (void)testAccessWithSAS:(NSString *)sasToken permissions:(AZSSharedAccessPermissions)permissions container:(AZSCloudBlobContainer *)container blob:(AZSCloudBlob *) blob completionHandler:(void(^)())completionHandler
{
    const AZSStorageCredentials *creds = (sasToken) ? [[AZSStorageCredentials alloc] initWithSASToken:sasToken] : [[AZSStorageCredentials alloc] init];
    const int permissionsErrorCode = (sasToken) ? 403 : 404;
    
    if (container) {
        container = [[AZSCloudBlobContainer alloc] initWithStorageUri:[creds transformWithStorageUri:container.storageUri]];
        blob = [container blockBlobReferenceFromName:blob.blobName];
    }
    else {
        blob = [[AZSCloudBlockBlob alloc] initWithStorageUri:[self addToQuery:blob.storageUri queryString:sasToken]];
    }
    
    __block AZSContinuationToken *token = [[AZSContinuationToken alloc] init];
    
    // Test presence or absence blob WRITE permissions
    [blob uploadMetadataWithCompletionHandler:^(NSError *err) {
        [self checkPassageOfError:err expectToPass:(permissions & AZSSharedAccessPermissionsWrite) errorCode:permissionsErrorCode message:@"Upload metadata"];
        
        // Test presence or absence Blob READ permissions
        [blob fetchAttributesWithCompletionHandler:^(NSError * err) {
            [self checkPassageOfError:err expectToPass:(permissions & AZSSharedAccessPermissionsRead) errorCode:permissionsErrorCode message:@"Fetch attributes"];
            
            // Test presence or absence Blob DELETE permissions
            [blob deleteWithCompletionHandler:^(NSError *err) {
                [self checkPassageOfError:err expectToPass:(permissions & AZSSharedAccessPermissionsDelete) errorCode:permissionsErrorCode message:@"Delete"];
                
                if (container) {
                    // TODO: Add test for presence or absence of Append Blob ADD permissions
                    
                    // Test presence or absence Container WRITE (and eventually CREATE) permissiomns
                    AZSCloudBlockBlob *sasBlob = [container blockBlobReferenceFromName:@"testAccessBlob"];
                    [sasBlob uploadFromText:@"test" completionHandler:^(NSError *err) {
                        // TODO: Uncomment create once it is supported by block blob
                        [self checkPassageOfError:err expectToPass:(permissions & (AZSSharedAccessPermissionsWrite /*| AZSSharedAccessPermissionsCreate*/)) errorCode:permissionsErrorCode message:@"Upload from text"];
                        
                        AZSTestSemaphore *innerSemaphore = [[AZSTestSemaphore alloc] init];
                        if (permissions & AZSSharedAccessPermissionsList) {
                            // Test presence of Container LIST permissions
                            __weak __block void (^listBlobs)(AZSContinuationToken *);
                            void (^continueBlock)(AZSContinuationToken *) = ^(AZSContinuationToken *tok) {
                                if (!tok) {
                                    [innerSemaphore signal];
                                }
                                else {
                                    [container listBlobsSegmentedWithContinuationToken:tok prefix:@"" useFlatBlobListing:YES blobListingDetails:AZSBlobListingDetailsNone maxResults:-1 completionHandler:^(NSError * err, AZSBlobResultSegment *result) {
                                        [self checkPassageOfError:err expectToPass:YES errorCode:permissionsErrorCode message:@"List blobs"];
                                        
                                        // This recursive call is to a weak block variable to avoid a retention cycle
                                        listBlobs(result.continuationToken);
                                    }];
                                }
                            };
                            listBlobs = continueBlock;

                            listBlobs(token);
                            [innerSemaphore wait];
                        }
                        else {
                            // Test absence of Container LIST permissions
                            [container listBlobsSegmentedWithContinuationToken:token prefix:@"" useFlatBlobListing:YES blobListingDetails:AZSBlobListingDetailsNone maxResults:-1 completionHandler:^(NSError * err, AZSBlobResultSegment *result) {
                                [self checkPassageOfError:err expectToPass:NO errorCode:permissionsErrorCode message:@"List blobs"];
                                [innerSemaphore signal];
                            }];
                            [innerSemaphore wait];
                        }
                        completionHandler();
                    }];
                }
                else {
                    completionHandler();
                }
            }];
        }];
    }];
}

@end