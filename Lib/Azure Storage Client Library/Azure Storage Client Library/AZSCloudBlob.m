// -----------------------------------------------------------------------------------------
// <copyright file="AZSCloudBlob.m" company="Microsoft">
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

#import "AZSCloudBlob.h"
#import "AZSCloudBlobContainer.h"
#import "AZSStorageUri.h"
#import "AZSStorageCommand.h"
#import "AZSBlobRequestFactory.h"
#import "AZSCloudBlobClient.h"
#import "AZSOperationContext.h"
#import "AZSExecutor.h"
#import "AZSBlobRequestOptions.h"
#import "AZSBlobProperties.h"
#import "AZSCopyState.h"
#import "AZSUriQueryBuilder.h"
#import "AZSUtil.h"
#import "AZSAccessCondition.h"
#import "AZSResponseParser.h"
#import "AZSNavigationUtil.h"
#import "AZSRequestResult.h"
#import "AZSErrors.h"
#import "AZSRequestFactory.h"
#import "AZSSharedAccessSignatureHelper.h"
#import "AZSStorageCredentials.h"
#import "AZSBlobResponseParser.h"

@interface AZSCloudBlob()

- (instancetype)init AZS_DESIGNATED_INITIALIZER;

@end

@implementation AZSCloudBlob

- (instancetype)init
{
    return nil;
}

- (instancetype)initWithUrl:(NSURL *)blobAbsoluteUrl
{
    return [self initWithUrl:blobAbsoluteUrl credentials:nil snapshotTime:nil];
}
- (instancetype)initWithUrl:(NSURL *)blobAbsoluteUrl credentials:(AZSStorageCredentials *)credentials snapshotTime:(NSString *)snapshotTime
{
    return [self initWithStorageUri:[[AZSStorageUri alloc] initWithPrimaryUri:blobAbsoluteUrl] credentials:credentials snapshotTime:snapshotTime];
}
- (instancetype)initWithStorageUri:(AZSStorageUri *)blobAbsoluteUri
{
    return [self initWithStorageUri:blobAbsoluteUri credentials:nil snapshotTime:nil];
}
- (instancetype)initWithStorageUri:(AZSStorageUri *)blobAbsoluteUri credentials:(AZSStorageCredentials *)credentials snapshotTime:(NSString *)snapshotTime
{
    self = [super init];
    if (self)
    {
        _blobCopyState = [[AZSCopyState alloc] init];
        _metadata = [[NSMutableDictionary alloc] init];
        _properties = [[AZSBlobProperties alloc] init];
        _snapshotTime = snapshotTime;
        [self parseQueryAndVerifyWithUri:blobAbsoluteUri credentials:credentials];
    }
    
    return self;
}

-(instancetype)initWithContainer:(AZSCloudBlobContainer *)blobContainer name:(NSString *)blobName
{
    return [self initWithContainer:blobContainer name:blobName snapshotTime:nil];
}

-(instancetype)initWithContainer:(AZSCloudBlobContainer *)blobContainer name:(NSString *)blobName snapshotTime:(NSString *)snapshotTime
{
    self = [super init];
    if (self)
    {
        _blobName = blobName;
        _blobContainer = blobContainer;
        _client = blobContainer.client;
        _storageUri = [AZSStorageUri appendToStorageUri:blobContainer.storageUri pathToAppend:blobName];
        _blobCopyState = [[AZSCopyState alloc] init];
        _metadata = [[NSMutableDictionary alloc] init];
        _properties = [[AZSBlobProperties alloc] init];
        _snapshotTime = snapshotTime;
    }
    
    return self;
}

-(void)downloadToStream:(NSOutputStream *)targetStream completionHandler:(void (^)(NSError*))completionHandler
{
    [self downloadToStream:targetStream accessCondition:nil requestOptions:nil operationContext:nil completionHandler:completionHandler];
}

-(void)downloadToStream:(NSOutputStream *)targetStream accessCondition:(AZSAccessCondition *)accessCondition requestOptions:(AZSBlobRequestOptions *)requestOptions operationContext:(AZSOperationContext *)operationContext completionHandler:(void (^)(NSError*))completionHandler
{
    [self downloadToStream:targetStream range:NSMakeRange(0, 0) accessCondition:accessCondition requestOptions:requestOptions operationContext:operationContext completionHandler:completionHandler];
}

-(void)downloadToStream:(NSOutputStream *)targetStream range:(NSRange)range accessCondition:(AZSAccessCondition *)accessCondition requestOptions:(AZSBlobRequestOptions *)requestOptions operationContext:(AZSOperationContext *)operationContext completionHandler:(void (^)(NSError*))completionHandler
{
    if (!operationContext)
    {
        operationContext = [[AZSOperationContext alloc] init];
    }
    AZSBlobRequestOptions *modifiedOptions = [[AZSBlobRequestOptions copyOptions:requestOptions] applyDefaultsFromOptions:self.client.defaultRequestOptions];
    AZSStorageCommand * command = [[AZSStorageCommand alloc] initWithStorageCredentials:self.client.credentials storageUri:self.storageUri calculateResponseMD5:!(modifiedOptions.disableContentMD5Validation) operationContext:operationContext];
    
    [command setBuildRequest:^ NSMutableURLRequest * (NSURLComponents *urlComponents, NSTimeInterval timeout, AZSOperationContext *operationContext)
     {
         return [AZSBlobRequestFactory getBlobWithSnapshotTime:self.snapshotTime range:range getRangeContentMD5:modifiedOptions.useTransactionalMD5 accessCondition:accessCondition urlComponents:urlComponents timeout:timeout operationContext:operationContext];
     }];
    
    [command setAuthenticationHandler:self.client.authenticationHandler];
    
    __block NSString *desiredContentMD5 = nil;
        
    [command setPreProcessResponse:^id(NSHTTPURLResponse * urlResponse, AZSRequestResult * requestResult, AZSOperationContext * operationContext) {
        NSError *error = [AZSResponseParser preprocessResponseWithResponse:urlResponse requestResult:requestResult operationContext:operationContext];
        if (error)
        {
            return error;
        }
        
        AZSBlobProperties *parsedProperties = [AZSBlobResponseParser getBlobPropertiesWithResponse:urlResponse operationContext:operationContext error:&error];
        if (error)
        {
            return error;
        }

        if (parsedProperties.blobType != AZSBlobTypeUnspecified && parsedProperties.blobType != self.properties.blobType)
        {
            return error = [NSError errorWithDomain:AZSErrorDomain code:AZSEInvalidArgument userInfo:@{NSLocalizedDescriptionKey:@"Blob type on the local object does not match blob type on the service."}];
        }
        
        if (modifiedOptions.useTransactionalMD5 && !modifiedOptions.disableContentMD5Validation && !parsedProperties.contentMD5)
        {
            NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
            NSError *storageError = [NSError errorWithDomain:AZSErrorDomain code:AZSEMD5Mismatch userInfo:userInfo];
            return storageError;
        }
        
        desiredContentMD5 = parsedProperties.contentMD5;
        
        if (range.length > 0)
        {
            // If it's a range get, don't update the contentMD5 on the blob's properties.
            parsedProperties.contentMD5 = self.properties.contentMD5;
        }
        
        self.properties = parsedProperties;
        self.blobCopyState = [AZSBlobResponseParser getCopyStateWithResponse:urlResponse];
        self.metadata = [AZSBlobResponseParser getMetadataWithResponse:urlResponse];
        
        return nil;
    }];
    
    [command setDestinationStream:targetStream];
    
    [command setPostProcessResponse:^id(NSHTTPURLResponse *response, AZSRequestResult *requestResult, NSOutputStream *outputStream, AZSOperationContext *operationContext, NSError **error) {
        if (desiredContentMD5 && !modifiedOptions.disableContentMD5Validation)
        {
            if ([desiredContentMD5 compare:requestResult.calculatedResponseMD5 options:NSLiteralSearch] != NSOrderedSame)
            {
                *error = [NSError errorWithDomain:AZSErrorDomain code:AZSEMD5Mismatch userInfo:nil];
            }
        }
        return nil;
    }];
    
    [AZSExecutor ExecuteWithStorageCommand:command requestOptions:modifiedOptions operationContext:operationContext completionHandler:^(NSError *error, id result)
     {
         completionHandler(error);
     }];
    return;

}

-(void)deleteWithCompletionHandler:(void (^)(NSError*))completionHandler
{
    [self deleteWithSnapshotsOption:AZSDeleteSnapshotsOptionNone completionHandler:completionHandler];
}

-(void)deleteWithSnapshotsOption:(AZSDeleteSnapshotsOption)snapshotsOption completionHandler:(void (^)(NSError*))completionHandler
{
    [self deleteWithSnapshotsOption:snapshotsOption accessCondition:nil requestOptions:nil operationContext:nil completionHandler:completionHandler];
}

-(void)deleteWithSnapshotsOption:(AZSDeleteSnapshotsOption)snapshotsOption accessCondition:(AZSAccessCondition *)accessCondition requestOptions:(AZSBlobRequestOptions *)requestOptions operationContext:(AZSOperationContext *)operationContext completionHandler:(void (^)(NSError*))completionHandler
{
    if (!operationContext)
    {
        operationContext = [[AZSOperationContext alloc] init];
    }
    AZSBlobRequestOptions *modifiedOptions = [[AZSBlobRequestOptions copyOptions:requestOptions] applyDefaultsFromOptions:self.client.defaultRequestOptions];
    AZSStorageCommand * command = [[AZSStorageCommand alloc] initWithStorageCredentials:self.client.credentials storageUri:self.storageUri operationContext:operationContext];
    
    [command setBuildRequest:^ NSMutableURLRequest * (NSURLComponents *urlComponents, NSTimeInterval timeout, AZSOperationContext *operationContext)
     {
         return [AZSBlobRequestFactory deleteBlobWithSnapshotsOption:snapshotsOption snapshotTime:self.snapshotTime accessCondition:accessCondition urlComponents:urlComponents timeout:timeout operationContext:operationContext];
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

- (void)uploadPropertiesWithCompletionHandler:(void (^)(NSError *))completionHandler
{
    return [self uploadPropertiesWithAccessCondition:nil requestOptions:nil operationContext:nil completionHandler:completionHandler];
}

- (void)uploadPropertiesWithAccessCondition:(AZSAccessCondition *)accessCondition requestOptions:(AZSBlobRequestOptions *)requestOptions operationContext:(AZSOperationContext *)operationContext completionHandler:(void (^)(NSError*))completionHandler
{
    if (!operationContext)
    {
        operationContext = [[AZSOperationContext alloc] init];
    }
    AZSBlobRequestOptions *modifiedOptions = [[AZSBlobRequestOptions copyOptions:requestOptions] applyDefaultsFromOptions:self.client.defaultRequestOptions];
    AZSStorageCommand * command = [[AZSStorageCommand alloc] initWithStorageCredentials:self.client.credentials storageUri:self.storageUri operationContext:operationContext];
    
    [command setBuildRequest:^ NSMutableURLRequest * (NSURLComponents *urlComponents, NSTimeInterval timeout, AZSOperationContext *operationContext)
     {
         return [AZSBlobRequestFactory uploadBlobPropertiesWithBlobProperties:self.properties cloudMetadata:self.metadata accessCondition:accessCondition urlComponents:urlComponents timeout:timeout operationContext:operationContext];
     }];
    
    [command setAuthenticationHandler:self.client.authenticationHandler];
    
    [command setPreProcessResponse:^id(NSHTTPURLResponse * urlResponse, AZSRequestResult * requestResult, AZSOperationContext * operationContext) {
        NSError *error = [AZSResponseParser preprocessResponseWithResponse:urlResponse requestResult:requestResult operationContext:operationContext];
        if (error)
        {
            return error;
        }
        
        [AZSCloudBlob updateEtagAndLastModifiedWithResponse:urlResponse properties:self.properties updateLength:NO];
        return nil;
    }];
    
    [AZSExecutor ExecuteWithStorageCommand:command requestOptions:modifiedOptions operationContext:operationContext completionHandler:^(NSError *error, id result)
     {
         completionHandler(error);
     }];
    return;
}

- (void)uploadMetadataWithCompletionHandler:(void (^)(NSError *))completionHandler
{
    [self uploadMetadataWithAccessCondition:nil requestOptions:nil operationContext:nil completionHandler:completionHandler];
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
         return [AZSBlobRequestFactory uploadBlobMetadataWithCloudMetadata:self.metadata accessCondition:accessCondition urlComponents:urlComponents timeout:timeout operationContext:operationContext];
     }];
    
    [command setAuthenticationHandler:self.client.authenticationHandler];
    
    [command setPreProcessResponse:^id(NSHTTPURLResponse * urlResponse, AZSRequestResult * requestResult, AZSOperationContext * operationContext) {
        NSError *error = [AZSResponseParser preprocessResponseWithResponse:urlResponse requestResult:requestResult operationContext:operationContext];
        if (error)
        {
            return error;
        }
        
        [AZSCloudBlob updateEtagAndLastModifiedWithResponse:urlResponse properties:self.properties updateLength:NO];
        return nil;
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
         return [AZSBlobRequestFactory fetchBlobAttributesWithAccessCondition:accessCondition snapshotTime:self.snapshotTime urlComponents:urlComponents timeout:timeout operationContext:operationContext];
     }];
    
    [command setAuthenticationHandler:self.client.authenticationHandler];
    
    [command setPreProcessResponse:^id(NSHTTPURLResponse * urlResponse, AZSRequestResult * requestResult, AZSOperationContext * operationContext) {
        NSError *error = [AZSResponseParser preprocessResponseWithResponse:urlResponse requestResult:requestResult operationContext:operationContext];
        if (error)
        {
            return error;
        }
        
        AZSBlobProperties *parsedProperties = [AZSBlobResponseParser getBlobPropertiesWithResponse:urlResponse operationContext:operationContext error:&error];
        if (error)
        {
            return error;
        }

        if (parsedProperties.blobType != AZSBlobTypeUnspecified && parsedProperties.blobType != self.properties.blobType)
        {
            return [NSError errorWithDomain:AZSErrorDomain code:AZSEInvalidArgument userInfo:@{NSLocalizedDescriptionKey:@"Blob type on the local object does not match blob type on the service."}];
        }
        
        self.properties = parsedProperties;
        self.blobCopyState = [AZSBlobResponseParser getCopyStateWithResponse:urlResponse];
        self.metadata = [AZSBlobResponseParser getMetadataWithResponse:urlResponse];
        
        return nil;
    }];
    
    [AZSExecutor ExecuteWithStorageCommand:command requestOptions:modifiedOptions operationContext:operationContext completionHandler:^(NSError *error, id result)
     {
         completionHandler(error);
     }];
}

-(void)snapshotBlobWithMetadata:(NSMutableDictionary *)metadata completionHandler:(void (^)(NSError*, AZSCloudBlob *))completionHandler
{
    [self snapshotBlobWithMetadata:metadata accessCondition:nil requestOptions:nil operationContext:nil completionHandler:completionHandler];
}

-(void)snapshotBlobWithMetadata:(NSMutableDictionary *)metadata accessCondition:(AZSAccessCondition *)accessCondition requestOptions:(AZSBlobRequestOptions *)requestOptions operationContext:(AZSOperationContext *)operationContext completionHandler:(void (^)(NSError*, AZSCloudBlob *))completionHandler
{
    if (!operationContext)
    {
        operationContext = [[AZSOperationContext alloc] init];
    }
    AZSBlobRequestOptions *modifiedOptions = [[AZSBlobRequestOptions copyOptions:requestOptions] applyDefaultsFromOptions:self.client.defaultRequestOptions];
    AZSStorageCommand * command = [[AZSStorageCommand alloc] initWithStorageCredentials:self.client.credentials storageUri:self.storageUri operationContext:operationContext];
    
    [command setBuildRequest:^ NSMutableURLRequest * (NSURLComponents *urlComponents, NSTimeInterval timeout, AZSOperationContext *operationContext)
    {
        return [AZSBlobRequestFactory snapshotBlobWithMetadata:metadata accessCondition:accessCondition urlComponents:urlComponents timeout:timeout operationContext:operationContext];
    }];
    
    [command setAuthenticationHandler:self.client.authenticationHandler];
    
    [command setPreProcessResponse:^id(NSHTTPURLResponse * urlResponse, AZSRequestResult * requestResult, AZSOperationContext * operationContext) {
        return [AZSResponseParser preprocessResponseWithResponse:urlResponse requestResult:requestResult operationContext:operationContext];
    }];
    
    [command setPostProcessResponse:^id(NSHTTPURLResponse *urlResponse, AZSRequestResult *requestResult, NSOutputStream *outputStream, AZSOperationContext *operationContext, NSError **error) {
        NSString *snapshotTime = [urlResponse.allHeaderFields valueForKey:@"x-ms-snapshot"];
        
        AZSCloudBlob *snapshotBlob = [[AZSCloudBlob alloc] initWithContainer:self.blobContainer name:self.blobName snapshotTime:snapshotTime];
        
        if (metadata)
        {
            snapshotBlob.metadata = metadata;
        }
        else
        {
            snapshotBlob.metadata = self.metadata;
        }
        snapshotBlob.properties = self.properties;
        
        [AZSCloudBlob updateEtagAndLastModifiedWithResponse:urlResponse properties:snapshotBlob.properties updateLength:NO];
        
        return snapshotBlob;
    }];

    [AZSExecutor ExecuteWithStorageCommand:command requestOptions:modifiedOptions operationContext:operationContext completionHandler:completionHandler];
    return;
}

-(void)existsWithCompletionHandler:(void (^)(NSError*, BOOL))completionHandler
{
    [self existsWithAccessCondition:nil requestOptions:nil operationContext:nil completionHandler:completionHandler];
}

-(void)existsWithAccessCondition:(AZSAccessCondition *)accessCondition requestOptions:(AZSBlobRequestOptions *)requestOptions operationContext:(AZSOperationContext *)operationContext completionHandler:(void (^)(NSError*, BOOL))completionHandler
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
    
    const AZSUriQueryBuilder *builder = [AZSSharedAccessSignatureHelper sharedAccessSignatureForBlobWithParameters:parameters resourceType:@"b" signature:signature error:error];
    return [builder builderAsString];
}

- (NSString *)createSharedAccessCanonicalName
{
    return [NSString stringWithFormat:@"/%@/%@/%@/%@", @"blob", self.client.credentials.accountName, self.blobContainer.name, self.blobName];
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
         
         return [AZSBlobRequestFactory leaseBlobWithLeaseAction:AZSLeaseActionAcquire proposedLeaseId:proposedLeaseId leaseDuration:leaseDuration leaseBreakPeriod:nil accessCondition:accessCondition urlComponents:urlComponents timeout:timeout operationContext:operationContext];
     }];
    
    [command setAuthenticationHandler:self.client.authenticationHandler];
    
    [command setPreProcessResponse:^id(NSHTTPURLResponse * urlResponse, AZSRequestResult * requestResult, AZSOperationContext * operationContext) {
        NSError *error = [AZSResponseParser preprocessResponseWithResponse:urlResponse requestResult:requestResult operationContext:operationContext];
        if (error)
        {
            return error;
        }
        
        [AZSCloudBlob updateEtagAndLastModifiedWithResponse:urlResponse properties:self.properties updateLength:NO];
        return nil;
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
         
         return [AZSBlobRequestFactory leaseBlobWithLeaseAction:AZSLeaseActionBreak proposedLeaseId:nil leaseDuration:nil leaseBreakPeriod:breakSeconds accessCondition:accessCondition urlComponents:urlComponents timeout:timeout operationContext:operationContext];
     }];
    
    [command setAuthenticationHandler:self.client.authenticationHandler];
    
    [command setPreProcessResponse:^id(NSHTTPURLResponse * urlResponse, AZSRequestResult * requestResult, AZSOperationContext * operationContext) {
        NSError *error = [AZSResponseParser preprocessResponseWithResponse:urlResponse requestResult:requestResult operationContext:operationContext];
        if (error)
        {
            return error;
        }
        
        [AZSCloudBlob updateEtagAndLastModifiedWithResponse:urlResponse properties:self.properties updateLength:NO];
        return nil;
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
        NSError *error = [NSError errorWithDomain:AZSErrorDomain code:AZSEInvalidArgument userInfo:@{NSLocalizedDescriptionKey:@"Cannot change a lease without providing an existing lease ID and a proposed new one."}];
        completionHandler(error, nil);
        return;
    }

    [command setBuildRequest:^ NSMutableURLRequest * (NSURLComponents *urlComponents, NSTimeInterval timeout, AZSOperationContext *operationContext)
     {
         return [AZSBlobRequestFactory leaseBlobWithLeaseAction:AZSLeaseActionChange proposedLeaseId:proposedLeaseId leaseDuration:nil leaseBreakPeriod:nil accessCondition:accessCondition urlComponents:urlComponents timeout:timeout operationContext:operationContext];
     }];
    
    [command setAuthenticationHandler:self.client.authenticationHandler];
    
    [command setPreProcessResponse:^id(NSHTTPURLResponse * urlResponse, AZSRequestResult * requestResult, AZSOperationContext * operationContext) {
        NSError *error = [AZSResponseParser preprocessResponseWithResponse:urlResponse requestResult:requestResult operationContext:operationContext];
        if (error)
        {
            return error;
        }
        
        [AZSCloudBlob updateEtagAndLastModifiedWithResponse:urlResponse properties:self.properties updateLength:NO];
        return nil;
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
        NSError *error = [NSError errorWithDomain:AZSErrorDomain code:AZSEInvalidArgument userInfo:@{NSLocalizedDescriptionKey:@"Cannot release a lease without providing a lease ID."}];
        completionHandler(error);
        return;
    }
    
    [command setBuildRequest:^ NSMutableURLRequest * (NSURLComponents *urlComponents, NSTimeInterval timeout, AZSOperationContext *operationContext)
     {
         return [AZSBlobRequestFactory leaseBlobWithLeaseAction:AZSLeaseActionRelease proposedLeaseId:nil leaseDuration:nil leaseBreakPeriod:nil accessCondition:accessCondition urlComponents:urlComponents timeout:timeout operationContext:operationContext];
     }];
    
    [command setAuthenticationHandler:self.client.authenticationHandler];
    
    [command setPreProcessResponse:^id(NSHTTPURLResponse * urlResponse, AZSRequestResult * requestResult, AZSOperationContext * operationContext) {
        NSError *error = [AZSResponseParser preprocessResponseWithResponse:urlResponse requestResult:requestResult operationContext:operationContext];
        if (error)
        {
            return error;
        }
        [AZSCloudBlob updateEtagAndLastModifiedWithResponse:urlResponse properties:self.properties updateLength:NO];
        return nil;
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
         return [AZSBlobRequestFactory leaseBlobWithLeaseAction:AZSLeaseActionRenew proposedLeaseId:nil leaseDuration:nil leaseBreakPeriod:nil accessCondition:accessCondition urlComponents:urlComponents timeout:timeout operationContext:operationContext];
     }];
    
    [command setAuthenticationHandler:self.client.authenticationHandler];
    
    [command setPreProcessResponse:^id(NSHTTPURLResponse * urlResponse, AZSRequestResult * requestResult, AZSOperationContext * operationContext) {
        NSError *error = [AZSResponseParser preprocessResponseWithResponse:urlResponse requestResult:requestResult operationContext:operationContext];
        if (error)
        {
            return error;
        }
        
        [AZSCloudBlob updateEtagAndLastModifiedWithResponse:urlResponse properties:self.properties updateLength:NO];
        
        return nil;
    }];
    
    [AZSExecutor ExecuteWithStorageCommand:command requestOptions:modifiedOptions operationContext:operationContext completionHandler:^(NSError *error, id result)
     {
         completionHandler(error);
     }];
    return;
}

+(void)updateEtagAndLastModifiedWithResponse:(NSHTTPURLResponse *)response properties:(AZSBlobProperties *)properties updateLength:(BOOL)updateLength
{
    NSString *parsedEtag = [response.allHeaderFields valueForKey:@"ETag"];
    NSDate *parsedLastModified = [[AZSUtil dateFormatterWithRFCFormat] dateFromString:[response.allHeaderFields valueForKey:@"Last-Modified"]];
    NSString *parsedSequenceNumberString = [response.allHeaderFields valueForKey:@"x-ms-blob-sequence-number"];

    if (parsedEtag)
    {
        properties.eTag = parsedEtag;
    }
    
    if (parsedLastModified) {
        properties.lastModified = parsedLastModified;
    }

    if (parsedSequenceNumberString)
    {
        properties.sequenceNumber = [NSNumber numberWithLongLong:[parsedSequenceNumberString longLongValue]];
    }
    
    if (updateLength)
    {
        NSString *rangeHeaderString = [response.allHeaderFields valueForKey:@"Range"];
        NSString *contentLengthHeaderString = [response.allHeaderFields valueForKey:@"Content-Length"];
        NSString *blobContentLengthHeaderString = [response.allHeaderFields valueForKey:@"x-ms-blob-content-length"];
        
        if (rangeHeaderString)
        {
            properties.length = [NSNumber numberWithLongLong:[[[rangeHeaderString componentsSeparatedByString:@"/"] objectAtIndex:1] longLongValue]];
        }
        else if (blobContentLengthHeaderString)
        {
            properties.length = [NSNumber numberWithLongLong:[blobContentLengthHeaderString longLongValue]];
        }
        else if (contentLengthHeaderString)
        {
            properties.length = [NSNumber numberWithLongLong:[contentLengthHeaderString longLongValue]];
        }
        else
        {
            properties.length = [NSNumber numberWithLongLong:[response expectedContentLength]];
        }
    }
}

// Note: This should only be called from the constructor
-(void)parseQueryAndVerifyWithUri:(AZSStorageUri *)uri credentials:(AZSStorageCredentials *)credentials
{
    NSMutableArray *parseQueryResults = [AZSNavigationUtil parseBlobQueryAndVerifyWithStorageUri:uri];
    
    _storageUri = ([[parseQueryResults objectAtIndex:0] isKindOfClass:[NSNull class]] ? nil : [parseQueryResults objectAtIndex:0]);
    
    // todo: if (parsedcreds && creds) but they're not equal then throw mult creds
    
    // todo: if (parsedSnap && snap) but they're not equal then throw mult snapshots
    
    if ([parseQueryResults count] > 2)
    {
        _snapshotTime = ([[parseQueryResults objectAtIndex:2] isKindOfClass:[NSNull class]] ? nil : [parseQueryResults objectAtIndex:2]);
    }
    
    _client = [[AZSCloudBlobClient alloc] initWithStorageUri: [AZSNavigationUtil getServiceClientBaseAddressWithStorageUri:self.storageUri usePathStyle:[AZSUtil usePathStyleAddressing:[uri primaryUri]]] credentials:(credentials != nil ? credentials : ([[parseQueryResults objectAtIndex:1] isKindOfClass:[NSNull class]] ? nil : [parseQueryResults objectAtIndex:1]))];
    
    _blobName = [AZSNavigationUtil getBlobNameWithBlobAddress:self.storageUri.primaryUri isPathStyle:[AZSUtil usePathStyleAddressing:self.storageUri.primaryUri]];
}

-(void)downloadToDataWithCompletionHandler:(void (^)(NSError *, NSData *))completionHandler
{
    [self downloadToDataWithAccessCondition:nil requestOptions:nil operationContext:nil completionHandler:completionHandler];
}

-(void)downloadToDataWithAccessCondition:(AZSAccessCondition *)accessCondition requestOptions:(AZSBlobRequestOptions *)requestOptions operationContext:(AZSOperationContext *)operationContext completionHandler:(void (^)(NSError *, NSData *))completionHandler
{
    NSOutputStream *targetStream = [NSOutputStream outputStreamToMemory];
    [self downloadToStream:targetStream accessCondition:accessCondition requestOptions:requestOptions operationContext:operationContext completionHandler:^(NSError *error) {
        NSData *targetData = [targetStream propertyForKey:NSStreamDataWrittenToMemoryStreamKey];
        completionHandler(error, targetData);
    }];
}

-(void)downloadToTextWithCompletionHandler:(void (^)(NSError *, NSString *))completionHandler
{
    [self downloadToTextWithAccessCondition:nil requestOptions:nil operationContext:nil completionHandler:completionHandler];
}

-(void)downloadToTextWithAccessCondition:(AZSAccessCondition *)accessCondition requestOptions:(AZSBlobRequestOptions *)requestOptions operationContext:(AZSOperationContext *)operationContext completionHandler:(void (^)(NSError *, NSString *))completionHandler
{
    NSOutputStream *targetStream = [NSOutputStream outputStreamToMemory];
    [self downloadToStream:targetStream accessCondition:accessCondition requestOptions:requestOptions operationContext:operationContext completionHandler:^(NSError *error) {
        NSString *targetString = [[NSString alloc] initWithData:[targetStream propertyForKey:NSStreamDataWrittenToMemoryStreamKey] encoding:NSUTF8StringEncoding];
        completionHandler(error, targetString);
    }];
}

-(void)downloadToFileWithPath:(NSString *)filePath append:(BOOL)shouldAppend completionHandler:(void (^)(NSError *))completionHandler
{
    [self downloadToFileWithPath:filePath append:shouldAppend accessCondition:nil requestOptions:nil operationContext:nil completionHandler:completionHandler];
}

-(void)downloadToFileWithPath:(NSString *)filePath append:(BOOL)shouldAppend accessCondition:(AZSAccessCondition *)accessCondition requestOptions:(AZSBlobRequestOptions *)requestOptions operationContext:(AZSOperationContext *)operationContext completionHandler:(void (^)(NSError *))completionHandler
{
    NSOutputStream *targetStream = [NSOutputStream outputStreamToFileAtPath:filePath append:shouldAppend];
    [self downloadToStream:targetStream accessCondition:accessCondition requestOptions:requestOptions operationContext:operationContext completionHandler:completionHandler];
}

-(void)downloadToFileWithURL:(NSURL *)fileURL append:(BOOL)shouldAppend completionHandler:(void (^)(NSError *))completionHandler
{
    [self downloadToFileWithURL:fileURL append:shouldAppend accessCondition:nil requestOptions:nil operationContext:nil completionHandler:completionHandler];
}

-(void)downloadToFileWithURL:(NSURL *)fileURL append:(BOOL)shouldAppend accessCondition:(AZSAccessCondition *)accessCondition requestOptions:(AZSBlobRequestOptions *)requestOptions operationContext:(AZSOperationContext *)operationContext completionHandler:(void (^)(NSError *))completionHandler
{
    NSOutputStream *targetStream = [NSOutputStream outputStreamWithURL:fileURL append:shouldAppend];
    [self downloadToStream:targetStream accessCondition:accessCondition requestOptions:requestOptions operationContext:operationContext completionHandler:completionHandler];
}

-(void)startAsyncCopyFromBlob:(AZSCloudBlob *)sourceBlob completionHandler:(void (^)(NSError *, NSString *))completionHandler
{
    [self startAsyncCopyFromBlob:sourceBlob sourceAccessCondition:nil destinationAccessCondition:nil requestOptions:nil operationContext:nil completionHandler:completionHandler];
}


-(void)startAsyncCopyFromBlob:(AZSCloudBlob *)sourceBlob sourceAccessCondition:(AZSAccessCondition *)sourceAccessCondition destinationAccessCondition:(AZSAccessCondition *)destinationAccessCondition requestOptions:(AZSBlobRequestOptions *)requestOptions operationContext:(AZSOperationContext *)operationContext completionHandler:(void (^)(NSError *, NSString *))completionHandler
{
    NSURLComponents *components = [NSURLComponents componentsWithURL:sourceBlob.storageUri.primaryUri resolvingAgainstBaseURL:YES];
    
    if (sourceBlob.snapshotTime)
    {
        components.query = [AZSRequestFactory appendToQuery:components.query stringToAppend:[NSString stringWithFormat:@"snapshot=%@",sourceBlob.snapshotTime]];
    }
    
    NSURL *transformedURL = [self.client.credentials transformWithUri:[components URL]];
    
    [self startAsyncCopyFromURL:transformedURL sourceAccessCondition:sourceAccessCondition destinationAccessCondition:destinationAccessCondition requestOptions:requestOptions operationContext:operationContext completionHandler:completionHandler];
}

-(void)startAsyncCopyFromURL:(NSURL *)sourceURL completionHandler:(void (^)(NSError *, NSString *))completionHandler;
{
    [self startAsyncCopyFromURL:sourceURL sourceAccessCondition:nil destinationAccessCondition:nil requestOptions:nil operationContext:nil completionHandler:completionHandler];
}

-(void)startAsyncCopyFromURL:(NSURL *)sourceURL sourceAccessCondition:(AZSAccessCondition *)sourceAccessCondition destinationAccessCondition:(AZSAccessCondition *)destinationAccessCondition requestOptions:(AZSBlobRequestOptions *)requestOptions operationContext:(AZSOperationContext *)operationContext completionHandler:(void (^)(NSError *, NSString *))completionHandler;
{
    if (!operationContext)
    {
        operationContext = [[AZSOperationContext alloc] init];
    }
    AZSBlobRequestOptions *modifiedOptions = [[AZSBlobRequestOptions copyOptions:requestOptions] applyDefaultsFromOptions:self.client.defaultRequestOptions];
    AZSStorageCommand * command = [[AZSStorageCommand alloc] initWithStorageCredentials:self.client.credentials storageUri:self.storageUri operationContext:operationContext];

    [command setBuildRequest:^ NSMutableURLRequest * (NSURLComponents *urlComponents, NSTimeInterval timeout, AZSOperationContext *operationContext)
     {
         return [AZSBlobRequestFactory copyBlobWithSourceURL:sourceURL sourceAccessCondition:sourceAccessCondition cloudMetadata:self.metadata accessCondition:destinationAccessCondition urlComponents:urlComponents timeout:timeout operationContext:operationContext];
     }];

    [command setAuthenticationHandler:self.client.authenticationHandler];
    [command setPreProcessResponse:^id(NSHTTPURLResponse * urlResponse, AZSRequestResult * requestResult, AZSOperationContext * operationContext)
    {
        NSError *error = [AZSResponseParser preprocessResponseWithResponse:urlResponse requestResult:requestResult operationContext:operationContext];
        if (error)
        {
            return  error;
        }

        AZSBlobProperties *parsedProperties = [AZSBlobResponseParser getBlobPropertiesWithResponse:urlResponse operationContext:operationContext error:&error];
        if (error)
        {
            return  error;
        }

        [AZSCloudBlob updateEtagAndLastModifiedWithResponse:urlResponse properties:parsedProperties updateLength:NO];
        self.blobCopyState = [AZSBlobResponseParser getCopyStateWithResponse:urlResponse];

        return nil;
    }];
    
    [command setPostProcessResponse:^id(NSHTTPURLResponse *urlResponse, AZSRequestResult *requestResult, NSOutputStream *outputStream, AZSOperationContext *operationContext, NSError **error) {
        return self.blobCopyState.operationId;
    }];

    [AZSExecutor ExecuteWithStorageCommand:command requestOptions:modifiedOptions operationContext:operationContext completionHandler:completionHandler];
}

-(void)abortAsyncCopyWithCopyId:(NSString *)copyId completionHandler:(void (^)(NSError *))completionHandler
{
    [self abortAsyncCopyWithCopyId:copyId accessCondition:nil requestOptions:nil operationContext:nil completionHandler:completionHandler];
}

-(void)abortAsyncCopyWithCopyId:(NSString *)copyId accessCondition:(AZSAccessCondition *)accessCondition requestOptions:(AZSBlobRequestOptions *)requestOptions operationContext:(AZSOperationContext *)operationContext completionHandler:(void (^)(NSError *))completionHandler
{
    if (!operationContext)
    {
        operationContext = [[AZSOperationContext alloc] init];
    }

    AZSBlobRequestOptions *modifiedOptions = [[AZSBlobRequestOptions copyOptions:requestOptions] applyDefaultsFromOptions:self.client.defaultRequestOptions];
    AZSStorageCommand * command = [[AZSStorageCommand alloc] initWithStorageCredentials:self.client.credentials storageUri:self.storageUri operationContext:operationContext];

    [command setBuildRequest:^ NSMutableURLRequest * (NSURLComponents *urlComponents, NSTimeInterval timeout, AZSOperationContext *operationContext)
     {
         return [AZSBlobRequestFactory abortCopyBlobWithCopyId:copyId accessCondition:accessCondition urlComponents:urlComponents timeout:timeout operationContext:operationContext];
     }];
    
    [command setAuthenticationHandler:self.client.authenticationHandler];
    [command setPreProcessResponse:^id(NSHTTPURLResponse * urlResponse, AZSRequestResult * requestResult, AZSOperationContext * operationContext)
     {
         NSError *error = [AZSResponseParser preprocessResponseWithResponse:urlResponse requestResult:requestResult operationContext:operationContext];
         if (error)
         {
             return  error;
         }

         [AZSCloudBlob updateEtagAndLastModifiedWithResponse:urlResponse properties:self.properties updateLength:NO];
         return nil;
     }];
    
    [AZSExecutor ExecuteWithStorageCommand:command requestOptions:modifiedOptions operationContext:operationContext completionHandler:^(NSError *error, id result) {
        completionHandler(error);
    }];
    
    return;
}

@end

