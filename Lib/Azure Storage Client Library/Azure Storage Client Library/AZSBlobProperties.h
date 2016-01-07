// -----------------------------------------------------------------------------------------
// <copyright file="AZSBlobProperties.h" company="Microsoft">
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

/** A collection of properties for the blob.*/
@interface AZSBlobProperties : NSObject

/** The Cache-Control header for the blob.  Set this, then upload the blob to set it on the service.*/
@property (copy, AZSNullable) NSString *cacheControl;

/** The Content-Disposition header for the blob.  Set this, then upload the blob to set it on the service.*/
@property (copy, AZSNullable) NSString *contentDisposition;

/** The Content-Encoding header for the blob.  Set this, then upload the blob to set it on the service.*/
@property (copy, AZSNullable) NSString *contentEncoding;

/** The Content-Language header for the blob.  Set this, then upload the blob to set it on the service.*/
@property (copy, AZSNullable) NSString *contentLanguage;

/** The size of the blob, as far as the library is aware.  Call downloadAttributes to update.*/
@property (copy, AZSNullable) NSNumber *length;

/** The Content-MD5 header for the blob.  Set this, then upload the blob to set it on the service.*/
@property (copy, AZSNullable) NSString *contentMD5;

/** The Content-Type header for the blob.  Set this, then upload the blob to set it on the service.*/
@property (copy, AZSNullable) NSString *contentType;

/** The eTag of the blob, as far as the library is aware.  Call downloadAttributes to update.*/
@property (copy, AZSNullable) NSString *eTag;

/** The last modified time of the blob, as far as the library is aware.  Call downloadAttributes to update.*/
@property (copy, AZSNullable) NSDate *lastModified;

/** The sequence number of the blob, as far as the library is aware.  Only valid for page blobs.  Call downloadAttributes to update.*/
@property (copy, AZSNullable) NSNumber *sequenceNumber;

/** The blob type - block, page, or append.*/
@property AZSBlobType blobType;

/** The lease status of the blob, as far as the library is aware.  Call downloadAttributes to update.*/
@property AZSLeaseStatus leaseStatus;

/** The lease state of the blob, as far as the library is aware.  Call downloadAttributes to update.*/
@property AZSLeaseState leaseState;

/** The lease duration of the blob, as far as the library is aware.  Call downloadAttributes to update.*/
@property AZSLeaseDuration leaseDuration;

@end

AZS_ASSUME_NONNULL_END