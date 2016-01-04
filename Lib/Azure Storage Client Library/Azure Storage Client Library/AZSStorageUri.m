// -----------------------------------------------------------------------------------------
// <copyright file="AZSStorageUri.m" company="Microsoft">
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

#import "AZSConstants.h"
#import "AZSStorageUri.h"

@interface AZSStorageUri()

-(instancetype)init AZS_DESIGNATED_INITIALIZER;

@end

@implementation AZSStorageUri

+ (NSURL *) appendToUrl:(NSURL *)url pathToAppend:(NSString *)pathToAppend
{
    if (url)
    {
        NSURLComponents *components = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
        NSString * path = components.path;
        if (path == nil)
        {
            path = AZSCEmptyString;
        }
        path = [[path stringByAppendingString:@"/"] stringByAppendingString:pathToAppend];
        [components setPath:path];
        return components.URL;
    }
    return nil;
}

+ (AZSStorageUri *) appendToStorageUri:(AZSStorageUri *)storageUri pathToAppend:(NSString *)pathToAppend
{
    return [[AZSStorageUri alloc] initWithPrimaryUri:[AZSStorageUri appendToUrl:storageUri.primaryUri pathToAppend:pathToAppend] secondaryUri:[AZSStorageUri appendToUrl:storageUri.secondaryUri pathToAppend:pathToAppend]];
}

-(instancetype)init
{
    return nil;
}

-(instancetype) initWithPrimaryUri:(NSURL *)primaryUri
{
    return [self initWithPrimaryUri:primaryUri secondaryUri:nil];
}

-(instancetype) initWithPrimaryUri:(NSURL *)primaryUri secondaryUri:(NSURL *)secondaryUri
{
    self = [super init];
    if (self)
    {
        _primaryUri = primaryUri;
        _secondaryUri = secondaryUri;
    }
    return self;
}

-(NSURL *) urlWithLocation:(AZSStorageLocation)storageLocation
{
    if (storageLocation == AZSStorageLocationPrimary)
    {
        return self.primaryUri;
    }
/*    else if (storageLocation == AZSStorageLocationSecondary)
    {
        return self.secondaryUri;
    }
 */
    else
    {
        NSException* myException = [NSException
                                    exceptionWithName:@"NotImplementedException"
                                    reason:@"Not implemented"
                                    userInfo:nil];
        @throw myException;
    }
}

@end