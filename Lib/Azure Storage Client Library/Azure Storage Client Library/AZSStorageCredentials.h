// -----------------------------------------------------------------------------------------
// <copyright file="AZSStorageCredentials.h" company="Microsoft">
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

/** AZSStorageCredentials is used to store credentials used to authenticate Storage Requests.
 
 AZSStorageCredentials can be created with a Storage account name and account key for Shared Key access,
 or with a SAS token (forthcoming.)  Sample usage with SharedKey authentication:
 
    AZSStorageCredentials *storageCredentials = [[AZSStorageCredentials alloc] initWithAccountName:<name> accountKey:<key>];
    AZSCloudStorageAccount *storageAccount = [[AZSCloudStorageAccount alloc] initWithCredentials:storageCredentials useHttps:YES];
    AZSCloudBlobClient *blobClient = [storageAccount getBlobClient];
 
 */
@interface AZSStorageCredentials : NSObject

/** The name of the account. */
@property (copy, readonly, AZSNullable) NSString *accountName;

/** The storage key used to access the account.*/
@property (copy, readonly, AZSNullable) NSData *accountKey;

/** The SAS token used to access. */
@property (copy, readonly, AZSNullable) NSString *sasToken;

/** Initializes a newly allocated AZSStorageCredentials object for shared key access
 
 @param accountName The name of the account.
 @param accountKey The account key used for signing requests.
 @return The newly allocated instance.
 */
-(instancetype)initWithAccountName:(NSString *)accountName accountKey:(NSString *) accountKey AZS_DESIGNATED_INITIALIZER;

/** Initializes a newly allocated AZSStorageCredentials object for sas access
 
 @param sasToken The Shared Access Signature token used for access.
 @return The newly allocated instance.
 */
-(instancetype)initWithSASToken:(NSString *)sasToken AZS_DESIGNATED_INITIALIZER;

-(BOOL) isSharedKey;
-(BOOL) isSAS;

-(NSURL *) transformWithUri:(NSURL *)uri;
-(AZSStorageUri *) transformWithStorageUri:(AZSStorageUri *)uri;

@end

AZS_ASSUME_NONNULL_END