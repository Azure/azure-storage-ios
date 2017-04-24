// -----------------------------------------------------------------------------------------
// <copyright file="AZSStorageCommand.h" company="Microsoft">
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
#import "AZSMacros.h"
#import "AZSEnums.h"
@class AZSStorageUri;
@class AZSOperationContext;
@class AZSRequestResult;
@class AZSStorageCredentials;
@class AZSUriQueryBuilder;

@protocol AZSAuthenticationHandler;

@interface AZSStorageCommand : NSObject

@property (nonatomic, strong, readonly) AZSStorageUri *storageUri;
@property (nonatomic, strong, readonly) AZSStorageCredentials *credentials;
@property (nonatomic, strong) AZSUriQueryBuilder *queryBuilder;
@property BOOL calculateResponseMD5;
@property (readonly) AZSAllowedStorageLocation allowedStorageLocation;

@property (copy) NSMutableURLRequest *(^buildRequest)(NSURLComponents *urlComponents, NSTimeInterval timeout, AZSOperationContext *operationContext);
@property (copy) void(^signRequest)(NSMutableURLRequest *request, AZSOperationContext *operationContext);
@property (copy) NSError *(^preProcessResponse)(NSHTTPURLResponse *response, AZSRequestResult *requestResult, AZSOperationContext *operationContext);
@property (copy) id(^postProcessResponse)(NSHTTPURLResponse *response, AZSRequestResult *requestResult, NSOutputStream *outputStream, AZSOperationContext *operationContext, NSError **error);
@property (copy) void(^processError)(NSOutputStream *outputStream, NSError **errorToPopulate, NSError **error);
@property (strong, nonatomic) NSData *source;
@property (strong, nonatomic) NSOutputStream *destinationStream;

-(instancetype) initWithStorageCredentials:(AZSStorageCredentials *)credentials storageUri:(AZSStorageUri *)storageUri operationContext:(AZSOperationContext *)operationContext;
-(instancetype) initWithStorageCredentials:(AZSStorageCredentials *)credentials storageUri:(AZSStorageUri *)storageUri calculateResponseMD5:(BOOL)calculateResponseMD5 operationContext:(AZSOperationContext *)operationContext AZS_DESIGNATED_INITIALIZER;
-(void) setAuthenticationHandler:(id<AZSAuthenticationHandler>)authenticationHandler;
-(void) setAllowedStorageLocation:(AZSAllowedStorageLocation)allowedStorageLocation;
-(void) setAllowedStorageLocation:(AZSAllowedStorageLocation)allowedStorageLocation withLockLocation:(AZSStorageLocation)lockLocation error:(NSError **)error;


@end
