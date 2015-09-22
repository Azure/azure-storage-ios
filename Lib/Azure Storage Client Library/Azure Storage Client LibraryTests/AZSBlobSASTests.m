// -----------------------------------------------------------------------------------------
// <copyright file="AZSBlobSASTests.m" company="Microsoft">
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
#import <CommonCrypto/CommonHMAC.h>
#import "Azure_Storage_Client_Library.h"
#import "AZSBlobTestBase.h"

@interface AZSBlobSASTests : AZSBlobTestBase
@property NSString *containerName;
@property AZSCloudBlobContainer *blobContainer;
@end

@implementation AZSBlobSASTests

- (void)setUp
{
    [super setUp];
    self.containerName = [[NSString stringWithFormat:@"sampleioscontainer%@",[[[NSUUID UUID] UUIDString] stringByReplacingOccurrencesOfString:@"-" withString:@""]] lowercaseString];
    self.blobContainer = [self.blobClient containerReferenceFromName:self.containerName];
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    [self.blobContainer createContainerWithCompletionHandler:^(NSError * error) {
        XCTAssertNil(error, @"Error in test setup, in creating container.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
        dispatch_semaphore_signal(semaphore);
    }];
    
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);

    // Put setup code here; it will be run once, before the first test case.
}

- (void)tearDown
{
    // Put teardown code here; it will be run once, after the last test case.
    AZSCloudBlobContainer *blobContainer = [self.blobClient containerReferenceFromName:self.containerName];
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    @try {
        // Best-effort cleanup
        // TODO: Change to delete if exists once that's implemented.
        
        [blobContainer deleteContainerWithCompletionHandler:^(NSError * error) {
            dispatch_semaphore_signal(semaphore);
        }];
    }
    @catch (NSException *exception) {
        
    }
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);    [super tearDown];
}

- (NSString *) URLEncodedStringWithString:(NSString *)stringToConvert {
    NSMutableString * output = [NSMutableString string];
    const unsigned char * source = (const unsigned char *)[stringToConvert UTF8String];
    int sourceLen = strlen((const char *)source);
    for (int i = 0; i < sourceLen; ++i) {
        const unsigned char thisChar = source[i];
        if (thisChar == ' '){
            [output appendString:@"+"];
        } else if (thisChar == '.' || thisChar == '-' || thisChar == '_' || thisChar == '~' ||
                   (thisChar >= 'a' && thisChar <= 'z') ||
                   (thisChar >= 'A' && thisChar <= 'Z') ||
                   (thisChar >= '0' && thisChar <= '9')) {
            [output appendFormat:@"%c", thisChar];
        } else {
            [output appendFormat:@"%%%02X", thisChar];
        }
    }
    return output;
}

-(NSString *)getSASTokenWithSv:(NSString *)sv st:(NSString *)st se:(NSString *)se sr:(NSString *)sr sp:(NSString *)sp canonicalizedResource:(NSString *)canonicalizedResource
{
    NSString *stringToSign = [NSString stringWithFormat:@"%@\n%@\n%@\n%@\n\n%@\n\n\n\n\n", sp, st, se, canonicalizedResource, sv];
    
    NSString *stringToSignEncoded = [stringToSign stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    
    NSLog(@"String to sign = %@", stringToSign);
    NSLog(@"String to sign encoded = %@", stringToSignEncoded);

    
    const char* stringToSignChar = [stringToSign cStringUsingEncoding:NSUTF8StringEncoding];
    unsigned char cHMAC[CC_SHA256_DIGEST_LENGTH];
    CCHmac(kCCHmacAlgSHA256, [self.blobClient.credentials.accountKey bytes], [self.blobClient.credentials.accountKey length], stringToSignChar, strlen(stringToSignChar), cHMAC);
    
    NSString *sig = [[[NSData alloc] initWithBytes:cHMAC length:sizeof(cHMAC)] base64EncodedStringWithOptions:0];

    NSString *sig2 = [sig stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    
    //NSString *sig2 = [sig stringByReplacingOccurrencesOfString:@"=" withString:@"%61"];//[sig stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    
    NSString *sig3 = [self URLEncodedStringWithString:sig];
    
    NSLog(@"sig = %@", sig);
    NSLog(@"sig2 = %@", sig2);
    NSLog(@"sig3 = %@", sig3);
    
    return [NSString stringWithFormat:@"sv=%@&st=%@&se=%@&sr=%@&sp=%@&sig=%@", sv, st, se, sr, sp, sig];
}

- (void)testContainerSAS
{
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);

    NSString *sv = @"2015-02-21";
    NSString *st = @"2009-01-01";
    NSString *se = @"2100-01-01";
    NSString *sr = @"c";
    NSString *sp = @"rw";
    NSString *canonicalizedResource = [NSString stringWithFormat: @"/blob/%@/%@",self.blobClient.credentials.accountName, self.containerName];
    
    NSString *containerSASToken = [self getSASTokenWithSv:sv st:st se:se sr:sr sp:sp canonicalizedResource:canonicalizedResource];

    NSString *containerURL = self.blobContainer.storageUri.primaryUri.absoluteString;
    NSString *containerURLWithSAS = [NSString stringWithFormat:@"%@?%@", containerURL, containerSASToken];
    AZSCloudBlobContainer *blobContainer = [[AZSCloudBlobContainer alloc] initWithUrl:[NSURL URLWithString:containerURLWithSAS]];
    
    NSString *blobName = @"blobName";
    AZSCloudBlockBlob *blockBlob = [blobContainer blockBlobReferenceFromName:blobName];
    NSString *blobText = @"blobText";
    [blockBlob uploadFromText:blobText completionHandler:^(NSError *error) {
        XCTAssertNil(error, @"Error in uploading text to a blob.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
        [blockBlob downloadToTextWithCompletionHandler:^(NSError *error, NSString *finalText) {
            XCTAssertNil(error, @"Error in downloading text from a blob.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
            XCTAssertTrue([blobText compare:finalText options:NSLiteralSearch] == NSOrderedSame, @"Text strings do not match.");

            dispatch_semaphore_signal(semaphore);
        }];
    }];
    
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
}

- (void)testBlobSAS
{
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    NSString *blobName = @"blobName";

    NSString *sv = @"2015-02-21";
    NSString *st = @"2009-01-01";
    NSString *se = @"2100-01-01";
    NSString *sr = @"b";
    NSString *sp = @"rw";
    NSString *canonicalizedResource = [NSString stringWithFormat: @"/blob/%@/%@/%@",self.blobClient.credentials.accountName, self.containerName, blobName];
    
    NSString *blobSASToken = [self getSASTokenWithSv:sv st:st se:se sr:sr sp:sp canonicalizedResource:canonicalizedResource];
    
    AZSCloudBlockBlob *blob = [self.blobContainer blockBlobReferenceFromName:blobName];
    
    NSString *blobURL = blob.storageUri.primaryUri.absoluteString;
    NSString *blobURLWithSAS = [NSString stringWithFormat:@"%@?%@", blobURL, blobSASToken];
    
    AZSCloudBlockBlob *blockBlobWithSAS = [[AZSCloudBlockBlob alloc] initWithUrl:[NSURL URLWithString:blobURLWithSAS]];
    NSString *blobText = @"blobText";
    [blockBlobWithSAS uploadFromText:blobText completionHandler:^(NSError *error) {
        XCTAssertNil(error, @"Error in uploading text to a blob.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
        [blockBlobWithSAS downloadToTextWithCompletionHandler:^(NSError *error, NSString *finalText) {
            XCTAssertNil(error, @"Error in downloading text from a blob.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
            XCTAssertTrue([blobText compare:finalText options:NSLiteralSearch] == NSOrderedSame, @"Text strings do not match.");
            
            dispatch_semaphore_signal(semaphore);
        }];
    }];
    
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
}

@end
