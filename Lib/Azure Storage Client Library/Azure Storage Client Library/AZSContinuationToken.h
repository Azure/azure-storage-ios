// -----------------------------------------------------------------------------------------
// <copyright file="AZSContinuationToken.h" company="Microsoft">
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

#import <Foundation/Foundation.h>
#import "AZSEnums.h"
#import "AZSMacros.h"

AZS_ASSUME_NONNULL_BEGIN

/** Represents a continuation token for listing operations on the service.
 
 An instance of AZSContinuationToken will be returned as part of a Segmented Listing operation
 when there are more results to be enumerated on the service.
 
 For example, here is a code snippet showing how to enumerate all containers on the service:
 
    -(void)listAllContainersWithPrefix:(NSString *)prefix containerList:(NSMutableArray *)allContainers token:(AZSContinuationToken *)token completionHandler:(void (^)(NSError *, NSMutableArray *))completionHandler
    {
        [self.blobClient listContainersSegmentedWithContinuationToken:token prefix:prefix containerListingDetails:AZSContainerListingDetailsNone maxResults:-1 completionHandler:^(NSError * error, AZSContainerResultSegment *resultSegment) {
 
            if (error != nil)
            {
                completionHandler(error, allContainers);
            }
            else 
            {
                [allContainers addObjectsFromArray:resultSegment.results];
                if (resultSegment.continuationToken != nil)
                {
                    [self listAllContainersWithPrefix:prefix containerList:allContainers token:resultSegment.continuationToken completionHandler:completionHandler];
                }
                else
                {
                    completionHandler(error, allContainers);
                }
            }
        }];
    }
 
 And then call this method as such:
 
    [self listAllContainersWithPrefix:self.containerName contanerList:[NSMutableArray arrayWithCapacity:10] token:nil completionHandler:^(NSError * error, NSMutableArray * results) {
        <continuation code>
    }];
 
 Note that the above sample is unsafe to use in the general case, as there is no upper bound for the number of 
 containers in a storage account.
 */
@interface AZSContinuationToken : NSObject

@property (copy) NSString *nextMarker;
@property AZSStorageLocation storageLocation;

+(instancetype) tokenFromString:(NSString *)nextMarker withLocation:(AZSStorageLocation)storageLocation;

@end

AZS_ASSUME_NONNULL_END
