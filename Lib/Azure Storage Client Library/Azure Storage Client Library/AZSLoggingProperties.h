// -----------------------------------------------------------------------------------------
// <copyright file="AZSLoggingProperties.h" company="Microsoft">
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

/** Represents the logging properties for the analytics service*/
@interface AZSLoggingProperties : NSObject

/** The analytics version to use.*/
@property (copy) NSString *version;

/** Represents which storage operations should be logged.*/
@property AZSLoggingOperation logOperationTypes;

/** Represents the duration of the retention policty for the logging data.*/
@property (AZSNullable) NSNumber *retentionIntervalInDays;

@end

AZS_ASSUME_NONNULL_END
