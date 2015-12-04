// -----------------------------------------------------------------------------------------
// <copyright file="AZSBlockListItem.m" company="Microsoft">
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

#import "AZSBlockListItem.h"

@interface AZSBlockListItem()

-(instancetype) init AZS_DESIGNATED_INITIALIZER;

@end

@implementation AZSBlockListItem

-(instancetype) init
{
    return nil;
}

-(instancetype) initWithBlockID:(NSString *)blockID blockListMode:(AZSBlockListMode)blockListMode
{
    return [self initWithBlockID:blockID blockListMode:blockListMode size:0];
}

-(instancetype) initWithBlockID:(NSString *)blockID blockListMode:(AZSBlockListMode)blockListMode size:(NSInteger)size
{
    self = [super init];
    if (self)
    {
        _blockID = blockID;
        _blockListMode = blockListMode;
        _size = size;
    }
    
    return self;
}

@end
