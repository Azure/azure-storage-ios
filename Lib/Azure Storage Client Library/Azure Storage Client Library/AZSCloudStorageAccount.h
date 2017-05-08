// -----------------------------------------------------------------------------------------
// <copyright file="AZSCloudStorageAccount.h" company="Microsoft">
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

@class AZSCloudBlobClient;
@class AZSSharedAccessAccountParameters;
@class AZSStorageCredentials;
@class AZSStorageUri;

AZS_ASSUME_NONNULL_BEGIN

/** AZSCloudStorageAccount represents a given Storage Account.
 
 Used primarily for creating AZSCloudClient objects.
 */
@interface AZSCloudStorageAccount : NSObject

/** Parse a CloudStorageAccount from a connection string.
 
 Pass in a connection string containing credentials to connect to the Storage service.
 This method will parse out everything necessary and create the AZSCloudStorageAccount instance,
 as well as the AZSStorageCredentials instance.
 
 Currently, this is the only supported format:
 "DefaultEndpointsProtocol=https;AccountName=<accountName>;AccountKey=<accountKey>"
 
 @param connectionString The connection string to parse.
 @param error A pointer to a NSError, to be set in case of failure.
 @return The newly created AZSCloudStorageAccount object, or nil in case of failure.
 */
+(AZSNullable AZSCloudStorageAccount *)accountFromConnectionString:(NSString *)connectionString error:(NSError **)error;

/** Initialize a fresh AZSCloudStorageAccount object
 
 @param storageCredentials The AZSStorageCredentials object containing connection information.
 @param blobEndpoint An explicit blob endpoint to use in place of the one the account generates automatically.
 @param tableEndpoint An explicit table endpoint to use in place of the one the account generates automatically.
 @param queueEndpoint An explicit queue endpoint to use in place of the one the account generates automatically.
 @param fileEndpoint An explicit file endpoint to use in place of the one the account generates automatically.
 @param error A pointer to a NSError, to be set in case of failure.
 @return The freshly allocated AZSCloudStorageAccount, or nil in case of failure.
 */
-(AZSNullable instancetype) initWithCredentials:(AZSStorageCredentials *)storageCredentials blobEndpoint:(AZSNullable AZSStorageUri *)blobEndpoint tableEndpoint:(AZSNullable AZSStorageUri *)tableEndpoint queueEndpoint:(AZSNullable AZSStorageUri *)queueEndpoint fileEndpoint:(AZSNullable AZSStorageUri *)fileEndpoint error:(NSError **)error AZS_DESIGNATED_INITIALIZER;

/** Initialize a fresh AZSCloudStorageAccount object
 
 @param storageCredentials The AZSStorageCredentials object containing connection information.
 @param useHttps Whether requests should use HTTPS or HTTP.
 @param error A pointer to a NSError, to be set in case of failure.
 @return The freshly allocated AZSCloudStorageAccount, or nil in case of failure.
 */
-(AZSNullable instancetype) initWithCredentials:(AZSStorageCredentials *)storageCredentials useHttps:(BOOL) useHttps error:(NSError **)error;

/** Initialize a fresh AZSCloudStorageAccount object
 
 @param storageCredentials The AZSStorageCredentials object containing connection information.
 @param useHttps Whether requests should use HTTPS or HTTP.
 @param endpointSuffix An explicit endpoint to use in place of the one the account generates automatically.
 @param error A pointer to a NSError, to be set in case of failure.
 @return The freshly allocated AZSCloudStorageAccount, or nil in case of failure.
 */
-(AZSNullable instancetype) initWithCredentials:(AZSStorageCredentials *)storageCredentials useHttps:(BOOL)useHttps endpointSuffix:(NSString *)endpointSuffix error:(NSError **)error AZS_DESIGNATED_INITIALIZER;

/** Create an AZSCloudBlobClient object
 
 @return The freshly created AZSCloudBlobClient.
 */
-(AZSCloudBlobClient *)getBlobClient;

// TODO: Remainder of the account-parsing options.

/** Creates a Shared Access Signature (SAS) token from the given parameters for this Account.
 Note that logging in this method uses the global logger configured statically on the AZSOperationContext as there is no operation being performed to provide a local operation context.
 
 @param parameters The shared access account parameters from which to create the SAS token.
 @param error A pointer to a NSError*, to be set in the event of failure.
 @returns The newly created SAS token.
 */
- (AZSNullable NSString *) createSharedAccessSignatureWithParameters:(AZSSharedAccessAccountParameters *)parameters error:(NSError **)error;

@end

AZS_ASSUME_NONNULL_END
