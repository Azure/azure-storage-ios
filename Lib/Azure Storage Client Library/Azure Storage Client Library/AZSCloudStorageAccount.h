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

@class AZSStorageCredentials;
@class AZSCloudBlobClient;
@class AZSStorageUri;

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
 @return The newly created AZSCloudStorageAccount object.
 */
+(AZSCloudStorageAccount *)accountFromConnectionString:(NSString *)connectionString;

/** Initialize a fresh AZSStorageCredentials object
 
 @param storageCredentials The AZSStorageCredentials object contianing connection information
 @param useHttps Whether requests should use HTTPS or HTTP
 @return The freshly allocated AZSCloudStorageAccount.
 */
-(instancetype)initWithCredentials:(AZSStorageCredentials *)storageCredentials useHttps:(BOOL) useHttps;
-(instancetype) initWithCredentials:(AZSStorageCredentials *)storageCredentials blobEndpoint:(AZSStorageUri *)blobEndpoint tableEndpoint:(AZSStorageUri *)tableEndpoint queueEndpoint:(AZSStorageUri *)queueEndpoint fileEndpoint:(AZSStorageUri *)fileEndpoint;
-(instancetype) initWithCredentials:(AZSStorageCredentials *)storageCredentials useHttps:(BOOL)useHttps endpointSuffix:(NSString *)endpointSuffix AZS_DESIGNATED_INITIALIZER;


/** Create an AZSCloudBlobClient object
 
 @return The freshly created AZSCloudBlobClient.
 */
-(AZSCloudBlobClient *)getBlobClient;

// TODO: Remainder of the account-parsing options.
@end
