// -----------------------------------------------------------------------------------------
// <copyright file="AZSResultSegment.h" company="Microsoft">
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

@class AZSContinuationToken;

/** AZSResultSegment contains the result of a segmented listing operation.
 
 Segmented listing operations have two return values - the actual results and a continuation token.
 The AZSResultSegment is a wrapper class around those two things.
 */
@interface AZSResultSegment : NSObject

/** The NSArray containing the actual results of the segmented listing operation.
 
 Note that even if the array is empty, if the AZSContinuationToken is populated, there may still be
 more results to list.
 */
@property (strong) NSArray *results;

/** The AZSContinuationToken representing the next set of results.
 
 If this is nil, then there are no further results on the service.
 */
@property (strong, AZSNullable) AZSContinuationToken *continuationToken;

+(instancetype) segmentWithResults:(NSArray *)results continuationToken:(AZSNullable AZSContinuationToken *)continuationToken;

@end

/** An AZSResultSegment that contains AZSCloudBlobContainer objects, the result of a ListContainersSegmented operation.
 */
@interface AZSContainerResultSegment : AZSResultSegment

@end

/** An AZSResultSegment that contains AZSCloudBlob objects and AZSCloudBlobDirectory objects, the result of a ListBlobsSegmented operation.
 
 This class does not inherit from AZSResultSegment due to it containing both blobs and directories.
 */
@interface AZSBlobResultSegment : NSObject

/** The NSArray containing the actual blob results of the segmented listing operation.
 
 Note that even if the array is empty, if the AZSContinuationToken is populated, there may still be
 more results to list.
 */
@property (strong, AZSNullable) NSArray *blobs;

/** The NSArray containing the actual blob directory results of the segmented listing operation.
 
 Note that even if the array is empty, if the AZSContinuationToken is populated, there may still be
 more results to list.
 */
@property (strong, AZSNullable) NSArray *directories;

/** The AZSContinuationToken representing the next set of results.
 
 If this is nil, then there are no further results on the service.
 */
@property (strong, AZSNullable) AZSContinuationToken *continuationToken;

+(instancetype) segmentWithBlobs:(AZSNullable NSArray *)blobs directories:(AZSNullable NSArray *)directories continuationToken:(AZSNullable AZSContinuationToken *)continuationToken;

@end

AZS_ASSUME_NONNULL_END
