// -----------------------------------------------------------------------------------------
// <copyright file="AZSUriQueryBuilder.m" company="Microsoft">
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

#import "AZSUriQueryBuilder.h"
#import "AZSUtil.h"

@implementation AZSUriQueryBuilder

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        _parameters = [[NSMutableDictionary alloc] init];
    }
    return self;
}

-(void) addWithKey:(NSString*)key value:(NSString*)value
{
    if (value)
    {
        [self.parameters setObject:value forKey:key];
    }
}

-(NSString*) builderAsString
{
    NSString *result = @"";
    
    BOOL first = YES;
    
    for (NSString *key in self.parameters)
    {
        if (first)
        {
            first = NO;
            result = [result stringByAppendingString:@"?"];
        }
        else
        {
            result = [result stringByAppendingString:@"&"];
        }
        
        result = [result stringByAppendingString:key];
        
        NSString *value = [self.parameters objectForKey:key];
        if (value)
        {
            result = [result stringByAppendingString:@"="];
            NSString *encodedvalue = [AZSUtil URLEncodedStringWithString:value];
            result = [result stringByAppendingString:encodedvalue];
        }
    }
    
    return result;
}

-(NSURL *) addToUri:(NSURL*)uri
{
    if (!uri)
    {
        return nil;
    }
    
    NSString *queryToAppend = [self builderAsString];
    
    if (queryToAppend.length > 1)
    {
        queryToAppend = [queryToAppend substringFromIndex:1];
    }
    
    NSString *existingQuery = uri.query;
    
    if (existingQuery && existingQuery.length > 0)
    {
        queryToAppend = [[existingQuery stringByAppendingString:@"&"] stringByAppendingString:queryToAppend];
    }
    
    NSString *originalUriString = uri.absoluteString;
    NSString *newUriString;
    NSRange qIndexRange = [originalUriString rangeOfString:@"?"];
    if (qIndexRange.length != 0)
    {
        newUriString = [[originalUriString substringToIndex:qIndexRange.location + 1] stringByAppendingString:queryToAppend];
    }
    else
    {
        newUriString = [[originalUriString stringByAppendingString:@"?"] stringByAppendingString:queryToAppend];
    }
    
    return [[NSURL alloc] initWithString:newUriString];
}

@end
