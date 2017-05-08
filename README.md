Azure Storage Client Library for iOS
===============

### Overview
This library is designed to help you build iOS applications that use Microsoft Azure Storage.
At the moment, the library is in a preview stage, so thank you for taking a look!  It will be some time before the library is stable.  In the meantime, we would like to get as much input as possible from the community.  Please let us know of any issues you encounter by opening an issue on Github.

The library currently supports almost all blob operations (some exceptions noted below.)  Other services (table, queue, file) are forthcoming, depending on demand.

### How to get started

The recommended way to use the library is through a Cocoapod, available [here](https://cocoapods.org/pods/AZSClient).

```ruby
platform :ios, '8.0'

target 'TargetName' do 
  use_frameworks!
  pod 'AZSClient'
end
```
If you are using Objective-C:
```objc
#import <AZSClient/AZSClient.h>
```

If you are using Swift:
```swift
import AZSClient
```

Otherwise, you can build the library from soruce.  To do so, clone the repo and open the Xcode project.  Build the library (the 'Azure Storage Client Library' target), and then build the Framework (the 'Framework' target).  This will create the .framework file on your desktop.  Then, in your code, in Build Phases->Link Binary With Libraries, add in the Azure Storage Client Library framework, and the libxml2.2.dylib.  Finally, import <AZSClient/AZSClient.h> in your code file. If you are using Swift, you will need to create a bridging header and import <AZSClient/AZSClient.h> there.

Here is a small code sample that creates and deletes a blob:

```objc
-(void)createAndDeleteBlob
{
    // Create a semaphore to prevent the method from exiting before all of the async operations finish.
    // In most real applications, you wouldn't do this, it makes this whole series of operations synchronous.
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    // Create a storage account object from a connection string.
    AZSCloudStorageAccount *account = [AZSCloudStorageAccount accountFromConnectionString:@"myConnectionString"];
    
    // Create a blob service client object.
    AZSCloudBlobClient *blobClient = [account getBlobClient];
    
    // Create a local container object with a unique name.
    NSString *containerName = [[NSString stringWithFormat:@"sampleioscontainer%@",[[[NSUUID UUID] UUIDString] stringByReplacingOccurrencesOfString:@"-" withString:@""]] lowercaseString];
    AZSCloudBlobContainer *blobContainer = [blobClient containerReferenceFromName:containerName];
    
    // Create the container on the service and check to see if there was an error.
    [blobContainer createContainerWithCompletionHandler:^(NSError* error){
        if (error != nil){
            NSLog(@"Error in creating container.");
        }
        
        // Create a local blob object
        AZSCloudBlockBlob *blockBlob = [blobContainer blockBlobReferenceFromName:@"blockBlob"];
        
        // Get some sample text for the blob
        NSString *blobText = @"Sample blob text";
        
        // Upload the text to the blob.
        [blockBlob uploadFromText:blobText completionHandler:^(NSError *error) {
            if (error != nil){
                NSLog(@"Error in uploading blob.");
            }
            
            // Download the blob's contents to a new text string.
            [blockBlob downloadToTextWithCompletionHandler:^(NSError *error, NSString *resultText) {
                if (error != nil){
                    NSLog(@"Error in downloading blob.");
                }
                
                // Validate that the uploaded/downloaded string is correct.
                if (![blobText isEqualToString:resultText])
                {
                    NSLog(@"Error - the text in the blob does not match.");
                }
                
                // Delete the container from the service.
                [blobContainer deleteContainerWithCompletionHandler:^(NSError* error){
                    if (error != nil){
                        NSLog(@"Error in deleting container.");
                    }
                    
                    dispatch_semaphore_signal(semaphore);
                }];
            }];
        }];
    }];
    
    // Pause the method until the above operations complete.
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
}
```

In general, all methods in the Storage Client that make service calls are asynchronous, roughly in the style of NSURLSession.  When you call methods on the Storage Client that interact with the Storage Service, you need to pass in a completion handler block to handle the results of the operation.  Service calls will return before the operation is complete.

More detailed examples can be found in the test code; better samples are coming soon.
Also coming soon: API docs, a getting-started guide, and a downloadable framework file.  This page will be updated with the relevant links when they're available.

### Functionality

- Create/List/Delete/Lease Containers.
- Create/List/Read/Update/Delete/Lease/StartAsyncCopy Blobs.
  - Read/Write from/to Blobs with an NSStream, NSString, NSData, or local file.
  - Operations for specific blob types (block operations for block blobs, etc.)
- Container and Blob properties and metadata.
- Get/Set Service Properties (properties for Storage Analytics and CORS rules).
- Blob virtual directories.
- Use Shared Key authentication or SAS authentication.
- Access conditions, automatic retries and retry policies, and logging.

### Missing functionality

The following functionality is all coming soon:
- If you want to download a blob's contents to a stream, this is possible using the DownloadToStream method on AZSCloudBlob.  However, it is not yet possible to open an input stream that reads directly from the blob.
- There are a number of internal details that will change in the upcoming releases.  If you look at the internals of the library (or fork it), be prepared.  Much of this will be clean-up related.

### Specific areas we would like feedback on:

- NSOperation support.  We have had requests to use NSOperation as the primary method of using the library - methods such as 'UploadFromText' would return an NSOperation, that could then be scheduled in an operation queue.  However, this approach seems to have several drawbacks, notably along the lines of error handling and data return.  (For example, imagine trying to implement a 'CreateIfNotExists' method, using 'Exists' and 'Create'.  If they both returned an NSOperation, you could have the 'Create' operation depend on the 'Exists' operation, but the 'Create' operation would need to behave differently in the case that 'Exists' returns an error, or that the resource already exists.)  If you have suggestions, please discuss in the wiki, or open an issue.
- The Azure Storage client currently uses NSURLSession behind the scenes to perform the HTTP requests.  Currently, the client does not expose the delegate queue or various session configuration options to users, other than what will be exposed in the RequestOptions object.  Is this something you would like to have control over?

### Logging
If you are having problems with the library, turning on logging may help.  Some notes:
- All logging is done through the AZSOperationContext.  You can either set a global logger (static on the AZSOperationContext class), and/or set a logger on a per-AZSOperationContext basis (both the global and instance loggers will be logged to, if available.)  The library supports ASL logging by default, just pass an aslclient into either setGlobalLogger: or setLogger:withCondition:.  You can also define your own logging function, with setLogFunction: and setGlobalLogFunction:.  This will call into the input block, allowing you to log however you like.
- Note that the library is multi-threaded.  If you use the global ASL logger, this is handled properly for you by the library.  If you use setLogger:withCondition:, the library will lock on the input condition before logging to the given logger.  It's important to associate loggers with the correct NSCondition objects when setting them, otherwise the single-threaded requirement of the aslclient will not be met.  If you pass in your own logging function(s), you should expect that they will be called in a multithreaded context, and you will need to take care of any required locking yourself.
- You will need to set a minimum log level on either the global or instance logger.  AZSLogLevelInfo should be sufficient for almost every scenario.  (It will log all REST calls that the library makes, as well as details about signing.)  Note that the library does not hide any authentication info, so your logs may contain sensitive data.  This makes any potential problems easier to diagnose.

### Internals
If you would like to look at the internals of the library, please do, but be aware that we will be iterating over the next several releases, drastic changes may occur.
If you would like to run the tests, you will need to provide your own credentials in the test_configurations.json file.  You will also have to change the scheme to actually build and run the tests, and you may need to enable code signing as well.
