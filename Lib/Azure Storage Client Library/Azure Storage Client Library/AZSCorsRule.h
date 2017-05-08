// -----------------------------------------------------------------------------------------
// <copyright file="AZSCorsRule.h" company="Microsoft">
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

#import "AZSEnums.h"
#import "AZSMacros.h"

AZS_ASSUME_NONNULL_BEGIN

/** Represents a Cross-Origin Resource Sharing (CORS) rule.*/
@interface AZSCorsRule : NSObject

/** The domain names allowed via CORS.*/
@property (strong) NSMutableArray *allowedOrigins;

/** The response headers that should be exposed to client via CORS.*/
@property (strong) NSMutableArray *exposedHeaders;

/** The headers allowed to be part of the CORS request.*/
@property (strong) NSMutableArray *allowedHeaders;

/** The HTTP methods permitted to execute.*/
@property AZSCorsHttpMethod allowedHttpMethods;

/** The length of time in seconds that a preflight response should be cached by the browser.*/
@property NSInteger maxAgeInSeconds;

@end

AZS_ASSUME_NONNULL_END
