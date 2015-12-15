// -----------------------------------------------------------------------------------------
// <copyright file="AZSCloudBlobDirectory.h" company="Microsoft">
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

#import "AZSCloudBlobDirectory.h"
#import "AZSCloudBlobContainer.h"
#import "AZSCloudBlobClient.h"
#import "AZSStorageUri.h"
#import "AZSCloudBlockBlob.h"

@interface AZSCloudBlobDirectory()

-(instancetype)init AZS_DESIGNATED_INITIALIZER;

@end

@implementation AZSCloudBlobDirectory

- (instancetype)init
{
    return nil;
}

- (instancetype)initWithDirectoryName:(NSString *)directoryName container:(AZSCloudBlobContainer *)container
{
    self = [super init];
    if (self)
    {
        if (!directoryName)
        {
            directoryName = AZSCEmptyString;
        }
        
        NSRange lastDelimiterRange = [directoryName rangeOfString:container.client.directoryDelimiter options:NSBackwardsSearch];
        
        if ((directoryName.length == 0) || (lastDelimiterRange.location + lastDelimiterRange.length == directoryName.length))
        {
            _name = directoryName;
        }
        else
        {
            _name = [directoryName stringByAppendingString:container.client.directoryDelimiter];
        }
        _storageUri = [AZSStorageUri appendToStorageUri:container.storageUri pathToAppend:_name];
        _blobContainer = container;
    }
    
    return self;
}

- (AZSCloudBlobClient *)client
{
    return self.blobContainer.client;
}

- (AZSCloudBlockBlob *)blockBlobReferenceFromName:(NSString *)blobName snapshotTime:(NSString *)snapshotTime
{
    AZSCloudBlockBlob *blockBlob = [[AZSCloudBlockBlob alloc] initWithContainer:self.blobContainer name:[self.name stringByAppendingString:blobName] snapshotTime:snapshotTime];
    return blockBlob;
}

- (AZSCloudBlockBlob *)blockBlobReferenceFromName:(NSString *)blobName
{
    return [self blockBlobReferenceFromName:blobName snapshotTime:nil];
}

- (AZSCloudBlobDirectory *)subdirectoryReferenceFromName:(NSString *)subdirectoryName
{
    return [self.blobContainer directoryReferenceFromName:[self.name stringByAppendingString:subdirectoryName]];
}

- (AZSCloudBlobDirectory *)parentReference
{
    NSRange lastRange = [self.name rangeOfString:self.blobContainer.client.directoryDelimiter options:NSBackwardsSearch];
    if (lastRange.location == NSNotFound)
    {
        return [self.blobContainer directoryReferenceFromName:AZSCEmptyString];
    }
    else
    {
        NSString *parentDirectoryNameCandidate = [self.name substringToIndex:lastRange.location];
        NSRange secondRange = [parentDirectoryNameCandidate rangeOfString:self.blobContainer.client.directoryDelimiter options:NSBackwardsSearch];
        
        if (secondRange.location == NSNotFound)
        {
            return [self.blobContainer directoryReferenceFromName:AZSCEmptyString];
        }
        else
        {
            return [self.blobContainer directoryReferenceFromName:[parentDirectoryNameCandidate substringToIndex:secondRange.location]];
        }
    }
}

- (void)listBlobsSegmentedWithContinuationToken:(AZSNullable AZSContinuationToken *)token useFlatBlobListing:(BOOL)useFlatBlobListing blobListingDetails:(AZSBlobListingDetails)blobListingDetails maxResults:(NSInteger)maxResults accessCondition:(AZSNullable AZSAccessCondition *)accessCondition requestOptions:(AZSNullable AZSBlobRequestOptions *)requestOptions operationContext:(AZSNullable AZSOperationContext *)operationContext completionHandler:(void (^)(NSError * __AZSNullable, AZSBlobResultSegment * __AZSNullable))completionHandler
{
    [self.blobContainer listBlobsSegmentedWithContinuationToken:token prefix:self.name useFlatBlobListing:useFlatBlobListing blobListingDetails:blobListingDetails maxResults:maxResults accessCondition:accessCondition requestOptions:requestOptions operationContext:operationContext completionHandler:completionHandler];
}

- (void)listBlobsSegmentedWithContinuationToken:(AZSNullable AZSContinuationToken *)token useFlatBlobListing:(BOOL)useFlatBlobListing blobListingDetails:(AZSBlobListingDetails)blobListingDetails maxResults:(NSInteger)maxResults completionHandler:(void (^)(NSError * __AZSNullable, AZSBlobResultSegment * __AZSNullable))completionHandler;
{
    [self listBlobsSegmentedWithContinuationToken:token useFlatBlobListing:useFlatBlobListing blobListingDetails:blobListingDetails maxResults:maxResults accessCondition:nil requestOptions:nil operationContext:nil completionHandler:completionHandler];
}

@end