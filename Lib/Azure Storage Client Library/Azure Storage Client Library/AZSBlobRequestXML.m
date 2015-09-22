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
#import "AZSBlobRequestXML.h"
#import "AZSBlockListItem.h"
#import "AZSErrors.h"
#import "AZSOperationContext.h"


@implementation AZSBlobRequestXML

+(void) checkReturnCodeAndCreateErrorWithReturnCode:(int)returnCode operationContext:(AZSOperationContext *)operationContext error:(NSError **)error
{
    if (returnCode < 0)
    {
        *error = [NSError errorWithDomain:AZSErrorDomain code:AZSEXMLCreationError userInfo:@{@"xmlReturnCode":@(returnCode)}];
        [operationContext logAtLevel:AZSLogLevelError withMessage:@"Error in generating XML block list."];
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
    
    int returnCode = xmlTextWriterStartDocument(writer, NULL, "ISO-8859-1", NULL);
    [AZSBlobRequestXML checkReturnCodeAndCreateErrorWithReturnCode:returnCode operationContext:operationContext error:error];
    
    returnCode = xmlTextWriterStartElement(writer, (const xmlChar *)"BlockList");
    [AZSBlobRequestXML checkReturnCodeAndCreateErrorWithReturnCode:returnCode operationContext:operationContext error:error];

    for (AZSBlockListItem *block in blockList)
    {
        switch (block.blockListMode)
        {
            case AZSBlockListModeLatest:
                returnCode = xmlTextWriterStartElement(writer, (const xmlChar *)"Latest");
                [AZSBlobRequestXML checkReturnCodeAndCreateErrorWithReturnCode:returnCode operationContext:operationContext error:error];
                break;
            case AZSBlockListModeCommitted:
                returnCode = xmlTextWriterStartElement(writer, (const xmlChar *)"Committed");
                [AZSBlobRequestXML checkReturnCodeAndCreateErrorWithReturnCode:returnCode operationContext:operationContext error:error];
                break;
            case AZSBlockListModeUncommitted:
                returnCode = xmlTextWriterStartElement(writer, (const xmlChar *)"Uncommitted");
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

@end
