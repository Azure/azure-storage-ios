// -----------------------------------------------------------------------------------------
// <copyright file="AZSBlobRequestOptions.h" company="Microsoft">
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

#import "AZSRequestOptions.h"
AZS_ASSUME_NONNULL_BEGIN

/** AZSBlobRequestOptions contains options used for requests to the blob service.
 
 AZSBlobRequestOptions is used for configuring the behavior of blob requests.
 Defaults will be used if any options that are not set, or if a AZSBlobRequestOptions object
 is not provided.
 */
@interface AZSBlobRequestOptions : AZSRequestOptions

/** If YES, all operations that support it will calculate the MD5 of the message bodies on both the client
 and the service, to validate that there were no errors in transmission.  This has nothing to do with the content-MD5
 header stored on a blob.*/
@property BOOL useTransactionalMD5;

/** If YES, when uploading a blob, the content-MD5 header will be stored along with the blob.  If one is not supplied,
 the library will calculate one where possible.*/
@property BOOL storeBlobContentMD5;

/** If YES, the library will not calculate and validate the MD5 when downloading a blob.*/
@property BOOL disableContentMD5Validation;

/** The number of simultaneous outstanding block uploads to permit when uploading a blob as a series of blocks.*/
@property NSInteger parallelismFactor;

/** If YES, when uploading an append blob in a streaming fashion, conditional errors should be ignored.
 
 When uploading append blobs in a streaming fashion, an append-offset conditional header is used to avoid duplicate blocks.
 If this is set to YES, errors from the append-offset header will be ignored when the error is coming from a block already being written to the service.
 Only set this to YES if there is no possiblity of multiple writers writing to the blob simultaneously.  Otherwise, data corruption can occur.
 */
@property BOOL absorbConditionalErrorsOnRetry;

// TODO: Implement logic to upload a blob as a single Put Blob call if below the below threshold.
//@property NSInteger *singleBlobUploadThreshold;

/** Initializes a new AZSBlobRequestOptions object.
 Once the object is initialized, individual properties can be set.*/
-(instancetype)init AZS_DESIGNATED_INITIALIZER;
+(AZSBlobRequestOptions *)copyOptions:(AZSNullable AZSBlobRequestOptions *)optionsToCopy;
-(instancetype)applyDefaultsFromOptions:(AZSNullable AZSBlobRequestOptions *)sourceOptions;

@end
AZS_ASSUME_NONNULL_END
