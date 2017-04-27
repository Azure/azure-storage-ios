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
#import "AZSConstants.h"
#import "AZSCorsRule.h"
#import "AZSErrors.h"
#import "AZSOperationContext.h"
#import "AZSLoggingProperties.h"
#import "AZSMetricsProperties.h"
#import "AZSServiceProperties.h"
#import "AZSSharedAccessPolicy.h"
#import "AZSSharedAccessSignatureHelper.h"
#import "AZSUtil.h"

@interface AZSBlobRequestXML()

+(void) createMetricsPropertiesXML:(AZSMetricsProperties *) metricsProperties writer:(xmlTextWriterPtr *)writer operationContext:(AZSOperationContext *)operationContext error:(NSError **)error;

+(void) createRetentionPolicyXML:(NSNumber *) retentionIntervalInDays writer:(xmlTextWriterPtr *)writer operationContext:(AZSOperationContext *)operationContext error:(NSError **)error;

+(void) createCorsPropertiesXML:(NSMutableArray *) corsRules writer:(xmlTextWriterPtr *)writer operationContext:(AZSOperationContext *)operationContext error:(NSError **)error;

+(NSString*) convertCorsHttpMethodToString:(AZSCorsHttpMethod) corsHttpMethod;

@end

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
        xmlBufferFree(buffer);
        return nil;
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

+(NSString *) createStoredPoliciesXMLFromPermissions:(NSMutableDictionary *)permissions operationContext:(AZSOperationContext *)operationContext error:(NSError **)error
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
        xmlBufferFree(buffer);
        return nil;
    }
    
    int returnCode = xmlTextWriterStartDocument(writer, NULL, [AZSCXmlIso UTF8String], NULL);
    [AZSBlobRequestXML checkReturnCodeAndCreateErrorWithReturnCode:returnCode operationContext:operationContext error:error];
    
    // <SignedIdentifiers>
    returnCode = xmlTextWriterStartElement(writer, (const xmlChar *)[AZSCXmlSignedIdentifiers UTF8String]);
    [AZSBlobRequestXML checkReturnCodeAndCreateErrorWithReturnCode:returnCode operationContext:operationContext error:error];
    
    for (NSString *key in permissions)
    {
        AZSSharedAccessPolicy *policy = permissions[key];
        // <SignedIdentifier>
        returnCode = xmlTextWriterStartElement(writer, (const xmlChar *)[AZSCXmlSignedIdentifier UTF8String]);
        [AZSBlobRequestXML checkReturnCodeAndCreateErrorWithReturnCode:returnCode operationContext:operationContext error:error];
        
        // <Id>policyIdentifier</Id>
        returnCode = xmlTextWriterStartElement(writer, (const xmlChar *)[AZSCXmlId UTF8String]);
        [AZSBlobRequestXML checkReturnCodeAndCreateErrorWithReturnCode:returnCode operationContext:operationContext error:error];
        returnCode = xmlTextWriterWriteString(writer, (const xmlChar *)[policy.policyIdentifier cStringUsingEncoding:NSUTF8StringEncoding]);
        [AZSBlobRequestXML checkReturnCodeAndCreateErrorWithReturnCode:returnCode operationContext:operationContext error:error];
        returnCode = xmlTextWriterEndElement(writer);
        [AZSBlobRequestXML checkReturnCodeAndCreateErrorWithReturnCode:returnCode operationContext:operationContext error:error];
        
        // <AccessPolicy>
        returnCode = xmlTextWriterStartElement(writer, (const xmlChar *)[AZSCXmlAccessPolicy UTF8String]);
        [AZSBlobRequestXML checkReturnCodeAndCreateErrorWithReturnCode:returnCode operationContext:operationContext error:error];
        
        // <Start>sharedAccessStartTime</Start>
        returnCode = xmlTextWriterStartElement(writer, (const xmlChar *)[AZSCXmlStart UTF8String]);
        [AZSBlobRequestXML checkReturnCodeAndCreateErrorWithReturnCode:returnCode operationContext:operationContext error:error];
        returnCode = xmlTextWriterWriteString(writer, (const xmlChar *)[[AZSUtil utcTimeOrEmptyWithDate:policy.sharedAccessStartTime] cStringUsingEncoding:NSUTF8StringEncoding]);
        [AZSBlobRequestXML checkReturnCodeAndCreateErrorWithReturnCode:returnCode operationContext:operationContext error:error];
        returnCode = xmlTextWriterEndElement(writer);
        [AZSBlobRequestXML checkReturnCodeAndCreateErrorWithReturnCode:returnCode operationContext:operationContext error:error];
        
        // <Expiry>sharedAccessExpiryTime</Expiry>
        returnCode = xmlTextWriterStartElement(writer, (const xmlChar *)[AZSCXmlExpiry UTF8String]);
        [AZSBlobRequestXML checkReturnCodeAndCreateErrorWithReturnCode:returnCode operationContext:operationContext error:error];
        returnCode = xmlTextWriterWriteString(writer, (const xmlChar *)[[AZSUtil utcTimeOrEmptyWithDate:policy.sharedAccessExpiryTime] cStringUsingEncoding:NSUTF8StringEncoding]);
        [AZSBlobRequestXML checkReturnCodeAndCreateErrorWithReturnCode:returnCode operationContext:operationContext error:error];
        returnCode = xmlTextWriterEndElement(writer);
        [AZSBlobRequestXML checkReturnCodeAndCreateErrorWithReturnCode:returnCode operationContext:operationContext error:error];
        
        // <Permission>permissionsString</Permission>
        returnCode = xmlTextWriterStartElement(writer, (const xmlChar *)[AZSCXmlPermission UTF8String]);
        [AZSBlobRequestXML checkReturnCodeAndCreateErrorWithReturnCode:returnCode operationContext:operationContext error:error];
        returnCode = xmlTextWriterWriteString(writer, (const xmlChar *)[[AZSSharedAccessSignatureHelper stringFromPermissions:policy.permissions error:error] cStringUsingEncoding:NSUTF8StringEncoding]);
        [AZSBlobRequestXML checkReturnCodeAndCreateErrorWithReturnCode:returnCode operationContext:operationContext error:error];
        returnCode = xmlTextWriterEndElement(writer);
        [AZSBlobRequestXML checkReturnCodeAndCreateErrorWithReturnCode:returnCode operationContext:operationContext error:error];
        
        // </AccessPolicy>
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

+(NSString *) createServicePropertiesXML:(AZSServiceProperties *)serviceProperties operationContext:(AZSOperationContext *)operationContext error:(NSError **)error
{
    xmlBufferPtr buffer;
    xmlTextWriterPtr writer;

    buffer = xmlBufferCreate();
    if (buffer == NULL)
    {
        *error = [NSError errorWithDomain:AZSErrorDomain code:AZSEXMLCreationError userInfo:nil];
        [operationContext logAtLevel:AZSLogLevelError withMessage:@"Error in generating service properties XML."];
        return nil;
    }

    writer = xmlNewTextWriterMemory(buffer, 0);
    if (writer == NULL)
    {
        *error = [NSError errorWithDomain:AZSErrorDomain code:AZSEXMLCreationError userInfo:nil];
        [operationContext logAtLevel:AZSLogLevelError withMessage:@"Error in generating service propertes XML."];
        xmlBufferFree(buffer);
        return nil;
    }

    int returnCode = xmlTextWriterStartDocument(writer, NULL, [AZSCXmlIso UTF8String], NULL);
    [AZSBlobRequestXML checkReturnCodeAndCreateErrorWithReturnCode:returnCode operationContext:operationContext error:error];

    // <StorageServiceProperties>
    returnCode = xmlTextWriterStartElement(writer, (const xmlChar *)[AZSCXmlStorageServiceProperties UTF8String]);
    [AZSBlobRequestXML checkReturnCodeAndCreateErrorWithReturnCode:returnCode operationContext:operationContext error:error];

    // Logging properties
    if (serviceProperties.logging != NULL)
    {
        // <Logging>
        returnCode = xmlTextWriterStartElement(writer, (const xmlChar *)[AZSCXmlLogging UTF8String]);
        [AZSBlobRequestXML checkReturnCodeAndCreateErrorWithReturnCode:returnCode operationContext:operationContext error:error];

        // <Version>version-number</Version>
        returnCode = xmlTextWriterStartElement(writer, (const xmlChar *)[AZSCXmlVersion UTF8String]);
        [AZSBlobRequestXML checkReturnCodeAndCreateErrorWithReturnCode:returnCode operationContext:operationContext error:error];
        returnCode = xmlTextWriterWriteString(writer, (const xmlChar *)[serviceProperties.logging.version cStringUsingEncoding:NSUTF8StringEncoding]);
        [AZSBlobRequestXML checkReturnCodeAndCreateErrorWithReturnCode:returnCode operationContext:operationContext error:error];
        returnCode = xmlTextWriterEndElement(writer);
        [AZSBlobRequestXML checkReturnCodeAndCreateErrorWithReturnCode:returnCode operationContext:operationContext error:error];

        // <Delete>true|false</Delete>
        returnCode = xmlTextWriterStartElement(writer, (const xmlChar *)[AZSCXmlLoggingDelete UTF8String]);
        [AZSBlobRequestXML checkReturnCodeAndCreateErrorWithReturnCode:returnCode operationContext:operationContext error:error];
        bool logDelete = (serviceProperties.logging.logOperationTypes & AZSLoggingOperationDelete);
        NSString *logDeleteString = logDelete ? @"true" : @"false";
        returnCode = xmlTextWriterWriteString(writer, (const xmlChar *)[logDeleteString cStringUsingEncoding:NSUTF8StringEncoding]);
        [AZSBlobRequestXML checkReturnCodeAndCreateErrorWithReturnCode:returnCode operationContext:operationContext error:error];
        returnCode = xmlTextWriterEndElement(writer);
        [AZSBlobRequestXML checkReturnCodeAndCreateErrorWithReturnCode:returnCode operationContext:operationContext error:error];

        // <Read>true|false</Read>
        returnCode = xmlTextWriterStartElement(writer, (const xmlChar *)[AZSCXmlLoggingRead UTF8String]);
        [AZSBlobRequestXML checkReturnCodeAndCreateErrorWithReturnCode:returnCode operationContext:operationContext error:error];
        bool logRead = (serviceProperties.logging.logOperationTypes & AZSLoggingOperationRead);
        NSString *logReadString = logRead ? @"true" : @"false";
        returnCode = xmlTextWriterWriteString(writer, (const xmlChar *)[logReadString cStringUsingEncoding:NSUTF8StringEncoding]);
        [AZSBlobRequestXML checkReturnCodeAndCreateErrorWithReturnCode:returnCode operationContext:operationContext error:error];
        returnCode = xmlTextWriterEndElement(writer);
        [AZSBlobRequestXML checkReturnCodeAndCreateErrorWithReturnCode:returnCode operationContext:operationContext error:error];

        // <Write>true|false</Write>
        returnCode = xmlTextWriterStartElement(writer, (const xmlChar *)[AZSCXmlLoggingWrite UTF8String]);
        [AZSBlobRequestXML checkReturnCodeAndCreateErrorWithReturnCode:returnCode operationContext:operationContext error:error];
        bool logWrite = (serviceProperties.logging.logOperationTypes & AZSLoggingOperationWrite);
        NSString *logWriteString = logWrite ? @"true" : @"false";
        returnCode = xmlTextWriterWriteString(writer, (const xmlChar *)[logWriteString cStringUsingEncoding:NSUTF8StringEncoding]);
        [AZSBlobRequestXML checkReturnCodeAndCreateErrorWithReturnCode:returnCode operationContext:operationContext error:error];
        returnCode = xmlTextWriterEndElement(writer);
        [AZSBlobRequestXML checkReturnCodeAndCreateErrorWithReturnCode:returnCode operationContext:operationContext error:error];

        // <RentionPolicy>Policy</RentionPolicy>
        [self createRetentionPolicyXML:serviceProperties.logging.retentionIntervalInDays writer:&writer operationContext:operationContext error:error];

        // </Logging>
        returnCode = xmlTextWriterEndElement(writer);
        [AZSBlobRequestXML checkReturnCodeAndCreateErrorWithReturnCode:returnCode operationContext:operationContext error:error];
    }

    if (serviceProperties.hourMetrics != nil)
    {
        // <HourMetrics>
        returnCode = xmlTextWriterStartElement(writer, (const xmlChar *)[AZSCXmlMetricsHourMetrics UTF8String]);
        [AZSBlobRequestXML checkReturnCodeAndCreateErrorWithReturnCode:returnCode operationContext:operationContext error:error];

        // Populate hour metrics
        [self createMetricsPropertiesXML:serviceProperties.hourMetrics writer:&writer operationContext:operationContext error:error];

        // </HourMetrics>
        returnCode = xmlTextWriterEndElement(writer);
        [AZSBlobRequestXML checkReturnCodeAndCreateErrorWithReturnCode:returnCode operationContext:operationContext error:error];
    }

    if (serviceProperties.minuteMetrics != nil)
    {
        // <MinuteMetrics>
        returnCode = xmlTextWriterStartElement(writer, (const xmlChar *)[AZSCXmlMetricsMinuteMetrics UTF8String]);
        [AZSBlobRequestXML checkReturnCodeAndCreateErrorWithReturnCode:returnCode operationContext:operationContext error:error];

        // Populate minute metrics
        [self createMetricsPropertiesXML:serviceProperties.minuteMetrics writer:&writer operationContext:operationContext error:error];

        // </MinuteMetrics>
        returnCode = xmlTextWriterEndElement(writer);
        [AZSBlobRequestXML checkReturnCodeAndCreateErrorWithReturnCode:returnCode operationContext:operationContext error:error];
    }

    // Populate Cors
    [self createCorsPropertiesXML:serviceProperties.corsRules writer:&writer operationContext:operationContext error:error];

    if (serviceProperties.defaultServiceVersion != nil)
    {
        // <DefaultServiceVersion>default-service-version-string</DefaultServiceVersion>
        returnCode = xmlTextWriterStartElement(writer, (const xmlChar *)[AZSCXmlDefaultServiceVersion UTF8String]);
        [AZSBlobRequestXML checkReturnCodeAndCreateErrorWithReturnCode:returnCode operationContext:operationContext error:error];
        returnCode = xmlTextWriterWriteString(writer, (const xmlChar *)[serviceProperties.defaultServiceVersion cStringUsingEncoding:NSUTF8StringEncoding]);
        [AZSBlobRequestXML checkReturnCodeAndCreateErrorWithReturnCode:returnCode operationContext:operationContext error:error];
        returnCode = xmlTextWriterEndElement(writer);
        [AZSBlobRequestXML checkReturnCodeAndCreateErrorWithReturnCode:returnCode operationContext:operationContext error:error];
    }

    // </StorageServiceProperties>
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

+(void)createMetricsPropertiesXML:(AZSMetricsProperties *)metricsProperties writer:(xmlTextWriterPtr *)writer operationContext:(AZSOperationContext *)operationContext error:(NSError **)error
{
    // <Version>version-number</Version>
    int returnCode = xmlTextWriterStartElement(*writer, (const xmlChar *)[AZSCXmlVersion UTF8String]);
    [AZSBlobRequestXML checkReturnCodeAndCreateErrorWithReturnCode:returnCode operationContext:operationContext error:error];
    returnCode = xmlTextWriterWriteString(*writer, (const xmlChar *)[metricsProperties.version cStringUsingEncoding:NSUTF8StringEncoding]);
    [AZSBlobRequestXML checkReturnCodeAndCreateErrorWithReturnCode:returnCode operationContext:operationContext error:error];
    returnCode = xmlTextWriterEndElement(*writer);
    [AZSBlobRequestXML checkReturnCodeAndCreateErrorWithReturnCode:returnCode operationContext:operationContext error:error];

    // <Enabled>true|false</Enabled>
    returnCode = xmlTextWriterStartElement(*writer, (const xmlChar *)[AZSCXmlEnabled UTF8String]);
    [AZSBlobRequestXML checkReturnCodeAndCreateErrorWithReturnCode:returnCode operationContext:operationContext error:error];
    bool metricsEnabled = (metricsProperties.metricsLevel != AZSMetricsLevelDisabled);
    NSString *metricsEnabledString = metricsEnabled ? @"true" : @"false";
    returnCode = xmlTextWriterWriteString(*writer, (const xmlChar *)[metricsEnabledString cStringUsingEncoding:NSUTF8StringEncoding]);
    [AZSBlobRequestXML checkReturnCodeAndCreateErrorWithReturnCode:returnCode operationContext:operationContext error:error];
    returnCode = xmlTextWriterEndElement(*writer);
    [AZSBlobRequestXML checkReturnCodeAndCreateErrorWithReturnCode:returnCode operationContext:operationContext error:error];

    // <IncludeAPIs>true|false</IncludeAPIs>
    if (metricsProperties.metricsLevel != AZSMetricsLevelDisabled)
    {
        returnCode = xmlTextWriterStartElement(*writer, (const xmlChar *)[AZSCXmlMetricsIncludeAPIs UTF8String]);
        [AZSBlobRequestXML checkReturnCodeAndCreateErrorWithReturnCode:returnCode operationContext:operationContext error:error];
        NSString *includeApisString = (metricsProperties.metricsLevel == AZSMetricsLevelServiceAndAPI) ? @"true" : @"false";
        returnCode = xmlTextWriterWriteString(*writer, (const xmlChar *)[includeApisString cStringUsingEncoding:NSUTF8StringEncoding]);
        [AZSBlobRequestXML checkReturnCodeAndCreateErrorWithReturnCode:returnCode operationContext:operationContext error:error];
        returnCode = xmlTextWriterEndElement(*writer);
        [AZSBlobRequestXML checkReturnCodeAndCreateErrorWithReturnCode:returnCode operationContext:operationContext error:error];
    }

    // <RentionPolicy>Policy</RentionPolicy>
    [self createRetentionPolicyXML:metricsProperties.retentionIntervalInDays writer:writer operationContext:operationContext error:error];
}



+(void) createRetentionPolicyXML:(NSNumber *)retentionIntervalInDays writer:(xmlTextWriterPtr *)writer operationContext:(AZSOperationContext *)operationContext error:(NSError **)error
{
    // <RetentionPolicy>
    int returnCode = xmlTextWriterStartElement(*writer, (const xmlChar *)[AZSCXmlRetentionPolicy UTF8String]);
    [AZSBlobRequestXML checkReturnCodeAndCreateErrorWithReturnCode:returnCode operationContext:operationContext error:error];

    // <Enabled>true|false</Enabled>
    returnCode = xmlTextWriterStartElement(*writer, (const xmlChar *)[AZSCXmlEnabled UTF8String]);
    [AZSBlobRequestXML checkReturnCodeAndCreateErrorWithReturnCode:returnCode operationContext:operationContext error:error];
    bool retentionPolicyEnabled = (retentionIntervalInDays != nil);
    NSString *retentionPolicyEnabledString = retentionPolicyEnabled ? @"true" : @"false";
    returnCode = xmlTextWriterWriteString(*writer, (const xmlChar *)[retentionPolicyEnabledString cStringUsingEncoding:NSUTF8StringEncoding]);
    [AZSBlobRequestXML checkReturnCodeAndCreateErrorWithReturnCode:returnCode operationContext:operationContext error:error];
    returnCode = xmlTextWriterEndElement(*writer);
    [AZSBlobRequestXML checkReturnCodeAndCreateErrorWithReturnCode:returnCode operationContext:operationContext error:error];

    // <Days>number-of-days</Days>
    if (retentionPolicyEnabled)
    {
        returnCode = xmlTextWriterStartElement(*writer, (const xmlChar *)[AZSCXmlRetentionPolicyDays UTF8String]);
        [AZSBlobRequestXML checkReturnCodeAndCreateErrorWithReturnCode:returnCode operationContext:operationContext error:error];
        NSString *retentionIntervalInDaysString = [retentionIntervalInDays stringValue];
        returnCode = xmlTextWriterWriteString(*writer, (const xmlChar *)[retentionIntervalInDaysString cStringUsingEncoding:NSUTF8StringEncoding]);
        [AZSBlobRequestXML checkReturnCodeAndCreateErrorWithReturnCode:returnCode operationContext:operationContext error:error];
        returnCode = xmlTextWriterEndElement(*writer);
        [AZSBlobRequestXML checkReturnCodeAndCreateErrorWithReturnCode:returnCode operationContext:operationContext error:error];
    }

    // </RentionPolicy>
    returnCode = xmlTextWriterEndElement(*writer);
    [AZSBlobRequestXML checkReturnCodeAndCreateErrorWithReturnCode:returnCode operationContext:operationContext error:error];
}

+(void) createCorsPropertiesXML:(NSMutableArray *)corsRules writer:(xmlTextWriterPtr *)writer operationContext:(AZSOperationContext *)operationContext error:(NSError **)error
{
    if (corsRules == nil)
    {
        return;
    }

    // <Cors>
    int returnCode = xmlTextWriterStartElement(*writer, (const xmlChar *)[AZSCXmlCors UTF8String]);
    [AZSBlobRequestXML checkReturnCodeAndCreateErrorWithReturnCode:returnCode operationContext:operationContext error:error];

    for (AZSCorsRule *corsRule in corsRules)
    {
        // <CorsRule>
        int returnCode = xmlTextWriterStartElement(*writer, (const xmlChar *)[AZSCXmlCorsRule UTF8String]);
        [AZSBlobRequestXML checkReturnCodeAndCreateErrorWithReturnCode:returnCode operationContext:operationContext error:error];

        // <AllowedOrigins>comma-separated-list-of-allowed-origins</AllowedOrigins>
        NSString *allowedOriginsString = nil;
        for (NSString *allowedOrigins in corsRule.allowedOrigins)
        {
            if (allowedOriginsString == nil)
            {
                allowedOriginsString = [NSString stringWithString:allowedOrigins];
            }
            else
            {
                allowedOriginsString = [allowedOriginsString stringByAppendingString:@","];
                allowedOriginsString = [allowedOriginsString stringByAppendingString:allowedOrigins];
            }
        }

        returnCode = xmlTextWriterStartElement(*writer, (const xmlChar *)[AZSCXmlCorsAllowedOrigins UTF8String]);
        [AZSBlobRequestXML checkReturnCodeAndCreateErrorWithReturnCode:returnCode operationContext:operationContext error:error];
        returnCode = xmlTextWriterWriteString(*writer, (const xmlChar *)[allowedOriginsString cStringUsingEncoding:NSUTF8StringEncoding]);
        [AZSBlobRequestXML checkReturnCodeAndCreateErrorWithReturnCode:returnCode operationContext:operationContext error:error];
        returnCode = xmlTextWriterEndElement(*writer);
        [AZSBlobRequestXML checkReturnCodeAndCreateErrorWithReturnCode:returnCode operationContext:operationContext error:error];

        // <AllowedMethods>comma-separated-list-of-HTTP-verb</AllowedMethods>
        NSString *allowedMethodsString = [self convertCorsHttpMethodToString:corsRule.allowedHttpMethods];

        returnCode = xmlTextWriterStartElement(*writer, (const xmlChar *)[AZSCXmlCorsAllowedMethods UTF8String]);
        [AZSBlobRequestXML checkReturnCodeAndCreateErrorWithReturnCode:returnCode operationContext:operationContext error:error];
        returnCode = xmlTextWriterWriteString(*writer, (const xmlChar *)[allowedMethodsString cStringUsingEncoding:NSUTF8StringEncoding]);
        [AZSBlobRequestXML checkReturnCodeAndCreateErrorWithReturnCode:returnCode operationContext:operationContext error:error];
        returnCode = xmlTextWriterEndElement(*writer);
        [AZSBlobRequestXML checkReturnCodeAndCreateErrorWithReturnCode:returnCode operationContext:operationContext error:error];

        // <MaxAgeInSeconds>max-caching-age-in-seconds</MaxAgeInSeconds>
        returnCode = xmlTextWriterStartElement(*writer, (const xmlChar *)[AZSCXmlCorsMaxAgeInSeconds UTF8String]);
        [AZSBlobRequestXML checkReturnCodeAndCreateErrorWithReturnCode:returnCode operationContext:operationContext error:error];
        NSString* maxAgeInSeconds = [NSString stringWithFormat:@"%ld",(long)corsRule.maxAgeInSeconds];
        returnCode = xmlTextWriterWriteString(*writer, (const xmlChar *)[maxAgeInSeconds cStringUsingEncoding:NSUTF8StringEncoding]);
        [AZSBlobRequestXML checkReturnCodeAndCreateErrorWithReturnCode:returnCode operationContext:operationContext error:error];
        returnCode = xmlTextWriterEndElement(*writer);
        [AZSBlobRequestXML checkReturnCodeAndCreateErrorWithReturnCode:returnCode operationContext:operationContext error:error];

        // <ExposedHeaders>comma-seperated-list-of-response-headers</ExposedHeaders>
        NSString *exposedHeadersString = @"";
        for (NSString *exposedHeader in corsRule.exposedHeaders)
        {
            if ([exposedHeadersString isEqualToString:@""])
            {
                exposedHeadersString = [NSString stringWithString:exposedHeader];
            }
            else
            {
                exposedHeadersString = [exposedHeadersString stringByAppendingString:@","];
                exposedHeadersString = [exposedHeadersString stringByAppendingString:exposedHeader];
            }
        }

        returnCode = xmlTextWriterStartElement(*writer, (const xmlChar *)[AZSCXmlCorsExposedHeaders UTF8String]);
        [AZSBlobRequestXML checkReturnCodeAndCreateErrorWithReturnCode:returnCode operationContext:operationContext error:error];
        returnCode = xmlTextWriterWriteString(*writer, (const xmlChar *)[exposedHeadersString cStringUsingEncoding:NSUTF8StringEncoding]);
        [AZSBlobRequestXML checkReturnCodeAndCreateErrorWithReturnCode:returnCode operationContext:operationContext error:error];
        returnCode = xmlTextWriterEndElement(*writer);
        [AZSBlobRequestXML checkReturnCodeAndCreateErrorWithReturnCode:returnCode operationContext:operationContext error:error];

        // <AllowedHeaders>comma-seperated-list-of-request-headers</AllowedHeaders>
        NSString *allowedHeadersString = @"";
        for (NSString *allowedHeader in corsRule.allowedHeaders)
        {
            if ([allowedHeadersString isEqualToString:@""])
            {
                allowedHeadersString = [NSString stringWithString:allowedHeader];
            }
            else
            {
                allowedHeadersString = [allowedHeadersString stringByAppendingString:@","];
                allowedHeadersString = [allowedHeadersString stringByAppendingString:allowedHeader];
            }
        }

        returnCode = xmlTextWriterStartElement(*writer, (const xmlChar *)[AZSCXmlCorsAllowedHeaders UTF8String]);
        [AZSBlobRequestXML checkReturnCodeAndCreateErrorWithReturnCode:returnCode operationContext:operationContext error:error];
        returnCode = xmlTextWriterWriteString(*writer, (const xmlChar *)[allowedHeadersString cStringUsingEncoding:NSUTF8StringEncoding]);
        [AZSBlobRequestXML checkReturnCodeAndCreateErrorWithReturnCode:returnCode operationContext:operationContext error:error];
        returnCode = xmlTextWriterEndElement(*writer);
        [AZSBlobRequestXML checkReturnCodeAndCreateErrorWithReturnCode:returnCode operationContext:operationContext error:error];

        // </CorsRule>
        returnCode = xmlTextWriterEndElement(*writer);
        [AZSBlobRequestXML checkReturnCodeAndCreateErrorWithReturnCode:returnCode operationContext:operationContext error:error];
    }

    // </Cors>
    returnCode = xmlTextWriterEndElement(*writer);
    [AZSBlobRequestXML checkReturnCodeAndCreateErrorWithReturnCode:returnCode operationContext:operationContext error:error];
}

+(NSString*) convertCorsHttpMethodToString:(AZSCorsHttpMethod) corsHttpMethod {
    NSString *corsMethodsString = nil;

    if ((corsHttpMethod & AZSCorsHttpMethodGet) == AZSCorsHttpMethodGet)
    {
        corsMethodsString = @"GET";
    }

    if ((corsHttpMethod & AZSCorsHttpMethodPut) == AZSCorsHttpMethodPut)
    {
        if (corsMethodsString == nil)
        {
            corsMethodsString = @"PUT";
        }
        else
        {
            corsMethodsString = [corsMethodsString stringByAppendingString:@","];
            corsMethodsString = [corsMethodsString stringByAppendingString:@"PUT"];
        }
    }

    if ((corsHttpMethod & AZSCorsHttpMethodHead) == AZSCorsHttpMethodHead)
    {
        if (corsMethodsString == nil)
        {
            corsMethodsString = @"HEAD";
        }
        else
        {
            corsMethodsString = [corsMethodsString stringByAppendingString:@","];
            corsMethodsString = [corsMethodsString stringByAppendingString:@"HEAD"];
        }
    }

    if ((corsHttpMethod & AZSCorsHttpMethodPost) == AZSCorsHttpMethodPost)
    {
        if (corsMethodsString == nil)
        {
            corsMethodsString = @"POST";
        }
        else
        {
            corsMethodsString = [corsMethodsString stringByAppendingString:@","];
            corsMethodsString = [corsMethodsString stringByAppendingString:@"POST"];
        }
    }

    if ((corsHttpMethod & AZSCorsHttpMethodMerge) == AZSCorsHttpMethodMerge)
    {
        if (corsMethodsString == nil)
        {
            corsMethodsString = @"MERGE";
        }
        else
        {
            corsMethodsString = [corsMethodsString stringByAppendingString:@","];
            corsMethodsString = [corsMethodsString stringByAppendingString:@"MERGE"];
        }
    }

    if ((corsHttpMethod & AZSCorsHttpMethodTrace) == AZSCorsHttpMethodTrace)
    {
        if (corsMethodsString == nil)
        {
            corsMethodsString = @"TRACE";
        }
        else
        {
            corsMethodsString = [corsMethodsString stringByAppendingString:@","];
            corsMethodsString = [corsMethodsString stringByAppendingString:@"TRACE"];
        }
    }

    if ((corsHttpMethod & AZSCorsHttpMethodDelete) == AZSCorsHttpMethodDelete)
    {
        if (corsMethodsString == nil)
        {
            corsMethodsString = @"DELETE";
        }
        else
        {
            corsMethodsString = [corsMethodsString stringByAppendingString:@","];
            corsMethodsString = [corsMethodsString stringByAppendingString:@"DELETE"];
        }
    }

    if ((corsHttpMethod & AZSCorsHttpMethodConnect) == AZSCorsHttpMethodConnect)
    {
        if (corsMethodsString == nil)
        {
            corsMethodsString = @"CONNECT";
        }
        else
        {
            corsMethodsString = [corsMethodsString stringByAppendingString:@","];
            corsMethodsString = [corsMethodsString stringByAppendingString:@"CONNECT"];
        }
    }

    if ((corsHttpMethod & AZSCorsHttpMethodOptions) == AZSCorsHttpMethodOptions)
    {
        if (corsMethodsString == nil)
        {
            corsMethodsString = @"OPTIONS";
        }
        else
        {
            corsMethodsString = [corsMethodsString stringByAppendingString:@","];
            corsMethodsString = [corsMethodsString stringByAppendingString:@"OPTIONS"];
        }
    }

    return corsMethodsString;
}


@end

