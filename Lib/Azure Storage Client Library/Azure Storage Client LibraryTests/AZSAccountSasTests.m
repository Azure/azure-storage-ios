// -----------------------------------------------------------------------------------------
// <copyright file="AZSAccountSasTests.m" company="Microsoft">
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

@interface AZSAccountSasTests : AZSTestBase
@end

@implementation AZSAccountSasTests : AZSTestBase

- (void)testBlobAccountSasIpAddressOrRange
{
    AZSTestSemaphore *semaphore = [[AZSTestSemaphore alloc] init];
    AZSSharedAccessAccountParameters *sp = [[AZSSharedAccessAccountParameters alloc] init];
    
    sp.services = AZSSharedAccessServicesBlob;
    sp.resourceTypes = AZSSharedAccessResourceTypesObject;
    sp.permissions = AZSSharedAccessPermissionsRead;
    sp.sharedAccessExpiryTime = [[NSDate alloc] initWithTimeIntervalSinceNow:300];
    
    AZSCloudBlobClient *client = [self.account getBlobClient];
    AZSCloudBlobContainer *container = [client containerReferenceFromName:[NSString stringWithFormat:@"sampleioscontainer%@", [AZSTestHelpers uniqueName]]];
    [container createContainerIfNotExistsWithCompletionHandler:^(NSError *err, BOOL exists) {
        AZSCloudBlockBlob *blob = [container blockBlobReferenceFromName:@"testblob"];

        [blob uploadFromText:@"test text" completionHandler:^(NSError *err) {
            // Ensure access attempt from invalid IP fails.
            struct in_addr ip;
            inet_aton([@"0.0.0.0" UTF8String], ((struct in_addr *) &ip));
            sp.ipAddressOrRange = [[AZSIPRange alloc] initWithSingleIP:ip];
            
            NSError *error = nil;
            NSString *accountSasNone = [self.account createSharedAccessSignatureWithParameters:sp error:&error];
            [self checkPassageOfError:error expectToPass:YES expectedHttpErrorCode:-1 message:@"Create SAS token"];
    
            AZSStorageCredentials *noneCredentials = [[AZSStorageCredentials alloc] initWithSASToken:accountSasNone accountName:client.credentials.accountName];
            AZSCloudBlobClient *noneClient = [[[AZSCloudStorageAccount alloc] initWithCredentials:noneCredentials useHttps:NO error:&error] getBlobClient];
            [self checkPassageOfError:error expectToPass:YES expectedHttpErrorCode:-1 message:@"Access account with SAS token"];
            AZSCloudBlockBlob *noneBlob = [[noneClient containerReferenceFromName:container.name] blockBlobReferenceFromName:blob.blobName];
            
            [noneBlob downloadToStream:[[NSOutputStream alloc] initToMemory] completionHandler:^(NSError * err) {
                [self checkPassageOfError:err expectToPass:NO expectedHttpErrorCode:403 message:@"Download blob"];
                XCTAssertTrue([(err.userInfo[@"Message"]) hasPrefix:@"This request is not authorized to perform this operation using this source IP"]);

                // Ensure access attempt from the single allowed IP succeeds.
                struct in_addr ip2;
                inet_aton([err.userInfo[@"AdditionalErrorDetails"][@"SourceIP"] UTF8String], ((struct in_addr *) &ip2));
                sp.ipAddressOrRange = [[AZSIPRange alloc] initWithSingleIP:ip2];
        
                NSError *error = nil;
                NSString *accountSasOne = [self.account createSharedAccessSignatureWithParameters:sp error:&error];
                [self checkPassageOfError:error expectToPass:YES expectedHttpErrorCode:-1 message:@"Create SAS token"];
                
                AZSStorageCredentials *oneCredentials = [[AZSStorageCredentials alloc] initWithSASToken:accountSasOne accountName:client.credentials.accountName];
                AZSCloudBlobClient *oneClient = [[[AZSCloudStorageAccount alloc] initWithCredentials:oneCredentials useHttps:NO error:&error] getBlobClient];
                [self checkPassageOfError:error expectToPass:YES expectedHttpErrorCode:-1 message:@"Access account with SAS token"];
                
                AZSCloudBlockBlob *oneBlob = [[oneClient containerReferenceFromName:container.name] blockBlobReferenceFromName:blob.blobName];
                
                [oneBlob downloadToStream:[[NSOutputStream alloc] initToMemory] completionHandler:^(NSError * err) {
                    [self checkPassageOfError:err expectToPass:YES expectedHttpErrorCode:-1 message:@"Download blob"];

                    // Ensure access attempt from one of many allowed IPs succeeds.
                    inet_aton([@"255.255.255.255" UTF8String], ((struct in_addr *) &ip2));
                    sp.ipAddressOrRange = [[AZSIPRange alloc] initWithMinIP:ip maxIP:ip2];

                    NSError *error = nil;
                    NSString *accountSasAll = [self.account createSharedAccessSignatureWithParameters:sp error:&error];
                    [self checkPassageOfError:error expectToPass:YES expectedHttpErrorCode:-1 message:@"Create SAS token"];
                    
                    AZSStorageCredentials *allCredentials = [[AZSStorageCredentials alloc] initWithSASToken:accountSasAll accountName:client.credentials.accountName];
                    AZSCloudBlobClient *allClient = [[[AZSCloudStorageAccount alloc] initWithCredentials:allCredentials useHttps:NO error:&error] getBlobClient];
                    [self checkPassageOfError:error expectToPass:YES expectedHttpErrorCode:-1 message:@"Access account with SAS token"];
                    
                    AZSCloudBlockBlob *allBlob = [[allClient containerReferenceFromName:container.name] blockBlobReferenceFromName:blob.blobName];
                    [allBlob downloadToStream:[[NSOutputStream alloc] initToMemory] completionHandler:^(NSError * err) {
                        [self checkPassageOfError:err expectToPass:YES expectedHttpErrorCode:-1 message:@"Download blob"];

                        [container deleteContainerIfExistsWithCompletionHandler:^(NSError *err, BOOL exists) {
                            [semaphore signal];
                        }];
                    }];
                }];
            }];
        }];
    }];
    [semaphore wait];
}

- (void)testBlobAccountSasProtocolRestrictions
{
    AZSTestSemaphore *semaphore = [[AZSTestSemaphore alloc] init];
    AZSSharedAccessAccountParameters *sp = [[AZSSharedAccessAccountParameters alloc] init];
    
    sp.services = AZSSharedAccessServicesBlob;
    sp.resourceTypes = AZSSharedAccessResourceTypesObject;
    sp.permissions = AZSSharedAccessPermissionsRead;
    sp.sharedAccessExpiryTime = [[NSDate alloc] initWithTimeIntervalSinceNow:300];
    
    AZSCloudBlobContainer *container = [[self.account getBlobClient] containerReferenceFromName:[NSString stringWithFormat:@"sampleioscontainer%@", [AZSTestHelpers uniqueName]]];
    [container createContainerIfNotExistsWithCompletionHandler:^(NSError *err, BOOL exists) {
        AZSCloudBlockBlob *blob = [container blockBlobReferenceFromName:@"testblob"];
        
        [blob uploadFromText:@"test text" completionHandler:^(NSError *err) {
            NSError *error = nil;
            
            // Ensure using http with https only SAS fails.
            sp.protocols = AZSSharedAccessProtocolHttpsOnly;
            NSString *accountSasHttps = [self.account createSharedAccessSignatureWithParameters:sp error:&error];
            [self checkPassageOfError:error expectToPass:YES expectedHttpErrorCode:-1 message:@"Create SAS token"];
    
            NSURLComponents *uri = [NSURLComponents componentsWithURL:blob.storageUri.primaryUri resolvingAgainstBaseURL:NO];
            uri.scheme = AZSCHttp;
            AZSUriQueryBuilder *httpsBuilder = [[AZSUriQueryBuilder alloc] initWithQuery:accountSasHttps];
            AZSCloudBlockBlob *httpBlob = [[AZSCloudBlockBlob alloc] initWithUrl:[httpsBuilder addToUri:uri.URL] error:&error];
            XCTAssertNil(error);
            
            [httpBlob downloadToStream:[[NSOutputStream alloc] initToMemory] completionHandler:^(NSError *err) {
                [self checkPassageOfError:err expectToPass:NO expectedHttpErrorCode:403 message:@"Download https only blob using http"];
                XCTAssertTrue([(err.userInfo[@"Message"]) hasPrefix:@"This request is not authorized to perform this operation using this protocol."]);
        
                // Ensure using https with https only SAS succeeds.
                NSError *error = nil;
                uri.scheme = AZSCHttps;
                AZSCloudBlockBlob *httpsBlob = [[AZSCloudBlockBlob alloc] initWithUrl:[httpsBuilder addToUri:uri.URL] error:&error];
                XCTAssertNil(error);
                
                [httpsBlob downloadToStream:[[NSOutputStream alloc] initToMemory] completionHandler:^(NSError *err) {
                    [self checkPassageOfError:err expectToPass:YES expectedHttpErrorCode:-1 message:@"Download https only blob using https"];
            
                    // Ensure using https with https,http SAS succeeds.
                    sp.protocols = AZSSharedAccessProtocolHttpsHttp;
                    NSError *error = nil;
                    NSString *accountSasHttp = [self.account createSharedAccessSignatureWithParameters:sp error:&error];
                    [self checkPassageOfError:error expectToPass:YES expectedHttpErrorCode:-1 message:@"Create SAS token"];
                    
                    AZSUriQueryBuilder *httpBuilder = [[AZSUriQueryBuilder alloc] initWithQuery:accountSasHttp];
                    AZSCloudBlockBlob *httpsBlob = [[AZSCloudBlockBlob alloc] initWithUrl:[httpBuilder addToUri:uri.URL] error:&error];
                    XCTAssertNil(error);
                    
                    [httpsBlob downloadToStream:[[NSOutputStream alloc] initToMemory] completionHandler:^(NSError *err) {
                        [self checkPassageOfError:err expectToPass:YES expectedHttpErrorCode:-1 message:@"Download blob using https"];

                        // Ensure using http with https,http SAS succeeds.
                        uri.scheme = AZSCHttp;
                        
                        NSError *error = nil;
                        AZSCloudBlockBlob *httpBlob = [[AZSCloudBlockBlob alloc] initWithUrl:[httpBuilder addToUri:uri.URL] error:&error];
                        XCTAssertNil(error);
                        
                        [httpBlob downloadToStream:[[NSOutputStream alloc] initToMemory] completionHandler:^(NSError *err) {
                            [self checkPassageOfError:err expectToPass:YES expectedHttpErrorCode:-1 message:@"Download blob using http"];
                            
                            [container deleteContainerIfExistsWithCompletionHandler:^(NSError *err, BOOL exists) {
                                [semaphore signal];
                            }];
                        }];
                    }];
                }];
            }];
        }];
    }];
    [semaphore wait];
}

- (void)testBlobAccountSasResourceCombinations
{
    NSMutableArray *semaphores = [[NSMutableArray alloc] init];
    
    for (AZSSharedAccessResourceTypes resourceTypes = AZSSharedAccessResourceTypesService; resourceTypes <= AZSSharedAccessResourceTypesAll; resourceTypes++) {
        AZSTestSemaphore *semaphore = [[AZSTestSemaphore alloc] init];
        [semaphores addObject:semaphore];
        [self testBlobAccountSasCombinationsWithResourceTypes:resourceTypes services:AZSSharedAccessServicesBlob permissions:AZSSharedAccessPermissionsBlobFull completionHandler:^() {
            [semaphore signal];
        }];
    }
    
    [AZSTestSemaphore barrierOnSemaphores:semaphores];
}

- (void)testBlobAccountSasServiceCombinations
{
    NSMutableArray *semaphores = [[NSMutableArray alloc] init];
    
    for (AZSSharedAccessServices services = AZSSharedAccessServicesBlob; services <= AZSSharedAccessServicesAll; services++) {
        AZSTestSemaphore *semaphore = [[AZSTestSemaphore alloc] init];
        [semaphores addObject:semaphore];
        [self testBlobAccountSasCombinationsWithResourceTypes:AZSSharedAccessResourceTypesAll services:services permissions:AZSSharedAccessPermissionsBlobFull completionHandler:^() {
            [semaphore signal];
        }];
    }
    
    [AZSTestSemaphore barrierOnSemaphores:semaphores];
}

- (void)testBlobAccountSasPermissionsCombinations
{
    NSMutableArray *semaphores = [[NSMutableArray alloc] init];
    dispatch_semaphore_t counter = dispatch_semaphore_create(4);
    
    for (AZSSharedAccessPermissions permissions = AZSSharedAccessPermissionsRead; permissions <= AZSSharedAccessPermissionsBlobFull; permissions++) {
        AZSTestSemaphore *semaphore = [[AZSTestSemaphore alloc] init];
        [semaphores addObject:semaphore];
        dispatch_semaphore_wait(counter, DISPATCH_TIME_FOREVER);
        [self testBlobAccountSasCombinationsWithResourceTypes:AZSSharedAccessResourceTypesAll services:AZSSharedAccessServicesBlob permissions:permissions completionHandler:^() {
            [semaphore signal];
            dispatch_semaphore_signal(counter);
        }];
    }
    
    [AZSTestSemaphore barrierOnSemaphores:semaphores];
}

- (void)testBlobAccountSasCombinationsWithResourceTypes:(AZSSharedAccessResourceTypes)resourceTypes services:(AZSSharedAccessServices)services permissions:(AZSSharedAccessPermissions)permissions completionHandler:(void(^)())completionHandler
{
    AZSSharedAccessAccountParameters *sp = [[AZSSharedAccessAccountParameters alloc] init];
    sp.services = services;
    sp.resourceTypes = resourceTypes;
    sp.permissions = permissions;
    sp.sharedAccessExpiryTime = [[NSDate alloc] initWithTimeIntervalSinceNow:300];
    
    NSError *error = nil;
    NSString *accountSAS = [self.account createSharedAccessSignatureWithParameters:sp error:&error];
    [self checkPassageOfError:error expectToPass:YES expectedHttpErrorCode:-1 message:@"Create SAS token"];
    
    AZSCloudBlobClient *client = [self.account getBlobClient];
    AZSStorageCredentials *credentials = [[AZSStorageCredentials alloc] initWithSASToken:accountSAS accountName:client.credentials.accountName];
    AZSCloudBlobClient *sasClient = [[[AZSCloudStorageAccount alloc] initWithCredentials:credentials useHttps:NO error:&error] getBlobClient];
    [self checkPassageOfError:error expectToPass:YES expectedHttpErrorCode:-1 message:@"Access account with SAS token"];
    
    AZSCloudBlobContainer *container = [client containerReferenceFromName:[NSString stringWithFormat:@"%@res%lu-perm%lu", [AZSTestHelpers uniqueName], resourceTypes, (unsigned long)permissions]];
    AZSCloudBlobContainer *sasContainer = [sasClient containerReferenceFromName:container.name];
    
    void (^createContainer)(id, void(^)(NSError *)) = ^void(id container, void(^completionHandler)(NSError *)) {
        [container createContainerWithCompletionHandler:^(NSError *err) {
            BOOL shouldPass = !((AZSCloudBlobContainer *) container).client.credentials.isSAS ||
                    [self isAccessAllowedWithParameters:sp acceptedPermissions:(AZSSharedAccessPermissionsCreate | AZSSharedAccessPermissionsWrite)
                    acceptedResourceTypes:AZSSharedAccessResourceTypesContainer acceptedServices:AZSSharedAccessServicesBlob];
            [self checkPassageOfError:err expectToPass:shouldPass expectedHttpErrorCode:403 message:@"Attempt to Create Container"];
            completionHandler(err);
        }];
    };
    
    void (^containerExists)(id, void(^)(NSError *)) = ^void(id container, void(^completionHandler)(NSError *)) {
        [container existsWithCompletionHandler:^(NSError *err, BOOL exists) {
            XCTAssertTrue(exists || err);
            BOOL shouldPass = !((AZSCloudBlobContainer *) container).client.credentials.isSAS ||
                    [self isAccessAllowedWithParameters:sp acceptedPermissions:AZSSharedAccessPermissionsRead
                    acceptedResourceTypes:AZSSharedAccessResourceTypesContainer acceptedServices:AZSSharedAccessServicesBlob];
            [self checkPassageOfError:err expectToPass:shouldPass expectedHttpErrorCode:403 message:@"Attempt to check whether Container Exists"];
            completionHandler(err);
        }];
    };
    
    void (^listContainer)(id, void(^)(NSError *)) = ^void(id client, void(^completionHandler)(NSError *)) {
        [client listContainersSegmentedWithContinuationToken:nil prefix:container.name completionHandler:^(NSError *err, AZSContainerResultSegment* result) {
            BOOL shouldPass = !((AZSCloudClient*) client).credentials.isSAS ||
                    [self isAccessAllowedWithParameters:sp acceptedPermissions:AZSSharedAccessPermissionsList
                    acceptedResourceTypes:AZSSharedAccessResourceTypesService acceptedServices:AZSSharedAccessServicesBlob];
            [self checkPassageOfError:err expectToPass:shouldPass expectedHttpErrorCode:403 message:@"Attempt to List Containers"];
            completionHandler(err);
        }];
    };
    
    void (^createBlob)(id, void(^)(NSError *)) = ^void(id blob, void(^completionHandler)(NSError *)) {
        // TODO: Add check for create permissions once our library allows creating empty blobs
        
        [blob uploadFromText:@"test data" completionHandler:^(NSError *err) {
            BOOL shouldPass = !((AZSCloudBlob *) blob).blobContainer.client.credentials.isSAS ||
                    [self isAccessAllowedWithParameters:sp acceptedPermissions:AZSSharedAccessPermissionsWrite
                    acceptedResourceTypes:AZSSharedAccessResourceTypesObject acceptedServices:AZSSharedAccessServicesBlob];
            [self checkPassageOfError:err expectToPass:shouldPass expectedHttpErrorCode:403 message:@"Attempt to Create Blob"];
            completionHandler(err);
        }];
    };
    
    void (^blobExists)(id, void(^)(NSError *)) = ^void(id blob, void(^completionHandler)(NSError *)) {
        [blob existsWithCompletionHandler:^(NSError *err, BOOL exists) {
            XCTAssertTrue(exists || err);
            BOOL shouldPass = !((AZSCloudBlob *) blob).blobContainer.client.credentials.isSAS ||
                    [self isAccessAllowedWithParameters:sp acceptedPermissions:AZSSharedAccessPermissionsRead
                    acceptedResourceTypes:AZSSharedAccessResourceTypesObject acceptedServices:AZSSharedAccessServicesBlob];
            [self checkPassageOfError:err expectToPass:shouldPass expectedHttpErrorCode:403 message:@"Attempt to check whether Blob Exists"];
            completionHandler(err);
        }];
    };
    
    void (^downloadBlob)(id, void(^)(NSError *)) = ^void(id blob, void(^completionHandler)(NSError *)) {
        [blob downloadToTextWithCompletionHandler:^(NSError *err, NSString *contents) {
            BOOL shouldPass = !((AZSCloudBlob *) blob).blobContainer.client.credentials.isSAS ||
            [self isAccessAllowedWithParameters:sp acceptedPermissions:AZSSharedAccessPermissionsRead
                    acceptedResourceTypes:AZSSharedAccessResourceTypesObject acceptedServices:AZSSharedAccessServicesBlob];
            [self checkPassageOfError:err expectToPass:shouldPass expectedHttpErrorCode:403 message:@"Attempt to Download Blob"];
            completionHandler(err);
        }];
    };
    
    void (^deleteBlob)(id, void(^)(NSError *)) = ^void(id blob, void(^completionHandler)(NSError *)) {
        [blob deleteWithCompletionHandler:^(NSError *err) {
            BOOL shouldPass = !((AZSCloudBlob *) blob).blobContainer.client.credentials.isSAS ||
            [self isAccessAllowedWithParameters:sp acceptedPermissions:AZSSharedAccessPermissionsDelete
                    acceptedResourceTypes:AZSSharedAccessResourceTypesObject acceptedServices:AZSSharedAccessServicesBlob];
            [self checkPassageOfError:err expectToPass:shouldPass expectedHttpErrorCode:403 message:@"Attempt to Delete Blob"];
            completionHandler(err);
        }];
    };
    
    void (^deleteContainer)(id, void(^)(NSError *)) = ^void(id container, void(^completionHandler)(NSError *)) {
        [container deleteContainerWithCompletionHandler:^(NSError *err) {
            BOOL shouldPass = !((AZSCloudBlobContainer *) container).client.credentials.isSAS ||
                    [self isAccessAllowedWithParameters:sp acceptedPermissions:AZSSharedAccessPermissionsDelete
                    acceptedResourceTypes:AZSSharedAccessResourceTypesContainer acceptedServices:AZSSharedAccessServicesBlob];
            [self checkPassageOfError:err expectToPass:shouldPass expectedHttpErrorCode:403 message:@"Attempt to Delete Container"];
            completionHandler(err);
        }];
    };
    
    [self testAccountSasWithOperation:createContainer sasObject:sasContainer testObject:container completionHandler:^() {
        [self testAccountSasWithOperation:containerExists sasObject:sasContainer testObject:container completionHandler:^() {
            [self testAccountSasWithOperation:listContainer sasObject:sasClient testObject:client completionHandler:^() {
                AZSCloudBlockBlob *blob = [container blockBlobReferenceFromName:@"testblob"];
                AZSCloudBlockBlob *sasBlob = [sasContainer blockBlobReferenceFromName:blob.blobName];
                
                [self testAccountSasWithOperation:createBlob sasObject:sasBlob testObject:blob completionHandler:^() {
                    [self testAccountSasWithOperation:blobExists sasObject:sasBlob testObject:blob completionHandler:^() {
                        [self testAccountSasWithOperation:downloadBlob sasObject:sasBlob testObject:blob completionHandler:^() {
                        // TODO: Test append permissions once we support Append Blobs
                        
                            [self testAccountSasWithOperation:deleteBlob sasObject:sasBlob testObject:blob completionHandler:^() {
                                [self testAccountSasWithOperation:deleteContainer sasObject:sasContainer testObject:container completionHandler:completionHandler];
                            }];
                        }];
                    }];
                }];
            }];
        }];
    }];
}

- (void)testAccountSasWithOperation:(void(^)(id, void(^)(NSError *)))operation sasObject:(id)sasObject testObject:(id)testObject completionHandler:(void(^)())completionHandler
{
    // Attempt operation on sas object
    operation(sasObject, ^(NSError * err) {
        if (err) {
            // If operation failed, perform operation on shared key object
            operation(testObject, ^(NSError * err) {
                completionHandler();
            });
        }
        else {
            completionHandler();
        }
    });
}

- (BOOL) isAccessAllowedWithParameters:(AZSSharedAccessAccountParameters *)parameters acceptedPermissions:(AZSSharedAccessPermissions)acceptedPermissions acceptedResourceTypes:(AZSSharedAccessResourceTypes)acceptedResourceTypes acceptedServices:(AZSSharedAccessServices)acceptedServices
{
    const AZSSharedAccessPermissions permissionsValid = parameters.permissions & acceptedPermissions;
    const AZSSharedAccessResourceTypes resourceTypesValid = parameters.resourceTypes & acceptedResourceTypes;
    const AZSSharedAccessServices servicesValid = parameters.services & acceptedServices;
    return permissionsValid && resourceTypesValid && servicesValid;
}

@end