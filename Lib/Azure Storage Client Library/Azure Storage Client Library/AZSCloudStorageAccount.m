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

#import "AZSEnums.h"
#import "AZSErrors.h"
#import "AZSConstants.h"
#import "AZSCloudStorageAccount.h"
#import "AZSCloudBlobClient.h"
#import "AZSOperationContext.h"
#import "AZSSharedAccessSignatureHelper.h"
#import "AZSStorageUri.h"
#import "AZSStorageCredentials.h"
#import "AZSUriQueryBuilder.h"
#import "AZSUtil.h"

@interface AZSCloudStorageAccount()

@property (strong) AZSStorageCredentials *storageCredentials;
@property (strong) AZSStorageUri *blob_endpoint;
@property (strong, readonly) NSString *connectionString;
@property (strong) NSString *endpointSuffix;
@property BOOL explicitEndpoints;
@property BOOL useHttps;

-(instancetype)init AZS_DESIGNATED_INITIALIZER;

@end

@implementation AZSCloudStorageAccount

@synthesize connectionString = _connectionString;

+ (AZSCloudStorageAccount *)accountFromConnectionString:(NSString *)connectionString error:(NSError *__autoreleasing *)error
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
    
    if (settingsDictionary[AZSCSettingsEndpointSuffix])
    {
        endpointSuffix = settingsDictionary[AZSCSettingsEndpointSuffix];
    }
    
    BOOL useHttps = ![((NSString *)settingsDictionary[AZSCSettingsEndpointsProtocol]) isEqualToString:AZSCHttp];
    
    AZSStorageCredentials *credentials = nil;
    if (settingsDictionary[AZSCSettingsAccountName] && settingsDictionary[AZSCSettingsAccountKey])
    {
        credentials = [[AZSStorageCredentials alloc] initWithAccountName:settingsDictionary[AZSCSettingsAccountName] accountKey:settingsDictionary[AZSCSettingsAccountKey]];
    }
    else if (settingsDictionary[AZSCSettingsSas])
    {
        credentials = [[AZSStorageCredentials alloc] initWithSASToken:settingsDictionary[AZSCSettingsSas]];
    }
    
    AZSStorageUri *explicitBlobEndpoint = settingsDictionary[AZSCSettingsBlobEndpoint] ? ([[AZSStorageUri alloc] initWithPrimaryUri:[NSURL URLWithString:settingsDictionary[AZSCSettingsBlobEndpoint]]]) : nil;
    
    if (explicitBlobEndpoint)
    {
        account = [[AZSCloudStorageAccount alloc] initWithCredentials:credentials blobEndpoint:explicitBlobEndpoint tableEndpoint:nil queueEndpoint:nil fileEndpoint:nil error:error];
    }
    else if (endpointSuffix)
    {
        account = [[AZSCloudStorageAccount alloc] initWithCredentials:credentials useHttps:useHttps endpointSuffix:endpointSuffix error:error];
    }
    else
    {
        account = [[AZSCloudStorageAccount alloc] initWithCredentials:credentials useHttps:useHttps error:error];
    }
    
    if (*error) {
        // An error occurred.
        return nil;
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
            credentialsString = [NSString stringWithFormat:AZSCSharedTemplateCredentials, @";", self.storageCredentials.accountName, self.storageCredentials.accountKey];
        }
        else if (self.storageCredentials.sasToken)
        {
            credentialsString = [NSString stringWithFormat:AZSCSasTemplateCredentials, self.storageCredentials.sasToken];
        }
        else
        {
            credentialsString = AZSCEmptyString;
        }
        
        if (self.explicitEndpoints)
        {
            _connectionString = [NSString stringWithFormat:AZSCSharedTemplateBlobEndpoint, credentialsString, self.blob_endpoint];
        }
        else if (self.endpointSuffix)
        {
            _connectionString = [NSString stringWithFormat:AZSCSharedTemplateEndpointSuffix, (self.useHttps ? AZSCHttps : AZSCHttp), credentialsString, self.endpointSuffix];
        }
        else
        {
            _connectionString = [NSString stringWithFormat:AZSCSharedTemplateDefaultEndpoint, (self.useHttps ? AZSCHttps : AZSCHttp), credentialsString];
        }
    }
    
    return _connectionString;
}

-(AZSStorageUri *) constructDefaultEndpointWithScheme:(NSString *)scheme hostnamePrefix:(NSString *)hostnamePrefix endpointSuffix:(NSString *)endpointSuffix
{
    NSString *primaryUriString = [NSString stringWithFormat:AZSCSharedTemplatePrimaryUri, scheme, self.storageCredentials.accountName, hostnamePrefix, endpointSuffix];
    NSString *secondaryUriString = [NSString stringWithFormat:AZSCSharedTemplateSecondaryUri, scheme, self.storageCredentials.accountName, hostnamePrefix, endpointSuffix];
    
    return [[AZSStorageUri alloc] initWithPrimaryUri:[NSURL URLWithString:primaryUriString] secondaryUri:[NSURL URLWithString:secondaryUriString]];
}

-(instancetype) init
{
    return nil;
}

-(instancetype) initWithCredentials:(AZSStorageCredentials *)storageCredentials blobEndpoint:(AZSStorageUri *)blobEndpoint tableEndpoint:(AZSStorageUri *)tableEndpoint queueEndpoint:(AZSStorageUri *)queueEndpoint fileEndpoint:(AZSStorageUri *)fileEndpoint error:(NSError *__autoreleasing *)error
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

-(instancetype) initWithCredentials:(AZSStorageCredentials *)storageCredentials useHttps:(BOOL)useHttps error:(NSError *__autoreleasing *)error
{
    self = [self initWithCredentials:storageCredentials useHttps:useHttps endpointSuffix:AZSCDefaultSuffix error:error];
    
    return self;
}

-(instancetype) initWithCredentials:(AZSStorageCredentials *)storageCredentials useHttps:(BOOL)useHttps endpointSuffix:(NSString *)endpointSuffix error:(NSError *__autoreleasing *)error
{
    self = [super init];
    
    if ([storageCredentials isSAS] && !storageCredentials.accountName) {
        *error = [NSError errorWithDomain:AZSErrorDomain code:AZSEInvalidArgument userInfo:nil];
        [[AZSUtil operationlessContext] logAtLevel:AZSLogLevelError withMessage:@"Storage credentials are missing an account name."];
        return nil;
    }
    
    if (self)
    {
        _storageCredentials = storageCredentials;
        _endpointSuffix = [endpointSuffix isEqualToString:AZSCDefaultSuffix] ? nil : endpointSuffix;
        _blob_endpoint = [self constructDefaultEndpointWithScheme:(useHttps ? AZSCHttps : AZSCHttp) hostnamePrefix:AZSCBlob endpointSuffix:endpointSuffix];
        _explicitEndpoints = NO;
        _useHttps = useHttps;
    }
    
    return self;
}

-(AZSCloudBlobClient *) getBlobClient
{
    return [[AZSCloudBlobClient alloc] initWithStorageUri:self.blob_endpoint credentials:self.storageCredentials];
}

- (NSString *) createSharedAccessSignatureWithParameters:(AZSSharedAccessAccountParameters *)parameters error:(NSError **)error
{
    if (![self.storageCredentials isSharedKey]) {
        *error = [NSError errorWithDomain:AZSErrorDomain code:AZSEInvalidArgument userInfo:nil];
        [[AZSUtil operationlessContext] logAtLevel:AZSLogLevelError withMessage:@"Cannot create SAS without account key."];
        return nil;
    }
    
    NSString *signature = [AZSSharedAccessSignatureHelper sharedAccessSignatureHashForAccountWithParameters:parameters accountName:self.storageCredentials.accountName credentials:self.storageCredentials error:error];
    if (!signature) {
        // An error occurred.
        return nil;
    }

    const AZSUriQueryBuilder *builder = [AZSSharedAccessSignatureHelper sharedAccessSignatureForAccountWithParameters:parameters signature:signature error:error];
    return [builder builderAsString];
}

@end