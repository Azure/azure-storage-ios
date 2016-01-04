// -----------------------------------------------------------------------------------------
// <copyright file="AZSStorageCredentials.m" company="Microsoft">
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
#import "AZSStorageCredentials.h"
#import "AZSUriQueryBuilder.h"
#import "AZSUtil.h"
#import "AZSStorageUri.h"

@interface AZSStorageCredentials()

@property (strong) AZSUriQueryBuilder *queryBuilder;

-(instancetype)init AZS_DESIGNATED_INITIALIZER;

@end

@implementation AZSStorageCredentials

// This is currently the preferred way to create a StorageCredentials object representing public access, but
// this will be changed in the near future.
- (instancetype)init
{
    self = [super init];
    return self;
}

-(instancetype) initWithAccountName:(NSString *)accountName accountKey:(NSString *)accountKeyString
{
    self = [super init];
    if (self)
    {
        _accountName = accountName;
        _accountKey = [[NSData alloc] initWithBase64EncodedString:accountKeyString options:0];
        _queryBuilder = [[AZSUriQueryBuilder alloc] init];
    }
    
    return self;
}


- (instancetype)initWithSASToken:(NSString *)sasToken
{
    self = [super init];
    if (self)
    {
        _sasToken = sasToken;
        _queryBuilder = [[AZSUriQueryBuilder alloc] init];
        [self updateQueryBuilder];
    }
    
    return self;
}

-(BOOL) isSharedKey
{
    if (self.accountKey)
    {
        return YES;
    }
    else
    {
        return NO;
    }
}

-(BOOL) isSAS
{
    if (self.sasToken)
    {
        return YES;
    }
    else
    {
        return NO;
    }
}

-(void) updateQueryBuilder
{
    self.queryBuilder = [[AZSUriQueryBuilder alloc] init];
    NSMutableDictionary *parameters = [AZSUtil parseQueryWithQueryString:self.sasToken];
    
    for (NSString *key in parameters)
    {
        [self.queryBuilder addWithKey:key value:[parameters objectForKey:key]];
    }
    
    //TODO use targetstorageversion constant.
    [self.queryBuilder addWithKey:AZSCQueryApiVersion value:AZSCTargetStorageVersion];
}

-(NSURL *) transformWithUri:(NSURL *)uri
{
    if (self.isSAS)
    {
        return [self.queryBuilder addToUri:uri];
    }
    else
    {
        return uri;
    }
}

-(AZSStorageUri *) transformWithStorageUri:(AZSStorageUri *)storageUri
{
    if (storageUri)
    {
        return [[AZSStorageUri alloc] initWithPrimaryUri:[self transformWithUri:storageUri.primaryUri] secondaryUri:[self transformWithUri:storageUri.secondaryUri]];
    }
    
    return nil;
}

@end