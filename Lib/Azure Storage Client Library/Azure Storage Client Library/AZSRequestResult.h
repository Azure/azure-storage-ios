// -----------------------------------------------------------------------------------------
// <copyright file="AZSRequestResult.h" company="Microsoft">
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

/** An AZSRequestResult contains all data from a single request.
 
 AZSRequestResult is distinguished from AZSOperationContext because the AZSOperationContext
 represents an entire operation, which may contain multiple requests (if the operation retries,
 or requires multiple HTTP requests.)
 */
@interface AZSRequestResult : NSObject

/** Whether this request used the primary or secondary location.
 */
@property AZSStorageLocation targetLocation;

/** The timestamp at which the request started.
 */
@property (copy) NSDate *startTime;

/** Whether or not the response is available.*/
@property BOOL responseAvailable;

/** The end time for this request.*/
@property (copy) NSDate *endTime;

/** The raw NSHTTPURLResponse from this request.*/
@property (strong, AZSNullable) NSHTTPURLResponse *response;

/** The request ID on the service. */
@property (copy, AZSNullable) NSString *serviceRequestID;

/** The timestamp of the request, according to the service.*/
@property (copy, AZSNullable) NSDate *serviceRequestDate;

/** The content-length of the rsponse.*/
@property NSUInteger contentReceivedLength;

/** The Content-MD5 header of the response, if present.
 Note that this is not the MD5 calculated by the library.*/
@property (copy, AZSNullable) NSString *contentReceivedMD5;

/** The etag in the response, if present.*/
@property (copy, AZSNullable) NSString *etag;

/** The error in this request.  This could be a server error (with an HTTP Status Code >= 400), or a client error.*/
@property (copy, AZSNullable) NSError *error;

/** The MD5 that was calculated for the response to this request, if known.
 This is unrelated to the Content-MD5 header of the request.*/
@property (copy, AZSNullable) NSString *calculatedResponseMD5;

// TODO: Should we also include the uploaded MD5?

-(instancetype) initWithStartTime:(NSDate *)startTime location:(AZSStorageLocation)currentLocation AZS_DESIGNATED_INITIALIZER;
-(instancetype) initWithStartTime:(NSDate *)startTime location:(AZSStorageLocation)currentLocation response:(NSHTTPURLResponse * __AZSNullable)response error:(NSError * __AZSNullable)error AZS_DESIGNATED_INITIALIZER;
@end

AZS_ASSUME_NONNULL_END
