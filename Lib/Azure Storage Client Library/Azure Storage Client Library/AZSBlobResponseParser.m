// -----------------------------------------------------------------------------------------
// <copyright file="AZSBlobResponseParser.m" company="Microsoft">
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

#import "AZSBlobContainerPermissions.h"
#import "AZSBlobResponseParser.h"
#import "AZSBlockListItem.h"
#import "AZSBlobContainerProperties.h"
#import "AZSUtil.h"
#import "AZSEnums.h"
#import "AZSBlobProperties.h"
#import "AZSCopyState.h"
#import "AZSResponseParser.h"
#import "AZSOperationContext.h"
#import "AZSSharedAccessPolicy.h"
#import "AZSSharedAccessSignatureHelper.h"
#import "AZSErrors.h"

@implementation AZSContainerListItem

-(instancetype)init
{
    self = [super init];
    if (self)
    {
        _properties = [[AZSBlobContainerProperties alloc] init];
        _metadata = [NSMutableDictionary dictionaryWithCapacity:3];
    }
    return self;
}

@end

@implementation AZSBlobListItem

-(instancetype)init
{
    self = [super init];
    if (self)
    {
        _properties = [[AZSBlobProperties alloc] init];
        _metadata = [NSMutableDictionary dictionaryWithCapacity:3];
        _blobCopyState = [[AZSCopyState alloc] init];
    }
    return self;
}

@end


@implementation AZSListContainersResponse

+(instancetype)parseListContainersResponseWithData:(NSData *)data operationContext:(AZSOperationContext *)operationContext error:(NSError **)error
{
    AZSStorageXMLParserDelegate *parserDelegate = [[AZSStorageXMLParserDelegate alloc] init];
    
    NSXMLParser *parser = [[NSXMLParser alloc] initWithData:data];
    parser.shouldProcessNamespaces = NO;
    
    __block NSMutableArray *containers = [NSMutableArray arrayWithCapacity:10];
    __block AZSContainerListItem *currentContainer = [[AZSContainerListItem alloc] init];
    __block NSMutableArray *elementStack = [NSMutableArray arrayWithCapacity:10];
    __block NSMutableString *builder = [[NSMutableString alloc] init];
    __block NSString *nextMarker = nil;
    
    parserDelegate.parseBeginElement = ^(NSXMLParser *parser, NSString *elementName,NSDictionary *attributeDict)
    {
        [operationContext logAtLevel:AZSLogLevelDebug withMessage:@"Beginning to parse element with name = %@", elementName];
        [elementStack addObject:elementName];
        if ([builder length] > 0)
        {
            builder = [[NSMutableString alloc] init];
        }
    };
    
    parserDelegate.parseEndElement = ^(NSXMLParser *parser, NSString *elementName)
    {
        [operationContext logAtLevel:AZSLogLevelDebug withMessage:@"Ending to parse element with name = %@", elementName];
        NSString *currentNode = elementStack.lastObject;
        [elementStack removeLastObject];
        
        if (![elementName isEqualToString:currentNode])
        {
            // Malformed XML
            [parser abortParsing];
        }
        
        NSString *parentNode = elementStack.lastObject;
        if ([parentNode isEqualToString:@"Containers"])
        {
            if ([currentNode isEqualToString:@"Container"])
            {
                [containers addObject:currentContainer];
                currentContainer = [[AZSContainerListItem alloc] init];
            }
        }
        else if ([parentNode isEqualToString:@"EnumerationResults"])
        {
            if ([currentNode isEqualToString:@"NextMarker"])
            {
                if (builder.length > 0)
                {
                    nextMarker = builder;
                }
            }
            
            builder = [[NSMutableString alloc] init];
        }
        else if ([parentNode isEqualToString:@"Container"])
        {
            if ([currentNode isEqualToString:@"Name"])
            {
                currentContainer.name = builder;
            }
            
            builder = [[NSMutableString alloc] init];
        }
        else if ([parentNode isEqualToString:@"Properties"])
        {
            if ([currentNode isEqualToString:@"Last-Modified"])
            {
                currentContainer.properties.lastModified = [[AZSUtil dateFormatterWithRFCFormat] dateFromString:builder];
            }
            else if ([currentNode isEqualToString:@"Etag"])
            {
                currentContainer.properties.eTag = builder;
            }
            else if ([currentNode isEqualToString:@"LeaseStatus"])
            {
                if ([builder isEqualToString:@"locked"])
                {
                    currentContainer.properties.leaseStatus = AZSLeaseStatusLocked;
                }
                else if ([builder isEqualToString:@"unlocked"])
                {
                    currentContainer.properties.leaseStatus = AZSLeaseStatusUnlocked;
                }
            }
            else if ([currentNode isEqualToString:@"LeaseState"])
            {
                if ([builder isEqualToString:@"available"])
                {
                    currentContainer.properties.leaseState = AZSLeaseStateAvailable;
                }
                else if ([builder isEqualToString:@"leased"])
                {
                    currentContainer.properties.leaseState = AZSLeaseStateLeased;
                }
                else if ([builder isEqualToString:@"expired"])
                {
                    currentContainer.properties.leaseState = AZSLeaseStateExpired;
                }
                else if ([builder isEqualToString:@"breaking"])
                {
                    currentContainer.properties.leaseState = AZSLeaseStateBreaking;
                }
                else if ([builder isEqualToString:@"broken"])
                {
                    currentContainer.properties.leaseState = AZSLeaseStateBroken;
                }
            }
            else if ([currentNode isEqualToString:@"LeaseDuration"])
            {
                if ([builder isEqualToString:@"infinite"])
                {
                    currentContainer.properties.leaseDuration = AZSLeaseDurationInfinite;
                }
                else if ([builder isEqualToString:@"fixed"])
                {
                    currentContainer.properties.leaseDuration = AZSLeaseDurationFixed;
                }
            }
            
            builder = [[NSMutableString alloc] init];
        }
        else if ([parentNode isEqualToString:@"Metadata"])
        {
            [currentContainer.metadata setValue:builder forKey:currentNode];
            
            builder = [[NSMutableString alloc] init];
        }
    };
    
    parserDelegate.foundCharacters = ^(NSXMLParser *parser, NSString *characters)
    {
        [operationContext logAtLevel:AZSLogLevelDebug withMessage:@"Found characters = %@", characters];
        [builder appendString:characters];
    };

    parser.delegate = parserDelegate;
    
    BOOL parseSuccessful = [parser parse];
    if (!parseSuccessful)
    {
        *error = [NSError errorWithDomain:AZSErrorDomain code:AZSEParseError userInfo:nil];
        [operationContext logAtLevel:AZSLogLevelError withMessage:@"Parse unsuccessful for list containers response."];
        return nil;
    }
    
    AZSListContainersResponse *listContainersResponse = [[AZSListContainersResponse alloc] init];
    listContainersResponse.containerListItems = containers;
    listContainersResponse.nextMarker = nextMarker;
    return listContainersResponse;
}

@end

@implementation AZSListBlobsResponse

+(instancetype)parseListBlobsResponseWithData:(NSData *)data operationContext:(AZSOperationContext *)operationContext error:(NSError **)error
{
    AZSStorageXMLParserDelegate *parserDelegate = [[AZSStorageXMLParserDelegate alloc] init];
    
    NSXMLParser *parser = [[NSXMLParser alloc] initWithData:data];
    parser.shouldProcessNamespaces = NO;
    
    __block NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
    __block NSMutableArray *blobListItems = [NSMutableArray arrayWithCapacity:10];
    __block AZSBlobListItem *currentBlobItem = [[AZSBlobListItem alloc] init];
    __block NSMutableArray *elementStack = [NSMutableArray arrayWithCapacity:10];
    __block NSMutableString *builder = [[NSMutableString alloc] init];
    __block NSString *nextMarker = nil;
    __block NSDictionary *currentAttributes = nil;

    parserDelegate.parseBeginElement = ^(NSXMLParser *parser, NSString *elementName,NSDictionary *attributeDict)
    {
        [operationContext logAtLevel:AZSLogLevelDebug withMessage:@"Beginning to parse element with name = %@", elementName];
        [elementStack addObject:elementName];
        if ([builder length] > 0)
        {
            builder = [[NSMutableString alloc] init];
        }
        currentAttributes = attributeDict;
    };

    parserDelegate.parseEndElement = ^(NSXMLParser *parser, NSString *elementName)
    {
        [operationContext logAtLevel:AZSLogLevelDebug withMessage:@"Ending to parse element with name = %@", elementName];
        NSString *currentNode = elementStack.lastObject;
        [elementStack removeLastObject];
        
        if (![elementName isEqualToString:currentNode])
        {
            // Malformed XML
            [parser abortParsing];
        }
        
        NSString *parentNode = elementStack.lastObject;
        if ([parentNode isEqualToString:@"Blobs"])
        {
            if ([currentNode isEqualToString:@"Blob"])
            {
                [blobListItems addObject:currentBlobItem];
                currentBlobItem = [[AZSBlobListItem alloc] init];
            }
            else if ([currentNode isEqualToString:@"BlobPrefix"])
            {
                // TODO: implement once we have blob directory support
                currentBlobItem = [[AZSBlobListItem alloc] init];
            }
        }
        else if ([parentNode isEqualToString:@"Blob"])
        {
            if ([currentNode isEqualToString:@"Name"])
            {
                currentBlobItem.name = builder;
            }
            else if ([currentNode isEqualToString:@"Snapshot"])
            {
                currentBlobItem.snapshotTime = builder;
            }
            
            builder = [[NSMutableString alloc] init];
        }
        else if ([parentNode isEqualToString:@"Properties"])
        {
            if ([currentNode isEqualToString:@"Last-Modified"])
            {
                currentBlobItem.properties.lastModified = [[AZSUtil dateFormatterWithRFCFormat] dateFromString:builder];
            }
            else if ([currentNode isEqualToString:@"Etag"])
            {
                currentBlobItem.properties.eTag = builder;
            }
            else if ([currentNode isEqualToString:@"Content-Length"])
            {
                currentBlobItem.properties.length = [numberFormatter numberFromString:builder];
            }
            else if ([currentNode isEqualToString:@"Content-Type"])
            {
                currentBlobItem.properties.contentType = builder;
            }
            else if ([currentNode isEqualToString:@"Content-Encoding"])
            {
                currentBlobItem.properties.contentEncoding = builder;
            }
            else if ([currentNode isEqualToString:@"Content-Language"])
            {
                currentBlobItem.properties.contentLanguage = builder;
            }
            else if ([currentNode isEqualToString:@"Content-MD5"])
            {
                currentBlobItem.properties.contentMD5 = builder;
            }
            else if ([currentNode isEqualToString:@"Cache-Control"])
            {
                currentBlobItem.properties.cacheControl = builder;
            }
            else if ([currentNode isEqualToString:@"x-ms-blob-sequence-number"])
            {
                currentBlobItem.properties.sequenceNumber = [numberFormatter numberFromString:builder];
            }
            else if ([currentNode isEqualToString:@"BlobType"])
            {
                if ([builder isEqualToString:@"BlockBlob"])
                {
                    currentBlobItem.properties.blobType = AZSBlobTypeBlockBlob;
                }
                else if ([builder isEqualToString:@"PageBlob"])
                {
                    currentBlobItem.properties.blobType = AZSBlobTypePageBlob;
                }
                else if ([builder isEqualToString:@"AppendBlob"])
                {
                    currentBlobItem.properties.blobType = AZSBlobTypeAppendBlob;
                }
            }
            else if ([currentNode isEqualToString:@"LeaseStatus"])
            {
                if ([builder isEqualToString:@"locked"])
                {
                    currentBlobItem.properties.leaseStatus = AZSLeaseStatusLocked;
                }
                else if ([builder isEqualToString:@"unlocked"])
                {
                    currentBlobItem.properties.leaseStatus = AZSLeaseStatusUnlocked;
                }
            }
            else if ([currentNode isEqualToString:@"LeaseState"])
            {
                if ([builder isEqualToString:@"available"])
                {
                    currentBlobItem.properties.leaseState = AZSLeaseStateAvailable;
                }
                else if ([builder isEqualToString:@"leased"])
                {
                    currentBlobItem.properties.leaseState = AZSLeaseStateLeased;
                }
                else if ([builder isEqualToString:@"expired"])
                {
                    currentBlobItem.properties.leaseState = AZSLeaseStateExpired;
                }
                else if ([builder isEqualToString:@"breaking"])
                {
                    currentBlobItem.properties.leaseState = AZSLeaseStateBreaking;
                }
                else if ([builder isEqualToString:@"broken"])
                {
                    currentBlobItem.properties.leaseState = AZSLeaseStateBroken;
                }
            }
            else if ([currentNode isEqualToString:@"LeaseDuration"])
            {
                if ([builder isEqualToString:@"infinite"])
                {
                    currentBlobItem.properties.leaseDuration = AZSLeaseDurationInfinite;
                }
                else if ([builder isEqualToString:@"fixed"])
                {
                    currentBlobItem.properties.leaseDuration = AZSLeaseDurationFixed;
                }
            }
            else if ([currentNode isEqualToString:@"CopyId"])
            {
                currentBlobItem.blobCopyState.operationId = builder;
            }
            else if ([currentNode isEqualToString:@"CopyStatus"])
            {
                if ([builder isEqualToString:@"pending"])
                {
                    currentBlobItem.blobCopyState.copyStatus = AZSCopyStatusPending;
                }
                else if ([builder isEqualToString:@"success"])
                {
                    currentBlobItem.blobCopyState.copyStatus = AZSCopyStatusSuccess;
                }
                else if ([builder isEqualToString:@"aborted"])
                {
                    currentBlobItem.blobCopyState.copyStatus = AZSCopyStatusAborted;
                }
                else if ([builder isEqualToString:@"failed"])
                {
                    currentBlobItem.blobCopyState.copyStatus = AZSCopyStatusFailed;
                }
            }
            else if ([currentNode isEqualToString:@"CopySource"])
            {
                currentBlobItem.blobCopyState.source = [NSURL URLWithString:builder];
            }
            else if ([currentNode isEqualToString:@"CopyProgress"])
            {
                NSArray *progressFraction = [builder componentsSeparatedByString:@"/"];
                currentBlobItem.blobCopyState.bytesCopied = [progressFraction objectAtIndex:0];
                currentBlobItem.blobCopyState.totalBytes = [progressFraction objectAtIndex:1];
            }
            else if ([currentNode isEqualToString:@"CopyCompletionTime"])
            {
                currentBlobItem.blobCopyState.completionTime = [[AZSUtil dateFormatterWithRFCFormat] dateFromString:builder];
            }
            else if ([currentNode isEqualToString:@"CopyStatusDescription"])
            {
                currentBlobItem.blobCopyState.statusDescription = builder;
            }
            
            builder = [[NSMutableString alloc] init];
        }
        else if ([parentNode isEqualToString:@"Metadata"])
        {
            [currentBlobItem.metadata setValue:builder forKey:currentNode];
            
            builder = [[NSMutableString alloc] init];
        }
        else if ([parentNode isEqualToString:@"EnumerationResults"])
        {
            if ([currentNode isEqualToString:@"NextMarker"])
            {
                if (builder.length > 0)
                {
                    nextMarker = builder;
                }
            }
            
            builder = [[NSMutableString alloc] init];
        }
    };
    
    parserDelegate.foundCharacters = ^(NSXMLParser *parser, NSString *characters)
    {
        [operationContext logAtLevel:AZSLogLevelDebug withMessage:@"Found characters = %@", characters];
        [builder appendString:characters];
    };
    
    parser.delegate = parserDelegate;
    
    BOOL parseSuccessful = [parser parse];
    if (!parseSuccessful)
    {
        *error = [NSError errorWithDomain:AZSErrorDomain code:AZSEParseError userInfo:nil];
        [operationContext logAtLevel:AZSLogLevelError withMessage:@"Parse unsuccessful for list blobs response."];
        return nil;
    }
    
    AZSListBlobsResponse *listBlobsResponse = [[AZSListBlobsResponse alloc] init];
    listBlobsResponse.blobListItems = blobListItems;
    listBlobsResponse.nextMarker = nextMarker;
    return listBlobsResponse;
}
@end

@implementation AZSDownloadContainerPermissions

+(instancetype)parseDownloadContainerPermissionsResponseWithData:(NSData *)data operationContext:(AZSOperationContext *)operationContext error:(NSError **)error
{
    AZSDownloadContainerPermissions *permissions = [[AZSDownloadContainerPermissions alloc] init];
    NSMutableDictionary *policies = [NSMutableDictionary dictionaryWithCapacity:5];
    
    AZSStorageXMLParserDelegate *parserDelegate = [[AZSStorageXMLParserDelegate alloc] init];
    
    NSXMLParser *parser = [[NSXMLParser alloc] initWithData:data];
    parser.shouldProcessNamespaces = NO;
    
    __block AZSSharedAccessPolicy *currentStoredPolicy = [[AZSSharedAccessPolicy alloc] initWithIdentifier:nil];
    __block NSMutableArray *elementStack = [NSMutableArray arrayWithCapacity:10];
    __block NSMutableString *builder = [[NSMutableString alloc] init];
    __block NSDictionary *currentAttributes = nil;
    
    parserDelegate.parseBeginElement = ^(NSXMLParser *parser, NSString *elementName,NSDictionary *attributeDict)
    {
        [operationContext logAtLevel:AZSLogLevelDebug withMessage:@"Beginning to parse element with name = %@", elementName];
        [elementStack addObject:elementName];
        if ([builder length] > 0)
        {
            builder = [[NSMutableString alloc] init];
        }
        currentAttributes = attributeDict;
    };
    
    parserDelegate.parseEndElement = ^(NSXMLParser *parser, NSString *elementName)
    {
        [operationContext logAtLevel:AZSLogLevelDebug withMessage:@"Ending to parse element with name = %@", elementName];
        NSString *currentNode = elementStack.lastObject;
        [elementStack removeLastObject];
        
        if (![elementName isEqualToString:currentNode])
        {
            // Malformed XML
            [parser abortParsing];
        }
        
        NSString *parentNode = elementStack.lastObject;
        if ([parentNode isEqualToString:@"SignedIdentifiers"])
        {
            if ([currentNode isEqualToString:@"SignedIdentifier"] && currentStoredPolicy.policyIdentifier)
            {
                policies[currentStoredPolicy.policyIdentifier] = currentStoredPolicy;
                currentStoredPolicy = [[AZSSharedAccessPolicy alloc] initWithIdentifier:nil];
            }
        }
        else if ([parentNode isEqualToString:@"SignedIdentifier"])
        {
            if ([currentNode isEqualToString:@"Id"])
            {
                currentStoredPolicy.policyIdentifier = builder;
            }
            else if ([currentNode isEqualToString:@"AccessPolicy"])
            {
                //currentStoredPolicy.snapshotTime = builder;
            }
            
            builder = [[NSMutableString alloc] init];
        }
        else if ([parentNode isEqualToString:@"AccessPolicy"])
        {
            if ([currentNode isEqualToString:@"Start"])
            {
                currentStoredPolicy.sharedAccessStartTime = [[AZSUtil dateFormatterWithRoundtripFormat] dateFromString:builder];
            }
            else if ([currentNode isEqualToString:@"Expiry"])
            {
                NSDate *date = [[AZSUtil dateFormatterWithRoundtripFormat] dateFromString:builder];
                currentStoredPolicy.sharedAccessExpiryTime = date;
            }
            else if ([currentNode isEqualToString:@"Permission"])
            {
                currentStoredPolicy.permissions = [AZSSharedAccessSignatureHelper permissionsFromString:builder error:error];
            }
            builder = [[NSMutableString alloc] init];
        }
    };
    
    parserDelegate.foundCharacters = ^(NSXMLParser *parser, NSString *characters)
    {
        [operationContext logAtLevel:AZSLogLevelDebug withMessage:@"Found characters = %@", characters];
        [builder appendString:characters];
    };
    
    parser.delegate = parserDelegate;
    
    if (![parser parse])
    {
        *error = [NSError errorWithDomain:AZSErrorDomain code:AZSEParseError userInfo:nil];
        [operationContext logAtLevel:AZSLogLevelError withMessage:@"Parse unsuccessful for fetch stored policies response."];
        return nil;
    }
    
    permissions.storedPolicies = policies;
    return permissions;
}

+(AZSBlobContainerPermissions *) createContainerPermissionsWithResponse:(NSHTTPURLResponse *)response operationContext:(AZSOperationContext *)operationContext error:(NSError **)error;
{
    NSString *publicAccess = [response.allHeaderFields objectForKey:@"x-ms-blob-public-access"];
    AZSContainerPublicAccessType accessType = AZSContainerPublicAccessTypeOff;
    
    if (publicAccess && [publicAccess length] > 0) {
        NSString *lowerCasePublicAccess = [publicAccess lowercaseString];
        
        if ([@"container" isEqual:lowerCasePublicAccess]) {
            accessType = AZSContainerPublicAccessTypeContainer;
        }
        else if ([@"blob" isEqual:lowerCasePublicAccess]) {
            accessType = AZSContainerPublicAccessTypeBlob;
        }
        else {
            *error = [NSError errorWithDomain:AZSErrorDomain code:AZSEInvalidArgument userInfo:@{NSLocalizedDescriptionKey:[NSString stringWithFormat:@"Invalid Public Access Type: %@", publicAccess]}];
            return nil;
        }
    }
    
    AZSBlobContainerPermissions *permissions = [[AZSBlobContainerPermissions alloc] init];
    permissions.publicAccess = accessType;
    
    return permissions;
}

@end

@implementation AZSGetBlockListResponse

+(NSArray *) parseGetBlockListResponseWithData:(NSData *)data operationContext:(AZSOperationContext *)operationContext error:(NSError **)error
{
    AZSStorageXMLParserDelegate *parserDelegate = [[AZSStorageXMLParserDelegate alloc] init];
    
    NSXMLParser *parser = [[NSXMLParser alloc] initWithData:data];
    parser.shouldProcessNamespaces = NO;
    
    __block NSMutableArray *blockList = [NSMutableArray arrayWithCapacity:10];
    __block AZSBlockListItem *currentBlock = [[AZSBlockListItem alloc] initWithBlockID:@"" blockListMode:AZSBlockListModeLatest];
    __block NSMutableArray *elementStack = [NSMutableArray arrayWithCapacity:10];
    __block NSMutableString *builder = [[NSMutableString alloc] init];

    parserDelegate.parseBeginElement = ^(NSXMLParser *parser, NSString *elementName,NSDictionary *attributeDict)
    {
        [operationContext logAtLevel:AZSLogLevelDebug withMessage:@"Beginning to parse element with name = %@", elementName];
        [elementStack addObject:elementName];
        if ([builder length] > 0)
        {
            builder = [[NSMutableString alloc] init];
        }
    };
    
    parserDelegate.parseEndElement = ^(NSXMLParser *parser, NSString *elementName)
    {
        [operationContext logAtLevel:AZSLogLevelDebug withMessage:@"Ending to parse element with name = %@", elementName];
        NSString *currentNode = elementStack.lastObject;
        [elementStack removeLastObject];
        
        if (![elementName isEqualToString:currentNode])
        {
            // Malformed XML
            [parser abortParsing];
        }
        
        NSString *parentNode = elementStack.lastObject;
        if ([parentNode isEqualToString:@"Block"])
        {
            if ([currentNode isEqualToString:@"Name"])
            {
                currentBlock.blockID = builder;
                builder = [[NSMutableString alloc] init];
            }
            else if ([currentNode isEqualToString:@"Size"])
            {
                currentBlock.size = [builder integerValue];
                builder = [[NSMutableString alloc] init];
            }
        }
        else if ([parentNode isEqualToString:@"CommittedBlocks"])
        {
            currentBlock.blockListMode = AZSBlockListModeCommitted;
            [blockList addObject:currentBlock];
            currentBlock = [[AZSBlockListItem alloc] initWithBlockID:@"" blockListMode:AZSBlockListModeLatest];
        }
        else if ([parentNode isEqualToString:@"UncommittedBlocks"])
        {
            currentBlock.blockListMode = AZSBlockListModeUncommitted;
            [blockList addObject:currentBlock];
            currentBlock = [[AZSBlockListItem alloc] initWithBlockID:@"" blockListMode:AZSBlockListModeLatest];
        }
    };

    
    parserDelegate.foundCharacters = ^(NSXMLParser *parser, NSString *characters)
    {
        [operationContext logAtLevel:AZSLogLevelDebug withMessage:@"Found characters = %@", characters];
        [builder appendString:characters];
    };

    parser.delegate = parserDelegate;
    
    BOOL parseSuccessful = [parser parse];
    if (!parseSuccessful)
    {
        *error = [NSError errorWithDomain:AZSErrorDomain code:AZSEParseError userInfo:nil];
        [operationContext logAtLevel:AZSLogLevelError withMessage:@"Parse unsuccessful for get block list operation."];
    }
    return blockList;
}

@end

@implementation AZSBlobResponseParser

+(AZSCopyState *)getCopyStateWithResponse:(NSHTTPURLResponse *)response
{
    AZSCopyState *result = [[AZSCopyState alloc] init];
    NSString *copyStatusString = [response.allHeaderFields valueForKey:@"x-ms-copy-status"];
    
    if (copyStatusString)
    {
        NSString *copyIdString = [response.allHeaderFields valueForKey:@"x-ms-copy-id"];
        NSString *copySourceString = [response.allHeaderFields valueForKey:@"x-ms-copy-source"];
        NSString *copyProgressString = [response.allHeaderFields valueForKey:@"x-ms-copy-progress"];
        NSString *copyCompletionTimeString = [response.allHeaderFields valueForKey:@"x-ms-copy-completion-time"];
        NSString *copyDescriptionString = [response.allHeaderFields valueForKey:@"x-ms-copy-status-description"];
        
        result.operationId = copyIdString;
        result.statusDescription = copyDescriptionString;
        
        if (copyStatusString)
        {
            if ([@"success" isEqualToString:copyStatusString])
            {
                result.copyStatus = AZSCopyStatusSuccess;
            }
            else if ([@"pending" isEqualToString:copyStatusString])
            {
                result.copyStatus = AZSCopyStatusPending;
            }
            else if ([@"aborted" isEqualToString:copyStatusString])
            {
                result.copyStatus = AZSCopyStatusAborted;
            }
            else if ([@"failed" isEqualToString:copyStatusString])
            {
                result.copyStatus = AZSCopyStatusFailed;
            }
            else
            {
                result.copyStatus = AZSCopyStatusInvalid;
            }
        }
        
        if (copyProgressString)
        {
            NSArray *progressFraction = [copyProgressString componentsSeparatedByString:@"/"];
            result.bytesCopied = [progressFraction objectAtIndex:0];
            result.totalBytes = [progressFraction objectAtIndex:1];
        }
        
        if (copySourceString)
        {
            result.source = [NSURL URLWithString:copySourceString];
        }
        
        if (copyCompletionTimeString)
        {
            result.completionTime = [[AZSUtil dateFormatterWithRoundtripFormat] dateFromString:copyCompletionTimeString];
        }
    }
    
    return result;
}

+(AZSBlobProperties *)getBlobPropertiesWithResponse:(NSHTTPURLResponse *)response operationContext:(AZSOperationContext *)operationContext error:(NSError **)error
{
    AZSBlobProperties *result = [[AZSBlobProperties alloc] init];
    
    result.eTag = [response.allHeaderFields valueForKey:@"ETag"];
    result.lastModified = [[AZSUtil dateFormatterWithRFCFormat] dateFromString:[response.allHeaderFields valueForKey:@"Last-Modified"]];
    
    result.leaseState = [AZSBlobResponseParser getLeaseStateWithResponse:response operationContext:operationContext error:error];
    if (*error)
    {
        return nil;
    }
    
    result.leaseStatus = [AZSBlobResponseParser getLeaseStatusWithResponse:response operationContext:operationContext error:error];
    if (*error)
    {
        return nil;
    }
    
    result.leaseDuration = [AZSBlobResponseParser getLeaseDurationWithResponse:response operationContext:operationContext error:error];
    if (*error)
    {
        return nil;
    }
    
    result.contentLanguage = [response.allHeaderFields valueForKey:@"Content-Language"];
    result.contentDisposition = [response.allHeaderFields valueForKey:@"Content-Disposition"];
    result.contentEncoding = [response.allHeaderFields valueForKey:@"Content-Encoding"];
    result.contentMD5 = [response.allHeaderFields valueForKey:@"Content-MD5"];
    result.contentType = [response.allHeaderFields valueForKey:@"Content-Type"];
    result.cacheControl = [response.allHeaderFields valueForKey:@"Cache-Control"];
    
    NSString *blobTypeString = [response.allHeaderFields valueForKey:@"x-ms-blob-type"];
    result.blobType = AZSBlobTypeUnspecified;
    //do we want unspecified or do we want to throw?
    if (blobTypeString)
    {
        if ([@"BlockBlob" isEqualToString:blobTypeString])
        {
            result.blobType = AZSBlobTypeBlockBlob;
        }
        else if ([@"PageBlob" isEqualToString:blobTypeString])
        {
            result.blobType = AZSBlobTypePageBlob;
        }
    }
    
    NSString *rangeHeaderString = [response.allHeaderFields valueForKey:@"Range"];
    NSString *contentLengthHeaderString = [response.allHeaderFields valueForKey:@"Content-Length"];
    NSString *blobContentLengthHeaderString = [response.allHeaderFields valueForKey:@"x-ms-blob-content-length"];
    
    if (rangeHeaderString)
    {
        result.length = [NSNumber numberWithLongLong:[[[rangeHeaderString componentsSeparatedByString:@"/"] objectAtIndex:1] longLongValue]];
    }
    else if (blobContentLengthHeaderString)
    {
        result.length = [NSNumber numberWithLongLong:[blobContentLengthHeaderString longLongValue]];
    }
    else if (contentLengthHeaderString)
    {
        result.length = [NSNumber numberWithLongLong:[contentLengthHeaderString longLongValue]];
    }
    else
    {
        result.length = [NSNumber numberWithLongLong:[response expectedContentLength]];
    }
    
    NSString *sequenceNumberHeaderString = [response.allHeaderFields valueForKey:@"x-ms-blob-sequence-number"];
    if (sequenceNumberHeaderString)
    {
        result.sequenceNumber = [NSNumber numberWithLongLong:[sequenceNumberHeaderString longLongValue]];
    }
    
    return result;
}

+(AZSBlobContainerProperties *)getContainerPropertiesWithResponse:(NSHTTPURLResponse *)response operationContext:(AZSOperationContext *)operationContext error:(NSError **)error
{
    AZSBlobContainerProperties *result = [[AZSBlobContainerProperties alloc] init];
    
    result.eTag = [response.allHeaderFields valueForKey:@"ETag"];
    result.lastModified = [[AZSUtil dateFormatterWithRFCFormat] dateFromString:[response.allHeaderFields valueForKey:@"Last-Modified"]];
    result.leaseState = [AZSBlobResponseParser getLeaseStateWithResponse:response operationContext:operationContext error:error];
    result.leaseStatus = [AZSBlobResponseParser getLeaseStatusWithResponse:response operationContext:operationContext error:error];
    result.leaseDuration = [AZSBlobResponseParser getLeaseDurationWithResponse:response operationContext:operationContext error:error];
    
    return result;
}

+(AZSLeaseState) getLeaseStateWithResponse:(NSHTTPURLResponse *)response operationContext:(AZSOperationContext *)operationContext error:(NSError **)error
{
    NSString *leaseStateString = [response.allHeaderFields valueForKey:@"x-ms-lease-state"];
    
    if (leaseStateString)
    {
        if ([@"available" isEqualToString:leaseStateString])
        {
            return AZSLeaseStateAvailable;
        }
        else if ([@"leased" isEqualToString:leaseStateString])
        {
            return AZSLeaseStateLeased;
        }
        else if ([@"expired" isEqualToString:leaseStateString])
        {
            return AZSLeaseStateExpired;
        }
        else if ([@"breaking" isEqualToString:leaseStateString])
        {
            return AZSLeaseStateBreaking;
        }
        else if ([@"broken" isEqualToString:leaseStateString])
        {
            return AZSLeaseStateBroken;
        }
        else
        {
            *error = [NSError errorWithDomain:AZSErrorDomain code:AZSEParseError userInfo:nil];
            [operationContext logAtLevel:AZSLogLevelError withMessage:@"Parse unsuccessful for get lease state."];
            return AZSLeaseStateUnspecified;
        }
    }
    
    return AZSLeaseStateUnspecified;
}

+(AZSLeaseStatus) getLeaseStatusWithResponse:(NSHTTPURLResponse *)response operationContext:(AZSOperationContext *)operationContext error:(NSError **)error
{
    NSString *leaseStatusString = [response.allHeaderFields valueForKey:@"x-ms-lease-status"];
    
    if (leaseStatusString)
    {
        if ([@"locked" isEqualToString:leaseStatusString])
        {
            return AZSLeaseStatusLocked;
        }
        else if ([@"unlocked" isEqualToString:leaseStatusString])
        {
            return AZSLeaseStatusUnlocked;
        }
        else
        {
            *error = [NSError errorWithDomain:AZSErrorDomain code:AZSEParseError userInfo:nil];
            [operationContext logAtLevel:AZSLogLevelError withMessage:@"Parse unsuccessful for get lease status."];
            return AZSLeaseStatusUnspecified;
        }
    }
    
    return AZSLeaseStatusUnspecified;
}

+(AZSLeaseDuration) getLeaseDurationWithResponse:(NSHTTPURLResponse *)response operationContext:(AZSOperationContext *)operationContext error:(NSError **)error
{
    NSString *leaseDurationString = [response.allHeaderFields valueForKey:@"lease-duration"];
    
    if (leaseDurationString)
    {
        if ([@"fixed" isEqualToString:leaseDurationString])
        {
            return AZSLeaseDurationFixed;
        }
        else if ([@"infinite" isEqualToString:leaseDurationString])
        {
            return AZSLeaseDurationInfinite;
        }
        else
        {
            *error = [NSError errorWithDomain:AZSErrorDomain code:AZSEParseError userInfo:nil];
            [operationContext logAtLevel:AZSLogLevelError withMessage:@"Parse unsuccessful for get lease duration."];
            return AZSLeaseDurationUnspecified;
        }
    }
    
    return AZSLeaseDurationUnspecified;
}

+(NSMutableDictionary *)getMetadataWithResponse: (NSHTTPURLResponse *)response
{
    NSMutableDictionary *result = [[NSMutableDictionary alloc] init];
    
    for (NSString* key in response.allHeaderFields)
    {
        if ([key hasPrefix:@"x-ms-meta-"])
        {
            [result setValue:[response.allHeaderFields valueForKey:key] forKey:[key substringFromIndex:[@"x-ms-meta-" length]]];
        }
    }
    
    return result;
}

+(NSNumber *)getRemainingLeaseTimeWithResponse:(NSHTTPURLResponse *)response
{
    NSString *remainingLeaseTimeString = [response.allHeaderFields valueForKey:@"x-ms-lease-time"];
    NSNumber *remainingLeaseTime = nil;
    if (remainingLeaseTimeString) {
        remainingLeaseTime = [NSNumber numberWithLongLong: [remainingLeaseTimeString integerValue]];
    }
    
    return remainingLeaseTime;
}

@end