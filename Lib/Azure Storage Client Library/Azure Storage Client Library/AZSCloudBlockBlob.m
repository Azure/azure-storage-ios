// -----------------------------------------------------------------------------------------
// <copyright file="AZSCloudBlockBlob.m" company="Microsoft">
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
#import "AZSCloudBlockBlob.h"
#import "AZSStorageCommand.h"
#import "AZSBlobRequestFactory.h"
#import "AZSCloudBlobClient.h"
#import "AZSOperationContext.h"
#import "AZSExecutor.h"
#import "AZSBlobRequestOptions.h"
#import "AZSBlobRequestXML.h"
#import "AZSBlobResponseParser.h"
#import "AZSBlobOutputStream.h"
#import "AZSResponseParser.h"
#import "AZSBlobUploadHelper.h"
#import "AZSUtil.h"
#import "AZSErrors.h"
#import "AZSStorageUri.h"


@interface AZSBlobUploadFromStreamInputContainer : NSObject

@property (strong) NSInputStream *sourceStream;
@property (strong) AZSCloudBlockBlob *targetBlob;
@property (strong) AZSAccessCondition *accessCondition;
@property (strong) AZSBlobRequestOptions *blobRequestOptions;
@property (strong) AZSOperationContext *operationContext;
@property (copy) void (^completionHandler)(NSError*);

@end

@implementation AZSBlobUploadFromStreamInputContainer


@end

@implementation AZSCloudBlockBlob

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
        self.properties.blobType = AZSBlobTypeBlockBlob;
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
        self.properties.blobType = AZSBlobTypeBlockBlob;
    }
    
    return self;
}

-(void)runBlobUploadFromStreamWithContainer:(AZSBlobUploadFromStreamInputContainer *)inputContainer
{
    @autoreleasepool {
        NSRunLoop *runLoopForUpload = [NSRunLoop currentRunLoop];
        BOOL __block blobFinished = NO;
        AZSBlobUploadHelper *blobUploadHelper = [[AZSBlobUploadHelper alloc] initToBlockBlob:inputContainer.targetBlob accessCondition:inputContainer.accessCondition requestOptions:inputContainer.blobRequestOptions operationContext:inputContainer.operationContext completionHandler:^(NSError * error) {
            [inputContainer.sourceStream close];
            [inputContainer.sourceStream removeFromRunLoop:runLoopForUpload forMode:NSDefaultRunLoopMode];
            blobFinished = YES;
            if (inputContainer.completionHandler)
            {
                inputContainer.completionHandler(error);
            }
        }];
        
        [inputContainer.sourceStream setDelegate:blobUploadHelper];
        
        [inputContainer.sourceStream scheduleInRunLoop:runLoopForUpload forMode:NSDefaultRunLoopMode];
        
        [inputContainer.sourceStream open];
        
        BOOL runLoopSuccess = YES;
        while ((!blobFinished) && runLoopSuccess)
        {
            // Adding an autoreleasepool here, otherwise the NSDate objects build up until the entire upload has finished.
            @autoreleasepool {
                NSDate *loopUntil = [NSDate dateWithTimeIntervalSinceNow:0.1];
                runLoopSuccess = [runLoopForUpload runMode:NSDefaultRunLoopMode beforeDate:loopUntil];
            }
        }
    }
}

-(void)uploadFromStream:(NSInputStream *)sourceStream completionHandler:(void (^)(NSError* __AZSNullable))completionHandler
{
    [self uploadFromStream:sourceStream accessCondition:nil requestOptions:nil operationContext:nil completionHandler:completionHandler];
}

-(void)uploadFromStream:(NSInputStream *)sourceStream accessCondition:(AZSAccessCondition *)accessCondition requestOptions:(AZSBlobRequestOptions *)requestOptions operationContext:(AZSOperationContext *)operationContext completionHandler:(void (^)(NSError*))completionHandler
{
    // TODO: Allow user to give us an input run loop if desired.
    AZSBlobRequestOptions *modifiedOptions = [[AZSBlobRequestOptions copyOptions:requestOptions] applyDefaultsFromOptions:self.client.defaultRequestOptions];
    if (operationContext == nil)
    {
        operationContext = [[AZSOperationContext alloc] init];
    }

    AZSBlobUploadFromStreamInputContainer *inputContainer = [[AZSBlobUploadFromStreamInputContainer alloc] init];
    inputContainer.sourceStream = sourceStream;
    inputContainer.accessCondition = accessCondition;
    inputContainer.blobRequestOptions = modifiedOptions;
    inputContainer.operationContext = operationContext;
    inputContainer.completionHandler = completionHandler;
    inputContainer.targetBlob = self;
    
    [NSThread detachNewThreadSelector:@selector(runBlobUploadFromStreamWithContainer:) toTarget:self withObject:inputContainer];

    return;
}

-(void)uploadFromData:(NSData *)sourceData completionHandler:(void (^)(NSError *))completionHandler
{
    [self uploadFromData:sourceData accessCondition:nil requestOptions:nil operationContext:nil completionHandler:completionHandler];
}

-(void)uploadFromData:(NSData *)sourceData accessCondition:(AZSAccessCondition *)accessCondition requestOptions:(AZSBlobRequestOptions *)requestOptions operationContext:(AZSOperationContext *)operationContext completionHandler:(void (^)(NSError *))completionHandler
{
    NSInputStream *sourceStream = [NSInputStream inputStreamWithData:sourceData];
    [self uploadFromStream:sourceStream accessCondition:accessCondition requestOptions:requestOptions operationContext:operationContext completionHandler:completionHandler];
}

-(void)uploadFromText:(NSString *)textToUpload completionHandler:(void (^)(NSError *))completionHandler
{
    [self uploadFromText:textToUpload accessCondition:nil requestOptions:nil operationContext:nil completionHandler:completionHandler];
}

-(void)uploadFromText:(NSString *)textToUpload accessCondition:(AZSAccessCondition *)accessCondition requestOptions:(AZSBlobRequestOptions *)requestOptions operationContext:(AZSOperationContext *)operationContext completionHandler:(void (^)(NSError *))completionHandler
{
    NSInputStream *sourceStream = [NSInputStream inputStreamWithData:[textToUpload dataUsingEncoding:NSUTF8StringEncoding]];
    [self uploadFromStream:sourceStream accessCondition:accessCondition requestOptions:requestOptions operationContext:operationContext completionHandler:completionHandler];
}

-(void)uploadFromFileWithPath:(NSString *)filePath completionHandler:(void (^)(NSError *))completionHandler
{
    [self uploadFromFileWithPath:filePath accessCondition:nil requestOptions:nil operationContext:nil completionHandler:completionHandler];
}

-(void)uploadFromFileWithPath:(NSString *)filePath accessCondition:(AZSAccessCondition *)accessCondition requestOptions:(AZSBlobRequestOptions *)requestOptions operationContext:(AZSOperationContext *)operationContext completionHandler:(void (^)(NSError *))completionHandler
{
    NSInputStream *sourceStream = [NSInputStream inputStreamWithFileAtPath:filePath];
    [self uploadFromStream:sourceStream accessCondition:accessCondition requestOptions:requestOptions operationContext:operationContext completionHandler:completionHandler];
}

-(void)uploadFromFileWithURL:(NSURL *)fileURL completionHandler:(void (^)(NSError *))completionHandler
{
    [self uploadFromFileWithURL:fileURL accessCondition:nil requestOptions:nil operationContext:nil completionHandler:completionHandler];
}

-(void)uploadFromFileWithURL:(NSURL *)fileURL accessCondition:(AZSAccessCondition *)accessCondition requestOptions:(AZSBlobRequestOptions *)requestOptions operationContext:(AZSOperationContext *)operationContext completionHandler:(void (^)(NSError *))completionHandler
{
    NSInputStream *sourceStream = [NSInputStream inputStreamWithURL:fileURL];
    [self uploadFromStream:sourceStream accessCondition:accessCondition requestOptions:requestOptions operationContext:operationContext completionHandler:completionHandler];
}

// TODO: Convert the below method into an explicit 'put blob' call.
/*
-(void)uploadFromData:(NSData *)sourceData accessCondition:(AZSAccessCondition *)accessCondition requestOptions:(AZSBlobRequestOptions *)requestOptions operationContext:(AZSOperationContext *)operationContext completionHandler:(void (^)(NSError *))completionHandler
{
    AZSBlobRequestOptions *modifiedOptions = [[AZSBlobRequestOptions copyOptions:requestOptions] applyDefaultsFromOptions:self.client.defaultRequestOptions];
    AZSStorageCommand * command = [[AZSStorageCommand alloc] initWithStorageCredentials:self.client.credentials storageUri:self.storageUri];
    
    NSString *contentMD5 = nil;
    if (requestOptions.useTransactionalMD5 || requestOptions.storeBlobContentMD5)
    {
        unsigned char md5Bytes[CC_MD5_DIGEST_LENGTH];
        CC_MD5(sourceData.bytes, sourceData.length, md5Bytes);
        NSString *contentMD5String = [[[NSData alloc] initWithBytes:md5Bytes length:CC_MD5_DIGEST_LENGTH] base64EncodedStringWithOptions:0];
        
        if (requestOptions.useTransactionalMD5)
        {
            contentMD5 = contentMD5String;
        }
        
        if (requestOptions.storeBlobContentMD5)
        {
            self.properties.contentMD5 = contentMD5String;
        }
    }
    
    [command setBuildRequest:^ NSMutableURLRequest * (NSURLComponents *urlComponents, NSTimeInterval timeout, AZSOperationContext *operationContext)
     {
         return [AZSBlobRequestFactory putBlockBlobWithLength:[sourceData length] blobProperties:self.properties contentMD5:contentMD5 cloudMetadata:self.metadata AccessCondition:accessCondition urlComponents:urlComponents timeout:timeout operationContext:operationContext];
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
    
    [command setSource:sourceData];
    
    if (operationContext == nil)
    {
        operationContext = [[AZSOperationContext alloc] init];
    }
    
    [AZSExecutor ExecuteWithStorageCommand:command requestOptions:modifiedOptions operationContext:operationContext completionHandler:^(NSError *error, id result)
     {
         completionHandler(error);
     }];
    return;
}
 */

-(void)uploadBlockFromData:(NSData *)sourceData blockID:(NSString *)blockID completionHandler:(void (^)(NSError*))completionHandler
{
    [self uploadBlockFromData:sourceData blockID:blockID contentMD5:nil accessCondition:nil requestOptions:nil operationContext:nil completionHandler:completionHandler];
}

-(void)uploadBlockFromData:(NSData *)sourceData blockID:(NSString *)blockID contentMD5:(NSString *)contentMD5 accessCondition:(AZSAccessCondition *)accessCondition requestOptions:(AZSBlobRequestOptions *)requestOptions operationContext:(AZSOperationContext *)operationContext completionHandler:(void (^)(NSError*))completionHandler
{
    if (!operationContext)
    {
        operationContext = [[AZSOperationContext alloc] init];
    }
    AZSBlobRequestOptions *modifiedOptions = [[AZSBlobRequestOptions copyOptions:requestOptions] applyDefaultsFromOptions:self.client.defaultRequestOptions];
    AZSStorageCommand * command = [[AZSStorageCommand alloc] initWithStorageCredentials:self.client.credentials storageUri:self.storageUri operationContext:operationContext];

    if (requestOptions.useTransactionalMD5 && !(contentMD5))
    {
        unsigned char md5Bytes[CC_MD5_DIGEST_LENGTH];
        CC_MD5(sourceData.bytes, (CC_LONG) sourceData.length, md5Bytes);
        contentMD5 = [[[NSData alloc] initWithBytes:md5Bytes length:CC_MD5_DIGEST_LENGTH] base64EncodedStringWithOptions:0];
    }

    [command setBuildRequest:^ NSMutableURLRequest * (NSURLComponents *urlComponents, NSTimeInterval timeout, AZSOperationContext *operationContext)
     {
         return [AZSBlobRequestFactory putBlockWithLength:[sourceData length] blockID:blockID contentMD5:contentMD5 AccessCondition:accessCondition urlComponents:urlComponents timeout:timeout operationContext:operationContext];
     }];
    
    [command setAuthenticationHandler:self.client.authenticationHandler];
    
    [command setPreProcessResponse:^id(NSHTTPURLResponse * urlResponse, AZSRequestResult * requestResult, AZSOperationContext * operationContext) {
        return [AZSResponseParser preprocessResponseWithResponse:urlResponse requestResult:requestResult operationContext:operationContext];
    }];
    
    [command setSource:sourceData];
    
    [AZSExecutor ExecuteWithStorageCommand:command requestOptions:modifiedOptions operationContext:operationContext completionHandler:^(NSError *error, id result)
     {
         completionHandler(error);
     }];
    return;
}

-(void)uploadBlockListFromArray:(NSArray *)blockList completionHandler:(void (^)(NSError*))completionHandler
{
    [self uploadBlockListFromArray:blockList accessCondition:nil requestOptions:nil operationContext:nil completionHandler:completionHandler];
}

-(void)uploadBlockListFromArray:(NSArray *)blockList accessCondition:(AZSAccessCondition *)accessCondition requestOptions:(AZSBlobRequestOptions *)requestOptions operationContext:(AZSOperationContext *)operationContext completionHandler:(void (^)(NSError*))completionHandler
{
    if (!operationContext)
    {
        operationContext = [[AZSOperationContext alloc] init];
    }
    AZSBlobRequestOptions *modifiedOptions = [[AZSBlobRequestOptions copyOptions:requestOptions] applyDefaultsFromOptions:self.client.defaultRequestOptions];
    
    NSError *error;
    if ((requestOptions.storeBlobContentMD5) && !self.properties.contentMD5)
    {
        error = [NSError errorWithDomain:AZSErrorDomain code:AZSEInvalidArgument userInfo:@{NSLocalizedDescriptionKey:@"Cannot store blob content MD5 without content MD5 set on the blob object when doing a Put Block List."}];
        completionHandler(error);
        return;
    }
    
    AZSStorageCommand * command = [[AZSStorageCommand alloc] initWithStorageCredentials:self.client.credentials storageUri:self.storageUri operationContext:operationContext];
    
    NSData *sourceData = [[AZSBlobRequestXML createBlockListXMLFromArray:blockList operationContext:operationContext error:&error] dataUsingEncoding:NSUTF8StringEncoding];
    if (error)
    {
        completionHandler(error);
        return;
    }
    
    NSString *contentMD5 = nil;
    if (requestOptions.useTransactionalMD5)
    {
        unsigned char md5Bytes[CC_MD5_DIGEST_LENGTH];
        CC_MD5(sourceData.bytes, (CC_LONG) sourceData.length, md5Bytes);
        contentMD5 = [[[NSData alloc] initWithBytes:md5Bytes length:CC_MD5_DIGEST_LENGTH] base64EncodedStringWithOptions:0];
    }
    
    [command setBuildRequest:^ NSMutableURLRequest * (NSURLComponents *urlComponents, NSTimeInterval timeout, AZSOperationContext *operationContext)
     {
         return [AZSBlobRequestFactory putBlockListWithLength:[sourceData length] blobProperties:self.properties contentMD5:contentMD5 cloudMetadata:self.metadata AccessCondition:accessCondition urlComponents:urlComponents timeout:timeout operationContext:operationContext];
     }];
    
    [command setAuthenticationHandler:self.client.authenticationHandler];
    
    [command setPreProcessResponse:^id(NSHTTPURLResponse * urlResponse, AZSRequestResult * requestResult, AZSOperationContext * operationContext) {
        NSError *error = [AZSResponseParser preprocessResponseWithResponse:urlResponse requestResult:requestResult operationContext:operationContext];
        if (error)
        {
            return  error;
        }
        
        [AZSCloudBlob updateEtagAndLastModifiedWithResponse:urlResponse properties:self.properties updateLength:NO];
        return nil;
    }];
    
    [command setSource:sourceData];
    
    [AZSExecutor ExecuteWithStorageCommand:command requestOptions:modifiedOptions operationContext:operationContext completionHandler:^(NSError *error, id result)
     {
         completionHandler(error);
     }];
    return;
}

-(void)downloadBlockListFromFilter:(AZSBlockListFilter)blockListFilter completionHandler:(void (^)(NSError *, NSArray *))completionHandler
{
    [self downloadBlockListFromFilter:blockListFilter accessCondition:nil requestOptions:nil operationContext:nil completionHandler:completionHandler];
}

-(void)downloadBlockListFromFilter:(AZSBlockListFilter)blockListFilter accessCondition:(AZSAccessCondition *)accessCondition requestOptions:(AZSBlobRequestOptions *)requestOptions operationContext:(AZSOperationContext *)operationContext completionHandler:(void (^)(NSError *, NSArray *))completionHandler
{
    if (!operationContext)
    {
        operationContext = [[AZSOperationContext alloc] init];
    }
    AZSBlobRequestOptions *modifiedOptions = [[AZSBlobRequestOptions copyOptions:requestOptions] applyDefaultsFromOptions:self.client.defaultRequestOptions];
    AZSStorageCommand * command = [[AZSStorageCommand alloc] initWithStorageCredentials:self.client.credentials storageUri:self.storageUri operationContext:operationContext];
    
    [command setBuildRequest:^ NSMutableURLRequest * (NSURLComponents *urlComponents, NSTimeInterval timeout, AZSOperationContext *operationContext)
     {
         return [AZSBlobRequestFactory getBlockListWithBlockListFilter:blockListFilter snapshotTime:self.snapshotTime accessCondition:accessCondition urlComponents:urlComponents timeout:timeout operationContext:operationContext];
     }];
    
    [command setAuthenticationHandler:self.client.authenticationHandler];
    
    [command setPreProcessResponse:^id(NSHTTPURLResponse * urlResponse, AZSRequestResult * requestResult, AZSOperationContext * operationContext) {
        NSError *error = [AZSResponseParser preprocessResponseWithResponse:urlResponse requestResult:requestResult operationContext:operationContext];
        if (error)
        {
            return error;
        }
        
        [AZSCloudBlob updateEtagAndLastModifiedWithResponse:urlResponse properties:self.properties updateLength:YES];
        return nil;
    }];
    
    [command setPostProcessResponse:^id(NSHTTPURLResponse *urlResponse, AZSRequestResult *requestResult, NSOutputStream *outputStream, AZSOperationContext *operationContext, NSError **error) {
        NSArray *blockListResponse = [AZSGetBlockListResponse parseGetBlockListResponseWithData:[outputStream propertyForKey:NSStreamDataWrittenToMemoryStreamKey] operationContext:operationContext error:error];
        
        if (*error)
        {
            return nil;
        }
        
        return blockListResponse;
    }];

    
    [AZSExecutor ExecuteWithStorageCommand:command requestOptions:modifiedOptions operationContext:operationContext completionHandler:completionHandler];
    return;
}

- (AZSBlobOutputStream *)createOutputStream
{
    return [self createOutputStreamWithAccessCondition:nil requestOptions:nil operationContext:nil];
}

- (AZSBlobOutputStream *)createOutputStreamWithAccessCondition:(AZSAccessCondition *)accessCondition requestOptions:(AZSBlobRequestOptions *)requestOptions operationContext:(AZSOperationContext *)operationContext
{
    if (!operationContext)
    {
        operationContext = [[AZSOperationContext alloc] init];
    }
    AZSBlobRequestOptions *modifiedOptions = [[AZSBlobRequestOptions copyOptions:requestOptions] applyDefaultsFromOptions:self.client.defaultRequestOptions];

    // TODO: Check access conditions properly (download attributes if necessary.).  Also for UploadFromStream.
    return [[AZSBlobOutputStream alloc] initToBlockBlob:self accessCondition:accessCondition requestOptions:modifiedOptions operationContext:operationContext];
}

@end
