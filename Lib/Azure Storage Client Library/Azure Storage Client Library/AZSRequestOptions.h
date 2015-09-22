// -----------------------------------------------------------------------------------------
// <copyright file="AZSRequestOptions.h" company="Microsoft">
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

/** AZSRequestOptions contains options used for requests that are common to all requests.
 
 AZSRequestOptions is used for configuring the behavior of the Azure Storage Client Library.
 Defaults will be used if any options that are not set, or if a RequestOptions object
 is not provided.
 
 AZSRequestOptions is distinguished from AZSOperationContext classes because the AZSOperationContext represents
 the results from an entire operation and will be populated throughout the operation, while the
 AZSRequestOptions is a set of options that governs how the library makes requests.  AZSRequestOptions instances
 can be reused freely in multiple operations, AZSOperationContext instances should not be.
 
 This class should never be directly instantiated, only subclasses:
 
 - AZSBlobRequestOptions
 
 */
@interface AZSRequestOptions : NSObject


@property (copy, readonly, AZSNullable) NSDate *operationExpiryTime;

/** The server timeout to send with the request(s).
 If the Storage Service takes longer than this for a single request, that request will timeout.*/
@property NSTimeInterval serverTimeout;

/** The maximum amount of data that the library will buffer on download.  If the library is downloading data to an input stream 
 (on a DownloadBlobToStream call, for example), and the stream temporarily does not have enough space, the library will buffer up to this much data.*/
@property NSUInteger maximumDownloadBufferSize;

/** The maximum execution time for this operation.  For multi-request operations, this includes round-trip time for all requests on the operation.
 This also includes retries.*/
@property NSTimeInterval maximumExecutionTime;

//@property AZSStorageLocation locationMode;

// TODO: detect and fix the 'runloop not running' issue and fail gracefully, if this is possible (it may not be).

/** The runloop on which to run the operation.  Can be nil.
 
 Internally, the Azure Storage Client requires a runloop to process any downloaded data.  This applies to all operations that 
 return a body from the service, not just direct blob downloads.  If this is set, then this will be the runloop used to download
 the response.  If this property is nil, the storage client will spin up a new thread and run a runloop on that thread for this purpose.
 
 @warning Note that if this property is set, the caller is responsible for ensuring that the runloop is running.  If the runloop is not
 running, behavior is undefined; in most cases the operation will never complete.
 */
@property (strong, AZSNullable) NSRunLoop *runLoopForDownload;

/** Initializes a new AZSRequestOptions object.
 Once the object is initialized, individual properties can be set.*/
-(instancetype)init AZS_DESIGNATED_INITIALIZER;

+(AZSRequestOptions *)copyOptions:(AZSNullable AZSRequestOptions *)optionsToCopy;
-(instancetype)applyDefaultsFromOptions:(AZSNullable AZSRequestOptions *)sourceOptions;

@end

AZS_ASSUME_NONNULL_END
