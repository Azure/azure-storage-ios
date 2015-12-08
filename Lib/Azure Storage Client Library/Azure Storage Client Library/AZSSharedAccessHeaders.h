// -----------------------------------------------------------------------------------------
// <copyright file="AZSSharedAccessHeaders.h" company="Microsoft">
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

/** The optional headers that can be returned using SAS.*/
@interface AZSSharedAccessHeaders : NSObject

/** The cache-control header returned. */
@property (strong, AZSNullable) NSString *cacheControl;

/** The content-disposition header returned. */
@property (strong, AZSNullable) NSString *contentDisposition;

/** The content-encoding header returned. */
@property (strong, AZSNullable) NSString *contentEncoding;

/** The content-language header returned. */
@property (strong, AZSNullable) NSString *contentLanguage;

/** The content-type header returned. */
@property (strong, AZSNullable) NSString *contentType;

@end

AZS_ASSUME_NONNULL_END