// -----------------------------------------------------------------------------------------
// <copyright file="AZSExecutor.h" company="Microsoft">
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

@class AZSStorageCommand;
@class AZSStreamDownloadBuffer;
@class AZSRequestOptions;
@class AZSOperationContext;

// This class is reserved for internal use.
// The executor contains all the business logic of actually making/executing HTTP requests.
// Funneling all requests through this one class allows us to implement retry policies, error handling, etc.
@interface AZSExecutor : NSObject <NSURLSessionDelegate, NSURLSessionTaskDelegate, NSURLSessionDataDelegate>

+(void)ExecuteWithStorageCommand:(AZSStorageCommand *)storageCommand requestOptions:(AZSRequestOptions *)requestOptions operationContext:(AZSOperationContext *)operationContext completionHandler:(void (^)(NSError*, id))completionHandler;
+(void)ExecuteWithStorageCommand:(AZSStorageCommand *)storageCommand requestOptions:(AZSRequestOptions *)requestOptions operationContext:(AZSOperationContext *)operationContext downloadBuffer:(AZSStreamDownloadBuffer *)downloadBuffer completionHandler:(void (^)(NSError*, id))completionHandler;

@end