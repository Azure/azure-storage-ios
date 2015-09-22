// -----------------------------------------------------------------------------------------
// <copyright file="AZSResultSegment.m" company="Microsoft">
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

#import "AZSResultSegment.h"

@implementation AZSResultSegment
+(instancetype) segmentWithResults:(NSArray *)results continuationToken:(AZSContinuationToken *)continuationToken
{
    AZSResultSegment *segment = [[AZSResultSegment alloc] init];
    segment.results = results;
    segment.continuationToken = continuationToken;
    return segment;
}
@end

@implementation AZSContainerResultSegment

@end

@implementation AZSBlobResultSegment

+(instancetype) segmentWithBlobs:(NSArray *)blobs directories:(NSArray *)directories continuationToken:(AZSContinuationToken *)continuationToken
{
    {
        AZSBlobResultSegment *segment = [[AZSBlobResultSegment alloc] init];
        segment.blobs = blobs;
        segment.directories = directories;
        segment.continuationToken = continuationToken;
        return segment;
    }
}

@end