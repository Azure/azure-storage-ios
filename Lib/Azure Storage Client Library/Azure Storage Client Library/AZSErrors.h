// -----------------------------------------------------------------------------------------
// <copyright file="AZSErrors.h" company="Microsoft">
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

#ifndef __AZS_ERRORS_DEFINED__
#define __AZS_ERRORS_DEFINED__
FOUNDATION_EXPORT NSString *const AZSErrorDomain;
FOUNDATION_EXPORT NSString *const AZSInnerErrorString;


#define AZSEInvalidArgument 1
#define AZSEURLSessionClientError 2
#define AZSEServerError 3
#define AZSEMD5Mismatch 4
#define AZSEClientTimeout 5
#define AZSEParseError 6
#define AZSEXMLCreationError 7
#define AZSEOutputStreamError 8
#define AZSEOutputStreamFull 9

#endif //__AZS_ERRORS_DEFINED__