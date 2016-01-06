// -----------------------------------------------------------------------------------------
// <copyright file="AZSIPRange.h" company="Microsoft">
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

/** A range of IPv4 addresses. Contains a minumum IP, maximum IP, and a string representing the range. */
@interface AZSIPRange : NSObject

/** The minimum IP address for this range, inclusive. */
@property (readonly) struct in_addr ipMinimum;

/** The maximum IP address for this range, inclusive. */
@property (readonly) struct in_addr ipMaximum;

/** The single IP address of range of IP addresses, represented as a string. */
@property (strong, readonly) NSString *rangeString;

/** Creates an IP range using the specified single IP address represented by the given string. The address must be IPv4.
 
 @param ip The single IP address.
 @param error A pointer to a NSError*, to be set in the event of failure.
 @returns The newly initialized IPRange or nil if the given string is invalid.
 */
-(instancetype) initWithSingleIPString:(NSString *)ipString error:(NSError *__autoreleasing *)error;

/** Creates an IP range encompassing the specified minimum and maximum IP addresses represented by the given strings. The addresses must be IPv4.
 
 @param minimum The minimum IP address.
 @param maximum The maximum IP address.
 @param error A pointer to a NSError*, to be set in the event of failure.
 @returns The newly initialized IPRange or nil if the given string is invalid.
 */
-(instancetype) initWithMinIPString:(NSString *)minimumString maxIPString:(NSString *)maximumString error:(NSError *__autoreleasing *)error;

/** Creates an IP range using the specified single IP address.  The address must be IPv4.
 
 @param ip The single IP address.
 @returns The newly initialized IPRange.
 */
-(instancetype) initWithSingleIP:(struct in_addr)ip AZS_DESIGNATED_INITIALIZER;

/** Creates an IP range encompassing the specified minimum and maximum IP addresses.  The addresses must be IPv4.
 
 @param minimum The minimum IP address.
 @param maximum The maximum IP address.
 @returns The newly initialized IPRange.
 */
-(instancetype) initWithMinIP:(struct in_addr)minimum maxIP:(struct in_addr)maximum AZS_DESIGNATED_INITIALIZER;

@end