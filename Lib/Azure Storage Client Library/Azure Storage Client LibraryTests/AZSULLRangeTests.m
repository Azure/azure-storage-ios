// -----------------------------------------------------------------------------------------
// <copyright file="AZSULLRangeTests.m" company="Microsoft">
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

#import <XCTest/XCTest.h>
#import "AZSULLRange.h"

@interface AZSULLRangeTests : XCTestCase

@end

@implementation AZSULLRangeTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

-(void)assertRangeCorrectWithRange:(AZSULLRange)range expectedLocation:(uint64_t)location expectedLength:(uint64_t)length {
    XCTAssert(range.location == location, @"Location does not match.");
    XCTAssert(range.length == length, @"Length does not match.");
}

-(void)testAZSULLMakeRange {
    [self assertRangeCorrectWithRange:AZSULLMakeRange(4, 5) expectedLocation:4 expectedLength:5];
    [self assertRangeCorrectWithRange:AZSULLMakeRange(4.3, 5) expectedLocation:4 expectedLength:5]; // Floats and doubles should be silently casted
    [self assertRangeCorrectWithRange:AZSULLMakeRange(400000000000, 5) expectedLocation:400000000000 expectedLength:5];
    [self assertRangeCorrectWithRange:AZSULLMakeRange(400000000000, 8000003000000) expectedLocation:400000000000 expectedLength:8000003000000];
    [self assertRangeCorrectWithRange:AZSULLMakeRange(4, 8000003000000) expectedLocation:4 expectedLength:8000003000000];
}

-(void)testAZSULLMaxRange {
    void(^testMaxRange)(uint64_t loc, uint64_t len) = ^void(uint64_t loc, uint64_t len)
    {
        AZSULLRange range = AZSULLMakeRange(loc, len);
        XCTAssert(AZSULLMaxRange(range) == loc + len, @"Max range value incorrect.");
    };
    
    testMaxRange(0, 0);
    testMaxRange(4, 5);
    testMaxRange(400000000000, 8000003000000);
    testMaxRange(400000000000, 5);
    testMaxRange(4, 8000003000000);
    testMaxRange(-1, -1);
}

-(void)testAZSULLLocationInRange {
    void(^testLocationInRange)(uint64_t loc, uint64_t len, uint64_t locToTest, BOOL expected) = ^void(uint64_t loc, uint64_t len, uint64_t locToTest, BOOL expected)
    {
        AZSULLRange range = AZSULLMakeRange(loc, len);
        XCTAssert(AZSULLLocationInRange(locToTest, range) == expected, @"Location in range test failed.");
    };
    
    testLocationInRange(4, 5, 7, YES);
    testLocationInRange(4, 5, 2, NO);
    testLocationInRange(4, 5, 0, NO);
    testLocationInRange(4, 5, 10, NO);
    testLocationInRange(4, 5, 9, NO);
    testLocationInRange(4, 5, 8, YES);
    testLocationInRange(4, 5, 4, YES);
    testLocationInRange(4, 5, -1, NO);
    testLocationInRange(4, 5, 8.4, YES);
    testLocationInRange(4, 5, 6.5, YES);
    testLocationInRange(400000000000, 8000003000000, 4000000000000, YES);
}

-(void)testAZSULLEqualRanges {
    void(^testEqualRanges)(AZSULLRange r1, AZSULLRange r2, BOOL expected) = ^void(AZSULLRange r1, AZSULLRange r2, BOOL expected)
    {
        XCTAssert(AZSULLEqualRanges(r1, r2) == expected, @"Are ranges equal test fails.");
    };
    
    testEqualRanges(AZSULLMakeRange(4, 5), AZSULLMakeRange(4, 5), YES);
    testEqualRanges(AZSULLMakeRange(4, 5), AZSULLMakeRange(3, 6), NO);
    testEqualRanges(AZSULLMakeRange(4, 5), AZSULLMakeRange(4, 6), NO);
    testEqualRanges(AZSULLMakeRange(4, 5), AZSULLMakeRange(3, 2), NO);
    testEqualRanges(AZSULLMakeRange(4, 5), AZSULLMakeRange(3, 5), NO);
    testEqualRanges(AZSULLMakeRange(4, 5), AZSULLMakeRange(4, 4), NO);
    testEqualRanges(AZSULLMakeRange(4, 5), AZSULLMakeRange(4, -1), NO);
    testEqualRanges(AZSULLMakeRange(400000000000, 8000003000000), AZSULLMakeRange(400000000000, 8000003000000), YES);
    testEqualRanges(AZSULLMakeRange(400000000000, 8000003000000), AZSULLMakeRange(400000000000, 8000003000001), NO);
    testEqualRanges(AZSULLMakeRange(400000000000, 8000003000000), AZSULLMakeRange(400000000001, 8000003000000), NO);
}

-(void)testAZSULLUnionRange {
    void(^testUnionRanges)(AZSULLRange r1, AZSULLRange r2, AZSULLRange expected) = ^void(AZSULLRange r1, AZSULLRange r2, AZSULLRange expected)
    {
        XCTAssertTrue(AZSULLEqualRanges(AZSULLUnionRange(r1, r2), expected), @"Range union incorrect.");
    };
    
    testUnionRanges(AZSULLMakeRange(4, 5), AZSULLMakeRange(4, 5), AZSULLMakeRange(4, 5));
    testUnionRanges(AZSULLMakeRange(4, 5), AZSULLMakeRange(9, 10), AZSULLMakeRange(4, 15));
    testUnionRanges(AZSULLMakeRange(4, 10), AZSULLMakeRange(4, 5), AZSULLMakeRange(4, 10));
    testUnionRanges(AZSULLMakeRange(4, 10), AZSULLMakeRange(5, 6), AZSULLMakeRange(4, 10));
    testUnionRanges(AZSULLMakeRange(4, 10), AZSULLMakeRange(8, 16), AZSULLMakeRange(4, 20));
    testUnionRanges(AZSULLMakeRange(4, 5), AZSULLMakeRange(1, 2), AZSULLMakeRange(1, 8));
    testUnionRanges(AZSULLMakeRange(4, 10), AZSULLMakeRange(2, 6), AZSULLMakeRange(2, 12));
    testUnionRanges(AZSULLMakeRange(400000000000, 8000003000000), AZSULLMakeRange(4000000000000, 80000030000000), AZSULLMakeRange(400000000000, 80000030000000 + 4000000000000 - 400000000000));
    testUnionRanges(AZSULLMakeRange(4000000000000, 80000030000000), AZSULLMakeRange(400000000000, 8000003000000), AZSULLMakeRange(400000000000, 80000030000000 + 4000000000000 - 400000000000));
}

-(void)testAZSULLIntersectionRange {
    void(^testIntersectionRanges)(AZSULLRange r1, AZSULLRange r2, AZSULLRange expected) = ^void(AZSULLRange r1, AZSULLRange r2, AZSULLRange expected)
    {
        if (expected.length == 0)
        {
            XCTAssertTrue(AZSULLIntersectionRange(r1, r2).length == 0, @"Range intersection incorrect when range is not intersecting.");
        }
        else
        {
            XCTAssertTrue(AZSULLEqualRanges(AZSULLIntersectionRange(r1, r2), expected), @"Range intersection incorrect.");
        }
    };

    testIntersectionRanges(AZSULLMakeRange(4, 5), AZSULLMakeRange(4, 5), AZSULLMakeRange(4, 5));
    testIntersectionRanges(AZSULLMakeRange(4, 5), AZSULLMakeRange(9, 10), AZSULLMakeRange(0, 0));
    testIntersectionRanges(AZSULLMakeRange(4, 10), AZSULLMakeRange(4, 5), AZSULLMakeRange(4, 5));
    testIntersectionRanges(AZSULLMakeRange(4, 10), AZSULLMakeRange(5, 6), AZSULLMakeRange(5, 6));
    testIntersectionRanges(AZSULLMakeRange(4, 10), AZSULLMakeRange(8, 16), AZSULLMakeRange(8, 6));
    testIntersectionRanges(AZSULLMakeRange(4, 5), AZSULLMakeRange(1, 2), AZSULLMakeRange(0, 0));
    testIntersectionRanges(AZSULLMakeRange(4, 10), AZSULLMakeRange(2, 6), AZSULLMakeRange(4, 4));
    testIntersectionRanges(AZSULLMakeRange(400000000000, 8000003000000), AZSULLMakeRange(4000000000000, 80000030000000), AZSULLMakeRange(4000000000000, 8000003000000 + 400000000000 - 4000000000000));
    testIntersectionRanges(AZSULLMakeRange(4000000000000, 80000030000000), AZSULLMakeRange(400000000000, 8000003000000), AZSULLMakeRange(4000000000000, 8000003000000 + 400000000000 - 4000000000000));
}

-(void)testNSStringFromAZSULLRange {
    XCTAssertTrue([@"{4, 5}" isEqualToString:NSStringFromAZSULLRange(AZSULLMakeRange(4, 5))], @"Strings not equal.");
    XCTAssertTrue([@"{8, 6}" isEqualToString:NSStringFromAZSULLRange(AZSULLMakeRange(8, 6))], @"Strings not equal.");
    XCTAssertTrue([@"{0, 3}" isEqualToString:NSStringFromAZSULLRange(AZSULLMakeRange(0, 3))], @"Strings not equal.");
    XCTAssertTrue([@"{42, 58}" isEqualToString:NSStringFromAZSULLRange(AZSULLMakeRange(42, 58))], @"Strings not equal.");
    XCTAssertTrue([@"{400000000000, 8000003000000}" isEqualToString:NSStringFromAZSULLRange(AZSULLMakeRange(400000000000, 8000003000000))], @"Strings not equal.");
    XCTAssertTrue([@"{4, 5}" isEqualToString:NSStringFromAZSULLRange(AZSULLMakeRange(4.6, 5.83))], @"Strings not equal.");
}

-(void)testNSValuevalueWithAZSULLRange {
    NSValue *value = [NSValue valueWithAZSULLRange:AZSULLMakeRange(4,5)];
    [self assertRangeCorrectWithRange:value.AZSULLRangeValue expectedLocation:4 expectedLength:5];
    value = [NSValue valueWithAZSULLRange:AZSULLMakeRange(400000000000,8000003000000)];
    [self assertRangeCorrectWithRange:value.AZSULLRangeValue expectedLocation:400000000000 expectedLength:8000003000000];
}

-(void)testRangeConversions {
    XCTAssertTrue(AZSULLEqualRanges(AZSULLMakeRange(4, 5), AZSULLRangeFromNSRange(NSRangeFromAZSULLRange(AZSULLMakeRange(4, 5)))));
    XCTAssertTrue(AZSULLEqualRanges(AZSULLMakeRange(0, 0), AZSULLRangeFromNSRange(NSRangeFromAZSULLRange(AZSULLMakeRange(0, 0)))));
    XCTAssertTrue(AZSULLEqualRanges(AZSULLMakeRange(0, 7), AZSULLRangeFromNSRange(NSRangeFromAZSULLRange(AZSULLMakeRange(0, 7)))));
    
    // This condition is the same condition used NSUInteger, in NSObjCRuntime.h.
    // We use it here to test if NSRange would be too small to contain a 64-bit value.
    #if __LP64__ || TARGET_OS_EMBEDDED || TARGET_OS_IPHONE || TARGET_OS_WIN32 || NS_BUILD_32_LIKE_64
    XCTAssertTrue(AZSULLEqualRanges(AZSULLMakeRange(400000000000, 8000003000000), AZSULLRangeFromNSRange(NSRangeFromAZSULLRange(AZSULLMakeRange(400000000000, 8000003000000)))));
    XCTAssertTrue(AZSULLEqualRanges(AZSULLMakeRange(4, 8000003000000), AZSULLRangeFromNSRange(NSRangeFromAZSULLRange(AZSULLMakeRange(4, 8000003000000)))));
    XCTAssertTrue(AZSULLEqualRanges(AZSULLMakeRange(400000000000, 8), AZSULLRangeFromNSRange(NSRangeFromAZSULLRange(AZSULLMakeRange(400000000000, 8)))));
    #else
    XCTAssertTrue(AZSULLEqualRanges(AZSULLMakeRange(0, 0), AZSULLRangeFromNSRange(NSRangeFromAZSULLRange(AZSULLMakeRange(400000000000, 8000003000000)))));
    XCTAssertTrue(AZSULLEqualRanges(AZSULLMakeRange(0, 0), AZSULLRangeFromNSRange(NSRangeFromAZSULLRange(AZSULLMakeRange(4, 8000003000000)))));
    XCTAssertTrue(AZSULLEqualRanges(AZSULLMakeRange(0, 0), AZSULLRangeFromNSRange(NSRangeFromAZSULLRange(AZSULLMakeRange(400000000000, 8)))));
    #endif
}

@end