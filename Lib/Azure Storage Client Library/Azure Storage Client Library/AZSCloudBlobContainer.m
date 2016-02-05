// -----------------------------------------------------------------------------------------
// <copyright file="AZSCloudBlobContainer.m" company="Microsoft">
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

#import <CommonCrypto/CommonDigest.h>
#import "AZSConstants.h"
#import "AZSCloudBlobContainer.h"
#import "AZSCloudBlobClient.h"
#import "AZSStorageCommand.h"
#import "AZSExecutor.h"
#import "AZSBlobRequestFactory.h"
#import "AZSOperationContext.h"
#import "AZSEnums.h"
#import "AZSStorageCredentials.h"
#import "AZSStorageUri.h"
#import "AZSBlobRequestOptions.h"
#import "AZSAccessCondition.h"
#import "AZSCloudBlockBlob.h"
#import "AZSBlobResponseParser.h"
#import "AZSCloudBlob.h"
#import "AZSRequestResult.h"
#import "AZSContinuationToken.h"
#import "AZSResultSegment.h"
#import "AZSBlobContainerProperties.h"
#import "AZSBlobRequestXML.h"
#import "AZSSharedAccessBlobParameters.h"
#import "AZSSharedAccessSignatureHelper.h"
#import "AZSResponseParser.h"
#import "AZSUriQueryBuilder.h"
#import "AZSUtil.h"
#import "AZSNavigationUtil.h"
#import "AZSErrors.h"

@interface AZSCloudBlobContainer()

-(instancetype)init AZS_DESIGNATED_INITIALIZER;

@end

@implementation AZSCloudBlobContainer

-(instancetype)init
{
    return nil;
}

- (instancetype)initWithUrl:(NSURL *)containerAbsoluteUrl error:(NSError **)error
{
    return [self initWithUrl:containerAbsoluteUrl credentials:nil error:error];
}

- (instancetype)initWithUrl:(NSURL *)containerAbsoluteUrl credentials:(AZSStorageCredentials *)credentials error:(NSError **)error
{
    return [self initWithStorageUri:[[AZSStorageUri alloc] initWithPrimaryUri:containerAbsoluteUrl] credentials:credentials error:error];
}

- (instancetype)initWithStorageUri:(AZSStorageUri *)containerAbsoluteUrl error:(NSError **)error
{
    return [self initWithStorageUri:containerAbsoluteUrl credentials:nil error:error];
}

- (instancetype)initWithStorageUri:(AZSStorageUri *)containerAbsoluteUrl credentials:(AZSStorageCredentials *)credentials error:(NSError **)error
{
    self = [super init];
    if (self)
    {
        NSMutableArray *parseQueryResults = [AZSNavigationUtil parseBlobQueryAndVerifyWithStorageUri:containerAbsoluteUrl];
        
        if (([credentials isSAS] || [credentials isSharedKey]) && (![parseQueryResults[1] isKindOfClass:[NSNull class]] && ([parseQueryResults[1] isSAS] || [parseQueryResults[1] isSharedKey]))) {
            *error = [NSError errorWithDomain:AZSErrorDomain code:AZSEInvalidArgument userInfo:nil];
            [[AZSUtil operationlessContext] logAtLevel:AZSLogLevelError withMessage:@"Multiple credentials provided."];
            return nil;
        }
        
        credentials = (credentials ?: ([parseQueryResults[1] isKindOfClass:[NSNull class]] ? nil : parseQueryResults[1]));
        
        _storageUri = ([parseQueryResults[0] isKindOfClass:[NSNull class]] ? nil : parseQueryResults[0]);
        _client = [[AZSCloudBlobClient alloc] initWithStorageUri: [AZSNavigationUtil getServiceClientBaseAddressWithStorageUri:_storageUri usePathStyle:[AZSUtil usePathStyleAddressing:[containerAbsoluteUrl primaryUri]] error:error] credentials:credentials];
        if (*error) {
            return nil;
        }
        
        _name = [AZSNavigationUtil getContainerNameWithContainerAddress:_storageUri.primaryUri isPathStyle:[AZSUtil usePathStyleAddressing:_storageUri.primaryUri]];
        _properties = [[AZSBlobContainerProperties alloc] init];
        _metadata = [[NSMutableDictionary alloc] init];
    }
    
    return self;
}

-(instancetype) initWithName:(NSString *)containerName client:(AZSCloudBlobClient *)client
{
    self = [super init];
    if (self)
    {
        self.name = containerName;
        self.client = client;
        self.storageUri = [AZSStorageUri appendToStorageUri:client.storageUri pathToAppend:containerName];
        self.metadata = [[NSMutableDictionary alloc] init];
        self.properties = [[AZSBlobContainerProperties alloc] init];
    }
    
    return self;
}

- (void) createContainerWithCompletionHandler:(void (^)(NSError*))completionHandler
{
    return [self createContainerWithAccessType:AZSContainerPublicAccessTypeOff requestOptions:nil operationContext:nil completionHandler:completionHandler];
}

- (void)createContainerWithAccessType:(AZSContainerPublicAccessType )accessType requestOptions:(AZSBlobRequestOptions *)requestOptions operationContext:(AZSOperationContext *)operationContext completionHandler:(void (^)(NSError*))completionHandler;
{
    if (!operationContext)
    {
        operationContext = [[AZSOperationContext alloc] init];
    }
    AZSBlobRequestOptions *modifiedOptions = [[AZSBlobRequestOptions copyOptions:requestOptions] applyDefaultsFromOptions:self.client.defaultRequestOptions];
    AZSStorageCommand * command = [[AZSStorageCommand alloc] initWithStorageCredentials:self.client.credentials storageUri:self.storageUri operationContext:operationContext];
    
    [command setBuildRequest:^ NSMutableURLRequest * (NSURLComponents *urlComponents, NSTimeInterval timeout, AZSOperationContext *operationContext)
     {
         return [AZSBlobRequestFactory createContainerWithAccessType:accessType cloudMetadata:nil urlComponents:urlComponents timeout:timeout operationContext:operationContext];
     }];

    [command setAuthenticationHandler:self.client.authenticationHandler];
    
    [command setPreProcessResponse:^id(NSHTTPURLResponse * urlResponse, AZSRequestResult * requestResult, AZSOperationContext * operationContext) {
        [self updateEtagAndLastModifiedWithResponse:urlResponse];
        return [AZSResponseParser preprocessResponseWithResponse:urlResponse requestResult:requestResult operationContext:operationContext];
    }];
    
    [AZSExecutor ExecuteWithStorageCommand:command requestOptions:modifiedOptions operationContext:operationContext completionHandler:^(NSError *error, id result)
     {
         completionHandler(error);
     }];
    return;
}

- (void) deleteContainerWithCompletionHandler:(void (^)(NSError*))completionHandler
{
    return [self deleteContainerWithAccessCondition:nil requestOptions:nil operationContext:nil completionHandler:completionHandler];
}

// TODO: Test access condition
- (void) deleteContainerWithAccessCondition:(AZSAccessCondition *)accessCondition requestOptions:(AZSBlobRequestOptions *)requestOptions operationContext:(AZSOperationContext *)operationContext completionHandler:(void (^)(NSError*))completionHandler;
{
    if (!operationContext)
    {
        operationContext = [[AZSOperationContext alloc] init];
    }
    AZSBlobRequestOptions *modifiedOptions = [[AZSBlobRequestOptions copyOptions:requestOptions] applyDefaultsFromOptions:self.client.defaultRequestOptions];
    AZSStorageCommand * command = [[AZSStorageCommand alloc] initWithStorageCredentials:self.client.credentials storageUri:self.storageUri operationContext:operationContext];
    
    [command setBuildRequest:^ NSMutableURLRequest * (NSURLComponents *urlComponents, NSTimeInterval timeout, AZSOperationContext *operationContext)
     {
         return [AZSBlobRequestFactory deleteContainerWithAccessCondition:accessCondition urlComponents:urlComponents timeout:timeout operationContext:operationContext];
     }];
    
    [command setAuthenticationHandler:self.client.authenticationHandler];
    
    [command setPreProcessResponse:^id(NSHTTPURLResponse * urlResponse, AZSRequestResult * requestResult, AZSOperationContext * operationContext) {
        return [AZSResponseParser preprocessResponseWithResponse:urlResponse requestResult:requestResult operationContext:operationContext];
    }];
        
    [AZSExecutor ExecuteWithStorageCommand:command requestOptions:modifiedOptions operationContext:operationContext completionHandler:^(NSError *error, id result)
     {
         completionHandler(error);
     }];
    return;
}

- (void)listBlobsSegmentedWithContinuationToken:(AZSContinuationToken *)token prefix:(NSString *)prefix useFlatBlobListing:(BOOL)useFlatBlobListing blobListingDetails:(AZSBlobListingDetails)blobListingDetails maxResults:(NSInteger)maxResults completionHandler:(void (^)(NSError * , AZSBlobResultSegment *))completionHandler
{
    return [self listBlobsSegmentedWithContinuationToken:token prefix:prefix useFlatBlobListing:useFlatBlobListing blobListingDetails:blobListingDetails maxResults:maxResults accessCondition:nil requestOptions:nil operationContext:nil completionHandler:completionHandler];
}

- (void)listBlobsSegmentedWithContinuationToken:(AZSContinuationToken *)token prefix:(NSString *)prefix useFlatBlobListing:(BOOL)useFlatBlobListing blobListingDetails:(AZSBlobListingDetails)blobListingDetails maxResults:(NSInteger)maxResults accessCondition:(AZSAccessCondition *)accessCondition requestOptions:(AZSBlobRequestOptions *)requestOptions operationContext:(AZSOperationContext *)operationContext completionHandler:(void (^)(NSError * , AZSBlobResultSegment *))completionHandler
{
    if (!operationContext)
    {
        operationContext = [[AZSOperationContext alloc] init];
    }
    AZSBlobRequestOptions *modifiedOptions = [[AZSBlobRequestOptions copyOptions:requestOptions] applyDefaultsFromOptions:self.client.defaultRequestOptions];
    AZSStorageCommand * command = [[AZSStorageCommand alloc] initWithStorageCredentials:self.client.credentials storageUri:self.storageUri operationContext:operationContext];
    
    [command setBuildRequest:^ NSMutableURLRequest * (NSURLComponents *urlComponents, NSTimeInterval timeout, AZSOperationContext *operationContext)
     {
         return [AZSBlobRequestFactory listBlobsWithPrefix:prefix delimiter:nil blobListingDetails:blobListingDetails maxResults:maxResults continuationToken:token urlComponents:urlComponents timeout:timeout operationContext:operationContext];
     }];
    
    [command setAuthenticationHandler:self.client.authenticationHandler];
    
    [command setPreProcessResponse:^id(NSHTTPURLResponse * urlResponse, AZSRequestResult * requestResult, AZSOperationContext * operationContext) {
        return [AZSResponseParser preprocessResponseWithResponse:urlResponse requestResult:requestResult operationContext:operationContext];
    }];
    
    [command setPostProcessResponse:^id(NSHTTPURLResponse *urlResponse, AZSRequestResult *requestResult, NSOutputStream *outputStream, AZSOperationContext *operationContext, NSError **error) {
        AZSListBlobsResponse *listBlobsResponse = [AZSListBlobsResponse parseListBlobsResponseWithData:[outputStream propertyForKey:NSStreamDataWrittenToMemoryStreamKey] operationContext:operationContext error:error];
        
        if (*error)
        {
            return nil;
        }

        NSMutableArray *results = [NSMutableArray arrayWithCapacity:[listBlobsResponse.blobListItems count]];
        for (AZSBlobListItem *blobListItem in listBlobsResponse.blobListItems)
        {
            AZSCloudBlob *temp = [[AZSCloudBlob alloc] initWithContainer:self name:blobListItem.name snapshotTime:blobListItem.snapshotTime];
            temp.metadata = blobListItem.metadata;
            temp.properties = blobListItem.properties;
            temp.blobCopyState = blobListItem.blobCopyState;
            
            [results addObject:temp];
        }
        
        AZSContinuationToken *continuationToken = nil;
        if (listBlobsResponse.nextMarker != nil && listBlobsResponse.nextMarker.length > 0)
        {
            continuationToken = [AZSContinuationToken tokenFromString:listBlobsResponse.nextMarker withLocation:requestResult.targetLocation];
        }
        return [AZSBlobResultSegment segmentWithBlobs:results directories:nil continuationToken:continuationToken];
    }];
    
    [AZSExecutor ExecuteWithStorageCommand:command requestOptions:modifiedOptions operationContext:operationContext completionHandler:completionHandler];
    return;
}

- (void)uploadMetadataWithCompletionHandler:(void (^)(NSError *))completionHandler
{
    return [self uploadMetadataWithAccessCondition:nil requestOptions:nil operationContext:nil completionHandler:completionHandler];
}

- (void)uploadMetadataWithAccessCondition:(AZSAccessCondition *)accessCondition requestOptions:(AZSBlobRequestOptions *)requestOptions operationContext:(AZSOperationContext *)operationContext completionHandler:(void (^)(NSError*))completionHandler
{
    if (!operationContext)
    {
        operationContext = [[AZSOperationContext alloc] init];
    }
    AZSBlobRequestOptions *modifiedOptions = [[AZSBlobRequestOptions copyOptions:requestOptions] applyDefaultsFromOptions:self.client.defaultRequestOptions];
    AZSStorageCommand * command = [[AZSStorageCommand alloc] initWithStorageCredentials:self.client.credentials storageUri:self.storageUri operationContext:operationContext];
    
    [command setBuildRequest:^ NSMutableURLRequest * (NSURLComponents *urlComponents, NSTimeInterval timeout, AZSOperationContext *operationContext)
     {
         return [AZSBlobRequestFactory uploadContainerMetadataWithCloudMetadata:self.metadata accessCondition:nil urlComponents:urlComponents timeout:timeout operationContext:operationContext];
     }];
    
    [command setAuthenticationHandler:self.client.authenticationHandler];
    
    [command setPreProcessResponse:^id(NSHTTPURLResponse * urlResponse, AZSRequestResult * requestResult, AZSOperationContext * operationContext) {
        [self updateEtagAndLastModifiedWithResponse:urlResponse];
        return [AZSResponseParser preprocessResponseWithResponse:urlResponse requestResult:requestResult operationContext:operationContext];
    }];
    
    [AZSExecutor ExecuteWithStorageCommand:command requestOptions:modifiedOptions operationContext:operationContext completionHandler:^(NSError *error, id result)
     {
         completionHandler(error);
     }];
    return;
}

-(void)uploadPermissions:(NSMutableDictionary *)permissions completionHandler:(void (^)(NSError *))completionHandler
{
    [self uploadPermissions:permissions publicAccess:AZSContainerPublicAccessTypeOff accessCondition:nil requestOptions:nil operationContext:nil completionHandler:completionHandler];
}

- (void)uploadPermissions:(NSMutableDictionary *)permissions publicAccess:(AZSContainerPublicAccessType)publicAccess accessCondition:(AZSAccessCondition *)accessCondition requestOptions:(AZSBlobRequestOptions *)requestOptions operationContext:(AZSOperationContext *)operationContext completionHandler:(void (^)(NSError *))completionHandler
{
    if (!operationContext) {
        operationContext = [[AZSOperationContext alloc] init];
    }
    
    AZSBlobRequestOptions *modifiedOptions = [[AZSBlobRequestOptions copyOptions:requestOptions] applyDefaultsFromOptions:self.client.defaultRequestOptions];
    AZSStorageCommand * command = [[AZSStorageCommand alloc] initWithStorageCredentials:self.client.credentials storageUri:self.storageUri operationContext:operationContext];

    NSError *error = nil;
    NSData *sourceData = [[AZSBlobRequestXML createStoredPoliciesXMLFromPermissions:permissions operationContext:operationContext error:&error] dataUsingEncoding:NSUTF8StringEncoding];
    if (error) {
        completionHandler(error);
        return;
    }
    
    [command setSource:sourceData];
    [command setBuildRequest:^ NSMutableURLRequest * (NSURLComponents *urlComponents, NSTimeInterval timeout, AZSOperationContext *operationContext) {
        return [AZSBlobRequestFactory uploadContainerPermissionsWithLength:sourceData.length urlComponents:urlComponents options:requestOptions accessCondition:accessCondition publicAccess:publicAccess timeout:timeout operationContext:operationContext];
    }];
    
    [command setAuthenticationHandler:self.client.authenticationHandler];
    
    [command setPreProcessResponse:^ NSError * (NSHTTPURLResponse *urlResponse, AZSRequestResult *requestResult, AZSOperationContext *operationContext) {
        [self updateEtagAndLastModifiedWithResponse:urlResponse];
        return [AZSResponseParser preprocessResponseWithResponse:urlResponse requestResult:requestResult operationContext:operationContext];
    }];
    
    [AZSExecutor ExecuteWithStorageCommand:command requestOptions:modifiedOptions operationContext:operationContext completionHandler:^(NSError *error, id result) {
        completionHandler(error);
    }];
}

-(void)downloadAttributesWithCompletionHandler:(void (^)(NSError *))completionHandler
{
    return [self downloadAttributesWithAccessCondition:nil requestOptions:nil operationContext:nil completionHandler:completionHandler];
}

- (void)downloadAttributesWithAccessCondition:(AZSAccessCondition *)accessCondition requestOptions:(AZSBlobRequestOptions *)requestOptions operationContext:(AZSOperationContext *)operationContext completionHandler:(void (^)(NSError*))completionHandler
{
    if (!operationContext)
    {
        operationContext = [[AZSOperationContext alloc] init];
    }
    AZSBlobRequestOptions *modifiedOptions = [[AZSBlobRequestOptions copyOptions:requestOptions] applyDefaultsFromOptions:self.client.defaultRequestOptions];
    AZSStorageCommand * command = [[AZSStorageCommand alloc] initWithStorageCredentials:self.client.credentials storageUri:self.storageUri operationContext:operationContext];
    
    [command setBuildRequest:^ NSMutableURLRequest * (NSURLComponents *urlComponents, NSTimeInterval timeout, AZSOperationContext *operationContext)
     {
         return [AZSBlobRequestFactory downloadContainerAttributesWithAccessCondition:accessCondition urlComponents:urlComponents timeout:timeout operationContext:operationContext];
     }];
    
    [command setAuthenticationHandler:self.client.authenticationHandler];
    
    [command setPreProcessResponse:^id(NSHTTPURLResponse * urlResponse, AZSRequestResult * requestResult, AZSOperationContext * operationContext) {
        [self updateEtagAndLastModifiedWithResponse:urlResponse];
        NSError *error = [AZSResponseParser preprocessResponseWithResponse:urlResponse requestResult:requestResult operationContext:operationContext];
        if (error)
        {
            return  error;
        }
        
        self.metadata = [AZSBlobResponseParser getMetadataWithResponse:urlResponse];
        self.properties = [AZSBlobResponseParser getContainerPropertiesWithResponse:urlResponse operationContext:operationContext error:&error];
        
        if (error)
        {
            return error;
        }

        return nil;
    }];
    
    [AZSExecutor ExecuteWithStorageCommand:command requestOptions:modifiedOptions operationContext:operationContext completionHandler:^(NSError *error, id result)
     {
         completionHandler(error);
     }];
}

- (void)downloadPermissionsWithCompletionHandler:(void (^)(NSError* __AZSNullable, NSMutableDictionary *, AZSContainerPublicAccessType))completionHandler
{
    [self downloadPermissionsWithAccessCondition:nil requestOptions:nil operationContext:nil completionHandler:completionHandler];
}

- (void)downloadPermissionsWithAccessCondition:(AZSNullable AZSAccessCondition *)accessCondition requestOptions:(AZSNullable AZSBlobRequestOptions *)requestOptions operationContext:(AZSNullable AZSOperationContext *)operationContext completionHandler:(void (^)(NSError* __AZSNullable, NSMutableDictionary *, AZSContainerPublicAccessType))completionHandler
{
    if (!operationContext) {
        operationContext = [[AZSOperationContext alloc] init];
    }
    AZSBlobRequestOptions *modifiedOptions = [[AZSBlobRequestOptions copyOptions:requestOptions] applyDefaultsFromOptions:self.client.defaultRequestOptions];
    AZSStorageCommand * command = [[AZSStorageCommand alloc] initWithStorageCredentials:self.client.credentials storageUri:self.storageUri operationContext:operationContext];
    
    [command setBuildRequest:^ NSMutableURLRequest * (NSURLComponents *urlComponents, NSTimeInterval timeout, AZSOperationContext *operationContext) {
         return [AZSBlobRequestFactory downloadContainerPermissionsWithAccessCondition:accessCondition urlComponents:urlComponents timeout:timeout operationContext:operationContext];
     }];
    
    [command setAuthenticationHandler:self.client.authenticationHandler];
    
    [command setPreProcessResponse:^id(NSHTTPURLResponse * urlResponse, AZSRequestResult * requestResult, AZSOperationContext * operationContext) {
        [self updateEtagAndLastModifiedWithResponse:urlResponse];
        return [AZSResponseParser preprocessResponseWithResponse:urlResponse requestResult:requestResult operationContext:operationContext];
    }];
    
    __block AZSContainerPublicAccessType publicAccess = AZSContainerPublicAccessTypeOff;
    [command setPostProcessResponse:^id(NSHTTPURLResponse * urlResponse, AZSRequestResult * requestResult, NSOutputStream *outputStream, AZSOperationContext * operationContext, NSError ** error) {
        if (*error) {
            return *error;
        }

        publicAccess = [AZSDownloadContainerPermissions createContainerPermissionsWithResponse:urlResponse operationContext:operationContext error:error];
        NSMutableDictionary *policies = [AZSDownloadContainerPermissions parseDownloadContainerPermissionsResponseWithData:[outputStream propertyForKey:NSStreamDataWrittenToMemoryStreamKey] operationContext:operationContext error:error].storedPolicies;
        
        return (*error) ?: policies;
    }];
    
    [AZSExecutor ExecuteWithStorageCommand:command requestOptions:modifiedOptions operationContext:operationContext completionHandler:^(NSError *error, id result) {
         completionHandler(error, result, publicAccess);
     }];
}

- (void)acquireLeaseWithLeaseTime:(NSNumber *)leaseTime proposedLeaseId:(NSString *)proposedLeaseId completionHandler:(void (^)(NSError*, NSString *))completionHandler
{
    [self acquireLeaseWithLeaseTime:leaseTime proposedLeaseId:proposedLeaseId accessCondition:nil requestOptions:nil operationContext:nil completionHandler:completionHandler];
}

- (void)acquireLeaseWithLeaseTime:(NSNumber *)leaseTime proposedLeaseId:(NSString *)proposedLeaseId accessCondition:(AZSAccessCondition *)accessCondition requestOptions:(AZSBlobRequestOptions *)requestOptions operationContext:(AZSOperationContext *)operationContext completionHandler:(void (^)(NSError*, NSString *))completionHandler
{
    if (!operationContext)
    {
        operationContext = [[AZSOperationContext alloc] init];
    }
    AZSBlobRequestOptions *modifiedOptions = [[AZSBlobRequestOptions copyOptions:requestOptions] applyDefaultsFromOptions:self.client.defaultRequestOptions];
    AZSStorageCommand * command = [[AZSStorageCommand alloc] initWithStorageCredentials:self.client.credentials storageUri:self.storageUri operationContext:operationContext];
    
    [command setBuildRequest:^ NSMutableURLRequest * (NSURLComponents *urlComponents, NSTimeInterval timeout, AZSOperationContext *operationContext)
     {
         NSNumber *leaseDuration = @(-1);
         if (leaseTime)
         {
             leaseDuration = [NSNumber numberWithLong:[leaseTime integerValue]];
         }
         
         return [AZSBlobRequestFactory leaseContainerWithLeaseAction:AZSLeaseActionAcquire proposedLeaseId:proposedLeaseId leaseDuration:leaseDuration leaseBreakPeriod:nil accessCondition:accessCondition urlComponents:urlComponents timeout:timeout operationContext:operationContext];
     }];
    
    [command setAuthenticationHandler:self.client.authenticationHandler];
    
    [command setPreProcessResponse:^id(NSHTTPURLResponse * urlResponse, AZSRequestResult * requestResult, AZSOperationContext * operationContext) {
        [self updateEtagAndLastModifiedWithResponse:urlResponse];
        return [AZSResponseParser preprocessResponseWithResponse:urlResponse requestResult:requestResult operationContext:operationContext];
    }];
    
    [command setPostProcessResponse:^id(NSHTTPURLResponse *urlResponse, AZSRequestResult *requestResult, NSOutputStream *outputStream, AZSOperationContext *operationContext, NSError **error) {
        return urlResponse.allHeaderFields[AZSCHeaderLeaseId];
    }];
    
    [AZSExecutor ExecuteWithStorageCommand:command requestOptions:modifiedOptions operationContext:operationContext completionHandler:^(NSError *error, NSString *leaseId)
     {
         completionHandler(error, leaseId);
     }];
    return;
}

- (void)breakLeaseWithBreakPeriod:(NSNumber *) breakPeriod completionHandler:(void (^)(NSError*, NSNumber*))completionHandler
{
    [self breakLeaseWithBreakPeriod:breakPeriod accessCondition:nil requestOptions:nil operationContext:nil completionHandler:completionHandler];
}

- (void)breakLeaseWithBreakPeriod:(NSNumber *) breakPeriod accessCondition:(AZSAccessCondition *)accessCondition requestOptions:(AZSBlobRequestOptions *)requestOptions operationContext:(AZSOperationContext *)operationContext completionHandler:(void (^)(NSError*, NSNumber*))completionHandler
{
    if (!operationContext)
    {
        operationContext = [[AZSOperationContext alloc] init];
    }
    AZSBlobRequestOptions *modifiedOptions = [[AZSBlobRequestOptions copyOptions:requestOptions] applyDefaultsFromOptions:self.client.defaultRequestOptions];
    AZSStorageCommand * command = [[AZSStorageCommand alloc] initWithStorageCredentials:self.client.credentials storageUri:self.storageUri operationContext:operationContext];
    
    [command setBuildRequest:^ NSMutableURLRequest * (NSURLComponents *urlComponents, NSTimeInterval timeout, AZSOperationContext *operationContext)
     {
         NSNumber* breakSeconds = nil;
         if (breakPeriod)
         {
             breakSeconds = [NSNumber numberWithLong:[breakPeriod integerValue]];
         }
         
         return [AZSBlobRequestFactory leaseContainerWithLeaseAction:AZSLeaseActionBreak proposedLeaseId:nil leaseDuration:nil leaseBreakPeriod:breakSeconds accessCondition:accessCondition urlComponents:urlComponents timeout:timeout operationContext:operationContext];
     }];
    
    [command setAuthenticationHandler:self.client.authenticationHandler];
    
    [command setPreProcessResponse:^id(NSHTTPURLResponse * urlResponse, AZSRequestResult * requestResult, AZSOperationContext * operationContext) {
        [self updateEtagAndLastModifiedWithResponse:urlResponse];
        return [AZSResponseParser preprocessResponseWithResponse:urlResponse requestResult:requestResult operationContext:operationContext];
    }];
    
    [command setPostProcessResponse:^id(NSHTTPURLResponse *urlResponse, AZSRequestResult *requestResult, NSOutputStream *outputStream, AZSOperationContext *operationContext, NSError **error) {
        
        NSNumber *remainingLeaseTime = [AZSBlobResponseParser getRemainingLeaseTimeWithResponse:urlResponse];
        return remainingLeaseTime;
    }];
    
    [AZSExecutor ExecuteWithStorageCommand:command requestOptions:modifiedOptions operationContext:operationContext completionHandler:^(NSError *error, NSNumber *remainingSeconds)
     {
         completionHandler(error, remainingSeconds);
     }];
    return;
}

- (void)changeLeaseWithProposedLeaseId:(NSString *) proposedLeaseId accessCondition:(AZSAccessCondition *)accessCondition completionHandler:(void (^)(NSError*, NSString*))completionHandler
{
    [self changeLeaseWithProposedLeaseId:proposedLeaseId accessCondition:accessCondition requestOptions:nil operationContext:nil completionHandler:completionHandler];
}

- (void)changeLeaseWithProposedLeaseId:(NSString *) proposedLeaseId accessCondition:(AZSAccessCondition *)accessCondition requestOptions:(AZSBlobRequestOptions *)requestOptions operationContext:(AZSOperationContext *)operationContext completionHandler:(void (^)(NSError*, NSString*))completionHandler
{
    if (!operationContext)
    {
        operationContext = [[AZSOperationContext alloc] init];
    }
    AZSBlobRequestOptions *modifiedOptions = [[AZSBlobRequestOptions copyOptions:requestOptions] applyDefaultsFromOptions:self.client.defaultRequestOptions];
    AZSStorageCommand * command = [[AZSStorageCommand alloc] initWithStorageCredentials:self.client.credentials storageUri:self.storageUri operationContext:operationContext];
    
    if (!accessCondition || !(accessCondition.leaseId) || !proposedLeaseId)
    {
        NSError *error = [NSError errorWithDomain:AZSErrorDomain code:AZSEInvalidArgument userInfo:@{NSLocalizedDescriptionKey:@"Cannot renew a lease without providing a lease ID."}];
        completionHandler(error, nil);
        return;
    }
    
    [command setBuildRequest:^ NSMutableURLRequest * (NSURLComponents *urlComponents, NSTimeInterval timeout, AZSOperationContext *operationContext)
     {
         return [AZSBlobRequestFactory leaseContainerWithLeaseAction:AZSLeaseActionChange proposedLeaseId:proposedLeaseId leaseDuration:nil leaseBreakPeriod:nil accessCondition:accessCondition urlComponents:urlComponents timeout:timeout operationContext:operationContext];
     }];
    
    [command setAuthenticationHandler:self.client.authenticationHandler];
    
    [command setPreProcessResponse:^id(NSHTTPURLResponse * urlResponse, AZSRequestResult * requestResult, AZSOperationContext * operationContext) {
        [self updateEtagAndLastModifiedWithResponse:urlResponse];
        return [AZSResponseParser preprocessResponseWithResponse:urlResponse requestResult:requestResult operationContext:operationContext];
    }];
    
    [command setPostProcessResponse:^id(NSHTTPURLResponse *urlResponse, AZSRequestResult *requestResult, NSOutputStream *outputStream, AZSOperationContext *operationContext, NSError *__autoreleasing *error) {
        return urlResponse.allHeaderFields[AZSCHeaderLeaseId];
    }];
    
    [AZSExecutor ExecuteWithStorageCommand:command requestOptions:modifiedOptions operationContext:operationContext completionHandler:^(NSError *error, NSString *leaseId)
     {
         completionHandler(error, leaseId);
     }];
    return;
}

- (void)releaseLeaseWithAccessCondition:(AZSAccessCondition *)accessCondition completionHandler:(void (^)(NSError*))completionHandler
{
    [self releaseLeaseWithAccessCondition:accessCondition requestOptions:nil operationContext:nil completionHandler:completionHandler];
}

- (void)releaseLeaseWithAccessCondition:(AZSAccessCondition *)accessCondition requestOptions:(AZSBlobRequestOptions *)requestOptions operationContext:(AZSOperationContext *)operationContext completionHandler:(void (^)(NSError*))completionHandler
{
    if (!operationContext)
    {
        operationContext = [[AZSOperationContext alloc] init];
    }
    AZSBlobRequestOptions *modifiedOptions = [[AZSBlobRequestOptions copyOptions:requestOptions] applyDefaultsFromOptions:self.client.defaultRequestOptions];
    AZSStorageCommand * command = [[AZSStorageCommand alloc] initWithStorageCredentials:self.client.credentials storageUri:self.storageUri operationContext:operationContext];
    
    if (!accessCondition || !(accessCondition.leaseId))
    {
        NSError *error = [NSError errorWithDomain:AZSErrorDomain code:AZSEInvalidArgument userInfo:@{NSLocalizedDescriptionKey:@"Cannot renew a lease without providing a lease ID."}];
        completionHandler(error);
        return;
    }
    
    [command setBuildRequest:^ NSMutableURLRequest * (NSURLComponents *urlComponents, NSTimeInterval timeout, AZSOperationContext *operationContext)
     {
         return [AZSBlobRequestFactory leaseContainerWithLeaseAction:AZSLeaseActionRelease proposedLeaseId:nil leaseDuration:nil leaseBreakPeriod:nil accessCondition:accessCondition urlComponents:urlComponents timeout:timeout operationContext:operationContext];
     }];
    
    [command setAuthenticationHandler:self.client.authenticationHandler];
    
    [command setPreProcessResponse:^id(NSHTTPURLResponse * urlResponse, AZSRequestResult * requestResult, AZSOperationContext * operationContext) {
        [self updateEtagAndLastModifiedWithResponse:urlResponse];
        return [AZSResponseParser preprocessResponseWithResponse:urlResponse requestResult:requestResult operationContext:operationContext];
    }];
    
    [command setPostProcessResponse:^id(NSHTTPURLResponse *urlResponse, AZSRequestResult *requestResult, NSOutputStream *outputStream, AZSOperationContext *operationContext, NSError *__autoreleasing *error) {
        return urlResponse.allHeaderFields[AZSCHeaderLeaseId];
    }];

    [AZSExecutor ExecuteWithStorageCommand:command requestOptions:modifiedOptions operationContext:operationContext completionHandler:^(NSError *error, id result)
     {
         completionHandler(error);
     }];
    return;
}

- (void)renewLeaseWithAccessCondition:(AZSAccessCondition *)accessCondition completionHandler:(void (^)(NSError*))completionHandler
{
    [self renewLeaseWithAccessCondition:accessCondition requestOptions:nil operationContext:nil completionHandler:completionHandler];
}

- (void)renewLeaseWithAccessCondition:(AZSAccessCondition *)accessCondition requestOptions:(AZSBlobRequestOptions *)requestOptions operationContext:(AZSOperationContext *)operationContext completionHandler:(void (^)(NSError*))completionHandler
{
    if (!operationContext)
    {
        operationContext = [[AZSOperationContext alloc] init];
    }
    AZSBlobRequestOptions *modifiedOptions = [[AZSBlobRequestOptions copyOptions:requestOptions] applyDefaultsFromOptions:self.client.defaultRequestOptions];
    AZSStorageCommand * command = [[AZSStorageCommand alloc] initWithStorageCredentials:self.client.credentials storageUri:self.storageUri operationContext:operationContext];
    
    if (!accessCondition || !(accessCondition.leaseId))
    {
        NSError *error = [NSError errorWithDomain:AZSErrorDomain code:AZSEInvalidArgument userInfo:@{NSLocalizedDescriptionKey:@"Cannot renew a lease without providing a lease ID."}];
        completionHandler(error);
        return;
    }
    
    [command setBuildRequest:^ NSMutableURLRequest * (NSURLComponents *urlComponents, NSTimeInterval timeout, AZSOperationContext *operationContext)
     {
         return [AZSBlobRequestFactory leaseContainerWithLeaseAction:AZSLeaseActionRenew proposedLeaseId:nil leaseDuration:nil leaseBreakPeriod:nil accessCondition:accessCondition urlComponents:urlComponents timeout:timeout operationContext:operationContext];
     }];
    
    [command setAuthenticationHandler:self.client.authenticationHandler];
    
    [command setPreProcessResponse:^id(NSHTTPURLResponse * urlResponse, AZSRequestResult * requestResult, AZSOperationContext * operationContext) {
        [self updateEtagAndLastModifiedWithResponse:urlResponse];
        return [AZSResponseParser preprocessResponseWithResponse:urlResponse requestResult:requestResult operationContext:operationContext];
    }];
    
    [AZSExecutor ExecuteWithStorageCommand:command requestOptions:modifiedOptions operationContext:operationContext completionHandler:^(NSError *error, id result)
     {
         completionHandler(error);
     }];
    return;
}

-(void)updateEtagAndLastModifiedWithResponse:(NSHTTPURLResponse *)response
{
    NSString *parsedEtag = response.allHeaderFields[AZSCXmlETag];
    NSDate *parsedLastModified = [[AZSUtil dateFormatterWithRFCFormat] dateFromString:response.allHeaderFields[AZSCXmlLastModified]];
    
    if (parsedEtag)
    {
        self.properties.eTag = parsedEtag;
    }
    
    if (parsedLastModified) {
        self.properties.lastModified = parsedLastModified;
    }
}

- (AZSCloudBlockBlob *)blockBlobReferenceFromName:(NSString *)blobName
{
    AZSCloudBlockBlob *blockBlob = [[AZSCloudBlockBlob alloc] initWithContainer:self name:blobName];
    return blockBlob;
}

-(void)existsWithCompletionHandler:(void (^)(NSError *, BOOL))completionHandler
{
    [self existsWithAccessCondition:nil requestOptions:nil operationContext:nil completionHandler:completionHandler];
}

-(void)existsWithAccessCondition:(AZSAccessCondition *)accessCondition requestOptions:(AZSBlobRequestOptions *)requestOptions operationContext:(AZSOperationContext *)operationContext completionHandler:(void (^)(NSError *, BOOL))completionHandler
{
    [self downloadAttributesWithAccessCondition:accessCondition requestOptions:requestOptions operationContext:operationContext completionHandler:^(NSError *error) {
        if (error)
        {
            if ([error.domain isEqualToString:AZSErrorDomain] && (error.code == AZSEServerError) && error.userInfo[AZSCHttpStatusCode] && (((NSNumber *)error.userInfo[AZSCHttpStatusCode]).intValue == 404))
            {
                completionHandler(nil, NO);
            }
            else
            {
                completionHandler(error, NO);
            }
        }
        else
        {
            completionHandler(nil, YES);
        }
    }];
}

-(void)createContainerIfNotExistsWithCompletionHandler:(void (^)(NSError *, BOOL))completionHandler
{
    [self createContainerIfNotExistsWithAccessType:AZSContainerPublicAccessTypeOff requestOptions:nil operationContext:nil completionHandler:completionHandler];
}

-(void)createContainerIfNotExistsWithAccessType:(AZSContainerPublicAccessType)accessType requestOptions:(AZSBlobRequestOptions *)requestOptions operationContext:(AZSOperationContext *)operationContext completionHandler:(void (^)(NSError *, BOOL))completionHandler
{
    [self existsWithAccessCondition:nil requestOptions:requestOptions operationContext:operationContext completionHandler:^(NSError *error, BOOL exists) {
        if (error)
        {
            completionHandler(error, NO);
        }
        else
        {
            if (exists)
            {
                completionHandler(nil, NO);
            }
            else
            {
                [self createContainerWithAccessType:accessType requestOptions:requestOptions operationContext:operationContext completionHandler:^(NSError *error) {
                    if (error)
                    {
                        completionHandler(error, NO);
                    }
                    else
                    {
                        completionHandler(nil, YES);
                    }
                }];
            }
        }
    }];
}

-(void)deleteContainerIfExistsWithCompletionHandler:(void (^)(NSError *, BOOL))completionHandler
{
    [self deleteContainerIfExistsWithAccessCondition:nil requestOptions:nil operationContext:nil completionHandler:completionHandler];
}

-(void)deleteContainerIfExistsWithAccessCondition:(AZSAccessCondition *)accessCondition requestOptions:(AZSBlobRequestOptions *)requestOptions operationContext:(AZSOperationContext *)operationContext completionHandler:(void (^)(NSError *, BOOL))completionHandler
{
    [self existsWithAccessCondition:accessCondition requestOptions:requestOptions operationContext:operationContext completionHandler:^(NSError *error, BOOL exists) {
        if (error)
        {
            completionHandler(error, NO);
        }
        else
        {
            if (exists)
            {
                [self deleteContainerWithAccessCondition:accessCondition requestOptions:requestOptions operationContext:operationContext completionHandler:^(NSError *error) {
                    if (error)
                    {
                        completionHandler(error, NO);
                    }
                    else
                    {
                        completionHandler(nil, YES);
                    }
                }];
            }
            else
            {
                completionHandler(nil, NO);
            }
        }
    }];
}

-(NSString *) createSharedAccessSignatureWithParameters:(AZSSharedAccessBlobParameters*)parameters error:(NSError **)error
{
    if (![self.client.credentials isSharedKey]) {
        *error = [NSError errorWithDomain:AZSErrorDomain code:AZSEInvalidArgument userInfo:nil];
        [[AZSUtil operationlessContext] logAtLevel:AZSLogLevelError withMessage:@"Cannot create SAS without account key."];
        return nil;
    }
    
    NSString *signature = [AZSSharedAccessSignatureHelper sharedAccessSignatureHashForBlobWithParameters:parameters resourceName:[self createSharedAccessCanonicalName] client:self.client error:error];
    
    if (!signature) {
        // An error occurred.
        return nil;
    }
    
    const AZSUriQueryBuilder *builder = [AZSSharedAccessSignatureHelper sharedAccessSignatureForBlobWithParameters:parameters resourceType:AZSCSasPermissionsCreate signature:signature error:error];
    return [builder builderAsString];
}

- (NSString *)createSharedAccessCanonicalName
{
    return [NSString stringWithFormat:AZSCSasTemplateContainerCanonicalName, AZSCBlob, self.client.credentials.accountName, self.name];
}

@end