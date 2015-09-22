// -----------------------------------------------------------------------------------------
// <copyright file="AZSCloudStorageAccount.m" company="Microsoft">
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

#import "AZSCloudStorageAccount.h"
#import "AZSCloudBlobClient.h"
#import "AZSStorageUri.h"
#import "AZSStorageCredentials.h"

@interface AZSCloudStorageAccount()

@property (strong) AZSStorageCredentials *storageCredentials;
@property (strong) AZSStorageUri *blob_endpoint;
@property (strong, readonly) NSString *connectionString;
@property (strong) NSString *endpointSuffix;
@property BOOL explicitEndpoints;
@property BOOL useHttps;

@end

@implementation AZSCloudStorageAccount

@synthesize connectionString = _connectionString;

+ (AZSCloudStorageAccount *)accountFromConnectionString:(NSString *)connectionString
{
    // Parse the connection string into settings:
    NSArray *settings = [connectionString componentsSeparatedByString:@";"];
    NSMutableDictionary *settingsDictionary = [NSMutableDictionary dictionaryWithCapacity:10];
    for (NSString *setting in settings)
    {
        NSUInteger equals = [setting rangeOfString:@"="].location;
        NSString *key = [setting substringToIndex:equals];
        NSString *value = [setting substringFromIndex:equals + 1];
        settingsDictionary[key] = value;
    }
    
    AZSCloudStorageAccount *account = nil;
    NSString *endpointSuffix = nil;
    
    if (settingsDictionary[@"EndpointSuffix"])
    {
        endpointSuffix = settingsDictionary[@"EndpointSuffix"];
    }
    
    BOOL useHttps = ![((NSString *)settingsDictionary[@"DefaultEndpointsProtocol"]) isEqualToString:@"http"];
    
    AZSStorageCredentials *credentials = nil;
    if (settingsDictionary[@"AccountName"] && settingsDictionary[@"AccountKey"])
    {
        credentials = [[AZSStorageCredentials alloc] initWithAccountName:settingsDictionary[@"AccountName"] accountKey:settingsDictionary[@"AccountKey"]];
    }
    else if (settingsDictionary[@"SharedAccessSignature"])
    {
        credentials = [[AZSStorageCredentials alloc] initWithSASToken:settingsDictionary[@"SharedAccessSignature"]];
    }
    
    AZSStorageUri *explicitBlobEndpoint = settingsDictionary[@"BlobEndpoint"] ? ([[AZSStorageUri alloc] initWithPrimaryUri:[NSURL URLWithString:settingsDictionary[@"BlobEndpoint"]]]) : nil;
    
    if (explicitBlobEndpoint)
    {
        account = [[AZSCloudStorageAccount alloc] initWithCredentials:credentials blobEndpoint:explicitBlobEndpoint tableEndpoint:nil queueEndpoint:nil fileEndpoint:nil];
    }
    else if (endpointSuffix)
    {
        account = [[AZSCloudStorageAccount alloc] initWithCredentials:credentials useHttps:useHttps endpointSuffix:endpointSuffix];
    }
    else
    {
        account = [[AZSCloudStorageAccount alloc] initWithCredentials:credentials useHttps:useHttps];
    }
    
    account->_connectionString = connectionString;
    
    return account;
}

-(NSString *)connectionString
{
    if (!_connectionString)
    {
        NSString *credentialsString = nil;
        if (self.storageCredentials.accountKey)
        {
            credentialsString = [NSString stringWithFormat:@";AccountName=%@;AccountKey=%@", self.storageCredentials.accountName, self.storageCredentials.accountKey];
        }
        else if (self.storageCredentials.sasToken)
        {
            credentialsString = [NSString stringWithFormat:@";SharedAccessSignature=%@", self.storageCredentials.sasToken];
        }
        else
        {
            credentialsString = @"";
        }
        
        if (self.explicitEndpoints)
        {
            _connectionString = [NSString stringWithFormat:@"%@;BlobEndpoint=%@", credentialsString, self.blob_endpoint];
        }
        else if (self.endpointSuffix)
        {
            _connectionString = [NSString stringWithFormat:@"DefaultEndpointsProtocol=%@%@;EndpointSuffix=%@", (self.useHttps ? @"https" : @"http"), credentialsString, self.endpointSuffix];
        }
        else
        {
            _connectionString = [NSString stringWithFormat:@"DefaultEndpointsProtocol=%@%@", (self.useHttps ? @"https" : @"http"), credentialsString];
        }
    }
    
    return _connectionString;
}

-(AZSStorageUri *) constructDefaultEndpointWithScheme:(NSString *)scheme hostnamePrefix:(NSString *)hostnamePrefix endpointSuffix:(NSString *)endpointSuffix
{
    NSString *primaryUriString = [NSString stringWithFormat:@"%@://%@.%@.%@", scheme, self.storageCredentials.accountName, hostnamePrefix, endpointSuffix];
    NSString *secondaryUriString = [NSString stringWithFormat:@"%@://%@-secondary.%@.%@", scheme, self.storageCredentials.accountName, hostnamePrefix, endpointSuffix];
    
    return [[AZSStorageUri alloc] initWithPrimaryUri:[NSURL URLWithString:primaryUriString] secondaryUri:[NSURL URLWithString:secondaryUriString]];
}

-(instancetype) initWithCredentials:(AZSStorageCredentials *)storageCredentials blobEndpoint:(AZSStorageUri *)blobEndpoint tableEndpoint:(AZSStorageUri *)tableEndpoint queueEndpoint:(AZSStorageUri *)queueEndpoint fileEndpoint:(AZSStorageUri *)fileEndpoint
{
    self = [super init];
    if (self)
    {
        _storageCredentials = storageCredentials;
        _blob_endpoint = blobEndpoint;
        _explicitEndpoints = YES;
    }
    
    return self;
}

-(instancetype) initWithCredentials:(AZSStorageCredentials *)storageCredentials useHttps:(BOOL)useHttps
{
    self = [super init];
    if (self)
    {
        _storageCredentials = storageCredentials;
        _blob_endpoint = [self constructDefaultEndpointWithScheme:(useHttps ? @"https" : @"http") hostnamePrefix:@"blob" endpointSuffix:@"core.windows.net"];
        _explicitEndpoints = NO;
        _useHttps = useHttps;
    }
    
    return self;
}

-(instancetype) initWithCredentials:(AZSStorageCredentials *)storageCredentials useHttps:(BOOL)useHttps endpointSuffix:(NSString *)endpointSuffix 
{
    self = [super init];
    if (self)
    {
        _storageCredentials = storageCredentials;
        _endpointSuffix = endpointSuffix;
        _blob_endpoint = [self constructDefaultEndpointWithScheme:(useHttps ? @"https" : @"http") hostnamePrefix:@"blob" endpointSuffix:endpointSuffix];
        _explicitEndpoints = NO;
        _useHttps = useHttps;
    }
    
    return self;
}


-(AZSCloudBlobClient *) getBlobClient
{
    return [[AZSCloudBlobClient alloc] initWithStorageUri:self.blob_endpoint credentials:self.storageCredentials];
}

@end
