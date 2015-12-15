// -----------------------------------------------------------------------------------------
// <copyright file="AZSAccessCondition.h" company="Microsoft">
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
#import "AZSEnums.h"

AZS_ASSUME_NONNULL_BEGIN

/** An AZSAccessCondition represents a condition that can be used for blob requests.
 
 An AZSAccessCondition can be used to restrict blob requests - the request will fail unless the
 condition is met.  This is primarily used for parallel / synchronizing scenarios - you can specify 
 (for example) that the request should only succeed if the blob has not been modified since the specified 
 date/time, or if the blob matches a given etag.
 Only one access condition can be set for a given request, not including the lease ID.  (This is a limitation of the library, not the
 Storage Service.)
 */
@interface AZSAccessCondition : NSObject

/** The ETag to match.  The service will fail the request if the ETag doesn't match.
 Use "*" to match any ETag, as long as the object already exists on the service.*/
@property (copy, readonly, AZSNullable) NSString* ifMatchETag;

/** The ETag to not match.  The service will fail the request if the ETag matches this.
 Use "*" to match any ETag, as long as the object already exists on the service.*/
@property (copy, readonly, AZSNullable) NSString* ifNoneMatchETag;

/** The request will fail if the object has not been modified since this date.*/
@property (copy, readonly, AZSNullable) NSDate* ifModifiedSinceDate;

/** The request will fail if the object has been modified since this date.*/
@property (copy, readonly, AZSNullable) NSDate* ifNotModifiedSinceDate;

/** The lease ID for this request.*/
@property (copy, AZSNullable) NSString* leaseId;

/** The sequence number to compare using the sequenceNumberOperator.  The request will fail if the comparison fails.  Page blobs only.*/
@property (copy, readonly, AZSNullable) NSNumber *sequenceNumber;

/** The operator to use to compare the sequence number here and the one on the service.  Page blobs only.*/
@property AZSSequenceNumberOperator sequenceNumberOperator;

/** The request will fail if the append blob will be greater than this after the append operation.  Append block API only.*/
@property (copy, readonly, AZSNullable) NSNumber *maxSize;

/** The request will fail if the append position before appending the current block is not equal to this.  Append block API only.*/
@property (copy, readonly, AZSNullable) NSNumber *appendPosition;

/** Initialize a new AZSAccessCondition object with a 'If-Match' condition.
 
 @param eTag The ETag that must match on the service; otherwise the request will fail.
 */
-(instancetype) initWithIfMatchCondition:(NSString* __AZSNullable)eTag AZS_DESIGNATED_INITIALIZER;

/** Initialize a new AZSAccessCondition object with a 'If-None-Match' condition.
 
 @param eTag The ETag that must not match on the service; otherwise the request will fail.
 */
-(instancetype) initWithIfNoneMatchCondition:(NSString*)eTag AZS_DESIGNATED_INITIALIZER;

/** Initialize a new AZSAccessCondition object with a 'If-Modified-Since' condition.
 
 @param modifiedDate The object on the service must have been modified since this time, otherwise the request will fail.
 */
-(instancetype) initWithIfModifiedSinceCondition:(NSDate*)modifiedDate AZS_DESIGNATED_INITIALIZER;

/** Initialize a new AZSAccessCondition object with a 'If-Not-Modified-Since' condition.
 
 @param modifiedDate The object on the service must not have been modified since this time, otherwise the request will fail.
 */
-(instancetype) initWithIfNotModifiedSinceCondition:(NSDate*)modifiedDate AZS_DESIGNATED_INITIALIZER;

/** Initialize a new AZSAccessCondition object with a 'If-Sequence-Number-Less-Than-Or-Equal-To' condition.*/
-(instancetype) initWithIfSequenceNumberLessThanOrEqualTo:(NSNumber *)sequenceNumber AZS_DESIGNATED_INITIALIZER;

/** Initialize a new AZSAccessCondition object with a 'If-Sequence-Number-Less-Than' condition.*/
-(instancetype) initWithIfSequenceNumberLessThan:(NSNumber *)sequenceNumber AZS_DESIGNATED_INITIALIZER;

/** Initialize a new AZSAccessCondition object with a 'If-Sequence-Number-Equal-To' condition.*/
-(instancetype) initWithIfSequenceNumberEqualTo:(NSNumber *)sequenceNumber AZS_DESIGNATED_INITIALIZER;

/** Initialize a new AZSAccessCondition object with a 'If-Max-Size-Less-Than-Or-Equal-To' condition.*/
-(instancetype) initWithIfMaxSizeLessThanOrEqualTo:(NSNumber *)maxSize AZS_DESIGNATED_INITIALIZER;

/** Initialize a new AZSAccessCondition object with a 'If-Append-Position-Equal-To' condition.*/
-(instancetype) initWithIfAppendPositionEqualTo:(NSNumber *)appendPosition AZS_DESIGNATED_INITIALIZER;

/** Initialize a new AZSAccessCondition object with a lease ID.
 Note that if you wish to specify both a lease ID and another access condition, you must use
 one of the other initializers, and then specify the lease ID afterwards.
 
 @param leaseId The lease ID to specify for the request.*/
-(instancetype) initWithLeaseId:(NSString*)leaseId AZS_DESIGNATED_INITIALIZER;

+(instancetype) cloneWithEtag:(NSString*)etag accessCondition:(AZSNullable AZSAccessCondition*)condition;

@end

AZS_ASSUME_NONNULL_END