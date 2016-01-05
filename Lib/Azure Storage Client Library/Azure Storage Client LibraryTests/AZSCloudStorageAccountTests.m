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
#import "Azure_Storage_Client_Library.h"
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
    return !error && [[[[account getBlobClient] containerReferenceFromName:AZSCContainer].storageUri primaryUri].absoluteString isEqualToString:[desiredURL stringByAppendingString:@"/container"]];
}

- (void)testaccountFromConnectionString
{
    // Test connection string parsing.
    // TODO: Test connection string round-triping
    NSString *connectionString = [NSString stringWithFormat:AZSCSharedTemplateCredentials, AZSCEmptyString, @"xaccount", @"key"];
    NSString *desiredURL = [NSString stringWithFormat:AZSCSharedTemplatePrimaryUri, AZSCHttps, @"xaccount", AZSCBlob, AZSCDefaultSuffix];
    XCTAssertTrue([self validateCorrectBlobURLIsCreatedWithConnectionString:connectionString desiredURL:desiredURL], @"Incorrect URL");

    connectionString = [NSString stringWithFormat:@"%@%@", connectionString, [NSString stringWithFormat:AZSCSharedTemplateDefaultEndpoint, AZSCHttps, AZSCEmptyString]];
    XCTAssertTrue([self validateCorrectBlobURLIsCreatedWithConnectionString:connectionString desiredURL:desiredURL], @"Incorrect URL");
    
    connectionString = [NSString stringWithFormat:@"%@;%@", connectionString, [NSString stringWithFormat:AZSCSharedTemplateDefaultEndpoint, AZSCHttp, AZSCEmptyString]];
    desiredURL = [NSString stringWithFormat:AZSCSharedTemplatePrimaryUri, AZSCHttp, @"xaccount", AZSCBlob, AZSCDefaultSuffix];
    XCTAssertTrue([self validateCorrectBlobURLIsCreatedWithConnectionString:connectionString desiredURL:desiredURL], @"Incorrect URL");

    desiredURL = @"http://sampleblobendpoint";
    connectionString = [NSString stringWithFormat:AZSCSharedTemplateBlobEndpoint, [NSString stringWithFormat:AZSCSharedTemplateCredentials, AZSCEmptyString, @"account", @"key"], desiredURL];
    XCTAssertTrue([self validateCorrectBlobURLIsCreatedWithConnectionString:connectionString desiredURL:desiredURL], @"Incorrect URL");
    
    connectionString = [NSString stringWithFormat:@"%@;%@;%@", [connectionString componentsSeparatedByString:@";"][2], [connectionString componentsSeparatedByString:@";"][0], [connectionString componentsSeparatedByString:@";"][1]];
    XCTAssertTrue([self validateCorrectBlobURLIsCreatedWithConnectionString:connectionString desiredURL:desiredURL], @"Incorrect URL");

    connectionString = [[[NSString stringWithFormat:AZSCSharedTemplateBlobEndpoint, AZSCEmptyString, desiredURL] stringByAppendingString:[NSString stringWithFormat:AZSCSasTemplateCredentials, @"sampleSAStoken"]] substringFromIndex:1];
    XCTAssertTrue([self validateCorrectBlobURLIsCreatedWithConnectionString:connectionString desiredURL:desiredURL], @"Incorrect URL");

    connectionString = [NSString stringWithFormat:@"%@;%@", @"EndpointSuffix=test.endpoint.suffix", [NSString stringWithFormat:AZSCSharedTemplateCredentials, AZSCEmptyString, @"account", @"key"]];
    desiredURL = [NSString stringWithFormat:AZSCSharedTemplatePrimaryUri, AZSCHttps, @"account", AZSCBlob, @"test.endpoint.suffix"];
    XCTAssertTrue([self validateCorrectBlobURLIsCreatedWithConnectionString:connectionString desiredURL:desiredURL], @"Incorrect URL");

    connectionString = [[connectionString stringByAppendingString:@";"] stringByAppendingString:[NSString stringWithFormat:AZSCSharedTemplateDefaultEndpoint, AZSCHttp, AZSCEmptyString]];
    desiredURL = [NSString stringWithFormat:AZSCSharedTemplatePrimaryUri, AZSCHttp, @"account", AZSCBlob, @"test.endpoint.suffix"];;
    XCTAssertTrue([self validateCorrectBlobURLIsCreatedWithConnectionString:connectionString desiredURL:desiredURL], @"Incorrect URL");
}

-(void)testInitWithCredentials
{
    // Test creating directly from a credential object.
    // Test all initializers.
    
    NSString *accountName = @"accountName";
    NSString *accountKey = @"accountKey";
    
    AZSStorageCredentials *accountKeyCreds = [[AZSStorageCredentials alloc] initWithAccountName:accountName accountKey:accountKey];
    //AZSStorageCredentials *sasCreds = [[AZSStorageCredentials alloc] initWithSASToken:@"sasToken"];
    
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
}

@end