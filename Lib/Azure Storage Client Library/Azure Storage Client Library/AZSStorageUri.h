// -----------------------------------------------------------------------------------------
// <copyright file="AZSStorageUri.h" company="Microsoft">
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

/** AZSStorageUri is a wrapper around two NSURL objects used to connect to Storage.
 
 An AZSStorageUri is designed to contain two URLs.  The first is used to connect to the Primary
 endpoint of the Storage Service, used for all requests.  The second, the Secondary URL, is 
 used for read request against RA-GRS accounts if configured properly (functionality forthcoming).
 */
@interface AZSStorageUri : NSObject

/** The primary URL of the Storage Service for this account. */
@property (copy) NSURL *primaryUri;

/** The secondary URL of the Storage Service for this account. */
@property (copy, AZSNullable) NSURL *secondaryUri;

/** Appends a given path to a Storage URI
 
 This method creates a new AZSStorageUri with the given path appended to each URL.  This is used,
 for example, to append a container and blob name to the root Storage Account URI.  Both the 
 primary and secondary URLs will be appended to.
 
 @param storageUri The AZSStorageUri to use as a base
 @param pathToAppend The path to append to the URLs
 @return A new StorageUri with the paths appended.
 */
+(AZSStorageUri *)appendToStorageUri:(AZSStorageUri *)storageUri pathToAppend:(NSString *)pathToAppend;

/** Initializes a fresh AZSStorageUri instance.
 
 @param primaryUri The URL of the Primary endpoint for the target storage account.
 @returns The freshly allocated instance.
 */
-(instancetype) initWithPrimaryUri:(NSURL *)primaryUri;

/** Initializes a fresh AZSStorageUri instance.
 
 @param primaryUri The URL of the Primary endpoint for the target storage account.
 @param secondaryUri The URL of the Secondary endpoint for the target storage account.
 @returns The freshly allocated instance.
 */
-(instancetype) initWithPrimaryUri:(NSURL *)primaryUri secondaryUri:(AZSNullable NSURL *)secondaryUri AZS_DESIGNATED_INITIALIZER;

/** Returns the NSURL associated with the given location.
 
 @param storageLocation The StorageLocation to return the URL from.
 @return The Primary URL or the Secondary URL, depending on the input.
 */
-(AZSNullable NSURL *) urlWithLocation:(AZSStorageLocation)storageLocation;

@end

AZS_ASSUME_NONNULL_END