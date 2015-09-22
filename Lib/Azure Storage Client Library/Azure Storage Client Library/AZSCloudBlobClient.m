// -----------------------------------------------------------------------------------------
// <copyright file="AZSCloudBlobClient.m" company="Microsoft">
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

#import "AZSResultSegment.h"
#import "AZSCloudBlobClient.h"
#import "AZSCloudBlobContainer.h"
#import "AZSSharedKeyBlobAuthenticationHandler.h"
#import "AZSNoOpAuthenticationHandler.h"
#import "AZSStorageCommand.h"
#import "AZSBlobRequestFactory.h"
#import "AZSBlobResponseParser.h"
#import "AZSOperationContext.h"
#import "AZSExecutor.h"
#import "AZSContinuationToken.h"
#import "AZSRequestResult.h"
#import "AZSStorageCredentials.h"
#import "AZSResponseParser.h"
#import "AZSBlobRequestOptions.h"

@implementation AZSCloudBlobClient

- (instancetype)initWithStorageUri:(AZSStorageUri *)storageUri credentials:(AZSStorageCredentials *)credentials
{
    self = [super initWithStorageUri:storageUri credentials:credentials];
    return self;
}

- (AZSCloudBlobContainer *)containerReferenceFromName:(NSString *)containerName
{
    AZSCloudBlobContainer *container = [[AZSCloudBlobContainer alloc] initWithName:containerName client:self];
    return container;
}

- (void)listContainersSegmentedWithContinuationToken:(AZSContinuationToken *)continuationToken completionHandler:(void (^) (NSError *, AZSContainerResultSegment *))completionHandler;
{
    return [self listContainersSegmentedWithContinuationToken:continuationToken prefix:nil completionHandler:completionHandler];
}

- (void)listContainersSegmentedWithContinuationToken:(AZSContinuationToken *)continuationToken prefix:(NSString *)prefix completionHandler:(void (^) (NSError *, AZSContainerResultSegment *))completionHandler;
{
    return [self listContainersSegmentedWithContinuationToken:continuationToken prefix:prefix containerListingDetails:AZSContainerListingDetailsNone maxResults:-1 completionHandler:completionHandler];
}

- (void)listContainersSegmentedWithContinuationToken:(AZSContinuationToken *)continuationToken prefix:(NSString *)prefix containerListingDetails:(AZSContainerListingDetails)containerListingDetails maxResults:(NSInteger)maxResults completionHandler:(void (^) (NSError *, AZSContainerResultSegment *))completionHandler
{
    return [self listContainersSegmentedWithContinuationToken:continuationToken prefix:prefix containerListingDetails:containerListingDetails maxResults:maxResults requestOptions:nil operationContext:nil completionHandler:completionHandler];
}

- (void)listContainersSegmentedWithContinuationToken:(AZSContinuationToken *)continuationToken prefix:(NSString *)prefix containerListingDetails:(AZSContainerListingDetails)containerListingDetails maxResults:(NSInteger)maxResults requestOptions:(AZSBlobRequestOptions *)requestOptions operationContext:(AZSOperationContext *)operationContext completionHandler:(void (^) (NSError *, AZSContainerResultSegment *))completionHandler
{
    if (!operationContext)
    {
        operationContext = [[AZSOperationContext alloc] init];
    }
    
    AZSBlobRequestOptions *modifiedOptions = [[AZSBlobRequestOptions copyOptions:requestOptions] applyDefaultsFromOptions:self.defaultRequestOptions];
    AZSStorageCommand * command = [[AZSStorageCommand alloc] initWithStorageCredentials:self.credentials storageUri:self.storageUri operationContext:operationContext];
        
    [command setBuildRequest:^ NSMutableURLRequest * (NSURLComponents *urlComponents, NSTimeInterval timeout, AZSOperationContext *operationContext)
     {
         return [AZSBlobRequestFactory listContainersWithPrefix:prefix containerListingDetails:containerListingDetails maxResults:maxResults continuationToken:continuationToken urlComponents:urlComponents timeout:timeout operationContext:operationContext];
     }];
    
    [command setAuthenticationHandler:self.authenticationHandler];
    
    [command setPreProcessResponse:^id(NSHTTPURLResponse * urlResponse, AZSRequestResult * requestResult, AZSOperationContext * operationContext) {
        return [AZSResponseParser preprocessResponseWithResponse:urlResponse requestResult:requestResult operationContext:operationContext];
    }];
    
    [command setPostProcessResponse:^id(NSHTTPURLResponse *urlResponse, AZSRequestResult *requestResult, NSOutputStream *outputStream, AZSOperationContext *operationContext, NSError **error) {
        AZSListContainersResponse *listContainersResponse = [AZSListContainersResponse parseListContainersResponseWithData:[outputStream propertyForKey:NSStreamDataWrittenToMemoryStreamKey] operationContext:operationContext error:error];
        
        if (*error)
        {
            return nil;
        }
        
        NSMutableArray *results = [NSMutableArray arrayWithCapacity:[listContainersResponse.containerListItems count]];
        for (AZSContainerListItem *containerListItem in listContainersResponse.containerListItems)
        {
            AZSCloudBlobContainer *container = [[AZSCloudBlobContainer alloc] initWithName:containerListItem.name client:self];
            container.properties = containerListItem.properties;
            container.metadata = containerListItem.metadata;
            [results addObject:container];
        }
             
        AZSContinuationToken *continuationToken = nil;
        if (listContainersResponse.nextMarker != nil && listContainersResponse.nextMarker.length > 0)
        {
            continuationToken = [AZSContinuationToken tokenFromString:listContainersResponse.nextMarker withLocation:requestResult.targetLocation];
        }
        return [AZSContainerResultSegment segmentWithResults:results continuationToken:continuationToken];
    }];
    
    [AZSExecutor ExecuteWithStorageCommand:command requestOptions:modifiedOptions operationContext:operationContext completionHandler:completionHandler];
    return;
}

-(void)setAuthenticationHandlerWithCredentials:(AZSStorageCredentials *)credentials
{
    if ([credentials isSharedKey])
    {
        self.authenticationHandler = [[AZSSharedKeyBlobAuthenticationHandler alloc] initWithStorageCredentials:credentials];
    }
    else
    {
        self.authenticationHandler = [[AZSNoOpAuthenticationHandler alloc] init];
    }
}

@end
