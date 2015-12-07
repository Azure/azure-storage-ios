// -----------------------------------------------------------------------------------------
// <copyright file="AZSNavigationUtil.m" company="Microsoft">
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

#import "AZSNavigationUtil.h"
#import "AZSStorageUri.h"
#import "AZSUtil.h"
#import "AZSStorageCredentials.h"
#import "AZSUriQueryBuilder.h"

@implementation AZSNavigationUtil

+(NSURL*)getServiceClientBaseAddressWithUri: (NSURL *)addressUri usePathStyle:(BOOL)usePathStyle
{
    if (!addressUri)
    {
        return nil;
    }
    
    NSURLComponents *authorityComponents = [[NSURLComponents alloc] init];
    authorityComponents.host = addressUri.host;
    authorityComponents.scheme = addressUri.scheme;
    authorityComponents.path = addressUri.path;
    NSURL *authority = authorityComponents.URL;
    
    if (usePathStyle)
    {
        /*
         TODO:  (convert)
         // Path style uri
         string[] segments = addressUri.Segments;
         if (segments.Length < 2)
         {
         string error = string.Format(CultureInfo.CurrentCulture, SR.PathStyleUriMissingAccountNameInformation);
         throw new ArgumentException("address", error);
         }
         
         return new Uri(authority, segments[1]);
         */
        return nil;
    }
    else
    {
        return authority;
    }
}

+(AZSStorageUri*)getServiceClientBaseAddressWithStorageUri: (AZSStorageUri*)addressUri usePathStyle:(BOOL)usePathStyle
{
    return [[AZSStorageUri alloc] initWithPrimaryUri:[AZSNavigationUtil getServiceClientBaseAddressWithUri:addressUri.primaryUri usePathStyle:usePathStyle] secondaryUri:[AZSNavigationUtil getServiceClientBaseAddressWithUri:addressUri.secondaryUri usePathStyle:usePathStyle]];
}

+(NSMutableArray*)parseBlobQueryAndVerifyWithStorageUri:(AZSStorageUri*)blobAddress
{
    NSMutableArray *primary = [AZSNavigationUtil parseBlobQueryAndVerifyWithUri:blobAddress.primaryUri];
    NSMutableArray *secondary = [AZSNavigationUtil parseBlobQueryAndVerifyWithUri:blobAddress.secondaryUri];
    
    AZSStorageUri *uriResult = [[AZSStorageUri alloc] initWithPrimaryUri:([[primary objectAtIndex:0] isKindOfClass:[NSNull class]] ? nil : [primary objectAtIndex:0]) secondaryUri:([[secondary objectAtIndex:0] isKindOfClass:[NSNull class]] ? nil : [secondary objectAtIndex:0])];

    NSMutableArray *result = [[NSMutableArray alloc] initWithArray:primary];
    [result setObject:uriResult atIndexedSubscript:0];
    
    return result;
}

+(NSMutableArray*)parseBlobQueryAndVerifyWithUri:(NSURL*)blobAddress
{
    if (!blobAddress)
    {
        return nil;
    }
    
    //todo: if relative uri, throw.
    
    NSMutableDictionary *queryParameters = [AZSUtil parseQueryWithQueryString:[blobAddress query]];
    
    NSString *snapshotString = [queryParameters objectForKey:@"snapshot"];
    
    AZSStorageCredentials *creds = [AZSNavigationUtil parseSASQueryWithQueryParameters:queryParameters];
    
    if (!creds)
    {
        // Public access, will be overridden if shared key:
        creds = [[AZSStorageCredentials alloc] init];
    }
    
    NSURLComponents *urlComponents = [[NSURLComponents alloc] init];
    urlComponents.scheme = blobAddress.scheme;
    urlComponents.host = blobAddress.host;
    urlComponents.path = blobAddress.path;
    NSURL *url = urlComponents.URL;
    
    // NSMutableArray *result = [[NSMutableArray alloc] initWithObjects:url, creds, snapshotString, nil];
    NSMutableArray *result = [[NSMutableArray alloc] initWithArray:@[url ? url : [NSNull null], creds ? creds : [NSNull null], snapshotString ? snapshotString : [NSNull null]]];
    
    return result;
}

+(AZSStorageCredentials*) parseSASQueryWithQueryParameters:(NSMutableDictionary*)queryParameters
{
    BOOL sasFound = NO;
    
    NSMutableArray *removeList = [[NSMutableArray alloc] init];
    
    for (NSString *key in queryParameters)
    {
        NSString *lowerKey = [key lowercaseString];
        if ([lowerKey isEqualToString:@"sig"])
        {
            sasFound = YES;
        }
        else if ([lowerKey isEqualToString:@"restype"] ||
                    [lowerKey isEqualToString:@"comp"] ||
                    [lowerKey isEqualToString:@"snapshot"] ||
                    [lowerKey isEqualToString:@"api-version"])
        {
            [removeList addObject:key];
        }
    }
    
    for (NSString *removeParam in removeList)
    {
        [queryParameters removeObjectForKey:removeParam];
    }
    
    AZSUriQueryBuilder *builder = [[AZSUriQueryBuilder alloc] init];
    if (sasFound)
    {
        for (NSString *parameter in queryParameters)
        {
            NSString *value = [queryParameters objectForKey:parameter];
            if (value)
            {
                [builder addWithKey:[parameter lowercaseString] value:value];
            }
        }
        
        return [[AZSStorageCredentials alloc] initWithSASToken:[builder builderAsString]];
    }
    
    return nil;
}

+(NSString *)getContainerNameWithContainerAddress:(NSURL*)uri isPathStyle:(BOOL)isPathStyle
{
    if (isPathStyle)
    {
        if ([[uri pathComponents] count] > 2)
        {
            return [[uri pathComponents] objectAtIndex:2];
        }
        
        //todo throw because we're missing account or container info in this uri.
        return nil;
    }
    else
    {
        return [[uri path] substringFromIndex:1];
    }
    
    return nil;
}


+(NSString *)getBlobNameWithBlobAddress:(NSURL*)uri isPathStyle:(BOOL)isPathStyle
{
    int containerIndex = 1;
    if (isPathStyle)
    {
        containerIndex = 2;
    }
    
    NSArray *uriParts = [uri pathComponents];
    
    if ([uriParts count] - 1 < containerIndex)
    {
        //todo throw because no blob here
    }
    else if ([uriParts count] - 1 == containerIndex)
    {
        //this is either a container or a blob implicitly in root container.
        return [uriParts objectAtIndex:containerIndex];
    }
    else
    {
        NSString *blobName = @"";
        NSMutableArray *mutableParts = [uriParts mutableCopy];
        [mutableParts removeObjectAtIndex:0];
        for (NSString *blobPiece in mutableParts)
        {
            blobName = [[blobName stringByAppendingString:@"/"] stringByAppendingString:blobPiece];
        }
        
        return [blobName substringFromIndex:1];
    }
        
    return nil;
}

@end
