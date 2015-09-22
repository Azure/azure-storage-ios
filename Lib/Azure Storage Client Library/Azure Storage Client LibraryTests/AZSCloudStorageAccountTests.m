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
#import "AZSTestBase.h"
#import "Azure_Storage_Client_Library.h"

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
    AZSCloudStorageAccount *account = [AZSCloudStorageAccount accountFromConnectionString:connectionString];
    return [[[[account getBlobClient] containerReferenceFromName:@"container"].storageUri primaryUri].absoluteString isEqualToString:[desiredURL stringByAppendingString:@"/container"]];

}

- (void)testaccountFromConnectionString
{
    // Test connection string parsing.
    // TODO: Test connection string round-triping
    NSString *connectionString = @"AccountName=xaccount;AccountKey=key";
    NSString *desiredURL = @"https://xaccount.blob.core.windows.net";
    XCTAssertTrue([self validateCorrectBlobURLIsCreatedWithConnectionString:connectionString desiredURL:desiredURL], @"Incorrect URL");

    connectionString = @"AccountName=xaccount;AccountKey=key;DefaultEndpointsProtocol=https";
    desiredURL = @"https://xaccount.blob.core.windows.net";
    XCTAssertTrue([self validateCorrectBlobURLIsCreatedWithConnectionString:connectionString desiredURL:desiredURL], @"Incorrect URL");
    
    connectionString = @"AccountName=xaccount;AccountKey=key;DefaultEndpointsProtocol=http";
    desiredURL = @"http://xaccount.blob.core.windows.net";
    XCTAssertTrue([self validateCorrectBlobURLIsCreatedWithConnectionString:connectionString desiredURL:desiredURL], @"Incorrect URL");

    connectionString = @"AccountName=account;AccountKey=key;BlobEndpoint=http://sampleblobendpoint";
    desiredURL = @"http://sampleblobendpoint";
    XCTAssertTrue([self validateCorrectBlobURLIsCreatedWithConnectionString:connectionString desiredURL:desiredURL], @"Incorrect URL");
    
    connectionString = @"BlobEndpoint=http://sampleblobendpoint;AccountName=account;AccountKey=key";
    desiredURL = @"http://sampleblobendpoint";
    XCTAssertTrue([self validateCorrectBlobURLIsCreatedWithConnectionString:connectionString desiredURL:desiredURL], @"Incorrect URL");

    connectionString = @"BlobEndpoint=http://sampleblobendpoint;SharedAccessSignature=sampleSAStoken";
    desiredURL = @"http://sampleblobendpoint";
    XCTAssertTrue([self validateCorrectBlobURLIsCreatedWithConnectionString:connectionString desiredURL:desiredURL], @"Incorrect URL");

    connectionString = @"EndpointSuffix=test.endpoint.suffix;AccountName=account;AccountKey=key";
    desiredURL = @"https://account.blob.test.endpoint.suffix";
    XCTAssertTrue([self validateCorrectBlobURLIsCreatedWithConnectionString:connectionString desiredURL:desiredURL], @"Incorrect URL");

    connectionString = @"EndpointSuffix=test.endpoint.suffix;AccountName=account;AccountKey=key;DefaultEndpointsProtocol=http";
    desiredURL = @"http://account.blob.test.endpoint.suffix";
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
    
    AZSCloudStorageAccount *account = [[AZSCloudStorageAccount alloc] initWithCredentials:accountKeyCreds useHttps:YES];
    NSString *containerUri = [[[account getBlobClient] containerReferenceFromName:@"container"].storageUri.primaryUri absoluteString];
    XCTAssertTrue([containerUri isEqualToString:@"https://accountName.blob.core.windows.net/container"], @"Incorrect container URI created.");
    
    account = [[AZSCloudStorageAccount alloc] initWithCredentials:accountKeyCreds useHttps:NO];
    containerUri = [[[account getBlobClient] containerReferenceFromName:@"container"].storageUri.primaryUri absoluteString];
    XCTAssertTrue([containerUri isEqualToString:@"http://accountName.blob.core.windows.net/container"], @"Incorrect container URI created.");

    account = [[AZSCloudStorageAccount alloc] initWithCredentials:accountKeyCreds useHttps:YES endpointSuffix:@"sample.suffix"];
    containerUri = [[[account getBlobClient] containerReferenceFromName:@"container"].storageUri.primaryUri absoluteString];
    XCTAssertTrue([containerUri isEqualToString:@"https://accountName.blob.sample.suffix/container"], @"Incorrect container URI created.");

    account = [[AZSCloudStorageAccount alloc] initWithCredentials:accountKeyCreds useHttps:NO endpointSuffix:@"sample.suffix"];
    containerUri = [[[account getBlobClient] containerReferenceFromName:@"container"].storageUri.primaryUri absoluteString];
    XCTAssertTrue([containerUri isEqualToString:@"http://accountName.blob.sample.suffix/container"], @"Incorrect container URI created.");
    
    account = [[AZSCloudStorageAccount alloc] initWithCredentials:accountKeyCreds blobEndpoint:[[AZSStorageUri alloc] initWithPrimaryUri:[NSURL URLWithString:@"sample://full.blob.endpoint"]] tableEndpoint:nil queueEndpoint:nil fileEndpoint:nil];
    containerUri = [[[account getBlobClient] containerReferenceFromName:@"container"].storageUri.primaryUri absoluteString];
    XCTAssertTrue([containerUri isEqualToString:@"sample://full.blob.endpoint/container"], @"Incorrect container URI created.");
}
@end
