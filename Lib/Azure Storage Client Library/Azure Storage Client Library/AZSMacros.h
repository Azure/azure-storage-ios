// -----------------------------------------------------------------------------------------
// <copyright file="AZSMacros.h" company="Microsoft">
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

#ifdef __IPHONE_OS_VERSION_MIN_REQUIRED

// This file contains various macros designed to assist with SWIFT compatibility.  Unfortunately, they don't compile on iOS 7.

#if __IPHONE_OS_VERSION_MIN_REQUIRED >= 80000 // If iOS vervion is at least 8.0

// Note: These are only used correctly in regions of the code that are meant to be user-facing.
// For example, users are expected to use an AZSRequestResults object, but never call its initializer.  Thus,
// the properties of an AZSRequestResults are annotated, but the initializers are not.

#define AZSNullable nullable
#define __AZSNullable __nullable
#define AZS_ASSUME_NONNULL_BEGIN NS_ASSUME_NONNULL_BEGIN
#define AZS_ASSUME_NONNULL_END NS_ASSUME_NONNULL_END
#define AZS_DESIGNATED_INITIALIZER NS_DESIGNATED_INITIALIZER


#else //__IPHONE_OS_VERSION_MIN_REQUIRED >= 80000

#define AZSNullable
#define __AZSNullable
#define AZS_ASSUME_NONNULL_BEGIN
#define AZS_ASSUME_NONNULL_END
#define AZS_DESIGNATED_INITIALIZER

#endif //__IPHONE_OS_VERSION_MIN_REQUIRED >= 80000

#else //def __IPHONE_OS_VERSION_MIN_REQUIRED

#define AZSNullable
#define __AZSNullable
#define AZS_ASSUME_NONNULL_BEGIN
#define AZS_ASSUME_NONNULL_END
#define AZS_DESIGNATED_INITIALIZER

#endif //def __IPHONE_OS_VERSION_MIN_REQUIRED

