// -----------------------------------------------------------------------------------------
// <copyright file="AZSBlobResponseParser.h" company="Microsoft">
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
@class AZSBlobContainerProperties;
@class AZSBlobProperties;
@class AZSCopyState;
@class AZSOperationContext;

@interface AZSContainerListItem : NSObject
@property (copy) NSString *name;
@property (strong) AZSBlobContainerProperties *properties;
@property (strong) NSMutableDictionary *metadata;
@end

@interface AZSBlobListItem : NSObject
@property (copy) NSString *name;
@property (strong) AZSBlobProperties *properties;
@property (strong) NSMutableDictionary *metadata;
@property (strong) AZSCopyState *blobCopyState;
@property (copy) NSString *snapshotTime;
@end


@interface AZSListContainersResponse : NSObject

@property (strong) NSArray *containerListItems;
@property (strong) NSString *nextMarker;
+(instancetype)parseListContainersResponseWithData:(NSData *)data operationContext:(AZSOperationContext *)operationContext error:(NSError **)error;

@end

@interface AZSListBlobsResponse : NSObject

@property (strong) NSArray *blobListItems;
@property (strong) NSString *nextMarker;
+(instancetype)parseListBlobsResponseWithData:(NSData *)data operationContext:(AZSOperationContext *)operationContext error:(NSError **)error;

@end

@interface AZSDownloadContainerPermissions : NSObject

@property (strong) NSMutableDictionary *storedPolicies;
+(instancetype)parseDownloadContainerPermissionsResponseWithData:(NSData *)data operationContext:(AZSOperationContext *)operationContext error:(NSError **)error;
+(AZSContainerPublicAccessType) createContainerPermissionsWithResponse:(NSHTTPURLResponse *)response operationContext:(AZSOperationContext *)operationContext error:(NSError **)error;

@end

@interface AZSGetBlockListResponse : NSObject

+(NSArray *)parseGetBlockListResponseWithData:(NSData *)data operationContext:(AZSOperationContext *)operationContext error:(NSError **)error;

@end

@interface AZSBlobResponseParser : NSObject
+(AZSBlobContainerProperties *)getContainerPropertiesWithResponse:(NSHTTPURLResponse *)response operationContext:(AZSOperationContext *)operationContext error:(NSError **)error;
+(AZSBlobProperties *)getBlobPropertiesWithResponse:(NSHTTPURLResponse *)response operationContext:(AZSOperationContext *)operationContext error:(NSError **)error;
+(AZSCopyState *)getCopyStateWithResponse:(NSHTTPURLResponse *)response;
+(NSMutableDictionary *)getMetadataWithResponse:(NSHTTPURLResponse *)response;
+(AZSLeaseState)getLeaseStateWithResponse:(NSHTTPURLResponse *)response operationContext:(AZSOperationContext *)operationContext error:(NSError **)error;
+(AZSLeaseStatus)getLeaseStatusWithResponse:(NSHTTPURLResponse *)response operationContext:(AZSOperationContext *)operationContext error:(NSError **)error;
+(AZSLeaseDuration)getLeaseDurationWithResponse:(NSHTTPURLResponse *)response operationContext:(AZSOperationContext *)operationContext error:(NSError **)error;
+(NSNumber *)getRemainingLeaseTimeWithResponse:(NSHTTPURLResponse *)response;

@end