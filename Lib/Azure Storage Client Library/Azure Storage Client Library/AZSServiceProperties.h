// -----------------------------------------------------------------------------------------
// <copyright file="AZSServiceProperties.h" company="Microsoft">
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
@class AZSLoggingProperties;
@class AZSMetricsProperties;

AZS_ASSUME_NONNULL_BEGIN

/** Represents the analytics properties for the service*/
@interface AZSServiceProperties : NSObject

/** The service logging properties.*/
@property (strong, AZSNullable) AZSLoggingProperties *logging;

/** The service hour metrics properties.*/
@property (strong, AZSNullable) AZSMetricsProperties *hourMetrics;

/** The service minute metrics properties.*/
@property (strong, AZSNullable) AZSMetricsProperties *minuteMetrics;

/** The Cross Origin Resource Sharing (CORS) properties.*/
@property (strong, AZSNullable) NSMutableArray *corsRules;

/** The default service version, or null if no default is specified.*/
@property (copy, AZSNullable) NSString *defaultServiceVersion;

@end

AZS_ASSUME_NONNULL_END
