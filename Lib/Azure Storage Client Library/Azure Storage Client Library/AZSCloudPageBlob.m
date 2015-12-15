// -----------------------------------------------------------------------------------------
// <copyright file="AZSCloudPageBlob.m" company="Microsoft">
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

#import "AZSCloudPageBlob.h"
#import "AZSStorageUri.h"
#import "AZSBlobProperties.h"
#import "AZSOperationContext.h"
#import "AZSBlobRequestOptions.h"
#import "AZSStorageCommand.h"
#import "AZSCloudBlobClient.h"
#import "AZSBlobRequestFactory.h"
#import "AZSResponseParser.h"
#import "AZSBlobResponseParser.h"
#import "AZSExecutor.h"
#import "AZSErrors.h"
#import "AZSUtil.h"

@implementation AZSCloudPageBlob

- (instancetype)initWithUrl:(NSURL *)blobAbsoluteUrl error:(NSError **)error
{
    return [self initWithUrl:blobAbsoluteUrl credentials:nil snapshotTime:nil error:error];
}
- (instancetype)initWithUrl:(NSURL *)blobAbsoluteUrl credentials:(AZSStorageCredentials *)credentials snapshotTime:(NSString *)snapshotTime error:(NSError **)error
{
    return [self initWithStorageUri:[[AZSStorageUri alloc] initWithPrimaryUri:blobAbsoluteUrl] credentials:credentials snapshotTime:snapshotTime error:error];
}
- (instancetype)initWithStorageUri:(AZSStorageUri *)blobAbsoluteUri error:(NSError **)error
{
    return [self initWithStorageUri:blobAbsoluteUri credentials:nil snapshotTime:nil error:error];
}
- (instancetype)initWithStorageUri:(AZSStorageUri *)blobAbsoluteUri credentials:(AZSStorageCredentials *)credentials snapshotTime:(NSString *)snapshotTime error:(NSError **)error
{
    self = [super initWithStorageUri:blobAbsoluteUri credentials:credentials snapshotTime:snapshotTime error:error];
    if (self)
    {
        self.properties.blobType = AZSBlobTypePageBlob;
    }
    
    return self;
}

-(instancetype)initWithContainer:(AZSCloudBlobContainer *)blobContainer name:(NSString *)blobName
{
    return [self initWithContainer:blobContainer name:blobName snapshotTime:nil];
}

-(instancetype)initWithContainer:(AZSCloudBlobContainer *)blobContainer name:(NSString *)blobName snapshotTime:(NSString *)snapshotTime
{
    self =[super initWithContainer:blobContainer name:blobName snapshotTime:snapshotTime];
    if (self)
    {
        self.properties.blobType = AZSBlobTypePageBlob;
    }
    
    return self;
}

-(void)createWithSize:(NSNumber *)totalBlobSize completionHandler:(void (^)(NSError * __AZSNullable))completionHandler
{
    [self createWithSize:totalBlobSize sequenceNumber:nil completionHandler:completionHandler];
}

-(void)createWithSize:(NSNumber *)totalBlobSize sequenceNumber:(NSNumber *)sequenceNumber completionHandler:(void (^)(NSError * __AZSNullable))completionHandler
{
    [self createWithSize:totalBlobSize sequenceNumber:sequenceNumber accessCondition:nil requestOptions:nil operationContext:nil completionHandler:completionHandler];
}

-(void)createWithSize:(NSNumber *)totalBlobSize sequenceNumber:(NSNumber *)sequenceNumber accessCondition:(AZSNullable AZSAccessCondition *)accessCondition requestOptions:(AZSNullable AZSBlobRequestOptions *)requestOptions operationContext:(AZSNullable AZSOperationContext *)operationContext completionHandler:(void (^)(NSError * __AZSNullable))completionHandler
{
    if (!operationContext)
    {
        operationContext = [[AZSOperationContext alloc] init];
    }
    AZSBlobRequestOptions *modifiedOptions = [[AZSBlobRequestOptions copyOptions:requestOptions] applyDefaultsFromOptions:self.client.defaultRequestOptions];
    AZSStorageCommand *command = [[AZSStorageCommand alloc] initWithStorageCredentials:self.client.credentials storageUri:self.storageUri operationContext:operationContext];
    
    [command setBuildRequest:^ NSMutableURLRequest * (NSURLComponents *urlComponents, NSTimeInterval timeout, AZSOperationContext *operationContext)
    {
        return [AZSBlobRequestFactory createPageBlobWithSize:totalBlobSize sequenceNumber:(sequenceNumber ?: [NSNumber numberWithInt:0]) blobProperties:self.properties cloudMetadata:self.metadata accessCondition:accessCondition urlComponents:urlComponents timeout:timeout operationContext:operationContext];
    }];
    
    [command setAuthenticationHandler:self.client.authenticationHandler];
    
    [command setPreProcessResponse:^id(NSHTTPURLResponse *urlResponse, AZSRequestResult *requestResult, AZSOperationContext *operationContext) {
        NSError *error = [AZSResponseParser preprocessResponseWithResponse:urlResponse requestResult:requestResult operationContext:operationContext];
        if (error)
        {
            return  error;
        }
        
        [AZSCloudBlob updateEtagAndLastModifiedWithResponse:urlResponse properties:self.properties updateLength:NO];
        self.properties.length = totalBlobSize;
        self.properties.sequenceNumber = sequenceNumber;
        return nil;
    }];
    
    [AZSExecutor ExecuteWithStorageCommand:command requestOptions:modifiedOptions operationContext:operationContext completionHandler:^(NSError *error, id result)
    {
        completionHandler(error);
    }];
}

-(void)createIfNotExistsWithSize:(NSNumber *)totalBlobSize completionHandler:(void (^)(NSError * _Nullable, BOOL))completionHandler
{
    [self createIfNotExistsWithSize:totalBlobSize sequenceNumber:nil accessCondition:nil requestOptions:nil operationContext:nil completionHandler:completionHandler];
}

-(void)createIfNotExistsWithSize:(NSNumber *)totalBlobSize sequenceNumber:(NSNumber *)sequenceNumber completionHandler:(void (^)(NSError * _Nullable, BOOL))completionHandler
{
    [self createIfNotExistsWithSize:totalBlobSize sequenceNumber:sequenceNumber accessCondition:nil requestOptions:nil operationContext:nil completionHandler:completionHandler];
}

-(void)createIfNotExistsWithSize:(NSNumber *)totalBlobSize sequenceNumber:(NSNumber *)sequenceNumber accessCondition:(AZSAccessCondition *)accessCondition requestOptions:(AZSBlobRequestOptions *)requestOptions operationContext:(AZSOperationContext *)operationContext completionHandler:(void (^)(NSError * _Nullable, BOOL))completionHandler
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
                [self createWithSize:totalBlobSize sequenceNumber:sequenceNumber accessCondition:accessCondition requestOptions:requestOptions operationContext:operationContext completionHandler:^(NSError *error) {
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

-(void)uploadPagesWithData:(NSData *)data startOffset:(NSNumber *)startOffset contentMD5:(NSString *)contentMD5 completionHandler:(void (^)(NSError *))completionHandler
{
    [self uploadPagesWithData:data startOffset:startOffset contentMD5:contentMD5 accessCondition:nil requestOptions:nil operationContext:nil completionHandler:completionHandler];
}

-(void)uploadPagesWithData:(NSData *)data startOffset:(NSNumber *)startOffset contentMD5:(NSString *)contentMD5 accessCondition:(AZSAccessCondition *)accessCondition requestOptions:(AZSBlobRequestOptions *)requestOptions operationContext:(AZSOperationContext *)operationContext completionHandler:(void (^)(NSError *))completionHandler
{
    if (!operationContext)
    {
        operationContext = [[AZSOperationContext alloc] init];
    }
    AZSBlobRequestOptions *modifiedOptions = [[AZSBlobRequestOptions copyOptions:requestOptions] applyDefaultsFromOptions:self.client.defaultRequestOptions];
    AZSStorageCommand *command = [[AZSStorageCommand alloc] initWithStorageCredentials:self.client.credentials storageUri:self.storageUri operationContext:operationContext];
    
    if (requestOptions.useTransactionalMD5 && !(contentMD5))
    {
        contentMD5 = [AZSUtil calculateMD5FromData:data];
    }
    
    [command setBuildRequest:^ NSMutableURLRequest * (NSURLComponents *urlComponents, NSTimeInterval timeout, AZSOperationContext *operationContext)
    {
        return [AZSBlobRequestFactory putPagesWithPageRange:(NSMakeRange(startOffset.longLongValue, data.length)) clear:NO contentMD5:contentMD5 accessCondition:accessCondition urlComponents:urlComponents timeout:timeout operationContext:operationContext];
    }];
    
    [command setAuthenticationHandler:self.client.authenticationHandler];
    
    [command setPreProcessResponse:^id(NSHTTPURLResponse *urlResponse, AZSRequestResult *requestResult, AZSOperationContext *operationContext) {
        NSError *error = [AZSResponseParser preprocessResponseWithResponse:urlResponse requestResult:requestResult operationContext:operationContext];
        if (error)
        {
            return  error;
        }
        
        [AZSCloudBlob updateEtagAndLastModifiedWithResponse:urlResponse properties:self.properties updateLength:NO];
        self.properties.sequenceNumber = [AZSBlobResponseParser getSequenceNumberWithResponse:urlResponse];
        return nil;
    }];
        
    [command setSource:data];
    
    [AZSExecutor ExecuteWithStorageCommand:command requestOptions:modifiedOptions operationContext:operationContext completionHandler:^(NSError *error, id result)
    {
        completionHandler(error);
    }];
    return;
}

-(void)clearPagesWithRange:(NSRange)range completionHandler:(void (^)(NSError * __AZSNullable))completionHandler
{
    [self clearPagesWithRange:range accessCondition:nil requestOptions:nil operationContext:nil completionHandler:completionHandler];
}

-(void)clearPagesWithRange:(NSRange)range accessCondition:(AZSNullable AZSAccessCondition *)accessCondition requestOptions:(AZSNullable AZSBlobRequestOptions *)requestOptions operationContext:(AZSNullable AZSOperationContext *)operationContext completionHandler:(void (^)(NSError * __AZSNullable))completionHandler
{
    if (!operationContext)
    {
        operationContext = [[AZSOperationContext alloc] init];
    }
    AZSBlobRequestOptions *modifiedOptions = [[AZSBlobRequestOptions copyOptions:requestOptions] applyDefaultsFromOptions:self.client.defaultRequestOptions];
    AZSStorageCommand *command = [[AZSStorageCommand alloc] initWithStorageCredentials:self.client.credentials storageUri:self.storageUri operationContext:operationContext];
    
    [command setBuildRequest:^ NSMutableURLRequest * (NSURLComponents *urlComponents, NSTimeInterval timeout, AZSOperationContext *operationContext)
    {
        return [AZSBlobRequestFactory putPagesWithPageRange:range clear:YES contentMD5:nil accessCondition:accessCondition urlComponents:urlComponents timeout:timeout operationContext:operationContext];
    }];
    
    [command setAuthenticationHandler:self.client.authenticationHandler];
    
    [command setPreProcessResponse:^id(NSHTTPURLResponse *urlResponse, AZSRequestResult *requestResult, AZSOperationContext *operationContext) {
        NSError *error = [AZSResponseParser preprocessResponseWithResponse:urlResponse requestResult:requestResult operationContext:operationContext];
        if (error)
        {
            return  error;
        }
        
        [AZSCloudBlob updateEtagAndLastModifiedWithResponse:urlResponse properties:self.properties updateLength:NO];
        self.properties.sequenceNumber = [AZSBlobResponseParser getSequenceNumberWithResponse:urlResponse];
        return nil;
    }];
    
    [AZSExecutor ExecuteWithStorageCommand:command requestOptions:modifiedOptions operationContext:operationContext completionHandler:^(NSError *error, id result)
    {
        completionHandler(error);
    }];
    return;
}

-(void)downloadPageRangesWithCompletionHandler:(void (^)(NSError * __AZSNullable, NSArray *))completionHandler
{
    [self downloadPageRangesWithRange:(NSMakeRange(0, 0)) completionHandler:completionHandler];
}

-(void)downloadPageRangesWithRange:(NSRange)range completionHandler:(void (^)(NSError * __AZSNullable, NSArray *))completionHandler
{
    [self downloadPageRangesWithRange:range accessCondition:nil requestOptions:nil operationContext:nil completionHandler:completionHandler];
}

-(void)downloadPageRangesWithRange:(NSRange)range accessCondition:(AZSNullable AZSAccessCondition *)accessCondition requestOptions:(AZSNullable AZSBlobRequestOptions *)requestOptions operationContext:(AZSNullable AZSOperationContext *)operationContext completionHandler:(void (^)(NSError * __AZSNullable, NSArray *))completionHandler
{
    if (!operationContext)
    {
        operationContext = [[AZSOperationContext alloc] init];
    }
    AZSBlobRequestOptions *modifiedOptions = [[AZSBlobRequestOptions copyOptions:requestOptions] applyDefaultsFromOptions:self.client.defaultRequestOptions];
    AZSStorageCommand *command = [[AZSStorageCommand alloc] initWithStorageCredentials:self.client.credentials storageUri:self.storageUri operationContext:operationContext];
    
    [command setBuildRequest:^ NSMutableURLRequest * (NSURLComponents *urlComponents, NSTimeInterval timeout, AZSOperationContext *operationContext)
    {
        return [AZSBlobRequestFactory getPageRangesWithRange:range snapshotTime:self.snapshotTime accessCondition:accessCondition urlComponents:urlComponents timeout:timeout operationContext:operationContext];
    }];
    
    [command setAuthenticationHandler:self.client.authenticationHandler];
    
    [command setPreProcessResponse:^id(NSHTTPURLResponse *urlResponse, AZSRequestResult *requestResult, AZSOperationContext *operationContext) {
        NSError *error = [AZSResponseParser preprocessResponseWithResponse:urlResponse requestResult:requestResult operationContext:operationContext];
        if (error)
        {
            return error;
        }
        
        [AZSCloudBlob updateEtagAndLastModifiedWithResponse:urlResponse properties:self.properties updateLength:YES];
        return nil;
    }];
    
    [command setPostProcessResponse:^id(NSHTTPURLResponse *urlResponse, AZSRequestResult *requestResult, NSOutputStream *outputStream, AZSOperationContext *operationContext, NSError **error) {
        NSArray *pageRangesResponse = [AZSGetPageRangesResponse parseGetPageRangesResponseWithData:[outputStream propertyForKey:NSStreamDataWrittenToMemoryStreamKey] operationContext:operationContext error:error];
        
        if (*error)
        {
            return nil;
        }
        
        return pageRangesResponse;
    }];
    
    [AZSExecutor ExecuteWithStorageCommand:command requestOptions:modifiedOptions operationContext:operationContext completionHandler:completionHandler];
    return;
}

-(void)resizeWithSize:(NSNumber *)totalBlobSize completionHandler:(void (^)(NSError * __AZSNullable))completionHandler
{
    [self resizeWithSize:totalBlobSize accessCondition:nil requestOptions:nil operationContext:nil completionHandler:completionHandler];
}
-(void)resizeWithSize:(NSNumber *)totalBlobSize accessCondition:(AZSNullable AZSAccessCondition *)accessCondition requestOptions:(AZSNullable AZSBlobRequestOptions *)requestOptions operationContext:(AZSNullable AZSOperationContext *)operationContext completionHandler:(void (^)(NSError * __AZSNullable))completionHandler
{
    if (!operationContext)
    {
        operationContext = [[AZSOperationContext alloc] init];
    }
    AZSBlobRequestOptions *modifiedOptions = [[AZSBlobRequestOptions copyOptions:requestOptions] applyDefaultsFromOptions:self.client.defaultRequestOptions];
    AZSStorageCommand *command = [[AZSStorageCommand alloc] initWithStorageCredentials:self.client.credentials storageUri:self.storageUri operationContext:operationContext];
    
    [command setBuildRequest:^ NSMutableURLRequest * (NSURLComponents *urlComponents, NSTimeInterval timeout, AZSOperationContext *operationContext)
    {
        return [AZSBlobRequestFactory resizePageBlobWithSize:totalBlobSize accessCondition:accessCondition urlComponents:urlComponents timeout:timeout operationContext:operationContext];
    }];
    
    [command setAuthenticationHandler:self.client.authenticationHandler];
    
    [command setPreProcessResponse:^id(NSHTTPURLResponse *urlResponse, AZSRequestResult *requestResult, AZSOperationContext *operationContext) {
        NSError *error = [AZSResponseParser preprocessResponseWithResponse:urlResponse requestResult:requestResult operationContext:operationContext];
        if (error)
        {
            return  error;
        }
        
        // TODO: Investigate whether this will overwrite any properties that aren't returned.
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
        self.properties.length = totalBlobSize;
        self.properties.sequenceNumber = [AZSBlobResponseParser getSequenceNumberWithResponse:urlResponse];;
        return nil;
    }];
    
    [AZSExecutor ExecuteWithStorageCommand:command requestOptions:modifiedOptions operationContext:operationContext completionHandler:^(NSError *error, id result)
    {
        completionHandler(error);
    }];
}

-(void)setSequenceNumberWithNumber:(NSNumber *)newSequenceNumber useMaximum:(BOOL)useMaximum completionHandler:(void (^)(NSError * __AZSNullable))completionHandler
{
    [self setSequenceNumberWithNumber:newSequenceNumber useMaximum:useMaximum accessCondition:nil requestOptions:nil operationContext:nil completionHandler:completionHandler];
}

-(void)setSequenceNumberWithNumber:(NSNumber *)newSequenceNumber useMaximum:(BOOL)useMaximum accessCondition:(AZSNullable AZSAccessCondition *)accessCondition requestOptions:(AZSNullable AZSBlobRequestOptions *)requestOptions operationContext:(AZSNullable AZSOperationContext *)operationContext completionHandler:(void (^)(NSError * __AZSNullable))completionHandler
{
    if (!operationContext)
    {
        operationContext = [[AZSOperationContext alloc] init];
    }
    AZSBlobRequestOptions *modifiedOptions = [[AZSBlobRequestOptions copyOptions:requestOptions] applyDefaultsFromOptions:self.client.defaultRequestOptions];
    AZSStorageCommand *command = [[AZSStorageCommand alloc] initWithStorageCredentials:self.client.credentials storageUri:self.storageUri operationContext:operationContext];
    
    [command setBuildRequest:^ NSMutableURLRequest * (NSURLComponents *urlComponents, NSTimeInterval timeout, AZSOperationContext *operationContext)
    {
        return [AZSBlobRequestFactory setPageBlobSequenceNumberWithNewSequenceNumber:newSequenceNumber isIncrement:NO useMaximum:useMaximum accessCondition:accessCondition urlComponents:urlComponents timeout:timeout operationContext:operationContext];
    }];
    
    [command setAuthenticationHandler:self.client.authenticationHandler];
    
    [command setPreProcessResponse:^id(NSHTTPURLResponse *urlResponse, AZSRequestResult *requestResult, AZSOperationContext *operationContext) {
        NSError *error = [AZSResponseParser preprocessResponseWithResponse:urlResponse requestResult:requestResult operationContext:operationContext];
        if (error)
        {
            return  error;
        }
        
        // TODO: Investigate whether this will overwrite any properties that aren't returned.
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
        self.properties.sequenceNumber = [AZSBlobResponseParser getSequenceNumberWithResponse:urlResponse];;
        return nil;
    }];
    
    [AZSExecutor ExecuteWithStorageCommand:command requestOptions:modifiedOptions operationContext:operationContext completionHandler:^(NSError *error, id result)
    {
        completionHandler(error);
    }];
}

-(void)incrementSequenceNumberWithCompletionHandler:(void (^)(NSError * __AZSNullable))completionHandler
{
    [self incrementSequenceNumberWithAccessCondition:nil requestOptions:nil operationContext:nil completionHandler:completionHandler];
}
-(void)incrementSequenceNumberWithAccessCondition:(AZSNullable AZSAccessCondition *)accessCondition requestOptions:(AZSNullable AZSBlobRequestOptions *)requestOptions operationContext:(AZSNullable AZSOperationContext *)operationContext completionHandler:(void (^)(NSError * __AZSNullable))completionHandler
{
    if (!operationContext)
    {
        operationContext = [[AZSOperationContext alloc] init];
    }
    AZSBlobRequestOptions *modifiedOptions = [[AZSBlobRequestOptions copyOptions:requestOptions] applyDefaultsFromOptions:self.client.defaultRequestOptions];
    AZSStorageCommand *command = [[AZSStorageCommand alloc] initWithStorageCredentials:self.client.credentials storageUri:self.storageUri operationContext:operationContext];
    
    [command setBuildRequest:^ NSMutableURLRequest * (NSURLComponents *urlComponents, NSTimeInterval timeout, AZSOperationContext *operationContext)
    {
        return [AZSBlobRequestFactory setPageBlobSequenceNumberWithNewSequenceNumber:0 isIncrement:YES useMaximum:NO accessCondition:accessCondition urlComponents:urlComponents timeout:timeout operationContext:operationContext];
    }];
    
    [command setAuthenticationHandler:self.client.authenticationHandler];
    
    [command setPreProcessResponse:^id(NSHTTPURLResponse *urlResponse, AZSRequestResult *requestResult, AZSOperationContext *operationContext) {
        NSError *error = [AZSResponseParser preprocessResponseWithResponse:urlResponse requestResult:requestResult operationContext:operationContext];
        if (error)
        {
            return  error;
        }
        
        // TODO: Investigate whether this will overwrite any properties that aren't returned.
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
        self.properties.sequenceNumber = [AZSBlobResponseParser getSequenceNumberWithResponse:urlResponse];;
        return nil;
    }];
    
    [AZSExecutor ExecuteWithStorageCommand:command requestOptions:modifiedOptions operationContext:operationContext completionHandler:^(NSError *error, id result)
    {
        completionHandler(error);
    }];
}

@end