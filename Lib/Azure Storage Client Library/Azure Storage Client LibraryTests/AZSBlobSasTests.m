// -----------------------------------------------------------------------------------------
// <copyright file="AZSBlobSasTests.m" company="Microsoft">
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
#import "AZSBlobTestBase.h"
#import "AZSBlockListItem.h"
#import "AZSConstants.h"
#import "AZSCloudBlob.h"
#import "AZSCloudBlobContainer.h"
#import "AZSCloudBlobClient.h"
#import "AZSCloudBlockBlob.h"
#import "AZSCloudStorageAccount.h"
#import "AZSContinuationToken.h"
#import "AZSIPRange.h"
#import "AZSOperationContext.h"
#import "AZSRequestResult.h"
#import "AZSResultSegment.h"
#import "AZSSharedAccessAccountParameters.h"
#import "AZSSharedAccessBlobParameters.h"
#import "AZSSharedAccessHeaders.h"
#import "AZSStorageCredentials.h"
#import "AZSStorageUri.h"
#import "AZSTestHelpers.h"
#import "AZSTestSemaphore.h"
#import "AZSUriQueryBuilder.h"
#import "arpa/inet.h"

@interface AZSBlobSasTests : AZSBlobTestBase
@property AZSCloudBlobContainer *blobContainer;
@property AZSCloudBlockBlob *blockBlob;

@end

@implementation AZSBlobSasTests : AZSBlobTestBase

- (void)setUp
{
    [super setUp];
    
    // Put setup code here; it will be run once, before the first test case.
    AZSTestSemaphore *semaphore = [[AZSTestSemaphore alloc] init];
    NSString *containerName = [NSString stringWithFormat:@"sampleioscontainer%@", [AZSTestHelpers uniqueName]];
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
    AZSTestSemaphore *semaphore = [[AZSTestSemaphore alloc] init];
    [self.blobContainer deleteContainerIfExistsWithCompletionHandler:^(NSError* err, BOOL created) {
        [semaphore signal];
    }];
    [semaphore wait];
    
    [super tearDown];
}

- (void)checkPassageOfError:(NSError *)err expectToPass:(BOOL)expected expectedHttpErrorCode:(int)code message:(NSString *)message
{
    if (expected) {
        XCTAssertNil(err, @"%@ failed.", message);
    }
    else {
        XCTAssertNotNil(err, @"%@ unexpectedly passed.", message);
        XCTAssertEqual(code, [err.userInfo[AZSCHttpStatusCode] intValue]);
    }
}

- (void)checkEqualityOfContainerPermissions:(NSMutableDictionary *)permissions otherPermissions:(NSMutableDictionary *)otherPermissions
{
    XCTAssertEqual(permissions.count, otherPermissions.count);
    
    for (NSString *policyIdentifier in permissions) {
        AZSSharedAccessPolicy *policy = permissions[policyIdentifier];
        XCTAssertNotNil(policy);
        
        AZSSharedAccessPolicy *otherPolicy = otherPermissions[policyIdentifier];
        XCTAssertNotNil(otherPolicy);
        
        XCTAssertEqual(policy.permissions, otherPolicy.permissions);
        XCTAssertEqualWithAccuracy(policy.sharedAccessStartTime.timeIntervalSince1970, otherPolicy.sharedAccessStartTime.timeIntervalSince1970, 1);
        XCTAssertEqualWithAccuracy(policy.sharedAccessExpiryTime.timeIntervalSince1970, otherPolicy.sharedAccessExpiryTime.timeIntervalSince1970, 1);
        
        XCTAssertEqualObjects(policyIdentifier, policy.policyIdentifier);
        XCTAssertEqualObjects(policy.policyIdentifier, otherPolicy.policyIdentifier);
    }
}

-(AZSStorageUri *)addToQuery:(AZSStorageUri *)initialUri queryString:(NSString *)queryString
{
    XCTAssertFalse([[initialUri.primaryUri absoluteString] containsString:@"?"]);
    XCTAssertFalse([[initialUri.secondaryUri absoluteString] containsString:@"?"]);
    
    NSURL *primary = [[NSURL alloc] initWithString:[NSString stringWithFormat:@"%@?%@", initialUri.primaryUri.absoluteString, queryString]];
    AZSStorageUri *uri = [[AZSStorageUri alloc] initWithPrimaryUri:primary];
    if (initialUri.secondaryUri) {
        uri.secondaryUri = [[NSURL alloc] initWithString:[NSString stringWithFormat:@"%@?%@", initialUri.secondaryUri.absoluteString, queryString]];
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
    [AZSTestHelpers checkPassageOfError:error expectToPass:YES expectedHttpErrorCode:-1 message:@"Create SAS token"];
    
    __block NSRange match = [sas rangeOfString:AZSCQueryApiVersion];
    XCTAssertTrue(match.location == NSNotFound);
    
    AZSOperationContext *context = [[AZSOperationContext alloc] init];
    context.responseReceived = ^void(NSMutableURLRequest *req, NSHTTPURLResponse *resp, AZSOperationContext *ctxt) {
        match = [[resp.URL absoluteString] rangeOfString:AZSCQueryApiVersion];
        XCTAssertFalse(match.location == NSNotFound);
    };
    
    AZSCloudBlockBlob *sasBlob = [[AZSCloudBlockBlob alloc] initWithStorageUri:[self addToQuery:self.blockBlob.storageUri queryString:sas] error:&error];
    XCTAssertNil(error);
    
    [sasBlob uploadFromText:@"test" accessCondition:nil requestOptions:nil operationContext:context completionHandler:^(NSError *err) {
        [AZSTestHelpers checkPassageOfError:err expectToPass:YES expectedHttpErrorCode:-1 message:@"Upload from text"];
        [semaphore signal];
    }];
    [semaphore wait];
}

- (void)testIpAddressOrRange
{
    AZSTestSemaphore *semaphore = [[AZSTestSemaphore alloc] init];
    NSError *error = nil;
    
    AZSSharedAccessBlobParameters *sp = [[AZSSharedAccessBlobParameters alloc] init];
    sp.permissions = AZSSharedAccessPermissionsRead;
    sp.sharedAccessExpiryTime = [[NSDate alloc] initWithTimeIntervalSinceNow:300];
    
    struct in_addr ip;
    XCTAssertTrue(inet_aton([@"0.0.0.0" UTF8String], &ip));
    sp.ipAddressOrRange = [[AZSIPRange alloc] initWithSingleIP:ip];
    
    // Ensure access attempt from invalid IP fails.
    NSString *containerSasNone = [self.blobContainer createSharedAccessSignatureWithParameters:sp error:&error];
    [AZSTestHelpers checkPassageOfError:error expectToPass:YES expectedHttpErrorCode:-1 message:@"Create SAS token"];
    AZSCloudBlobContainer *noneContainer = [[AZSCloudBlobContainer alloc] initWithStorageUri:
            [[AZSStorageUri alloc] initWithPrimaryUri:[[[AZSUriQueryBuilder alloc] initWithQuery:containerSasNone] addToUri:self.blobContainer.storageUri.primaryUri]] error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(noneContainer.client.credentials.isSAS);
    
    AZSCloudBlockBlob *noneBlob = [noneContainer blockBlobReferenceFromName:self.blockBlob.blobName];
    [noneBlob downloadToStream:[[NSOutputStream alloc] initToMemory] completionHandler:^(NSError * err) {
        [AZSTestHelpers checkPassageOfError:err expectToPass:NO expectedHttpErrorCode:403 message:@"Download blob"];
        
        // Ensure access attempt from the single allowed IP succeeds.
        struct in_addr ip2;
        XCTAssertTrue(inet_aton([err.userInfo[@"AdditionalErrorDetails"][@"SourceIP"] UTF8String], &ip2));
        sp.ipAddressOrRange = [[AZSIPRange alloc] initWithSingleIP:ip2];
        
        NSError *error = nil;
        NSString *containerSasOne = [self.blobContainer createSharedAccessSignatureWithParameters:sp error:&error];
        [AZSTestHelpers checkPassageOfError:error expectToPass:YES expectedHttpErrorCode:-1 message:@"Create SAS token"];
        AZSCloudBlobContainer *oneContainer = [[AZSCloudBlobContainer alloc] initWithStorageUri:
                [[AZSStorageUri alloc] initWithPrimaryUri:[[[AZSUriQueryBuilder alloc] initWithQuery:containerSasOne] addToUri:self.blobContainer.storageUri.primaryUri]] error:&error];
        XCTAssertNil(error);
        XCTAssertTrue(oneContainer.client.credentials.isSAS);
        
        AZSCloudBlockBlob *oneBlob = [oneContainer blockBlobReferenceFromName:self.blockBlob.blobName];
        [oneBlob downloadToStream:[[NSOutputStream alloc] initToMemory] completionHandler:^(NSError * err) {
            [AZSTestHelpers checkPassageOfError:err expectToPass:YES expectedHttpErrorCode:-1 message:@"Download blob"];
            
            // Ensure access attempt from one of many allowed IPs succeeds.
            struct in_addr ip2;
            XCTAssertTrue(inet_aton([@"255.255.255.255" UTF8String], &ip2));
            sp.ipAddressOrRange = [[AZSIPRange alloc] initWithMinIP:ip maxIP:ip2];
            
            NSError *error = nil;
            NSString *containerSasAll = [self.blobContainer createSharedAccessSignatureWithParameters:sp error:&error];
            [AZSTestHelpers checkPassageOfError:error expectToPass:YES expectedHttpErrorCode:-1 message:@"Create SAS token"];
            AZSCloudBlobContainer *allContainer = [[AZSCloudBlobContainer alloc] initWithStorageUri:
                    [[AZSStorageUri alloc] initWithPrimaryUri:[[[AZSUriQueryBuilder alloc] initWithQuery:containerSasAll] addToUri:self.blobContainer.storageUri.primaryUri]] error:&error];
            XCTAssertNil(error);
            XCTAssertTrue(allContainer.client.credentials.isSAS);
            
            AZSCloudBlockBlob *allBlob = [allContainer blockBlobReferenceFromName:self.blockBlob.blobName];
            [allBlob downloadToStream:[[NSOutputStream alloc] initToMemory] completionHandler:^(NSError * err) {
                [AZSTestHelpers checkPassageOfError:err expectToPass:YES expectedHttpErrorCode:-1 message:@"Download blob"];
                
                [semaphore signal];
            }];
        }];
    }];
    [semaphore wait];
}

- (void)testIpAddressOrRangeString
{
    AZSTestSemaphore *semaphore = [[AZSTestSemaphore alloc] init];
    NSError *error = nil;
    
    AZSSharedAccessBlobParameters *sp = [[AZSSharedAccessBlobParameters alloc] init];
    sp.permissions = AZSSharedAccessPermissionsRead;
    sp.sharedAccessExpiryTime = [[NSDate alloc] initWithTimeIntervalSinceNow:300];
    sp.ipAddressOrRange = [[AZSIPRange alloc] initWithSingleIPString:@"0.0.0.0" error:&error];
    [AZSTestHelpers checkPassageOfError:error expectToPass:YES expectedHttpErrorCode:-1 message:@"Create IPRange"];
    
    // Ensure access attempt from invalid IP fails.
    NSString *containerSasNone = [self.blobContainer createSharedAccessSignatureWithParameters:sp error:&error];
    [AZSTestHelpers checkPassageOfError:error expectToPass:YES expectedHttpErrorCode:-1 message:@"Create SAS token"];
    AZSCloudBlobContainer *noneContainer = [[AZSCloudBlobContainer alloc] initWithStorageUri:
            [[AZSStorageUri alloc] initWithPrimaryUri:[[[AZSUriQueryBuilder alloc] initWithQuery:containerSasNone] addToUri:self.blobContainer.storageUri.primaryUri]] error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(noneContainer.client.credentials.isSAS);
    
    AZSCloudBlockBlob *noneBlob = [noneContainer blockBlobReferenceFromName:self.blockBlob.blobName];
    [noneBlob downloadToStream:[[NSOutputStream alloc] initToMemory] completionHandler:^(NSError * err) {
        [AZSTestHelpers checkPassageOfError:err expectToPass:NO expectedHttpErrorCode:403 message:@"Download blob"];
        XCTAssertNotNil(err.userInfo[@"AdditionalErrorDetails"][@"SourceIP"]);
        
        // Ensure access attempt from the single allowed IP succeeds.
        NSError *error = nil;
        sp.ipAddressOrRange = [[AZSIPRange alloc] initWithSingleIPString:err.userInfo[@"AdditionalErrorDetails"][@"SourceIP"] error:&error];
        [AZSTestHelpers checkPassageOfError:error expectToPass:YES expectedHttpErrorCode:-1 message:@"Create IPRange"];
        
        NSString *containerSasOne = [self.blobContainer createSharedAccessSignatureWithParameters:sp error:&error];
        [AZSTestHelpers checkPassageOfError:error expectToPass:YES expectedHttpErrorCode:-1 message:@"Create SAS token"];
        AZSCloudBlobContainer *oneContainer = [[AZSCloudBlobContainer alloc] initWithStorageUri:
                [[AZSStorageUri alloc] initWithPrimaryUri:[[[AZSUriQueryBuilder alloc] initWithQuery:containerSasOne] addToUri:self.blobContainer.storageUri.primaryUri]] error:&error];
        XCTAssertNil(error);
        XCTAssertTrue(oneContainer.client.credentials.isSAS);
        
        AZSCloudBlockBlob *oneBlob = [oneContainer blockBlobReferenceFromName:self.blockBlob.blobName];
        [oneBlob downloadToStream:[[NSOutputStream alloc] initToMemory] completionHandler:^(NSError * err) {
            [AZSTestHelpers checkPassageOfError:err expectToPass:YES expectedHttpErrorCode:-1 message:@"Download blob"];
            
            // Ensure access attempt from one of many allowed IPs succeeds.
            NSError *error = nil;
            sp.ipAddressOrRange = [[AZSIPRange alloc] initWithMinIPString:@"0.0.0.0" maxIPString:@"255.255.255.255" error:&error];
            [AZSTestHelpers checkPassageOfError:error expectToPass:YES expectedHttpErrorCode:-1 message:@"Create IPRange"];
            
            NSString *containerSasAll = [self.blobContainer createSharedAccessSignatureWithParameters:sp error:&error];
            [AZSTestHelpers checkPassageOfError:error expectToPass:YES expectedHttpErrorCode:-1 message:@"Create SAS token"];
            AZSCloudBlobContainer *allContainer = [[AZSCloudBlobContainer alloc] initWithStorageUri:
                    [[AZSStorageUri alloc] initWithPrimaryUri:[[[AZSUriQueryBuilder alloc] initWithQuery:containerSasAll] addToUri:self.blobContainer.storageUri.primaryUri]] error:&error];
            XCTAssertNil(error);
            XCTAssertTrue(allContainer.client.credentials.isSAS);
            
            AZSCloudBlockBlob *allBlob = [allContainer blockBlobReferenceFromName:self.blockBlob.blobName];
            [allBlob downloadToStream:[[NSOutputStream alloc] initToMemory] completionHandler:^(NSError * err) {
                [AZSTestHelpers checkPassageOfError:err expectToPass:YES expectedHttpErrorCode:-1 message:@"Download blob"];
                
                [semaphore signal];
            }];
        }];
    }];
    [semaphore wait];
}

- (void)testProtocolRestrictions
{
    AZSTestSemaphore *semaphore = [[AZSTestSemaphore alloc] init];
    NSError *error = nil;
    
    AZSSharedAccessBlobParameters *sp = [[AZSSharedAccessBlobParameters alloc] init];
    sp.permissions = AZSSharedAccessPermissionsRead;
    sp.sharedAccessExpiryTime = [[NSDate alloc] initWithTimeIntervalSinceNow:300];
    sp.protocols = AZSSharedAccessProtocolHttpsOnly;
    
    // Ensure using http with https only SAS fails.
    NSString *containerSasHttps = [self.blobContainer createSharedAccessSignatureWithParameters:sp error:&error];
    [AZSTestHelpers checkPassageOfError:error expectToPass:YES expectedHttpErrorCode:-1 message:@"Create SAS token"];
    AZSUriQueryBuilder *httpsBuilder = [[AZSUriQueryBuilder alloc] initWithQuery:containerSasHttps];
    
    NSURLComponents *uri = [NSURLComponents componentsWithURL:self.blobContainer.storageUri.primaryUri resolvingAgainstBaseURL:NO];
    uri.scheme = AZSCHttp;
    
    AZSCloudBlobContainer *httpContainer = [[AZSCloudBlobContainer alloc] initWithStorageUri:
            [[AZSStorageUri alloc] initWithPrimaryUri:[httpsBuilder addToUri:uri.URL]] error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(httpContainer.client.credentials.isSAS);
    
    AZSCloudBlockBlob *httpBlob = [httpContainer blockBlobReferenceFromName:self.blockBlob.blobName];
    [httpBlob downloadToStream:[[NSOutputStream alloc] initToMemory] completionHandler:^(NSError *err) {
        [AZSTestHelpers checkPassageOfError:err expectToPass:NO expectedHttpErrorCode:403 message:@"Download https only blob using http"];
        XCTAssertTrue([(err.userInfo[@"Message"]) hasPrefix:@"This request is not authorized to perform this operation using this protocol."]);
        
        // Ensure using https with https only SAS succeeds.
        NSError *error = nil;
        uri.scheme = AZSCHttps;
        AZSCloudBlobContainer *httpsContainer = [[AZSCloudBlobContainer alloc] initWithStorageUri:
                [[AZSStorageUri alloc] initWithPrimaryUri:[httpsBuilder addToUri:uri.URL]] error:&error];
        XCTAssertNil(error);
        XCTAssertTrue(httpsContainer.client.credentials.isSAS);
        
        AZSCloudBlockBlob *httpsBlob = [httpsContainer blockBlobReferenceFromName:self.blockBlob.blobName];
        [httpsBlob downloadToStream:[[NSOutputStream alloc] initToMemory] completionHandler:^(NSError *err) {
            [AZSTestHelpers checkPassageOfError:err expectToPass:YES expectedHttpErrorCode:-1 message:@"Download https only blob using https"];
            
            // Ensure using https with https,http SAS succeeds.
            sp.protocols = AZSSharedAccessProtocolHttpsHttp;
            NSError *error = nil;
            NSString *containerSasHttp = [self.blobContainer createSharedAccessSignatureWithParameters:sp error:&error];
            [AZSTestHelpers checkPassageOfError:error expectToPass:YES expectedHttpErrorCode:-1 message:@"Create SAS token"];
            AZSUriQueryBuilder *httpBuilder = [[AZSUriQueryBuilder alloc] initWithQuery:containerSasHttp];
            
            AZSCloudBlobContainer *httpsContainer = [[AZSCloudBlobContainer alloc] initWithStorageUri:
                    [[AZSStorageUri alloc] initWithPrimaryUri:[httpBuilder addToUri:uri.URL]] error:&error];
            XCTAssertNil(error);
            XCTAssertTrue(httpsContainer.client.credentials.isSAS);
            
            AZSCloudBlockBlob *httpsBlob = [httpsContainer blockBlobReferenceFromName:self.blockBlob.blobName];
            [httpsBlob downloadToStream:[[NSOutputStream alloc] initToMemory] completionHandler:^(NSError *err) {
                [AZSTestHelpers checkPassageOfError:err expectToPass:YES expectedHttpErrorCode:-1 message:@"Download blob using https"];
                
                // Ensure using http with https,http SAS succeeds.
                NSError *error = nil;
                uri.scheme = AZSCHttp;
                AZSCloudBlobContainer *httpContainer = [[AZSCloudBlobContainer alloc] initWithStorageUri:
                        [[AZSStorageUri alloc] initWithPrimaryUri:[httpBuilder addToUri:uri.URL]] error:&error];
                XCTAssertNil(error);
                XCTAssertTrue(httpContainer.client.credentials.isSAS);
                
                AZSCloudBlockBlob *httpBlob = [httpContainer blockBlobReferenceFromName:self.blockBlob.blobName];
                [httpBlob downloadToStream:[[NSOutputStream alloc] initToMemory] completionHandler:^(NSError *err) {
                    [AZSTestHelpers checkPassageOfError:err expectToPass:YES expectedHttpErrorCode:-1 message:@"Download blob using http"];
                    
                    [semaphore signal];
                }];
            }];
        }];
    }];
    [semaphore wait];
}

- (void)testContainerSas
{
    // Test from stored policy
    AZSSharedAccessBlobParameters *sp = [[AZSSharedAccessBlobParameters alloc] init];
    sp.storedPolicyIdentifier = @"readlist";
    AZSTestSemaphore *semaphore = [[AZSTestSemaphore alloc] init];
    AZSSharedAccessPolicy *policy = [[AZSSharedAccessPolicy alloc] initWithIdentifier:sp.storedPolicyIdentifier];
    policy.permissions = AZSSharedAccessPermissionsRead|AZSSharedAccessPermissionsList;
    policy.sharedAccessStartTime = [[NSDate alloc] initWithTimeIntervalSinceNow:0];
    policy.sharedAccessExpiryTime = [[NSDate alloc] initWithTimeIntervalSinceNow:300];
    
    NSMutableDictionary *permissions = [NSMutableDictionary dictionaryWithDictionary:@{sp.storedPolicyIdentifier : policy}];
    [self.blobContainer uploadPermissions:permissions completionHandler:^(NSError *err) {
        [AZSTestHelpers checkPassageOfError:err expectToPass:YES expectedHttpErrorCode:-1 message:@"Upload permissions"];
        [NSThread sleepForTimeInterval:30];
        
        [self testContainerSASWithParameters:sp completionHandler:^{
            [self.blobContainer downloadPermissionsWithCompletionHandler:^(NSError *error, NSMutableDictionary *storedPermissions, AZSContainerPublicAccessType publicAccess) {
                [AZSTestHelpers checkPassageOfError:err expectToPass:YES expectedHttpErrorCode:-1 message:@"Download permissions"];
                [self checkEqualityOfContainerPermissions:permissions otherPermissions:storedPermissions];
                XCTAssertEqual(publicAccess, AZSContainerPublicAccessTypeOff);
                
                [semaphore signal];
            }];
        }];
    }];
    
    // Test from local parameters
    AZSTestSemaphore *innerSemaphore = [[AZSTestSemaphore alloc] init];
    AZSSharedAccessBlobParameters *sp2 = [[AZSSharedAccessBlobParameters alloc] init];
    sp2.permissions = policy.permissions;
    sp2.sharedAccessExpiryTime = policy.sharedAccessExpiryTime;
    [self testContainerSASWithParameters:sp2 completionHandler:^() {
        [innerSemaphore signal];
    }];
    [innerSemaphore wait];
    [semaphore wait];
}

- (void)testContainerSASWithParameters:(AZSSharedAccessBlobParameters *)sp completionHandler:(void(^)())completionHandler
{
    __block NSError *error = nil;
    NSString *containerReadListSAS = [self.blobContainer createSharedAccessSignatureWithParameters:sp error:&error];
    [AZSTestHelpers checkPassageOfError:error expectToPass:YES expectedHttpErrorCode:-1 message:@"Create SAS token"];
    
    AZSCloudBlobContainer *readListContainer = [[AZSCloudBlobContainer alloc] initWithStorageUri:[self addToQuery:self.blobContainer.storageUri queryString:containerReadListSAS] error:&error];
    XCTAssertNil(error);
    XCTAssertTrue([readListContainer.client.credentials isSAS]);
    
    AZSCloudBlockBlob *blobFromSasContainer = [readListContainer blockBlobReferenceFromName:self.blockBlob.blobName];
    [blobFromSasContainer downloadToStream:[[NSOutputStream alloc] initToMemory] accessCondition:nil requestOptions:nil operationContext:nil completionHandler:^(NSError * err) {
        [AZSTestHelpers checkPassageOfError:err expectToPass:YES expectedHttpErrorCode:-1 message:@"Download blobFromSasContainer to stream"];
        
        // Withhold client and check new container's client has correct permissions
        NSError *initError;
        AZSCloudBlobContainer *containerFromURI = [[AZSCloudBlobContainer alloc] initWithStorageUri:[self addToQuery:readListContainer.storageUri queryString:[self.blobContainer createSharedAccessSignatureWithParameters:sp error:&error]] error:&initError];
        XCTAssertNil(initError);
        [AZSTestHelpers checkPassageOfError:error expectToPass:YES expectedHttpErrorCode:-1 message:@"Create SAS token"];
        XCTAssertTrue([containerFromURI.client.credentials isSAS]);
        
        AZSCloudBlockBlob *blobFromUriContainer = [containerFromURI blockBlobReferenceFromName:self.blockBlob.blobName];
        [blobFromUriContainer downloadToStream:[[NSOutputStream alloc] initToMemory] accessCondition:nil requestOptions:nil operationContext:nil completionHandler:^(NSError * err) {
            [AZSTestHelpers checkPassageOfError:err expectToPass:YES expectedHttpErrorCode:-1 message:@"Download blobFromUriContainer to stream"];
            
            // Generate credentials from SAS
            AZSStorageCredentials *creds = [[AZSStorageCredentials alloc] initWithSASToken:[self.blobContainer createSharedAccessSignatureWithParameters:sp error:&error]];
            [AZSTestHelpers checkPassageOfError:error expectToPass:YES expectedHttpErrorCode:-1 message:@"Create SAS token"];
            
            AZSCloudBlobClient *bClient = [[AZSCloudBlobClient alloc] initWithStorageUri:self.blobContainer.client.storageUri credentials:creds];
            AZSCloudBlobContainer *containterFromClient = [bClient containerReferenceFromName:self.blobContainer.name];
            XCTAssertTrue([containterFromClient.client.credentials isSAS]);
            XCTAssertEqualObjects(bClient, containterFromClient.client);
            
            AZSCloudBlockBlob *blobFromClientContainer = [containerFromURI blockBlobReferenceFromName:self.blockBlob.blobName];
            [blobFromClientContainer downloadToStream:[[NSOutputStream alloc] initToMemory] accessCondition:nil requestOptions:nil operationContext:nil completionHandler:^(NSError * err) {
                [AZSTestHelpers checkPassageOfError:err expectToPass:YES expectedHttpErrorCode:-1 message:@"Download blobFromClientContainer to stream"];
                
                completionHandler();
            }];
        }];
    }];
}

- (void)testContainerSasBlobHeaders
{
    
    AZSOperationContext *context = [[AZSOperationContext alloc] init];
    
    // Test with stored policy
    AZSTestSemaphore *semaphore = [[AZSTestSemaphore alloc] init];
    AZSSharedAccessBlobParameters *sp = [[AZSSharedAccessBlobParameters alloc] init];
    sp.storedPolicyIdentifier = @"readperm";
    
    AZSSharedAccessPolicy *policy = [[AZSSharedAccessPolicy alloc] initWithIdentifier:sp.storedPolicyIdentifier];
    policy.permissions = AZSSharedAccessPermissionsRead|AZSSharedAccessPermissionsWrite|AZSSharedAccessPermissionsList;
    policy.sharedAccessExpiryTime = [[NSDate alloc] initWithTimeIntervalSinceNow:300];
    
    NSMutableDictionary *permissions = [NSMutableDictionary dictionaryWithDictionary:@{@"readperm" : policy}];
    [self.blobContainer uploadPermissions:permissions completionHandler:^(NSError * err) {
        [AZSTestHelpers checkPassageOfError:err expectToPass:YES expectedHttpErrorCode:-1 message:@"Upload permissions"];
        
        [NSThread sleepForTimeInterval:30];
        
        [self testContainerSasBlobHeadersWithParameters:sp context:context completionHandler:^() {
            [self.blobContainer downloadPermissionsWithCompletionHandler:^(NSError *error, NSMutableDictionary *storedPermissions, AZSContainerPublicAccessType publicAccess) {
                [AZSTestHelpers checkPassageOfError:err expectToPass:YES expectedHttpErrorCode:-1 message:@"Download permissions"];
                [self checkEqualityOfContainerPermissions:permissions otherPermissions:storedPermissions];
                XCTAssertEqual(publicAccess, AZSContainerPublicAccessTypeOff);
                
                [semaphore signal];
            }];
        }];
    }];
    
    // Test with local parameters
    AZSTestSemaphore *innerSemaphore = [[AZSTestSemaphore alloc] init];
    AZSSharedAccessBlobParameters *sp2 = [[AZSSharedAccessBlobParameters alloc] init];
    sp2.permissions = policy.permissions;
    sp2.sharedAccessExpiryTime = policy.sharedAccessExpiryTime;
    
    [self testContainerSasBlobHeadersWithParameters:sp2 context:context completionHandler:^() {
        [innerSemaphore signal];
    }];
    [innerSemaphore wait];
    [semaphore wait];
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
        XCTAssertTrue([@"no-cache" isEqualToString:resp.allHeaderFields[AZSCXmlContentCacheControl]]);
        XCTAssertTrue([@"attachment; filename=\"fname.ext\"" isEqualToString:resp.allHeaderFields[AZSCXmlContentDisposition]]);
        XCTAssertTrue([@"gzip" isEqualToString:resp.allHeaderFields[AZSCXmlContentEncoding]]);
        XCTAssertTrue([@"da" isEqualToString:resp.allHeaderFields[AZSCXmlContentLanguage]]);
        XCTAssertTrue([@"text/html; charset=utf-8" isEqualToString:resp.allHeaderFields[AZSCXmlContentType]]);
    };
    
    NSError *error = nil;
    AZSStorageCredentials *creds = [[AZSStorageCredentials alloc] initWithSASToken:[self.blobContainer createSharedAccessSignatureWithParameters:sp error:&error]];
    [AZSTestHelpers checkPassageOfError:error expectToPass:YES expectedHttpErrorCode:-1 message:@"Create SAS token"];
    
    AZSCloudBlobContainer *container = [[AZSCloudBlobContainer alloc] initWithStorageUri:self.blobContainer.storageUri credentials:creds error:&error];
    XCTAssertNil(error);
    AZSCloudBlockBlob *sasBlob = [container blockBlobReferenceFromName:self.blockBlob.blobName];
    
    [sasBlob downloadToStream:[[NSOutputStream alloc] initToMemory] accessCondition:nil requestOptions:nil operationContext:context completionHandler:^(NSError * err) {
        [AZSTestHelpers checkPassageOfError:err expectToPass:YES expectedHttpErrorCode:-1 message:@"Download to stream"];
        
        completionHandler();
    }];
}

- (void)testContainerUpdateSas
{
    // Create a policy with read/write access and generate SAS
    AZSTestSemaphore *semaphore= [[AZSTestSemaphore alloc] init];
    
    // Test with stored policy
    AZSSharedAccessBlobParameters *sp = [[AZSSharedAccessBlobParameters alloc] init];
    sp.storedPolicyIdentifier = @"readwrite";
    AZSSharedAccessBlobParameters *sp2 = [[AZSSharedAccessBlobParameters alloc] init];
    sp2.storedPolicyIdentifier = @"read";
    
    AZSSharedAccessPolicy *policy = [[AZSSharedAccessPolicy alloc] initWithIdentifier:sp.storedPolicyIdentifier];
    policy.permissions = AZSSharedAccessPermissionsRead|AZSSharedAccessPermissionsWrite;
    policy.sharedAccessExpiryTime = [[NSDate alloc] initWithTimeIntervalSinceNow:300];
    AZSSharedAccessPolicy *policy2 = [[AZSSharedAccessPolicy alloc] initWithIdentifier:sp2.storedPolicyIdentifier];
    policy2.permissions = AZSSharedAccessPermissionsRead;
    policy2.sharedAccessExpiryTime = policy.sharedAccessExpiryTime;
    
    NSMutableDictionary *permissions = [NSMutableDictionary dictionaryWithDictionary:
            @{sp.storedPolicyIdentifier : policy, sp2.storedPolicyIdentifier : policy2}];
    
    [self.blobContainer uploadPermissions:permissions completionHandler:^(NSError *err) {
        [AZSTestHelpers checkPassageOfError:err expectToPass:YES expectedHttpErrorCode:-1 message:@"Upload permissions"];
        
        [NSThread sleepForTimeInterval:30];
        
        [self testContainerUpdateSasWithReadWriteParameters:sp readOnlyParameters:sp2 policies:permissions completionHandler:^() {
            [self.blobContainer downloadPermissionsWithCompletionHandler:^(NSError *error, NSMutableDictionary *storedPermissions, AZSContainerPublicAccessType publicAccess) {
                [AZSTestHelpers checkPassageOfError:err expectToPass:YES expectedHttpErrorCode:-1 message:@"Download permissions"];
                [self checkEqualityOfContainerPermissions:permissions otherPermissions:storedPermissions];
                XCTAssertEqual(publicAccess, AZSContainerPublicAccessTypeOff);
                
                [semaphore signal];
            }];
        }];
    }];
    [semaphore wait];
    
    // Test with local parameters
    AZSSharedAccessBlobParameters *sp3 = [[AZSSharedAccessBlobParameters alloc] init];
    sp3.permissions = policy.permissions;
    sp3.sharedAccessExpiryTime = policy.sharedAccessExpiryTime;
    
    AZSSharedAccessBlobParameters *sp4 = [[AZSSharedAccessBlobParameters alloc] init];
    sp4.permissions = policy2.permissions;
    sp4.sharedAccessExpiryTime = policy2.sharedAccessExpiryTime;
    
    [self testContainerUpdateSasWithReadWriteParameters:sp3 readOnlyParameters:sp4 policies:nil completionHandler:^() {
        [semaphore signal];
    }];
    [semaphore wait];
}

- (void)testContainerUpdateSasWithReadWriteParameters:(AZSSharedAccessBlobParameters *)sp readOnlyParameters:(AZSSharedAccessBlobParameters *)sp2 policies:(NSMutableDictionary *)policies completionHandler:(void(^)())completionHandler
{
    __block NSError *error = nil;
    NSString *sasToken = [self.blobContainer createSharedAccessSignatureWithParameters:sp error:&error];
    [AZSTestHelpers checkPassageOfError:error expectToPass:YES expectedHttpErrorCode:-1 message:@"Create SAS token"];
    
    __block AZSCloudBlockBlob *testBlob = [self.blobContainer blockBlobReferenceFromName:[NSString stringWithFormat:@"sasBlob%@",sp.storedPolicyIdentifier]];
    [testBlob uploadFromText:@"test" completionHandler:^(NSError *err) {
        [AZSTestHelpers checkPassageOfError:err expectToPass:YES expectedHttpErrorCode:-1 message:@"Upload from text"];
        
        AZSSharedAccessPermissions permissions = (sp.permissions) ? sp.permissions : ((AZSSharedAccessPolicy *) policies[sp.storedPolicyIdentifier]).permissions;
        [self testAccessWithSAS:sasToken permissions:permissions container:self.blobContainer blob:testBlob completionHandler:^{
            // Change the policy to only read and update SAS.
            NSString *sasToken2 = [self.blobContainer createSharedAccessSignatureWithParameters:sp2 error:&error];
            [AZSTestHelpers checkPassageOfError:error expectToPass:YES expectedHttpErrorCode:-1 message:@"Create SAS token"];
            
            AZSCloudBlobContainer *sasContainer = [[AZSCloudBlobContainer alloc] initWithStorageUri:[self addToQuery:self.blobContainer.storageUri queryString:sasToken2] error:&error];
            XCTAssertNil(error);
            
            testBlob = [sasContainer blockBlobReferenceFromName:[NSString stringWithFormat:@"sasBlob2%@", sp.storedPolicyIdentifier]];
            [testBlob uploadFromText:@"test" completionHandler:^(NSError *err) {
                [AZSTestHelpers checkPassageOfError:err expectToPass:NO expectedHttpErrorCode:403 message:@"Upload from text"];
                
                completionHandler();
            }];
        }];
    }];
}

- (void)testContainerSasCombinations
{
    dispatch_semaphore_t counter = dispatch_semaphore_create(32);
    NSMutableArray *semaphores = [[NSMutableArray alloc] init];
    
    for (int accessPermissions = AZSSharedAccessPermissionsRead; accessPermissions <= AZSSharedAccessPermissionsBlobFull; accessPermissions++) {
        // TODO: Remove once these are supported (right now Add only applies to AppendBlobs and Create isn't yet supported by block blob)
        if ((accessPermissions & (AZSSharedAccessPermissionsAll ^ AZSSharedAccessPermissionsAdd ^ AZSSharedAccessPermissionsCreate)) == 0) {
            continue;
        }
        
        __block AZSTestSemaphore *semaphore= [[AZSTestSemaphore alloc] init];
        [semaphores addObject:semaphore];
        
        // Create random container and upload a test blob to it
        NSString *containerName = [NSString stringWithFormat:@"sampleioscontainer%@", [AZSTestHelpers uniqueName]];
        AZSCloudBlobContainer *container = [self.blobClient containerReferenceFromName:containerName];
        [container createContainerIfNotExistsWithCompletionHandler:^(NSError* err, BOOL created) {
            [AZSTestHelpers checkPassageOfError:err expectToPass:YES expectedHttpErrorCode:-1 message:@"Create container"];
            
            AZSCloudBlockBlob *blob = [container blockBlobReferenceFromName:@"sasBlob"];
            [blob uploadFromText:@"test" completionHandler:^(NSError *err) {
                [AZSTestHelpers checkPassageOfError:err expectToPass:YES expectedHttpErrorCode:-1 message:@"Upload from text"];
                
                // Generate permissions from i
                AZSSharedAccessBlobParameters *sp = [[AZSSharedAccessBlobParameters alloc] init];
                sp.storedPolicyIdentifier = [NSString stringWithFormat:@"test%d", accessPermissions];
                
                AZSSharedAccessPolicy *policy = [[AZSSharedAccessPolicy alloc] initWithIdentifier:sp.storedPolicyIdentifier];
                policy.permissions = accessPermissions & AZSSharedAccessPermissionsBlobFull;
                policy.sharedAccessExpiryTime = [[NSDate alloc] initWithTimeIntervalSinceNow:300];
                
                // Test with stored policy
                NSMutableDictionary *containerPermissions = [NSMutableDictionary dictionaryWithDictionary:@{policy.policyIdentifier : policy}];
                AZSTestSemaphore *innerSemaphore = [[AZSTestSemaphore alloc] init];
                NSError *error = nil;
                
                [container uploadPermissions:containerPermissions completionHandler:^(NSError *err) {
                    [AZSTestHelpers checkPassageOfError:error expectToPass:YES expectedHttpErrorCode:-1 message:@"Upload permissions"];
                    
                    [NSThread sleepForTimeInterval:30 + arc4random_uniform(10)];
                    // Generate SAS token and test access
                    NSError *error = nil;
                    NSString *sasToken = [container createSharedAccessSignatureWithParameters:sp error:&error];
                    [AZSTestHelpers checkPassageOfError:error expectToPass:YES expectedHttpErrorCode:-1 message:@"Create SAS token"];
                    
                    dispatch_semaphore_wait(counter, DISPATCH_TIME_FOREVER);
                    [self testAccessWithSAS:sasToken permissions:accessPermissions container:container blob:blob completionHandler:^() {
                        [container downloadPermissionsWithCompletionHandler:^(NSError *error, NSMutableDictionary *storedPermissions, AZSContainerPublicAccessType publicAccess) {
                            [AZSTestHelpers checkPassageOfError:err expectToPass:YES expectedHttpErrorCode:-1 message:@"Download permissions"];
                            [self checkEqualityOfContainerPermissions:containerPermissions otherPermissions:storedPermissions];
                            XCTAssertEqual(publicAccess, AZSContainerPublicAccessTypeOff);
                            
                            dispatch_semaphore_signal(counter);
                            [innerSemaphore signal];
                        }];
                    }];
                }];
                
                // Test with local parameters
                // Generate SAS token and test access
                AZSSharedAccessBlobParameters *sp2 = [[AZSSharedAccessBlobParameters alloc] init];
                sp2.permissions = policy.permissions;
                sp2.sharedAccessExpiryTime = policy.sharedAccessExpiryTime;
                NSString *sasToken = [container createSharedAccessSignatureWithParameters:sp2 error:&error];
                [AZSTestHelpers checkPassageOfError:error expectToPass:YES expectedHttpErrorCode:-1 message:@"Create SAS token"];
                
                dispatch_semaphore_wait(counter, DISPATCH_TIME_FOREVER);
                AZSCloudBlockBlob *blob2 = [container blockBlobReferenceFromName:@"sasBlob2"];
                [blob2 uploadFromText:@"test" completionHandler:^(NSError *err) {
                    [self testAccessWithSAS:sasToken permissions:accessPermissions container:container blob:blob2 completionHandler:^() {
                        dispatch_semaphore_signal(counter);
                        [innerSemaphore wait];
                        
                        [container deleteContainerIfExistsWithCompletionHandler:^(NSError *err, BOOL deleted) {
                            [AZSTestHelpers checkPassageOfError:err expectToPass:YES expectedHttpErrorCode:-1 message:@"Delete Container"];
                            
                            [semaphore signal];
                        }];
                    }];
                }];
            }];
        }];
    }
    [AZSTestSemaphore barrierOnSemaphores:semaphores];
}

- (void)testContainerPublicAccess
{
    AZSTestSemaphore *semaphore = [[AZSTestSemaphore alloc] init];
    AZSCloudBlockBlob *testBlob = [self.blobContainer blockBlobReferenceFromName:@"publicBlob"];
    [testBlob uploadFromText:@"test" completionHandler:^(NSError *err) {
        [AZSTestHelpers checkPassageOfError:err expectToPass:YES expectedHttpErrorCode:-1 message:@"Upload from text"];
        
        AZSContainerPublicAccessType publicAccess = AZSContainerPublicAccessTypeContainer;
        [self.blobContainer uploadPermissions:nil publicAccess:publicAccess accessCondition:nil requestOptions:nil operationContext:nil completionHandler:^(NSError * err) {
            [AZSTestHelpers checkPassageOfError:err expectToPass:YES expectedHttpErrorCode:-1 message:@"Upload permissions"];
            
            [NSThread sleepForTimeInterval:35];
            
            [self testAccessWithSAS:nil permissions:AZSSharedAccessPermissionsList|AZSSharedAccessPermissionsRead container:self.blobContainer blob:testBlob completionHandler:^{
                AZSContainerPublicAccessType publicAccess = AZSContainerPublicAccessTypeBlob;
                [self.blobContainer uploadPermissions:nil publicAccess:publicAccess accessCondition:nil requestOptions:nil operationContext:nil  completionHandler:^(NSError * err) {
                    [AZSTestHelpers checkPassageOfError:err expectToPass:YES expectedHttpErrorCode:-1 message:@"Upload Permissions"];
                    
                    [NSThread sleepForTimeInterval:30];
                    [self testAccessWithSAS:nil permissions:AZSSharedAccessPermissionsRead container:self.blobContainer blob:testBlob completionHandler:^{
                        
                        [self.blobContainer downloadPermissionsWithCompletionHandler:^(NSError *err, NSMutableDictionary *storedPermissions, AZSContainerPublicAccessType storedPublicAccess) {
                            [AZSTestHelpers checkPassageOfError:err expectToPass:YES expectedHttpErrorCode:-1 message:@"Fetch permissions"];
                            XCTAssertEqual(storedPermissions.count, 0);
                            XCTAssertEqual(publicAccess, storedPublicAccess);
                            
                            [semaphore signal];
                        }];
                    }];
                }];
            }];
        }];
    }];
    [semaphore wait];
}

- (void) testBlockBlobSasCombinations
{
    NSMutableArray *semaphores = [[NSMutableArray alloc] init];
    dispatch_semaphore_t counter = dispatch_semaphore_create(32);
    
    for (AZSSharedAccessPermissions accessPermissions = AZSSharedAccessPermissionsNone; accessPermissions <= AZSSharedAccessPermissionsBlobFull; accessPermissions++) {
        // TODO: Remove once these are supported (right now Add only applies to AppendBlobs and Create isn't yet supported by block blob)
        if ((accessPermissions & (AZSSharedAccessPermissionsAll ^ AZSSharedAccessPermissionsAdd ^ AZSSharedAccessPermissionsCreate)) == 0) {
            continue;
        }
        
        dispatch_semaphore_wait(counter, DISPATCH_TIME_FOREVER);
        AZSTestSemaphore *semaphore = [[AZSTestSemaphore alloc] init];
        [semaphores addObject:semaphore];
        
        // Create random container and upload a test blob to it
        NSString *containerName = [NSString stringWithFormat:@"sampleioscontainer%@", [AZSTestHelpers uniqueName]];
        AZSCloudBlobContainer *container = [self.blobClient containerReferenceFromName:containerName];
        [container createContainerIfNotExistsWithCompletionHandler:^(NSError *err, BOOL exists) {
            [AZSTestHelpers checkPassageOfError:err expectToPass:YES expectedHttpErrorCode:-1 message:@"Create container"];
            
            AZSCloudBlockBlob *blob = [container blockBlobReferenceFromName:@"testSasBlockBlob"];
            [blob uploadFromText:@"test" completionHandler:^(NSError * err) {
                [AZSTestHelpers checkPassageOfError:err expectToPass:YES expectedHttpErrorCode:-1 message:@"Upload from text"];
                
                AZSSharedAccessBlobParameters *sp = [[AZSSharedAccessBlobParameters alloc] init];
                sp.storedPolicyIdentifier = [NSString stringWithFormat:@"test%lu", (unsigned long)accessPermissions];
                
                AZSSharedAccessPolicy *policy = [[AZSSharedAccessPolicy alloc] initWithIdentifier:sp.storedPolicyIdentifier];
                policy.permissions = accessPermissions & AZSSharedAccessPermissionsBlobFull;
                policy.sharedAccessExpiryTime = [[NSDate alloc] initWithTimeIntervalSinceNow:300];
                
                // Test with stored policy
                NSMutableDictionary *containerPermissions = [NSMutableDictionary dictionaryWithDictionary:@{policy.policyIdentifier : policy}];
                AZSTestSemaphore *innerSemaphore = [[AZSTestSemaphore alloc] init];
                __block NSError *error = nil;
                
                [container uploadPermissions:containerPermissions completionHandler:^(NSError *err) {
                    [AZSTestHelpers checkPassageOfError:error expectToPass:YES expectedHttpErrorCode:-1 message:@"Upload permissions"];
                    
                    [NSThread sleepForTimeInterval:30 + arc4random_uniform(10)];
                    // Generate SAS token and test access
                    NSError *error = nil;
                    NSString *sasToken = [container createSharedAccessSignatureWithParameters:sp error:&error];
                    [AZSTestHelpers checkPassageOfError:error expectToPass:YES expectedHttpErrorCode:-1 message:@"Create SAS token"];
                    
                    [self testAccessWithSAS:sasToken permissions:accessPermissions container:nil blob:blob completionHandler:^() {
                        [container downloadPermissionsWithCompletionHandler:^(NSError *error, NSMutableDictionary *storedPermissions, AZSContainerPublicAccessType publicAccess) {
                            [AZSTestHelpers checkPassageOfError:err expectToPass:YES expectedHttpErrorCode:-1 message:@"Download permissions"];
                            [self checkEqualityOfContainerPermissions:containerPermissions otherPermissions:storedPermissions];
                            XCTAssertEqual(publicAccess, AZSContainerPublicAccessTypeOff);
                            
                            [innerSemaphore signal];
                        }];
                    }];
                }];
                
                // Test with local parameters
                AZSSharedAccessBlobParameters *sp2 = [[AZSSharedAccessBlobParameters alloc] init];
                sp2.permissions = policy.permissions;
                sp2.sharedAccessExpiryTime = policy.sharedAccessExpiryTime;
                
                AZSCloudBlockBlob *blob2 = [container blockBlobReferenceFromName:@"testSasBlockBlob2"];
                [blob2 uploadFromText:@"test" completionHandler:^(NSError *err) {
                    NSString *sasToken = [blob2 createSharedAccessSignatureWithParameters:sp2 error:&error];
                    [AZSTestHelpers checkPassageOfError:error expectToPass:YES expectedHttpErrorCode:-1 message:@"Create SAS token"];
                    
                    [self testAccessWithSAS:sasToken permissions:accessPermissions container:nil blob:blob2 completionHandler:^{
                        [innerSemaphore wait];
                        
                        [container deleteContainerIfExistsWithCompletionHandler:^(NSError *err, BOOL deleted) {
                            dispatch_semaphore_signal(counter);
                            [semaphore signal];
                        }];
                    }];
                }];
            }];
        }];
    }
    [AZSTestSemaphore barrierOnSemaphores:semaphores];
}

- (void) testBlobSas
{
    // Test with stored policy
    AZSTestSemaphore *semaphore = [[AZSTestSemaphore alloc] init];
    AZSSharedAccessBlobParameters *sp = [[AZSSharedAccessBlobParameters alloc] init];
    sp.storedPolicyIdentifier = @"readperm";
    
    AZSSharedAccessPolicy *policy = [[AZSSharedAccessPolicy alloc] initWithIdentifier:sp.storedPolicyIdentifier];
    policy.permissions = AZSSharedAccessPermissionsRead|AZSSharedAccessPermissionsList;
    policy.sharedAccessExpiryTime = [[NSDate alloc] initWithTimeIntervalSinceNow:300];
    NSMutableDictionary *permissions = [NSMutableDictionary dictionaryWithDictionary:@{sp.storedPolicyIdentifier : policy}];
    
    [self.blobContainer uploadPermissions:permissions completionHandler:^(NSError *err) {
        [AZSTestHelpers checkPassageOfError:err expectToPass:YES expectedHttpErrorCode:-1 message:@"Upload Permissions"];
        
        [self testBlobSasWithParameters:sp completionHandler:^{
            [self.blobContainer downloadPermissionsWithCompletionHandler:^(NSError *err, NSMutableDictionary *storedPermissions, AZSContainerPublicAccessType publicAccess) {
                [AZSTestHelpers checkPassageOfError:err expectToPass:YES expectedHttpErrorCode:-1 message:@"Fetch permissions"];
                [self checkEqualityOfContainerPermissions:permissions otherPermissions:storedPermissions];
                XCTAssertEqual(publicAccess, AZSContainerPublicAccessTypeOff);
                
                [semaphore signal];
            }];
        }];
    }];
    [NSThread sleepForTimeInterval:30];
    
    // Test with local parameters
    AZSTestSemaphore *innerSemaphore = [[AZSTestSemaphore alloc] init];
    AZSSharedAccessBlobParameters *sp2 = [[AZSSharedAccessBlobParameters alloc] init];
    sp2.permissions = policy.permissions;
    sp2.sharedAccessExpiryTime = policy.sharedAccessExpiryTime;
    [self testBlobSasWithParameters:sp2 completionHandler:^() {
        [innerSemaphore signal];
    }];
    
    [innerSemaphore wait];
    [semaphore wait];
}

- (void) testBlobSasWithParameters:(AZSSharedAccessBlobParameters *)sp completionHandler:(void(^)())completionHandler
{
    __block NSError *error = nil;
    NSString *blobURL = [NSString stringWithFormat:@"%@?%@", [[self.blockBlob.storageUri urlWithLocation:AZSStorageLocationPrimary] absoluteString], [self.blockBlob createSharedAccessSignatureWithParameters:sp error:&error]];
    [AZSTestHelpers checkPassageOfError:error expectToPass:YES expectedHttpErrorCode:-1 message:@"Create SAS token"];
    
    AZSCloudBlockBlob *sasBlob = [[AZSCloudBlockBlob alloc] initWithUrl:[[NSURL alloc] initWithString:blobURL] error:&error];
    XCTAssertNil(error);
    [sasBlob downloadToStream:[[NSOutputStream alloc] initToMemory] completionHandler:^(NSError * err) {
        [AZSTestHelpers checkPassageOfError:err expectToPass:YES expectedHttpErrorCode:-1 message:@"Dowload to stream"];
        
        // Withhold the client and ensure the new blob's client still has SAS permissions
        NSError *initError;
        AZSCloudBlockBlob *blobFromUri = [[AZSCloudBlockBlob alloc] initWithStorageUri:[self addToQuery:self.blockBlob.storageUri queryString:[self.blockBlob createSharedAccessSignatureWithParameters:sp error:&error]] error:&initError];
        XCTAssertNil(initError);
        [AZSTestHelpers checkPassageOfError:error expectToPass:YES expectedHttpErrorCode:-1 message:@"Create SAS token"];
        XCTAssertTrue([blobFromUri.client.credentials isSAS]);
        
        [blobFromUri downloadToStream:[[NSOutputStream alloc] initToMemory] accessCondition:nil requestOptions:nil operationContext:nil completionHandler:^(NSError * err) {
            [AZSTestHelpers checkPassageOfError:err expectToPass:YES expectedHttpErrorCode:-1 message:@"Dowload to stream"];
            
            // Generate credentials from SAS
            AZSStorageCredentials *creds = [[AZSStorageCredentials alloc] initWithSASToken:[self.blockBlob createSharedAccessSignatureWithParameters:sp error:&error]];
            [AZSTestHelpers checkPassageOfError:error expectToPass:YES expectedHttpErrorCode:-1 message:@"Create SAS token"];
            
            AZSCloudBlobClient *bClient = [[AZSCloudBlobClient alloc] initWithStorageUri:sasBlob.client.storageUri credentials:creds];
            AZSCloudBlockBlob *blobFromClient = [[bClient containerReferenceFromName:self.blobContainer.name] blockBlobReferenceFromName:self.blockBlob.blobName];
            XCTAssertTrue([blobFromClient.client.credentials isSAS]);
            XCTAssertEqualObjects(bClient, blobFromClient.client);
            
            [blobFromClient downloadToStream:[[NSOutputStream alloc] initToMemory] accessCondition:nil requestOptions:nil operationContext:nil completionHandler:^(NSError *Err) {
                [AZSTestHelpers checkPassageOfError:err expectToPass:YES expectedHttpErrorCode:-1 message:@"Dowload to stream"];
                
                completionHandler();
            }];
        }];
    }];
}

- (void) testBlobSasSharedAccessBlobHeaders
{
    AZSOperationContext *context = [[AZSOperationContext alloc] init];
    
    // Test with stored policy
    AZSTestSemaphore *semaphore = [[AZSTestSemaphore alloc] init];
    AZSSharedAccessBlobParameters *sp = [[AZSSharedAccessBlobParameters alloc] init];
    sp.storedPolicyIdentifier = @"readperm";
    
    AZSSharedAccessPolicy *policy = [[AZSSharedAccessPolicy alloc] initWithIdentifier:sp.storedPolicyIdentifier];
    policy.permissions = AZSSharedAccessPermissionsRead|AZSSharedAccessPermissionsWrite|AZSSharedAccessPermissionsList;
    policy.sharedAccessExpiryTime = [[NSDate alloc] initWithTimeIntervalSinceNow:300];
    NSMutableDictionary *permissions = [NSMutableDictionary dictionaryWithDictionary:@{sp.storedPolicyIdentifier : policy}];
    [self.blobContainer uploadPermissions:permissions completionHandler:^(NSError * err) {
        [AZSTestHelpers checkPassageOfError:err expectToPass:YES expectedHttpErrorCode:-1 message:@"Upload permissions"];
        
        [self testBlobSasSharedAccessBlobHeadersWithParameters:sp context:context completionHandler:^() {
            [self.blobContainer downloadPermissionsWithCompletionHandler:^(NSError *err, NSMutableDictionary *storedPermissions, AZSContainerPublicAccessType publicAccess) {
                [AZSTestHelpers checkPassageOfError:err expectToPass:YES expectedHttpErrorCode:-1 message:@"Fetch permissions"];
                [self checkEqualityOfContainerPermissions:permissions otherPermissions:storedPermissions];
                XCTAssertEqual(publicAccess, AZSContainerPublicAccessTypeOff);
                
                [semaphore signal];
            }];
        }];
    }];
    [NSThread sleepForTimeInterval:30];
    
    // Test with local parameters
    AZSTestSemaphore *innerSemaphore = [[AZSTestSemaphore alloc] init];
    AZSSharedAccessBlobParameters *sp2 = [[AZSSharedAccessBlobParameters alloc] init];
    sp2.permissions = policy.permissions;
    sp2.sharedAccessExpiryTime = policy.sharedAccessExpiryTime;
    [self testBlobSasSharedAccessBlobHeadersWithParameters:sp2 context:context completionHandler:^() {
        [innerSemaphore signal];
    }];
    
    [innerSemaphore wait];
    [semaphore wait];
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
    [AZSTestHelpers checkPassageOfError:error expectToPass:YES expectedHttpErrorCode:-1 message:@"Create SAS token"];
    
    AZSCloudBlockBlob *sasBlob = [[AZSCloudBlockBlob alloc] initWithUrl:[[NSURL alloc] initWithString:blobURL] error:&error];
    XCTAssertNil(error);
    
    context.responseReceived = ^void(NSMutableURLRequest *req, NSHTTPURLResponse *resp, AZSOperationContext *ctxt) {
        XCTAssertTrue([@"no-cache" isEqualToString:resp.allHeaderFields[AZSCXmlContentCacheControl]]);
        XCTAssertTrue([@"attachment; filename=\"fname.ext\"" isEqualToString:resp.allHeaderFields[AZSCXmlContentDisposition]]);
        XCTAssertTrue([@"gzip" isEqualToString:resp.allHeaderFields[AZSCXmlContentEncoding]]);
        XCTAssertTrue([@"da" isEqualToString:resp.allHeaderFields[AZSCXmlContentLanguage]]);
        XCTAssertTrue([@"text/html; charset=utf-8" isEqualToString:resp.allHeaderFields[AZSCXmlContentType]]);
    };
    [sasBlob downloadToStream:[[NSOutputStream alloc] initToMemory] accessCondition:nil requestOptions:nil operationContext:context completionHandler:^(NSError * err) {
        [AZSTestHelpers checkPassageOfError:err expectToPass:YES expectedHttpErrorCode:-1 message:@"Download to stream"];
        
        completionHandler();
    }];
}

- (void)testAccessWithSAS:(NSString *)sasToken permissions:(AZSSharedAccessPermissions)permissions container:(AZSCloudBlobContainer *)container blob:(AZSCloudBlob *) blob completionHandler:(void(^)())completionHandler
{
    const AZSStorageCredentials *creds = [[AZSStorageCredentials alloc] initWithSASToken:sasToken];
    const int permissionsErrorCode = (sasToken) ? 403 : 404;
    
    NSError *error;
    if (container) {
        container = [[AZSCloudBlobContainer alloc] initWithStorageUri:[creds transformWithStorageUri:container.storageUri] error:&error];
        blob = [container blockBlobReferenceFromName:blob.blobName];
    }
    else {
        blob = [[AZSCloudBlockBlob alloc] initWithStorageUri:[self addToQuery:blob.storageUri queryString:sasToken] error:&error];
    }
    XCTAssertNil(error);
    
    __block AZSContinuationToken *token = [[AZSContinuationToken alloc] init];
    
    // Test presence or absence blob WRITE permissions
    [blob uploadMetadataWithCompletionHandler:^(NSError *err) {
        [AZSTestHelpers checkPassageOfError:err expectToPass:(permissions & AZSSharedAccessPermissionsWrite) expectedHttpErrorCode:permissionsErrorCode message:@"Upload metadata"];
        
        // Test presence or absence Blob READ permissions

        [blob downloadAttributesWithCompletionHandler:^(NSError * err) {
            [self checkPassageOfError:err expectToPass:(permissions & AZSSharedAccessPermissionsRead) expectedHttpErrorCode:permissionsErrorCode message:@"Fetch attributes"];
            
            // Test presence or absence Blob DELETE permissions
            [blob deleteWithCompletionHandler:^(NSError *err) {
                [AZSTestHelpers checkPassageOfError:err expectToPass:(permissions & AZSSharedAccessPermissionsDelete) expectedHttpErrorCode:permissionsErrorCode message:@"Delete"];
                
                if (container) {
                    // TODO: Add test for presence or absence of Append Blob ADD permissions
                    
                    // Test presence or absence Container WRITE (and eventually CREATE) permissiomns
                    AZSCloudBlockBlob *sasBlob = [container blockBlobReferenceFromName:@"testAccessBlob"];
                    [sasBlob uploadFromText:@"test" completionHandler:^(NSError *err) {
                        // TODO: Uncomment create once it is supported by block blob
                        [AZSTestHelpers checkPassageOfError:err expectToPass:(permissions & (AZSSharedAccessPermissionsWrite /*| AZSSharedAccessPermissionsCreate*/)) expectedHttpErrorCode:permissionsErrorCode message:@"Upload from text"];
                        
                        AZSTestSemaphore *innerSemaphore = [[AZSTestSemaphore alloc] init];
                        if (permissions & AZSSharedAccessPermissionsList) {
                            // Test presence of Container LIST permissions
                            __weak __block void (^listBlobs)(AZSContinuationToken *);
                            void (^continueBlock)(AZSContinuationToken *) = ^(AZSContinuationToken *tok) {
                                if (!tok) {
                                    [innerSemaphore signal];
                                }
                                else {
                                    [container listBlobsSegmentedWithContinuationToken:tok prefix:AZSCEmptyString useFlatBlobListing:YES blobListingDetails:AZSBlobListingDetailsNone maxResults:-1 completionHandler:^(NSError * err, AZSBlobResultSegment *result) {
                                        [AZSTestHelpers checkPassageOfError:err expectToPass:YES expectedHttpErrorCode:permissionsErrorCode message:@"List blobs"];
                                        
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
                            [container listBlobsSegmentedWithContinuationToken:token prefix:AZSCEmptyString useFlatBlobListing:YES blobListingDetails:AZSBlobListingDetailsNone maxResults:-1 completionHandler:^(NSError * err, AZSBlobResultSegment *result) {
                                [AZSTestHelpers checkPassageOfError:err expectToPass:NO expectedHttpErrorCode:permissionsErrorCode message:@"List blobs"];
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