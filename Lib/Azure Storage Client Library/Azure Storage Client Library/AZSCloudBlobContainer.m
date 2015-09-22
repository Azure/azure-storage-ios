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

#import "AZSCloudBlobContainer.h"
#import "AZSCloudBlobClient.h"
#import "AZSStorageCommand.h"
#import "AZSExecutor.h"
#import "AZSBlobRequestFactory.h"
#import "AZSOperationContext.h"
#import "AZSEnums.h"
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
#import "AZSResponseParser.h"
#import "AZSUtil.h"
#import "AZSNavigationUtil.h"
#import "AZSErrors.h"

@implementation AZSCloudBlobContainer

- (instancetype)initWithUrl:(NSURL *)containerAbsoluteUrl
{
    return [self initWithUrl:containerAbsoluteUrl credentials:nil];
}

- (instancetype)initWithUrl:(NSURL *)containerAbsoluteUrl credentials:(AZSStorageCredentials *)credentials
{
    return [self initWithStorageUri:[[AZSStorageUri alloc] initWithPrimaryUri:containerAbsoluteUrl] credentials:credentials];
}

- (instancetype)initWithStorageUri:(AZSStorageUri *)containerAbsoluteUrl
{
    return [self initWithStorageUri:containerAbsoluteUrl credentials:nil];
}

- (instancetype)initWithStorageUri:(AZSStorageUri *)containerAbsoluteUrl credentials:(AZSStorageCredentials *)credentials
{
    self = [super init];
    
    if (self)
    {
        [self parseQueryAndVerifyWithUri:containerAbsoluteUrl credentials:credentials];
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

// TODO: Test container public access type once we have GetContainerAcl implemented.
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

-(void)fetchAttributesWithCompletionHandler:(void (^)(NSError *))completionHandler
{
    return [self fetchAttributesWithAccessCondition:nil requestOptions:nil operationContext:nil completionHandler:completionHandler];
}

- (void)fetchAttributesWithAccessCondition:(AZSAccessCondition *)accessCondition requestOptions:(AZSBlobRequestOptions *)requestOptions operationContext:(AZSOperationContext *)operationContext completionHandler:(void (^)(NSError*))completionHandler
{
    if (!operationContext)
    {
        operationContext = [[AZSOperationContext alloc] init];
    }
    AZSBlobRequestOptions *modifiedOptions = [[AZSBlobRequestOptions copyOptions:requestOptions] applyDefaultsFromOptions:self.client.defaultRequestOptions];
    AZSStorageCommand * command = [[AZSStorageCommand alloc] initWithStorageCredentials:self.client.credentials storageUri:self.storageUri operationContext:operationContext];
    
    [command setBuildRequest:^ NSMutableURLRequest * (NSURLComponents *urlComponents, NSTimeInterval timeout, AZSOperationContext *operationContext)
     {
         return [AZSBlobRequestFactory fetchContainerAttributesWithAccessCondition:nil urlComponents:urlComponents timeout:timeout operationContext:operationContext];
     }];
    
    [command setAuthenticationHandler:self.client.authenticationHandler];
    
    [command setPreProcessResponse:^id(NSHTTPURLResponse * urlResponse, AZSRequestResult * requestResult, AZSOperationContext * operationContext) {
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
        return [urlResponse.allHeaderFields valueForKey:@"x-ms-lease-id"];
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
        return [urlResponse.allHeaderFields valueForKey:@"x-ms-lease-id"];
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
        return [urlResponse.allHeaderFields valueForKey:@"x-ms-lease-id"];
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
    NSString *parsedEtag = [response.allHeaderFields valueForKey:@"ETag"];
    NSDate *parsedLastModified = [[AZSUtil dateFormatterWithRFCFormat] dateFromString:[response.allHeaderFields valueForKey:@"Last-Modified"]];
    
    if (parsedEtag)
    {
        self.properties.eTag = parsedEtag;
    }
    
    if (parsedLastModified) {
        self.properties.lastModified = parsedLastModified;
    }
}

// Note: this should only be called from the constructor
-(void)parseQueryAndVerifyWithUri:(AZSStorageUri *)uri credentials:(AZSStorageCredentials *)credentials
{
    NSMutableArray *parseQueryResults = [AZSNavigationUtil parseBlobQueryAndVerifyWithStorageUri:uri];
    
    _storageUri = ([[parseQueryResults objectAtIndex:0] isKindOfClass:[NSNull class]] ? nil : [parseQueryResults objectAtIndex:0]);
    
    // todo: if (parsedcreds && creds) != null then throw mult creds
    
    _client = [[AZSCloudBlobClient alloc] initWithStorageUri: [AZSNavigationUtil getServiceClientBaseAddressWithStorageUri:self.storageUri usePathStyle:[AZSUtil usePathStyleAddressing:[uri primaryUri]]] credentials:(credentials != nil ? credentials : ([[parseQueryResults objectAtIndex:1] isKindOfClass:[NSNull class]] ? nil : [parseQueryResults objectAtIndex:1]))];
    
    _name = [AZSNavigationUtil getContainerNameWithContainerAddress:self.storageUri.primaryUri isPathStyle:[AZSUtil usePathStyleAddressing:self.storageUri.primaryUri]];
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
    [self fetchAttributesWithAccessCondition:accessCondition requestOptions:requestOptions operationContext:operationContext completionHandler:^(NSError *error) {
        if (error)
        {
            if ([error.domain isEqualToString:AZSErrorDomain] && (error.code == AZSEServerError) && error.userInfo[@"HTTP Status Code"] && (((NSNumber *)error.userInfo[@"HTTP Status Code"]).intValue == 404))
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

@end
