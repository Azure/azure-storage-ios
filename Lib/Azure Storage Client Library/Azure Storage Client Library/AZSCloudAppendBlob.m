// -----------------------------------------------------------------------------------------
// <copyright file="AZSCloudAppendBlob.h" company="Microsoft">
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

#import "AZSCloudAppendBlob.h"
#import "AZSStorageUri.h"
#import "AZSBlobProperties.h"
#import "AZSOperationContext.h"
#import "AZSBlobRequestOptions.h"
#import "AZSStorageCommand.h"
#import "AZSBlobRequestFactory.h"
#import "AZSCloudBlobClient.h"
#import "AZSResponseParser.h"
#import "AZSExecutor.h"
#import "AZSBlobResponseParser.h"
#import "AZSUtil.h"
#import "AZSBlobUploadHelper.h"
#import "AZSAccessCondition.h"
#import "AZSBlobOutputStream.h"

@interface AZSAppendBlobUploadFromStreamInputContainer : NSObject

@property (strong) NSInputStream *sourceStream;
@property (strong) AZSCloudAppendBlob *targetBlob;
@property (strong) AZSAccessCondition *accessCondition;
@property (strong) AZSBlobRequestOptions *blobRequestOptions;
@property (strong) AZSOperationContext *operationContext;
@property (copy) void (^completionHandler)(NSError*);

@end

@implementation AZSAppendBlobUploadFromStreamInputContainer

@end

@implementation AZSCloudAppendBlob

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
        self.properties.blobType = AZSBlobTypeAppendBlob;
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
        self.properties.blobType = AZSBlobTypeAppendBlob;
    }
    
    return self;
}

-(void)createWithCompletionHandler:(void (^)(NSError * __AZSNullable))completionHandler
{
    [self createWithAccessCondition:nil requestOptions:nil operationContext:nil completionHandler:completionHandler];
}

-(void)createWithAccessCondition:(AZSNullable AZSAccessCondition *)accessCondition requestOptions:(AZSNullable AZSBlobRequestOptions *)requestOptions operationContext:(AZSNullable AZSOperationContext *)operationContext completionHandler:(void (^)(NSError * __AZSNullable))completionHandler
{
    if (!operationContext)
    {
        operationContext = [[AZSOperationContext alloc] init];
    }
    AZSBlobRequestOptions *modifiedOptions = [[AZSBlobRequestOptions copyOptions:requestOptions] applyDefaultsFromOptions:self.client.defaultRequestOptions];
    AZSStorageCommand *command = [[AZSStorageCommand alloc] initWithStorageCredentials:self.client.credentials storageUri:self.storageUri operationContext:operationContext];
    
    [command setBuildRequest:^ NSMutableURLRequest * (NSURLComponents *urlComponents, NSTimeInterval timeout, AZSOperationContext *operationContext)
    {
        return [AZSBlobRequestFactory createAppendBlobWithBlobProperties:self.properties cloudMetadata:self.metadata accessCondition:accessCondition urlComponents:urlComponents timeout:timeout operationContext:operationContext];
    }];
    
    [command setAuthenticationHandler:self.client.authenticationHandler];
    
    [command setPreProcessResponse:^id(NSHTTPURLResponse *urlResponse, AZSRequestResult *requestResult, AZSOperationContext *operationContext) {
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
}

-(void)createIfNotExistsWithCompletionHandler:(void (^)(NSError * _Nullable, BOOL))completionHandler
{
    [self createIfNotExistsWithAccessCondition:nil requestOptions:nil operationContext:nil completionHandler:completionHandler];
}

-(void)createIfNotExistsWithAccessCondition:(AZSAccessCondition *)accessCondition requestOptions:(AZSBlobRequestOptions *)requestOptions operationContext:(AZSOperationContext *)operationContext completionHandler:(void (^)(NSError * _Nullable, BOOL))completionHandler
{
    [self existsWithAccessCondition:nil requestOptions:requestOptions operationContext:operationContext completionHandler:^(NSError *error, BOOL exists) {
        if (error)
        {
            completionHandler(error, NO);
        }
        else if (exists)
        {
            completionHandler(nil, NO);
        }
        else
        {
            [self createWithAccessCondition:accessCondition requestOptions:requestOptions operationContext:operationContext completionHandler:^(NSError *error) {
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
    }];
}

-(void)appendBlockWithData:(NSData *)blockData contentMD5:(NSString *)contentMD5 completionHandler:(void (^)(NSError * __AZSNullable, NSNumber *appendOffset))completionHandler
{
    [self appendBlockWithData:blockData contentMD5:contentMD5 accessCondition:nil requestOptions:nil operationContext:nil completionHandler:completionHandler];
}

-(void)appendBlockWithData:(NSData *)blockData contentMD5:(NSString *)contentMD5 accessCondition:(AZSNullable AZSAccessCondition *)accessCondition requestOptions:(AZSNullable AZSBlobRequestOptions *)requestOptions operationContext:(AZSNullable AZSOperationContext *)operationContext completionHandler:(void (^)(NSError * __AZSNullable, NSNumber *appendOffset))completionHandler
{
    if (!operationContext)
    {
        operationContext = [[AZSOperationContext alloc] init];
    }
    AZSBlobRequestOptions *modifiedOptions = [[AZSBlobRequestOptions copyOptions:requestOptions] applyDefaultsFromOptions:self.client.defaultRequestOptions];
    AZSStorageCommand *command = [[AZSStorageCommand alloc] initWithStorageCredentials:self.client.credentials storageUri:self.storageUri operationContext:operationContext];
    
    if (requestOptions.useTransactionalMD5 && !(contentMD5))
    {
        contentMD5 = [AZSUtil calculateMD5FromData:blockData];
    }

    [command setBuildRequest:^ NSMutableURLRequest * (NSURLComponents *urlComponents, NSTimeInterval timeout, AZSOperationContext *operationContext)
    {
        return [AZSBlobRequestFactory appendBlockWithLength:blockData.length contentMD5:contentMD5 accessCondition:accessCondition urlComponents:urlComponents timeout:timeout operationContext:operationContext];
    }];
    
    [command setAuthenticationHandler:self.client.authenticationHandler];
    
    __block NSNumber *appendPosition;
    [command setPreProcessResponse:^id(NSHTTPURLResponse *urlResponse, AZSRequestResult *requestResult, AZSOperationContext *operationContext) {
        NSError *error = [AZSResponseParser preprocessResponseWithResponse:urlResponse requestResult:requestResult operationContext:operationContext];
        if (error)
        {
            return error;
        }
        
        [AZSCloudBlob updateEtagAndLastModifiedWithResponse:urlResponse properties:self.properties updateLength:NO];
        self.properties.appendBlobCommittedBlockCount = [AZSBlobResponseParser getAppendCommittedBlockCountWithResponse:urlResponse];
        appendPosition = [AZSBlobResponseParser getAppendPositionWithResponse:urlResponse];
        self.properties.length = [NSNumber numberWithLongLong:appendPosition.longLongValue + blockData.length];
        return nil;
    }];
    
    [command setSource:blockData];
    
    [AZSExecutor ExecuteWithStorageCommand:command requestOptions:modifiedOptions operationContext:operationContext completionHandler:^(NSError *error, id result)
    {
        completionHandler(error, appendPosition);
    }];
}

-(void)runBlobUploadFromStreamWithContainer:(AZSAppendBlobUploadFromStreamInputContainer *)inputContainer
{
    @autoreleasepool {
        NSRunLoop *runLoopForUpload = [NSRunLoop currentRunLoop];
        __block BOOL blobFinished = NO;
        __block NSError *error;
        
        // The blob will already exist in this case.
        AZSBlobUploadHelper *blobUploadHelper = [[AZSBlobUploadHelper alloc] initToAppendBlob:inputContainer.targetBlob createNew:NO accessCondition:inputContainer.accessCondition requestOptions:inputContainer.blobRequestOptions operationContext:inputContainer.operationContext completionHandler:^(NSError * err) {
            error = err;
            blobFinished = YES;
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
        
        [inputContainer.sourceStream close];
        [inputContainer.sourceStream removeFromRunLoop:runLoopForUpload forMode:NSDefaultRunLoopMode];
        if (inputContainer.completionHandler)
        {
            inputContainer.completionHandler(error);
        }
    }
}

-(void)uploadFromStream:(NSInputStream *)sourceStream createNew:(BOOL)createNew completionHandler:(void (^)(NSError * _Nullable))completionHandler
{
    [self uploadFromStream:sourceStream createNew:createNew accessCondition:nil requestOptions:nil operationContext:nil completionHandler:completionHandler];
}

-(void)uploadFromStream:(NSInputStream *)sourceStream createNew:(BOOL)createNew accessCondition:(AZSAccessCondition *)accessCondition requestOptions:(AZSBlobRequestOptions *)requestOptions operationContext:(AZSOperationContext *)operationContext completionHandler:(void (^)(NSError * _Nullable))completionHandler
{
    // TODO: Allow user to give us an input run loop if desired.
    AZSBlobRequestOptions *modifiedOptions = [[AZSBlobRequestOptions copyOptions:requestOptions] applyDefaultsFromOptions:self.client.defaultRequestOptions];
    if (operationContext == nil)
    {
        operationContext = [[AZSOperationContext alloc] init];
    }
    
    if (accessCondition)
    {
        AZSAccessCondition *newAccessCondition = [[AZSAccessCondition alloc] init];
        if (accessCondition.leaseId)
        {
            newAccessCondition.leaseId = accessCondition.leaseId;
        }
        if (accessCondition.appendPosition)
        {
            newAccessCondition.appendPosition = accessCondition.appendPosition;
        }
        if (accessCondition.maxSize)
        {
            newAccessCondition.maxSize = accessCondition.maxSize;
        }
        accessCondition = newAccessCondition;
    }
    
    AZSAppendBlobUploadFromStreamInputContainer *inputContainer = [[AZSAppendBlobUploadFromStreamInputContainer alloc] init];
    inputContainer.sourceStream = sourceStream;
    inputContainer.accessCondition = accessCondition;
    inputContainer.blobRequestOptions = modifiedOptions;
    inputContainer.operationContext = operationContext;
    inputContainer.completionHandler = completionHandler;
    inputContainer.targetBlob = self;
    
    if (createNew)
    {
        [self createWithAccessCondition:accessCondition requestOptions:requestOptions operationContext:operationContext completionHandler:^(NSError * _Nullable error) {
            if (error)
            {
                completionHandler(error);
            }
            else
            {
                [NSThread detachNewThreadSelector:@selector(runBlobUploadFromStreamWithContainer:) toTarget:self withObject:inputContainer];
            }
        }];
    }
    else
    {
        [NSThread detachNewThreadSelector:@selector(runBlobUploadFromStreamWithContainer:) toTarget:self withObject:inputContainer];
    }
    return;
}

-(AZSBlobOutputStream *)createOutputStreamWithCreateNew:(BOOL)createNew
{
    return [self createOutputStreamWithCreateNew:createNew accessCondition:nil requestOptions:nil operationContext:nil];
}

-(AZSBlobOutputStream *)createOutputStreamWithCreateNew:(BOOL)createNew accessCondition:(AZSAccessCondition *)accessCondition requestOptions:(AZSBlobRequestOptions *)requestOptions operationContext:(AZSOperationContext *)operationContext
{
    if (!operationContext)
    {
        operationContext = [[AZSOperationContext alloc] init];
    }
    AZSBlobRequestOptions *modifiedOptions = [[AZSBlobRequestOptions copyOptions:requestOptions] applyDefaultsFromOptions:self.client.defaultRequestOptions];
    
    // TODO: Check access conditions properly (download attributes if necessary.).  Also for UploadFromStream.
    return [[AZSBlobOutputStream alloc] initToAppendBlob:self createNew:createNew accessCondition:accessCondition requestOptions:modifiedOptions operationContext:operationContext];
}

@end