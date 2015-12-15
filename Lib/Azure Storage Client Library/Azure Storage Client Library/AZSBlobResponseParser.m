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

#import "AZSBlobResponseParser.h"
#import "AZSBlockListItem.h"
#import "AZSBlobContainerProperties.h"
#import "AZSConstants.h"
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
        _isDirectory = NO;
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
    __block NSMutableString *currentXmlText = [[NSMutableString alloc] init];
    __block NSString *nextMarker = nil;
    
    parserDelegate.parseBeginElement = ^(NSXMLParser *parser, NSString *elementName,NSDictionary *attributeDict)
    {
        [operationContext logAtLevel:AZSLogLevelDebug withMessage:@"Beginning to parse element with name = %@", elementName];
        [elementStack addObject:elementName];
        if ([currentXmlText length] > 0)
        {
            currentXmlText = [[NSMutableString alloc] init];
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
        if ([parentNode isEqualToString:AZSCXmlContainers])
        {
            if ([currentNode isEqualToString:AZSCXmlContainer])
            {
                [containers addObject:currentContainer];
                currentContainer = [[AZSContainerListItem alloc] init];
            }
        }
        else if ([parentNode isEqualToString:AZSCXmlEnumerationResults])
        {
            if ([currentNode isEqualToString:AZSCXmlNextMarker])
            {
                if (currentXmlText.length > 0)
                {
                    nextMarker = currentXmlText;
                }
            }
            
            currentXmlText = [[NSMutableString alloc] init];
        }
        else if ([parentNode isEqualToString:AZSCXmlContainer])
        {
            if ([currentNode isEqualToString:AZSCXmlName])
            {
                currentContainer.name = currentXmlText;
            }
            
            currentXmlText = [[NSMutableString alloc] init];
        }
        else if ([parentNode isEqualToString:AZSCXmlProperties])
        {
            if ([currentNode isEqualToString:AZSCXmlLastModified])
            {
                currentContainer.properties.lastModified = [[AZSUtil dateFormatterWithRFCFormat] dateFromString:currentXmlText];
            }
            else if ([currentNode isEqualToString:[AZSCXmlETag capitalizedString]])
            {
                currentContainer.properties.eTag = currentXmlText;
            }
            else if ([currentNode isEqualToString:AZSCXmlLeaseStatus])
            {
                if ([currentXmlText isEqualToString:AZSCXmlLocked])
                {
                    currentContainer.properties.leaseStatus = AZSLeaseStatusLocked;
                }
                else if ([currentXmlText isEqualToString:AZSCXmlUnlocked])
                {
                    currentContainer.properties.leaseStatus = AZSLeaseStatusUnlocked;
                }
            }
            else if ([currentNode isEqualToString:AZSCXmlLeaseState])
            {
                if ([currentXmlText isEqualToString:AZSCXmlAvailable])
                {
                    currentContainer.properties.leaseState = AZSLeaseStateAvailable;
                }
                else if ([currentXmlText isEqualToString:AZSCXmlLeased])
                {
                    currentContainer.properties.leaseState = AZSLeaseStateLeased;
                }
                else if ([currentXmlText isEqualToString:AZSCXmlExpired])
                {
                    currentContainer.properties.leaseState = AZSLeaseStateExpired;
                }
                else if ([currentXmlText isEqualToString:AZSCXmlBreaking])
                {
                    currentContainer.properties.leaseState = AZSLeaseStateBreaking;
                }
                else if ([currentXmlText isEqualToString:AZSCXmlBroken])
                {
                    currentContainer.properties.leaseState = AZSLeaseStateBroken;
                }
            }
            else if ([currentNode isEqualToString:AZSCXmlLeaseDuration])
            {
                if ([currentXmlText isEqualToString:AZSCXmlInfinite])
                {
                    currentContainer.properties.leaseDuration = AZSLeaseDurationInfinite;
                }
                else if ([currentXmlText isEqualToString:AZSCXmlFixed])
                {
                    currentContainer.properties.leaseDuration = AZSLeaseDurationFixed;
                }
            }
            
            currentXmlText = [[NSMutableString alloc] init];
        }
        else if ([parentNode isEqualToString:AZSCXmlMetadata])
        {
            [currentContainer.metadata setValue:currentXmlText forKey:currentNode];
            
            currentXmlText = [[NSMutableString alloc] init];
        }
    };
    
    parserDelegate.foundCharacters = ^(NSXMLParser *parser, NSString *characters)
    {
        [operationContext logAtLevel:AZSLogLevelDebug withMessage:@"Found characters = %@", characters];
        [currentXmlText appendString:characters];
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
    __block NSMutableString *currentXmlText = [[NSMutableString alloc] init];
    __block NSString *nextMarker = nil;
    __block NSDictionary *currentAttributes = nil;

    parserDelegate.parseBeginElement = ^(NSXMLParser *parser, NSString *elementName,NSDictionary *attributeDict)
    {
        [operationContext logAtLevel:AZSLogLevelDebug withMessage:@"Beginning to parse element with name = %@", elementName];
        [elementStack addObject:elementName];
        if ([currentXmlText length] > 0)
        {
            currentXmlText = [[NSMutableString alloc] init];
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
        if ([parentNode isEqualToString:AZSCXmlBlobs])
        {
            if ([currentNode isEqualToString:AZSCXmlBlob])
            {
                currentBlobItem.isDirectory = NO;
                [blobListItems addObject:currentBlobItem];
                currentBlobItem = [[AZSBlobListItem alloc] init];
            }
            else if ([currentNode isEqualToString:AZSCXmlBlobPrefix])
            {
                currentBlobItem.isDirectory = YES;
                [blobListItems addObject:currentBlobItem];
                currentBlobItem = [[AZSBlobListItem alloc] init];
            }
        }
        else if ([parentNode isEqualToString:AZSCXmlBlob])
        {
            if ([currentNode isEqualToString:AZSCXmlName])
            {
                currentBlobItem.name = currentXmlText;
            }
            else if ([currentNode isEqualToString:AZSCXmlSnapshot])
            {
                currentBlobItem.snapshotTime = currentXmlText;
            }
            
            currentXmlText = [[NSMutableString alloc] init];
        }
        else if ([parentNode isEqualToString:AZSCXmlBlobPrefix])
        {
            if ([currentNode isEqualToString:AZSCXmlName])
            {
                currentBlobItem.name = currentXmlText;
            }
            
            currentXmlText = [[NSMutableString alloc] init];
        }
        else if ([parentNode isEqualToString:AZSCXmlProperties])
        {
            if ([currentNode isEqualToString:AZSCXmlLastModified])
            {
                currentBlobItem.properties.lastModified = [[AZSUtil dateFormatterWithRFCFormat] dateFromString:currentXmlText];
            }
            else if ([currentNode isEqualToString:[AZSCXmlETag capitalizedString]])
            {
                currentBlobItem.properties.eTag = currentXmlText;
            }
            else if ([currentNode isEqualToString:AZSCXmlContentLength])
            {
                currentBlobItem.properties.length = [numberFormatter numberFromString:currentXmlText];
            }
            else if ([currentNode isEqualToString:AZSCXmlContentType])
            {
                currentBlobItem.properties.contentType = currentXmlText;
            }
            else if ([currentNode isEqualToString:AZSCXmlContentEncoding])
            {
                currentBlobItem.properties.contentEncoding = currentXmlText;
            }
            else if ([currentNode isEqualToString:AZSCXmlContentLanguage])
            {
                currentBlobItem.properties.contentLanguage = currentXmlText;
            }
            else if ([currentNode isEqualToString:AZSCXmlContentMd5])
            {
                currentBlobItem.properties.contentMD5 = currentXmlText;
            }
            else if ([currentNode isEqualToString:AZSCXmlContentCacheControl])
            {
                currentBlobItem.properties.cacheControl = currentXmlText;
            }
            else if ([currentNode isEqualToString:AZSCHeaderBlobSequenceNumber])
            {
                currentBlobItem.properties.sequenceNumber = [numberFormatter numberFromString:currentXmlText];
            }
            else if ([currentNode isEqualToString:AZSCXmlBlobType])
            {
                if ([currentXmlText isEqualToString:AZSCXmlBlobBlockBlob])
                {
                    currentBlobItem.properties.blobType = AZSBlobTypeBlockBlob;
                }
                else if ([currentXmlText isEqualToString:AZSCXmlBlobPageBlob])
                {
                    currentBlobItem.properties.blobType = AZSBlobTypePageBlob;
                }
                else if ([currentXmlText isEqualToString:AZSCXmlBlobAppendBlob])
                {
                    currentBlobItem.properties.blobType = AZSBlobTypeAppendBlob;
                }
            }
            else if ([currentNode isEqualToString:AZSCXmlLeaseStatus])
            {
                if ([currentXmlText isEqualToString:AZSCXmlLocked])
                {
                    currentBlobItem.properties.leaseStatus = AZSLeaseStatusLocked;
                }
                else if ([currentXmlText isEqualToString:AZSCXmlUnlocked])
                {
                    currentBlobItem.properties.leaseStatus = AZSLeaseStatusUnlocked;
                }
            }
            else if ([currentNode isEqualToString:AZSCXmlLeaseState])
            {
                if ([currentXmlText isEqualToString:AZSCXmlAvailable])
                {
                    currentBlobItem.properties.leaseState = AZSLeaseStateAvailable;
                }
                else if ([currentXmlText isEqualToString:AZSCXmlLeased])
                {
                    currentBlobItem.properties.leaseState = AZSLeaseStateLeased;
                }
                else if ([currentXmlText isEqualToString:AZSCXmlExpired])
                {
                    currentBlobItem.properties.leaseState = AZSLeaseStateExpired;
                }
                else if ([currentXmlText isEqualToString:AZSCXmlBreaking])
                {
                    currentBlobItem.properties.leaseState = AZSLeaseStateBreaking;
                }
                else if ([currentXmlText isEqualToString:AZSCXmlBroken])
                {
                    currentBlobItem.properties.leaseState = AZSLeaseStateBroken;
                }
            }
            else if ([currentNode isEqualToString:AZSCXmlLeaseDuration])
            {
                if ([currentXmlText isEqualToString:AZSCXmlInfinite])
                {
                    currentBlobItem.properties.leaseDuration = AZSLeaseDurationInfinite;
                }
                else if ([currentXmlText isEqualToString:AZSCXmlFixed])
                {
                    currentBlobItem.properties.leaseDuration = AZSLeaseDurationFixed;
                }
            }
            else if ([currentNode isEqualToString:AZSCXmlCopyId])
            {
                currentBlobItem.blobCopyState.operationId = currentXmlText;
            }
            else if ([currentNode isEqualToString:AZSCXmlCopyStatus])
            {
                if ([currentXmlText isEqualToString:AZSCXmlCopyPending])
                {
                    currentBlobItem.blobCopyState.copyStatus = AZSCopyStatusPending;
                }
                else if ([currentXmlText isEqualToString:AZSCXmlCopySuccess])
                {
                    currentBlobItem.blobCopyState.copyStatus = AZSCopyStatusSuccess;
                }
                else if ([currentXmlText isEqualToString:AZSCXmlCopyAborted])
                {
                    currentBlobItem.blobCopyState.copyStatus = AZSCopyStatusAborted;
                }
                else if ([currentXmlText isEqualToString:AZSCXmlCopyFailed])
                {
                    currentBlobItem.blobCopyState.copyStatus = AZSCopyStatusFailed;
                }
            }
            else if ([currentNode isEqualToString:AZSCXmlCopySource])
            {
                currentBlobItem.blobCopyState.source = [NSURL URLWithString:currentXmlText];
            }
            else if ([currentNode isEqualToString:AZSCXmlCopyProgress])
            {
                NSArray *progressFraction = [currentXmlText componentsSeparatedByString:@"/"];
                currentBlobItem.blobCopyState.bytesCopied = [progressFraction objectAtIndex:0];
                currentBlobItem.blobCopyState.totalBytes = [progressFraction objectAtIndex:1];
            }
            else if ([currentNode isEqualToString:AZSCXmlCopyCompletionTime])
            {
                currentBlobItem.blobCopyState.completionTime = [[AZSUtil dateFormatterWithRFCFormat] dateFromString:currentXmlText];
            }
            else if ([currentNode isEqualToString:AZSCXmlCopyStatusDescription])
            {
                currentBlobItem.blobCopyState.statusDescription = currentXmlText;
            }
            
            currentXmlText = [[NSMutableString alloc] init];
        }
        else if ([parentNode isEqualToString:AZSCXmlMetadata])
        {
            [currentBlobItem.metadata setValue:currentXmlText forKey:currentNode];
            
            currentXmlText = [[NSMutableString alloc] init];
        }
        else if ([parentNode isEqualToString:AZSCXmlEnumerationResults])
        {
            if ([currentNode isEqualToString:AZSCXmlNextMarker])
            {
                if (currentXmlText.length > 0)
                {
                    nextMarker = currentXmlText;
                }
            }
            
            currentXmlText = [[NSMutableString alloc] init];
        }
    };
    
    parserDelegate.foundCharacters = ^(NSXMLParser *parser, NSString *characters)
    {
        [operationContext logAtLevel:AZSLogLevelDebug withMessage:@"Found characters = %@", characters];
        [currentXmlText appendString:characters];
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
    __block NSMutableString *currentXmlText = [[NSMutableString alloc] init];
    __block NSDictionary *currentAttributes = nil;
    
    parserDelegate.parseBeginElement = ^(NSXMLParser *parser, NSString *elementName,NSDictionary *attributeDict)
    {
        [operationContext logAtLevel:AZSLogLevelDebug withMessage:@"Beginning to parse element with name = %@", elementName];
        [elementStack addObject:elementName];
        if ([currentXmlText length] > 0)
        {
            currentXmlText = [[NSMutableString alloc] init];
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
        if ([parentNode isEqualToString:AZSCXmlSignedIdentifiers])
        {
            if ([currentNode isEqualToString:AZSCXmlSignedIdentifier] && currentStoredPolicy.policyIdentifier)
            {
                policies[currentStoredPolicy.policyIdentifier] = currentStoredPolicy;
                currentStoredPolicy = [[AZSSharedAccessPolicy alloc] initWithIdentifier:nil];
            }
        }
        else if ([parentNode isEqualToString:AZSCXmlSignedIdentifier])
        {
            if ([currentNode isEqualToString:AZSCXmlId])
            {
                currentStoredPolicy.policyIdentifier = currentXmlText;
            }
            
            currentXmlText = [[NSMutableString alloc] init];
        }
        else if ([parentNode isEqualToString:AZSCXmlAccessPolicy])
        {
            if ([currentNode isEqualToString:AZSCXmlStart])
            {
                currentStoredPolicy.sharedAccessStartTime = [[AZSUtil dateFormatterWithRoundtripFormat] dateFromString:currentXmlText];
            }
            else if ([currentNode isEqualToString:AZSCXmlExpiry])
            {
                NSDate *date = [[AZSUtil dateFormatterWithRoundtripFormat] dateFromString:currentXmlText];
                currentStoredPolicy.sharedAccessExpiryTime = date;
            }
            else if ([currentNode isEqualToString:AZSCXmlPermission])
            {
                currentStoredPolicy.permissions = [AZSSharedAccessSignatureHelper permissionsFromString:currentXmlText error:error];
            }
            currentXmlText = [[NSMutableString alloc] init];
        }
    };
    
    parserDelegate.foundCharacters = ^(NSXMLParser *parser, NSString *characters)
    {
        [operationContext logAtLevel:AZSLogLevelDebug withMessage:@"Found characters = %@", characters];
        [currentXmlText appendString:characters];
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

+(AZSContainerPublicAccessType) createContainerPermissionsWithResponse:(NSHTTPURLResponse *)response operationContext:(AZSOperationContext *)operationContext error:(NSError **)error;
{
    NSString *publicAccess = [response.allHeaderFields objectForKey:@"x-ms-blob-public-access"];
    AZSContainerPublicAccessType accessType = AZSContainerPublicAccessTypeOff;
    
    if (publicAccess && [publicAccess length] > 0) {
        NSString *lowerCasePublicAccess = [publicAccess lowercaseString];
        
        if ([AZSCContainer isEqual:lowerCasePublicAccess]) {
            accessType = AZSContainerPublicAccessTypeContainer;
        }
        else if ([AZSCBlob isEqual:lowerCasePublicAccess]) {
            accessType = AZSContainerPublicAccessTypeBlob;
        }
        else {
            *error = [NSError errorWithDomain:AZSErrorDomain code:AZSEInvalidArgument userInfo:@{NSLocalizedDescriptionKey:[NSString stringWithFormat:@"Invalid Public Access Type: %@", publicAccess]}];
        }
    }
    
    return accessType;
}

@end

@implementation AZSGetBlockListResponse

+(NSArray *) parseGetBlockListResponseWithData:(NSData *)data operationContext:(AZSOperationContext *)operationContext error:(NSError **)error
{
    AZSStorageXMLParserDelegate *parserDelegate = [[AZSStorageXMLParserDelegate alloc] init];
    
    NSXMLParser *parser = [[NSXMLParser alloc] initWithData:data];
    parser.shouldProcessNamespaces = NO;
    
    __block NSMutableArray *blockList = [NSMutableArray arrayWithCapacity:10];
    __block AZSBlockListItem *currentBlock = [[AZSBlockListItem alloc] initWithBlockID:AZSCEmptyString blockListMode:AZSBlockListModeLatest];
    __block NSMutableArray *elementStack = [NSMutableArray arrayWithCapacity:10];
    __block NSMutableString *currentXmlText = [[NSMutableString alloc] init];

    parserDelegate.parseBeginElement = ^(NSXMLParser *parser, NSString *elementName,NSDictionary *attributeDict)
    {
        [operationContext logAtLevel:AZSLogLevelDebug withMessage:@"Beginning to parse element with name = %@", elementName];
        [elementStack addObject:elementName];
        if ([currentXmlText length] > 0)
        {
            currentXmlText = [[NSMutableString alloc] init];
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
        if ([parentNode isEqualToString:AZSCXmlBlock])
        {
            if ([currentNode isEqualToString:AZSCXmlName])
            {
                currentBlock.blockID = currentXmlText;
                currentXmlText = [[NSMutableString alloc] init];
            }
            else if ([currentNode isEqualToString:AZSCXmlSize])
            {
                currentBlock.size = [currentXmlText integerValue];
                currentXmlText = [[NSMutableString alloc] init];
            }
        }
        else if ([parentNode isEqualToString:AZSCXmlCommittedBlocks])
        {
            currentBlock.blockListMode = AZSBlockListModeCommitted;
            [blockList addObject:currentBlock];
            currentBlock = [[AZSBlockListItem alloc] initWithBlockID:AZSCEmptyString blockListMode:AZSBlockListModeLatest];
        }
        else if ([parentNode isEqualToString:AZSCXmlUncommittedBlocks])
        {
            currentBlock.blockListMode = AZSBlockListModeUncommitted;
            [blockList addObject:currentBlock];
            currentBlock = [[AZSBlockListItem alloc] initWithBlockID:AZSCEmptyString blockListMode:AZSBlockListModeLatest];
        }
    };

    
    parserDelegate.foundCharacters = ^(NSXMLParser *parser, NSString *characters)
    {
        [operationContext logAtLevel:AZSLogLevelDebug withMessage:@"Found characters = %@", characters];
        [currentXmlText appendString:characters];
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
    NSString *copyStatusString = response.allHeaderFields[AZSCHeaderCopyStatus];
    
    if (copyStatusString)
    {
        NSString *copyIdString = response.allHeaderFields[AZSCHeaderCopyId];
        NSString *copySourceString = response.allHeaderFields[AZSCHeaderCopySource];
        NSString *copyProgressString = response.allHeaderFields[AZSCHeaderCopyProgress];
        NSString *copyCompletionTimeString = response.allHeaderFields[AZSCHeaderCopyCompletionTime];
        NSString *copyDescriptionString = response.allHeaderFields[AZSCHeaderCopyStatusDescription];
        
        result.operationId = copyIdString;
        result.statusDescription = copyDescriptionString;
        
        if (copyStatusString)
        {
            if ([AZSCXmlCopySuccess isEqualToString:copyStatusString])
            {
                result.copyStatus = AZSCopyStatusSuccess;
            }
            else if ([AZSCXmlCopyPending isEqualToString:copyStatusString])
            {
                result.copyStatus = AZSCopyStatusPending;
            }
            else if ([AZSCXmlCopyAborted isEqualToString:copyStatusString])
            {
                result.copyStatus = AZSCopyStatusAborted;
            }
            else if ([AZSCXmlCopyFailed isEqualToString:copyStatusString])
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
    
    result.eTag = response.allHeaderFields[AZSCXmlETag];
    result.lastModified = [[AZSUtil dateFormatterWithRFCFormat] dateFromString:response.allHeaderFields[AZSCXmlLastModified]];
    
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
    
    result.contentLanguage = response.allHeaderFields[AZSCXmlContentLanguage];
    result.contentDisposition = response.allHeaderFields[AZSCXmlContentDisposition];
    result.contentEncoding = response.allHeaderFields[AZSCXmlContentEncoding];
    result.contentMD5 = response.allHeaderFields[AZSCXmlContentMd5];
    result.contentType = response.allHeaderFields[AZSCXmlContentType];
    result.cacheControl = response.allHeaderFields[AZSCXmlContentCacheControl];
    
    NSString *blobTypeString = response.allHeaderFields[AZSCHeaderBlobType];
    result.blobType = AZSBlobTypeUnspecified;
    //do we want unspecified or do we want to throw?
    if (blobTypeString)
    {
        if ([AZSCXmlBlobBlockBlob isEqualToString:blobTypeString])
        {
            result.blobType = AZSBlobTypeBlockBlob;
        }
        else if ([AZSCXmlBlobPageBlob isEqualToString:blobTypeString])
        {
            result.blobType = AZSBlobTypePageBlob;
        }
    }
    
    NSString *rangeHeaderString = response.allHeaderFields[AZSCXmlRange];
    NSString *contentLengthHeaderString = response.allHeaderFields[AZSCXmlContentLength];
    NSString *blobContentLengthHeaderString = response.allHeaderFields[AZSCHeaderBlobContentLength];
    
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
    
    NSString *sequenceNumberHeaderString = response.allHeaderFields[AZSCHeaderBlobSequenceNumber];
    if (sequenceNumberHeaderString)
    {
        result.sequenceNumber = [NSNumber numberWithLongLong:[sequenceNumberHeaderString longLongValue]];
    }
    
    return result;
}

+(AZSBlobContainerProperties *)getContainerPropertiesWithResponse:(NSHTTPURLResponse *)response operationContext:(AZSOperationContext *)operationContext error:(NSError **)error
{
    AZSBlobContainerProperties *result = [[AZSBlobContainerProperties alloc] init];
    
    result.eTag = response.allHeaderFields[AZSCXmlETag];
    result.lastModified = [[AZSUtil dateFormatterWithRFCFormat] dateFromString:response.allHeaderFields[AZSCXmlLastModified]];
    result.leaseState = [AZSBlobResponseParser getLeaseStateWithResponse:response operationContext:operationContext error:error];
    result.leaseStatus = [AZSBlobResponseParser getLeaseStatusWithResponse:response operationContext:operationContext error:error];
    result.leaseDuration = [AZSBlobResponseParser getLeaseDurationWithResponse:response operationContext:operationContext error:error];
    
    return result;
}

+(AZSLeaseState) getLeaseStateWithResponse:(NSHTTPURLResponse *)response operationContext:(AZSOperationContext *)operationContext error:(NSError **)error
{
    NSString *leaseStateString = response.allHeaderFields[AZSCHeaderLeaseState];
    
    if (leaseStateString)
    {
        if ([AZSCXmlAvailable isEqualToString:leaseStateString])
        {
            return AZSLeaseStateAvailable;
        }
        else if ([AZSCXmlLeased isEqualToString:leaseStateString])
        {
            return AZSLeaseStateLeased;
        }
        else if ([AZSCXmlExpired isEqualToString:leaseStateString])
        {
            return AZSLeaseStateExpired;
        }
        else if ([AZSCXmlBreaking isEqualToString:leaseStateString])
        {
            return AZSLeaseStateBreaking;
        }
        else if ([AZSCXmlBroken isEqualToString:leaseStateString])
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
    NSString *leaseStatusString = response.allHeaderFields[AZSCHeaderLeaseStatus];
    
    if (leaseStatusString)
    {
        if ([AZSCXmlLocked isEqualToString:leaseStatusString])
        {
            return AZSLeaseStatusLocked;
        }
        else if ([AZSCXmlUnlocked isEqualToString:leaseStatusString])
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
    NSString *leaseDurationString = response.allHeaderFields[AZSCHeaderLeaseDuration];
    
    if (leaseDurationString)
    {
        if ([AZSCXmlFixed isEqualToString:leaseDurationString])
        {
            return AZSLeaseDurationFixed;
        }
        else if ([AZSCXmlInfinite isEqualToString:leaseDurationString])
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
        if ([key hasPrefix:AZSCHeaderMetaPrefix])
        {
            result[[key substringFromIndex:[AZSCHeaderMetaPrefix length]]] = response.allHeaderFields[key];
        }
    }
    
    return result;
}

+(NSNumber *)getRemainingLeaseTimeWithResponse:(NSHTTPURLResponse *)response
{
    NSString *remainingLeaseTimeString = response.allHeaderFields[AZSCHeaderLeaseTime];
    NSNumber *remainingLeaseTime = nil;
    if (remainingLeaseTimeString) {
        remainingLeaseTime = [NSNumber numberWithLongLong: [remainingLeaseTimeString integerValue]];
    }
    
    return remainingLeaseTime;
}

@end