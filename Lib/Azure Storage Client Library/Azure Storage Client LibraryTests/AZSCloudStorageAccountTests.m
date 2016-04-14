// -----------------------------------------------------------------------------------------
// <copyright file="AZSCloudStorageAccountTests.m" company="Microsoft">
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
#import "AZSClient.h"
#import "AZSConstants.h"
#import "AZSTestBase.h"

@interface AZSCloudStorageAccountTests : AZSTestBase

@end

@implementation AZSCloudStorageAccountTests

- (void)setUp
{
    [super setUp];
    // Put setup code here; it will be run once, before the first test case.
}

- (void)tearDown
{
    // Put teardown code here; it will be run once, after the last test case.
    [super tearDown];
}

-(BOOL)validateCorrectBlobURLIsCreatedWithConnectionString:(NSString *)connectionString desiredURL:(NSString *)desiredURL
{
    NSError *error = nil;
    AZSCloudStorageAccount *account = [AZSCloudStorageAccount accountFromConnectionString:connectionString error:&error];
    XCTAssertNil(error);
    XCTAssertEqualObjects([[[account getBlobClient] containerReferenceFromName:AZSCContainer].storageUri primaryUri].absoluteString, [desiredURL stringByAppendingString:@"/container"], @"Incorrect URL");
}

- (void)testaccountFromConnectionString
{
    // Test connection string parsing.
    // TODO: Test connection string round-triping
    
    // "AccountName=xaccount;AccountKey=key"
    NSString *connectionString = [NSString stringWithFormat:AZSCSharedTemplateCredentials, AZSCEmptyString, @"xaccount", @"key"];
    NSString *desiredURL = [NSString stringWithFormat:AZSCSharedTemplatePrimaryUri, AZSCHttps, @"xaccount", AZSCBlob, AZSCDefaultSuffix];
    [self validateCorrectBlobURLIsCreatedWithConnectionString:connectionString desiredURL:desiredURL];

    // "AccountName=xaccount;AccountKey=keyDefaultEndpointsProtocol=https"
    connectionString = [NSString stringWithFormat:@"%@%@", connectionString, [NSString stringWithFormat:AZSCSharedTemplateDefaultEndpoint, AZSCHttps, AZSCEmptyString]];
    [self validateCorrectBlobURLIsCreatedWithConnectionString:connectionString desiredURL:desiredURL];
    
    // "AccountName=xaccount;AccountKey=keyDefaultEndpointsProtocol=https;DefaultEndpointsProtocol=http"
    connectionString = [NSString stringWithFormat:@"%@;%@", connectionString, [NSString stringWithFormat:AZSCSharedTemplateDefaultEndpoint, AZSCHttp, AZSCEmptyString]];
    desiredURL = [NSString stringWithFormat:AZSCSharedTemplatePrimaryUri, AZSCHttp, @"xaccount", AZSCBlob, AZSCDefaultSuffix];
    [self validateCorrectBlobURLIsCreatedWithConnectionString:connectionString desiredURL:desiredURL];

    // "AccountName=account;AccountKey=key;BlobEndpoint=http://sampleblobendpoint"
    desiredURL = @"http://sampleblobendpoint";
    connectionString = [NSString stringWithFormat:AZSCSharedTemplateBlobEndpoint, [NSString stringWithFormat:AZSCSharedTemplateCredentials, AZSCEmptyString, @"account", @"key"], desiredURL];
    [self validateCorrectBlobURLIsCreatedWithConnectionString:connectionString desiredURL:desiredURL];
    
    // "BlobEndpoint=http://sampleblobendpoint;AccountName=account;AccountKey=key"
    connectionString = [NSString stringWithFormat:@"%@=%@;%@;%@", AZSCSettingsBlobEndpoint, desiredURL, [connectionString componentsSeparatedByString:@";"][0], [connectionString componentsSeparatedByString:@";"][1]];
    [self validateCorrectBlobURLIsCreatedWithConnectionString:connectionString desiredURL:desiredURL];
    
    // "BlobEndpoint=http://127.0.0.1:10000/devstoraccount1;AccountName=account;AccountKey=key"
    connectionString = [NSString stringWithFormat:@"%@=%@;%@;%@", AZSCSettingsBlobEndpoint, AZSCEmulatorUrl, [connectionString componentsSeparatedByString:@";"][1], [connectionString componentsSeparatedByString:@";"][2]];
    [self validateCorrectBlobURLIsCreatedWithConnectionString:connectionString desiredURL:AZSCEmulatorUrl];

    // "BlobEndpoint=http://sampleblobendpoint;SharedAccessSignature=sampleSAStoken"
    connectionString = [[[NSString stringWithFormat:AZSCSharedTemplateBlobEndpoint, AZSCEmptyString, desiredURL] stringByAppendingString:[NSString stringWithFormat:AZSCSasTemplateCredentials, @"sampleSAStoken"]] substringFromIndex:1];
    [self validateCorrectBlobURLIsCreatedWithConnectionString:connectionString desiredURL:desiredURL];
    
    // "BlobEndpoint=http://127.0.0.1:10000/devstoraccount1;SharedAccessSignature=sampleSAStoken"
    connectionString = [[[NSString stringWithFormat:AZSCSharedTemplateBlobEndpoint, AZSCEmptyString, AZSCEmulatorUrl] stringByAppendingString:[NSString stringWithFormat:AZSCSasTemplateCredentials, @"sampleSAStoken"]] substringFromIndex:1];
    [self validateCorrectBlobURLIsCreatedWithConnectionString:connectionString desiredURL:AZSCEmulatorUrl];

    // "EndpointSuffix=test.endpoint.suffix;AccountName=account;AccountKey=key"
    connectionString = [NSString stringWithFormat:@"%@;%@", @"EndpointSuffix=test.endpoint.suffix", [NSString stringWithFormat:AZSCSharedTemplateCredentials, AZSCEmptyString, @"account", @"key"]];
    desiredURL = [NSString stringWithFormat:AZSCSharedTemplatePrimaryUri, AZSCHttps, @"account", AZSCBlob, @"test.endpoint.suffix"];
    [self validateCorrectBlobURLIsCreatedWithConnectionString:connectionString desiredURL:desiredURL];

    // "EndpointSuffix=test.endpoint.suffix;AccountName=account;AccountKey=key;DefaultEndpointsProtocol=http"
    connectionString = [[connectionString stringByAppendingString:@";"] stringByAppendingString:[NSString stringWithFormat:AZSCSharedTemplateDefaultEndpoint, AZSCHttp, AZSCEmptyString]];
    desiredURL = [NSString stringWithFormat:AZSCSharedTemplatePrimaryUri, AZSCHttp, @"account", AZSCBlob, @"test.endpoint.suffix"];
    [self validateCorrectBlobURLIsCreatedWithConnectionString:connectionString desiredURL:desiredURL];
    
    // "UseDevelopmentStorage=true"
    connectionString = [NSString stringWithFormat:@"%@=%@", AZSCSettingsEmulator, AZSCTrue];
    [self validateCorrectBlobURLIsCreatedWithConnectionString:connectionString desiredURL:AZSCEmulatorUrl];
}

-(void)testInitWithCredentials
{
    // Test creating directly from a credential object.
    // Test all initializers.
    
    NSString *accountName = @"accountName";
    NSString *accountKey = @"accountKey";
    
    AZSStorageCredentials *accountKeyCreds = [[AZSStorageCredentials alloc] initWithAccountName:accountName accountKey:accountKey];
    // AZSStorageCredentials *sasCreds = [[AZSStorageCredentials alloc] initWithSASToken:@"sasToken"];
    
    NSError *error = nil;
    AZSCloudStorageAccount *account = [[AZSCloudStorageAccount alloc] initWithCredentials:accountKeyCreds useHttps:YES error:&error];
    XCTAssertNil(error);
    
    NSString *containerUri = [[[account getBlobClient] containerReferenceFromName:AZSCContainer].storageUri.primaryUri absoluteString];
    XCTAssertTrue([containerUri isEqualToString:@"https://accountName.blob.core.windows.net/container"], @"Incorrect container URI created.");
    
    account = [[AZSCloudStorageAccount alloc] initWithCredentials:accountKeyCreds useHttps:NO error:&error];
    XCTAssertNil(error);
    
    containerUri = [[[account getBlobClient] containerReferenceFromName:AZSCContainer].storageUri.primaryUri absoluteString];
    XCTAssertTrue([containerUri isEqualToString:@"http://accountName.blob.core.windows.net/container"], @"Incorrect container URI created.");

    account = [[AZSCloudStorageAccount alloc] initWithCredentials:accountKeyCreds useHttps:YES endpointSuffix:@"sample.suffix" error:&error];
    XCTAssertNil(error);
    
    containerUri = [[[account getBlobClient] containerReferenceFromName:AZSCContainer].storageUri.primaryUri absoluteString];
    XCTAssertTrue([containerUri isEqualToString:@"https://accountName.blob.sample.suffix/container"], @"Incorrect container URI created.");

    account = [[AZSCloudStorageAccount alloc] initWithCredentials:accountKeyCreds useHttps:NO endpointSuffix:@"sample.suffix" error:&error];
    XCTAssertNil(error);
    
    containerUri = [[[account getBlobClient] containerReferenceFromName:AZSCContainer].storageUri.primaryUri absoluteString];
    XCTAssertTrue([containerUri isEqualToString:@"http://accountName.blob.sample.suffix/container"], @"Incorrect container URI created.");
    
    account = [[AZSCloudStorageAccount alloc] initWithCredentials:accountKeyCreds blobEndpoint:[[AZSStorageUri alloc] initWithPrimaryUri:[NSURL URLWithString:@"sample://full.blob.endpoint"]] tableEndpoint:nil queueEndpoint:nil fileEndpoint:nil error:&error];
    XCTAssertNil(error);
    
    containerUri = [[[account getBlobClient] containerReferenceFromName:AZSCContainer].storageUri.primaryUri absoluteString];
    XCTAssertTrue([containerUri isEqualToString:@"sample://full.blob.endpoint/container"], @"Incorrect container URI created.");
    
    AZSStorageUri *uri = [[AZSStorageUri alloc] initWithPrimaryUri:[NSURL URLWithString:AZSCEmulatorUrl]];
    account = [[AZSCloudStorageAccount alloc] initWithCredentials:accountKeyCreds blobEndpoint:uri tableEndpoint:nil queueEndpoint:nil fileEndpoint:nil error:&error];
    XCTAssertNil(error);
    
    containerUri = [[[account getBlobClient] containerReferenceFromName:AZSCContainer].storageUri.primaryUri absoluteString];
    NSString *desiredUri = [NSString stringWithFormat:@"%@/%@", AZSCEmulatorUrl, AZSCContainer];
    XCTAssertTrue([containerUri isEqualToString:desiredUri], @"Incorrect container URI created.");
    
    AZSCloudBlobContainer *container = [[AZSCloudBlobContainer alloc] initWithStorageUri:uri credentials:accountKeyCreds error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(container);
}

@end