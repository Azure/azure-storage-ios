// -----------------------------------------------------------------------------------------
// <copyright file="AZSULLRange.h" company="Microsoft">
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

#include "AZSMacros.h"

#ifndef AZSULLRange_h
#define AZSULLRange_h

AZS_ASSUME_NONNULL_BEGIN

/* Unfortunately, we cannot use NSRange, because we need a range struct that is always 64-bit.
 This struct is designed to be as compatible with NSRange as possible.
 All methods are copied from NSRange.h except for intersect, union, and NSStringFromAZSULLRange.
 */
typedef struct _AZSULLRange
{
    uint64_t location;
    uint64_t length;
} AZSULLRange;

typedef AZSULLRange *AZSULLRangePointer;

// Functions that NSRange has, re-implemented for AZSULLRange
NS_INLINE AZSULLRange AZSULLMakeRange(uint64_t loc, uint64_t len) {
    AZSULLRange r;
    r.location = loc;
    r.length = len;
    return r;
}

NS_INLINE uint64_t AZSULLMaxRange(AZSULLRange range) {
    return (range.location + range.length);
}

NS_INLINE BOOL AZSULLLocationInRange(uint64_t loc, AZSULLRange range) {
    return (!(loc < range.location) && (loc - range.location) < range.length) ? YES : NO;
}

NS_INLINE BOOL AZSULLEqualRanges(AZSULLRange range1, AZSULLRange range2) {
    return (range1.location == range2.location && range1.length == range2.length);
}

NS_INLINE AZSULLRange AZSULLUnionRange(AZSULLRange range1, AZSULLRange range2){
    AZSULLRange r;
    r.location = MIN(range1.location, range2.location);
    r.length = MAX(AZSULLMaxRange(range1) - r.location, AZSULLMaxRange(range2) - r.location);
    return r;
}

NS_INLINE AZSULLRange AZSULLIntersectionRange(AZSULLRange range1, AZSULLRange range2) {
    AZSULLRange r;
    r.location = MAX(range1.location, range2.location);
    
    // Avoid underflow errors
    if ((AZSULLMaxRange(range1) <= r.location) || (AZSULLMaxRange(range2) <= r.location)) {
        r.length = 0;
        return r;
    }
        
    r.length = MIN(AZSULLMaxRange(range1) - r.location, AZSULLMaxRange(range2) - r.location);
    return r;
}

NS_INLINE NSString *NSStringFromAZSULLRange(AZSULLRange range) {
    return [NSString stringWithFormat:@"{%llu, %llu}", range.location, range.length];
}

/*
 This is implemented in NSRange.
 Not implementing the from-String method unless it's really needed (it's non-trivial and I don't think we'll need it.)
NS_INLINE AZSULLRange AZSULLRangeFromString(NSString *aString) {
    
}
 */

@interface NSValue (NSValueAZSULLRangeExtensions)
+ (NSValue *)valueWithAZSULLRange:(AZSULLRange)range;
@property (readonly) AZSULLRange AZSULLRangeValue;
@end

@implementation NSValue (NSValueAZSULLRangeExtensions)
+ (NSValue *)valueWithAZSULLRange:(AZSULLRange)value
{
    return [self valueWithBytes:&value objCType:@encode(AZSULLRange)];
}

- (AZSULLRange) AZSULLRangeValue
{
    AZSULLRange value;
    [self getValue:&value];
    return value;
}
@end


// Converting between an AZSULLRange and an NSRange
NS_INLINE AZSULLRange AZSULLRangeFromNSRange(NSRange range) {
    AZSULLRange r;
    r.location = range.location;
    r.length = range.length;
    return r;
}

NS_INLINE NSRange NSRangeFromAZSULLRange(AZSULLRange range) {
    NSRange r;
    if ((range.location > NSUIntegerMax) || (range.length > NSUIntegerMax)) {
        return r;
    }
    r.location = (NSUInteger)range.location;
    r.length = (NSUInteger)range.length;
    return r;
}

AZS_ASSUME_NONNULL_END

#endif /* AZSULLRange_h */