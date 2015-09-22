// -----------------------------------------------------------------------------------------
// <copyright file="AZSCloudClient.h" company="Microsoft">
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

AZS_ASSUME_NONNULL_BEGIN

@class AZSStorageUri;
@class AZSStorageCredentials;
@class AZSRequestOptions;
@protocol AZSAuthenticationHandler;

/** AZSCloudClient is the base class for all service clients.
 
 This class should not be instanciated directly, subclasses should be used instead:
 
 - AZSCloudBlobClient
 
 */
@interface AZSCloudClient : NSObject

/** The AZSStorageUri for this service.*/
@property (strong) AZSStorageUri *storageUri;

@property (strong, AZSNullable) id<AZSAuthenticationHandler> authenticationHandler;

/** The AZSStorageCredentials that this client will use to authenticate requests. */
@property (strong, readonly, nonatomic) AZSStorageCredentials * credentials;

- (instancetype)initWithStorageUri:(AZSStorageUri *) storageUri credentials:(AZSStorageCredentials *) credentials AZS_DESIGNATED_INITIALIZER;

-(void)setAuthenticationHandlerWithCredentials:(AZSStorageCredentials *)credentials;

@end

AZS_ASSUME_NONNULL_END