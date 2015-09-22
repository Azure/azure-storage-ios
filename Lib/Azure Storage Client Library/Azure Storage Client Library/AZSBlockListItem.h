// -----------------------------------------------------------------------------------------
// <copyright file="AZSBlockListItem.h" company="Microsoft">
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

/** Represents a block in a list of blocks.  The block can be either the result of a GetBlockList operation, or the input
 to a PutBlockList operation.*/
@interface AZSBlockListItem : NSObject

/** The BlockListMode for this block item.  For block items that are the result of a GetBlockList operation, this indicates whether
 this block is committed or uncommitted.  For block items that are input to PutBlockList, this indicates whether the block on
 the service should be pulled from the committed block list, the uncommitted block list, or whichever is most recent.  */
@property AZSBlockListMode blockListMode;

/** The block ID for this block.  Must be base-64 encoded.*/
@property (copy) NSString *blockID;

/** The size of the block.  Only relevant for a GetBlockList operation.*/
@property NSInteger size;

/** Initializes a newly allocated AZSBlockListItem object.
 
 @param blockID The block ID for this block.
 @param blockListMode The BlockListMode for this block.
 @returns The freshly allocated object.
 */
-(instancetype) initWithBlockID:(NSString *)blockID blockListMode:(AZSBlockListMode)blockListMode;

// This method is for use by the library, not externally.
-(instancetype) initWithBlockID:(NSString *)blockID blockListMode:(AZSBlockListMode)blockListMode size:(NSInteger)size AZS_DESIGNATED_INITIALIZER;
@end

AZS_ASSUME_NONNULL_END