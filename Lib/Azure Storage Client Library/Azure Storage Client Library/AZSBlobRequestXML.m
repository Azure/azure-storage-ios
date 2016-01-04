// -----------------------------------------------------------------------------------------
// <copyright file="AZSBlobRequestXML.m" company="Microsoft">
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

#import <libxml/xmlwriter.h>
#import "AZSBlobContainerPermissions.h"
#import "AZSBlobRequestXML.h"
#import "AZSBlockListItem.h"
#import "AZSConstants.h"
#import "AZSErrors.h"
#import "AZSOperationContext.h"
#import "AZSSharedAccessPolicy.h"
#import "AZSSharedAccessSignatureHelper.h"
#import "AZSUtil.h"

@implementation AZSBlobRequestXML

+(void) checkReturnCodeAndCreateErrorWithReturnCode:(int)returnCode operationContext:(AZSOperationContext *)operationContext error:(NSError **)error
{
    if (!*error && returnCode < 0)
    {
        *error = [NSError errorWithDomain:AZSErrorDomain code:AZSEXMLCreationError userInfo:@{@"xmlReturnCode":@(returnCode)}];
        [operationContext logAtLevel:AZSLogLevelError withMessage:@"Error in generating XML."];
    }
}

+(NSString *) createBlockListXMLFromArray:(NSArray *)blockList operationContext:(AZSOperationContext *)operationContext error:(NSError **)error
{
    xmlBufferPtr buffer;
    xmlTextWriterPtr writer;
    
    buffer = xmlBufferCreate();
    if (buffer == NULL)
    {
        *error = [NSError errorWithDomain:AZSErrorDomain code:AZSEXMLCreationError userInfo:nil];
        [operationContext logAtLevel:AZSLogLevelError withMessage:@"Error in generating XML block list."];
        return nil;
    }
    
    writer = xmlNewTextWriterMemory(buffer, 0);
    if (writer == NULL)
    {
        *error = [NSError errorWithDomain:AZSErrorDomain code:AZSEXMLCreationError userInfo:nil];
        [operationContext logAtLevel:AZSLogLevelError withMessage:@"Error in generating XML block list."];
    }
    
    int returnCode = xmlTextWriterStartDocument(writer, NULL, [AZSCXmlIso UTF8String], NULL);
    [AZSBlobRequestXML checkReturnCodeAndCreateErrorWithReturnCode:returnCode operationContext:operationContext error:error];
    
    returnCode = xmlTextWriterStartElement(writer, (const xmlChar *)[AZSCXmlBlockList UTF8String]);
    [AZSBlobRequestXML checkReturnCodeAndCreateErrorWithReturnCode:returnCode operationContext:operationContext error:error];

    for (AZSBlockListItem *block in blockList)
    {
        switch (block.blockListMode)
        {
            case AZSBlockListModeLatest:
                returnCode = xmlTextWriterStartElement(writer, (const xmlChar *)[AZSCXmlLatest UTF8String]);
                [AZSBlobRequestXML checkReturnCodeAndCreateErrorWithReturnCode:returnCode operationContext:operationContext error:error];
                break;
            case AZSBlockListModeCommitted:
                returnCode = xmlTextWriterStartElement(writer, (const xmlChar *)[AZSCXmlCommitted UTF8String]);
                [AZSBlobRequestXML checkReturnCodeAndCreateErrorWithReturnCode:returnCode operationContext:operationContext error:error];
                break;
            case AZSBlockListModeUncommitted:
                returnCode = xmlTextWriterStartElement(writer, (const xmlChar *)[AZSCXmlUncommitted UTF8String]);
                [AZSBlobRequestXML checkReturnCodeAndCreateErrorWithReturnCode:returnCode operationContext:operationContext error:error];
                break;
            default:
                *error = [NSError errorWithDomain:AZSErrorDomain code:AZSEXMLCreationError userInfo:nil];
                [operationContext logAtLevel:AZSLogLevelError withMessage:@"Error in generating XML block list."];
                break;
        }
        
        returnCode = xmlTextWriterWriteString(writer, (const xmlChar *)[block.blockID cStringUsingEncoding:NSUTF8StringEncoding]);
        [AZSBlobRequestXML checkReturnCodeAndCreateErrorWithReturnCode:returnCode operationContext:operationContext error:error];

        returnCode = xmlTextWriterEndElement(writer);
        [AZSBlobRequestXML checkReturnCodeAndCreateErrorWithReturnCode:returnCode operationContext:operationContext error:error];
    }

    returnCode = xmlTextWriterEndDocument(writer);
    [AZSBlobRequestXML checkReturnCodeAndCreateErrorWithReturnCode:returnCode operationContext:operationContext error:error];

    if (writer != NULL)
    {
        xmlFreeTextWriter(writer);
    }
    
    NSString *result = [NSString stringWithCString:(const char *)buffer->content encoding:NSUTF8StringEncoding];
    
    xmlBufferFree(buffer);
    
    return result;
}

+(NSString *) createStoredPoliciesXMLFromPermissions:(AZSBlobContainerPermissions *)permissions operationContext:(AZSOperationContext *)operationContext error:(NSError **)error
{
    xmlBufferPtr buffer;
    xmlTextWriterPtr writer;
    
    buffer = xmlBufferCreate();
    if (buffer == NULL)
    {
        *error = [NSError errorWithDomain:AZSErrorDomain code:AZSEXMLCreationError userInfo:nil];
        [operationContext logAtLevel:AZSLogLevelError withMessage:@"Error in generating XML block list."];
        return nil;
    }
    
    writer = xmlNewTextWriterMemory(buffer, 0);
    if (writer == NULL)
    {
        *error = [NSError errorWithDomain:AZSErrorDomain code:AZSEXMLCreationError userInfo:nil];
        [operationContext logAtLevel:AZSLogLevelError withMessage:@"Error in generating XML block list."];
    }
    
    int returnCode = xmlTextWriterStartDocument(writer, NULL, [AZSCXmlIso UTF8String], NULL);
    [AZSBlobRequestXML checkReturnCodeAndCreateErrorWithReturnCode:returnCode operationContext:operationContext error:error];
    
    // <SignedIdentifiers>
    returnCode = xmlTextWriterStartElement(writer, (const xmlChar *)[AZSCXmlSignedIdentifiers UTF8String]);
    [AZSBlobRequestXML checkReturnCodeAndCreateErrorWithReturnCode:returnCode operationContext:operationContext error:error];
    
    for (NSString *key in permissions.sharedAccessPolicies)
    {
        AZSSharedAccessPolicy *policy = [permissions.sharedAccessPolicies objectForKey:key];
        // <SignedIdentifier>
        returnCode = xmlTextWriterStartElement(writer, (const xmlChar *)[AZSCXmlSignedIdentifier UTF8String]);
        [AZSBlobRequestXML checkReturnCodeAndCreateErrorWithReturnCode:returnCode operationContext:operationContext error:error];
        
        //      <Id>policyIdentifier</Id>
        returnCode = xmlTextWriterStartElement(writer, (const xmlChar *)[AZSCXmlId UTF8String]);
        [AZSBlobRequestXML checkReturnCodeAndCreateErrorWithReturnCode:returnCode operationContext:operationContext error:error];
        returnCode = xmlTextWriterWriteString(writer, (const xmlChar *)[policy.policyIdentifier cStringUsingEncoding:NSUTF8StringEncoding]);
        [AZSBlobRequestXML checkReturnCodeAndCreateErrorWithReturnCode:returnCode operationContext:operationContext error:error];
        returnCode = xmlTextWriterEndElement(writer);
        [AZSBlobRequestXML checkReturnCodeAndCreateErrorWithReturnCode:returnCode operationContext:operationContext error:error];
        
        //      <AccessPolicy>
        returnCode = xmlTextWriterStartElement(writer, (const xmlChar *)[AZSCXmlAccessPolicy UTF8String]);
        [AZSBlobRequestXML checkReturnCodeAndCreateErrorWithReturnCode:returnCode operationContext:operationContext error:error];
        
        //          <Start>sharedAccessStartTime</Start>
        returnCode = xmlTextWriterStartElement(writer, (const xmlChar *)[AZSCXmlStart UTF8String]);
        [AZSBlobRequestXML checkReturnCodeAndCreateErrorWithReturnCode:returnCode operationContext:operationContext error:error];
        returnCode = xmlTextWriterWriteString(writer, (const xmlChar *)[[AZSUtil utcTimeOrEmptyWithDate:policy.sharedAccessStartTime] cStringUsingEncoding:NSUTF8StringEncoding]);
        [AZSBlobRequestXML checkReturnCodeAndCreateErrorWithReturnCode:returnCode operationContext:operationContext error:error];
        returnCode = xmlTextWriterEndElement(writer);
        [AZSBlobRequestXML checkReturnCodeAndCreateErrorWithReturnCode:returnCode operationContext:operationContext error:error];
        
        //          <Expiry>sharedAccessExpiryTime</Expiry>
        returnCode = xmlTextWriterStartElement(writer, (const xmlChar *)[AZSCXmlExpiry UTF8String]);
        [AZSBlobRequestXML checkReturnCodeAndCreateErrorWithReturnCode:returnCode operationContext:operationContext error:error];
        returnCode = xmlTextWriterWriteString(writer, (const xmlChar *)[[AZSUtil utcTimeOrEmptyWithDate:policy.sharedAccessExpiryTime] cStringUsingEncoding:NSUTF8StringEncoding]);
        [AZSBlobRequestXML checkReturnCodeAndCreateErrorWithReturnCode:returnCode operationContext:operationContext error:error];
        returnCode = xmlTextWriterEndElement(writer);
        [AZSBlobRequestXML checkReturnCodeAndCreateErrorWithReturnCode:returnCode operationContext:operationContext error:error];
        
        //          <Permission>permissionsString</Permission>
        returnCode = xmlTextWriterStartElement(writer, (const xmlChar *)[AZSCXmlPermission UTF8String]);
        [AZSBlobRequestXML checkReturnCodeAndCreateErrorWithReturnCode:returnCode operationContext:operationContext error:error];
        returnCode = xmlTextWriterWriteString(writer, (const xmlChar *)[[AZSSharedAccessSignatureHelper stringFromPermissions:policy.permissions error:error] cStringUsingEncoding:NSUTF8StringEncoding]);
        [AZSBlobRequestXML checkReturnCodeAndCreateErrorWithReturnCode:returnCode operationContext:operationContext error:error];
        returnCode = xmlTextWriterEndElement(writer);
        [AZSBlobRequestXML checkReturnCodeAndCreateErrorWithReturnCode:returnCode operationContext:operationContext error:error];
        
        //      </AccessPolicy>
        returnCode = xmlTextWriterEndElement(writer);
        [AZSBlobRequestXML checkReturnCodeAndCreateErrorWithReturnCode:returnCode operationContext:operationContext error:error];
        
        // </SignedIdentifier>
        returnCode = xmlTextWriterEndElement(writer);
        [AZSBlobRequestXML checkReturnCodeAndCreateErrorWithReturnCode:returnCode operationContext:operationContext error:error];
    }
    
    // </SignedIdentifiers>
    returnCode = xmlTextWriterEndDocument(writer);
    [AZSBlobRequestXML checkReturnCodeAndCreateErrorWithReturnCode:returnCode operationContext:operationContext error:error];
    
    if (writer != NULL)
    {
        xmlFreeTextWriter(writer);
    }
    
    NSString *result = [NSString stringWithCString:(const char *)buffer->content encoding:NSUTF8StringEncoding];
    
    xmlBufferFree(buffer);
    
    return result;
}

@end