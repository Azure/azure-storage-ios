// -----------------------------------------------------------------------------------------
// <copyright file="AZSShareAccessSignatureHelper.m" company="Microsoft">
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
#import "AZSCloudClient.h"
#import "AZSErrors.h"
#import "AZSOperationContext.h"
#import "AZSNavigationUtil.h"
#import "AZSSharedAccessAccountParameters.h"
#import "AZSSharedAccessBlobParameters.h"
#import "AZSSharedAccessHeaders.h"
#import "AZSSharedAccessSignatureHelper.h"
#import "AZSStorageUri.h"
#import "AZSUtil.h"
#import "AZSStorageCredentials.h"
#import "AZSUriQueryBuilder.h"

@implementation AZSSharedAccessSignatureHelper

+(AZSUriQueryBuilder *)sharedAccessSignatureForAccountWithParameters:(AZSSharedAccessAccountParameters*)parameters signature:(NSString *)signature error:(NSError **)error
{
    return [AZSSharedAccessSignatureHelper sharedAccessSignatureWithPermissions:parameters.permissions services:parameters.services resourceTypes:parameters.resourceTypes sharedAccessStartTime:parameters.sharedAccessStartTime sharedAccessExpiryTime:parameters.sharedAccessExpiryTime startPartitionKey:nil startRowKey:nil endPartitionKey:nil endRowKey:nil headers:nil storedPolicyIdentifier:nil resourceType:nil ipAddressOrRange:parameters.ipAddressOrRange protocols:parameters.protocols tableName:nil signature:signature error:error];
}

+(AZSUriQueryBuilder *)sharedAccessSignatureForBlobWithParameters:(AZSSharedAccessBlobParameters *)parameters resourceType:(NSString *)resourceType signature:(NSString *)signature error:(NSError **)error
{
    if (!resourceType) {
        *error = [NSError errorWithDomain:AZSErrorDomain code:AZSEInvalidArgument userInfo:nil];
        [[AZSUtil operationlessContext] logAtLevel:AZSLogLevelError withMessage:@"Missing resourceType argument."];
        return nil;
    }
    
    return [AZSSharedAccessSignatureHelper sharedAccessSignatureWithPermissions:parameters.permissions services:AZSSharedAccessServicesNone resourceTypes:AZSSharedAccessResourceTypesNone sharedAccessStartTime:parameters.sharedAccessStartTime sharedAccessExpiryTime:parameters.sharedAccessExpiryTime startPartitionKey:nil startRowKey:nil endPartitionKey:nil endRowKey:nil headers:parameters.headers storedPolicyIdentifier:parameters.storedPolicyIdentifier resourceType:resourceType ipAddressOrRange:parameters.ipAddressOrRange protocols:parameters.protocols tableName:nil signature:signature error:error];
}

+(NSString *)sharedAccessSignatureHashForAccountWithParameters:(AZSSharedAccessAccountParameters*)parameters accountName:(NSString*)accountName credentials:(AZSStorageCredentials *)credentials error:(NSError **)error
{
    if (!accountName) {
        *error = [NSError errorWithDomain:AZSErrorDomain code:AZSEInvalidArgument userInfo:nil];
        [[AZSUtil operationlessContext] logAtLevel:AZSLogLevelError withMessage:@"Missing account name argument."];
        return nil;
    }
    
    NSString *stringToSign = [NSString stringWithFormat:@"%@\n%@\n%@\n%@\n%@\n%@\n%@\n%@\n%@\n", accountName,
                              [AZSSharedAccessSignatureHelper emptyIfNilString:[AZSSharedAccessSignatureHelper stringFromPermissions:parameters.permissions error:error]],
                              [AZSSharedAccessSignatureHelper emptyIfNilString:[AZSSharedAccessSignatureHelper stringFromServices:parameters.services error:error]],
                              [AZSSharedAccessSignatureHelper emptyIfNilString:[AZSSharedAccessSignatureHelper stringFromResourceTypes:parameters.resourceTypes error:error]],
                              [AZSUtil utcTimeOrEmptyWithDate:parameters.sharedAccessStartTime], [AZSUtil utcTimeOrEmptyWithDate:parameters.sharedAccessExpiryTime],
                              [AZSSharedAccessSignatureHelper emptyIfNilString:parameters.ipAddressOrRange.rangeString],
                              [AZSSharedAccessSignatureHelper emptyIfNilString:[AZSSharedAccessSignatureHelper stringFromProtocols:parameters.protocols error:error]],
                              AZSCTargetStorageVersion];
    
    return (*error) ? nil : [AZSSharedAccessSignatureHelper sharedAccessSignatureHashWithStringToSign:stringToSign credentials:credentials error:error];
}

+(NSString *)sharedAccessSignatureHashForBlobWithParameters:(AZSSharedAccessBlobParameters *)parameters resourceName:(NSString *)resourceName client:(AZSCloudClient *)client error:(NSError **)error
{
    NSString *stringToSign = [AZSSharedAccessSignatureHelper sharedAccessSignatureStringToSignWithPermissions:parameters.permissions sharedAccessStartTime:parameters.sharedAccessStartTime sharedAccessExpiryTime:parameters.sharedAccessExpiryTime resource:resourceName storedPolicyIdentifier:parameters.storedPolicyIdentifier ipAddressOrRange:parameters.ipAddressOrRange protocols:parameters.protocols error:error];
    
    if (!stringToSign) {
        // An error occurred. Error will have been set by sharedAccessSignatureStringToSignWithParameters.
        return nil;
    }
    
    stringToSign = [NSString stringWithFormat:AZSCSasTemplateBlobParameters, stringToSign, [AZSSharedAccessSignatureHelper emptyIfNilString:parameters.headers.cacheControl], [AZSSharedAccessSignatureHelper emptyIfNilString:parameters.headers.contentDisposition], [AZSSharedAccessSignatureHelper emptyIfNilString:parameters.headers.contentEncoding], [AZSSharedAccessSignatureHelper emptyIfNilString:parameters.headers.contentLanguage], [AZSSharedAccessSignatureHelper emptyIfNilString:parameters.headers.contentType]];
    return [AZSSharedAccessSignatureHelper sharedAccessSignatureHashWithStringToSign:stringToSign credentials:[client credentials] error:error];
}

+(NSString *)emptyIfNilString:(NSString *)testString
{
    return testString ?: AZSCEmptyString;
}

+(AZSUriQueryBuilder *)sharedAccessSignatureWithPermissions:(AZSSharedAccessPermissions)permissions services:(AZSSharedAccessServices)services resourceTypes:(AZSSharedAccessResourceTypes)resourceTypes sharedAccessStartTime:(NSDate *)startTime sharedAccessExpiryTime:(NSDate *)expiryTime startPartitionKey:(NSString *)startPartitionKey startRowKey:(NSString *)startRowKey endPartitionKey:(NSString *)endPartitionKey endRowKey:(NSString *)endRowKey headers:(AZSSharedAccessHeaders *)headers storedPolicyIdentifier:(NSString *)storedPolicyIdentifier resourceType:(NSString *)resourceType ipAddressOrRange:(AZSIPRange *)ipAddressOrRange protocols:(AZSSharedAccessProtocols)protocols tableName:(NSString *)tableName signature:(NSString *)signature error:(NSError **)error
{
    if (!signature) {
        *error = [NSError errorWithDomain:AZSErrorDomain code:AZSEInvalidArgument userInfo:nil];
        [[AZSUtil operationlessContext] logAtLevel:AZSLogLevelError withMessage:@"Missing signature argument."];
        return nil;
    }
    
    AZSUriQueryBuilder *builder = [[AZSUriQueryBuilder alloc] init];
    [builder addIfNotNilOrEmptyWithKey:AZSCSasPermissions value:[AZSSharedAccessSignatureHelper stringFromPermissions:permissions error:error]];
    if (*error) {
        // An error occurred.
        return nil;
    }
    
    [builder addIfNotNilOrEmptyWithKey:AZSCSasServices value:[AZSSharedAccessSignatureHelper stringFromServices:services error:error]];
    if (*error) {
        return nil;
    }
    
    [builder addIfNotNilOrEmptyWithKey:AZSCSasResourceTypes value:[AZSSharedAccessSignatureHelper stringFromResourceTypes:resourceTypes error:error]];
    if (*error) {
        return nil;
    }
    
    [builder addIfNotNilOrEmptyWithKey:AZSCSasProtocolRestriction value:[AZSSharedAccessSignatureHelper stringFromProtocols:protocols error:error]];
    if (*error) {
        return nil;
    }
    
    [builder addWithKey:AZSCSasServiceVersion value: AZSCTargetStorageVersion];
    
    NSString *startString = [AZSUtil utcTimeOrEmptyWithDate:startTime];
    [builder addIfNotNilOrEmptyWithKey:AZSCSasStartTime value:startString];
    
    NSString *expiryString = [AZSUtil utcTimeOrEmptyWithDate:expiryTime];
    [builder addIfNotNilOrEmptyWithKey:AZSCSasExpiryTime value:expiryString];
    
    [builder addIfNotNilOrEmptyWithKey:AZSCSasStartPartionKey value:startPartitionKey];
    [builder addIfNotNilOrEmptyWithKey:AZSCSasStartRowKey value:startRowKey];
    [builder addIfNotNilOrEmptyWithKey:AZSCSasEndPartionKey value:endPartitionKey];
    [builder addIfNotNilOrEmptyWithKey:AZSCSasEndRowKey value:endRowKey];
    
    [builder addIfNotNilOrEmptyWithKey:AZSCSasStoredIdentifier value:storedPolicyIdentifier];
    [builder addIfNotNilOrEmptyWithKey:AZSCSasResource value:resourceType];
    [builder addIfNotNilOrEmptyWithKey:AZSCSasIpAddressOrRange value:ipAddressOrRange.rangeString];
    
    [builder addIfNotNilOrEmptyWithKey:AZSCSasTableName value:tableName];
    
    [builder addIfNotNilOrEmptyWithKey:AZSCSasCacheControl value:headers.cacheControl];
    [builder addIfNotNilOrEmptyWithKey:AZSCSasContentType value:headers.contentType];
    [builder addIfNotNilOrEmptyWithKey:AZSCSasContentEncoding value:headers.contentEncoding];
    [builder addIfNotNilOrEmptyWithKey:AZSCSasContentLanguage value:headers.contentLanguage];
    [builder addIfNotNilOrEmptyWithKey:AZSCSasContentDisposition value:headers.contentDisposition];
    
    [builder addIfNotNilOrEmptyWithKey:AZSCQuerySig value:signature];
    
    return builder;
}

+(NSString *)sharedAccessSignatureHashWithStringToSign:(NSString *)stringToSign credentials:(AZSStorageCredentials *)credentials error:(NSError **)error
{
    if (!credentials) {
        *error = [NSError errorWithDomain:AZSErrorDomain code:AZSEInvalidArgument userInfo:nil];
        [[AZSUtil operationlessContext] logAtLevel:AZSLogLevelError withMessage:@"Client is missing credentials."];
        return nil;
    }
    
    [[AZSUtil operationlessContext] logAtLevel:AZSLogLevelInfo withMessage:@"String To Sign:\n%@", stringToSign];
    
    /* TODO: Add AZSUtil safeDecode */;
    return [AZSUtil computeHmac256WithString:stringToSign credentials:credentials];
}

+(NSString *)sharedAccessSignatureStringToSignWithPermissions:(AZSSharedAccessPermissions)permissions sharedAccessStartTime:(NSDate *)startTime sharedAccessExpiryTime:(NSDate *)expiryTime resource:(NSString *)resource storedPolicyIdentifier:(NSString *)storedPolicyIdentifier ipAddressOrRange:(AZSIPRange *)ipAddressOrRange protocols:(AZSSharedAccessProtocols)protocols error:(NSError **)error
{
    if (!resource) {
        *error = [NSError errorWithDomain:AZSErrorDomain code:AZSEInvalidArgument userInfo:nil];
        [[AZSUtil operationlessContext] logAtLevel:AZSLogLevelError withMessage:@"Missing resource argument."];
        return nil;
    }
    
    NSString *stringToSign = [NSString stringWithFormat:AZSCSasTemplateBlobStringToSign,
            [AZSSharedAccessSignatureHelper emptyIfNilString:[AZSSharedAccessSignatureHelper stringFromPermissions:permissions error:error]],
            [AZSUtil utcTimeOrEmptyWithDate:startTime], [AZSUtil utcTimeOrEmptyWithDate:expiryTime],
            resource, [AZSSharedAccessSignatureHelper emptyIfNilString:storedPolicyIdentifier], [AZSSharedAccessSignatureHelper emptyIfNilString:ipAddressOrRange.rangeString],
            [AZSSharedAccessSignatureHelper stringFromProtocols:protocols error:error], AZSCTargetStorageVersion];
    return (*error) ? nil : stringToSign;
}

+(NSString *)stringFromProtocols:(AZSSharedAccessProtocols)protocols error:(NSError **)error
{
    switch (protocols) {
        case AZSSharedAccessProtocolAll:
            return AZSCEmptyString;
            
        case AZSSharedAccessProtocolHttpsOnly:
            return AZSCHttps;
            
        case AZSSharedAccessProtocolHttpsHttp:
            return AZSCSasProtocolsHttpsHttp;
            
        default:
            *error = (*error) ?: [NSError errorWithDomain:AZSErrorDomain code:AZSEInvalidArgument userInfo:nil];
            [[AZSUtil operationlessContext] logAtLevel:AZSLogLevelError withMessage:@"Unrecognized protocol restriction."];
            return nil;
    }
}

+(NSString *)stringFromServices:(AZSSharedAccessServices)services error:(NSError **)error
{
    if (*error) {
        // There was already an error.
        return nil;
    }
    
    if (services & ~AZSSharedAccessServicesAll) {
        *error = [NSError errorWithDomain:AZSErrorDomain code:AZSEInvalidArgument userInfo:nil];
        [[AZSUtil operationlessContext] logAtLevel:AZSLogLevelError withMessage:@"Unrecognized services argument."];
        return nil;
    }
    
    NSMutableString *builder = [[NSMutableString alloc] init];
    if (services & AZSSharedAccessServicesBlob) {
        [builder appendString:@"b"];
    }
    if (services & AZSSharedAccessServicesFile) {
        [builder appendString:@"f"];
    }
    if (services & AZSSharedAccessServicesQueue) {
        [builder appendString:@"q"];
    }
    if (services & AZSSharedAccessServicesTable) {
        [builder appendString:@"t"];
    }
    
    return builder;
}

+(NSString *)stringFromResourceTypes:(AZSSharedAccessResourceTypes)resourceTypes error:(NSError **)error
{
    if (*error) {
        // There was already an error.
        return nil;
    }
    
    if (resourceTypes & ~AZSSharedAccessServicesAll) {
        *error = [NSError errorWithDomain:AZSErrorDomain code:AZSEInvalidArgument userInfo:nil];
        [[AZSUtil operationlessContext] logAtLevel:AZSLogLevelError withMessage:@"Unrecognized resource types argument."];
        return nil;
    }
    
    NSMutableString *builder = [[NSMutableString alloc] init];
    if (resourceTypes & AZSSharedAccessResourceTypesService) {
        [builder appendString:@"s"];
    }
    if (resourceTypes & AZSSharedAccessResourceTypesContainer) {
        [builder appendString:@"c"];
    }
    if (resourceTypes & AZSSharedAccessResourceTypesObject) {
        [builder appendString:@"o"];
    }
    
    return builder;
}

+(NSString *)stringFromPermissions:(AZSSharedAccessPermissions)permissions error:(NSError **)error
{
    if (*error) {
        // There was already an error.
        return nil;
    }
    
    if (permissions & ~AZSSharedAccessPermissionsAll) {
        *error = [NSError errorWithDomain:AZSErrorDomain code:AZSEInvalidArgument userInfo:nil];
        [[AZSUtil operationlessContext] logAtLevel:AZSLogLevelError withMessage:@"Unrecognized permissions argument."];
        return nil;
    }
    
    NSMutableString *builder = [[NSMutableString alloc] init];
    if (permissions & AZSSharedAccessPermissionsRead) {
        [builder appendString:AZSCSasPermissionsRead];
    }
    if (permissions & AZSSharedAccessPermissionsAdd) {
        [builder appendString:AZSCSasPermissionsAdd];
    }
    if (permissions & AZSSharedAccessPermissionsCreate) {
        [builder appendString:AZSCSasPermissionsCreate];
    }
    if (permissions & AZSSharedAccessPermissionsWrite) {
        [builder appendString:AZSCSasPermissionsWrite];
    }
    if (permissions & AZSSharedAccessPermissionsDelete) {
        [builder appendString:AZSCSasPermissionsDelete];
    }
    if (permissions & AZSSharedAccessPermissionsList) {
        [builder appendString:AZSCSasPermissionsList];
    }
    
    return builder;
}

+(AZSSharedAccessPermissions)permissionsFromString:(NSString *)permissionString error:(NSError **)error
{
    AZSSharedAccessPermissions permissions = AZSSharedAccessPermissionsNone;
    
    for (int i = 0; i < permissionString.length; i++) {
        char c = [permissionString characterAtIndex:i];
        
        if (c == 'r') {
            permissions |= AZSSharedAccessPermissionsRead;
        }
        else if (c == 'a') {
            permissions |= AZSSharedAccessPermissionsAdd;
        }
        else if (c == 'c') {
            permissions |= AZSSharedAccessPermissionsCreate;
        }
        else if (c == 'w') {
            permissions |= AZSSharedAccessPermissionsWrite;
        }
        else if (c == 'd') {
            permissions |= AZSSharedAccessPermissionsDelete;
        }
        else if (c == 'l') {
            permissions |= AZSSharedAccessPermissionsList;
        }
        else {
            *error = [NSError errorWithDomain:AZSErrorDomain code:AZSEInvalidArgument userInfo:nil];
            [[AZSUtil operationlessContext] logAtLevel:AZSLogLevelError withMessage:@"Unrecognized permissions character."];
            return NSUIntegerMax;
        }
    }
    
    return permissions;
}

@end