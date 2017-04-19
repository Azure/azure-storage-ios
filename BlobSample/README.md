README - PLEASE READ THIS BEFORE ATTEMPTING TO RUN THE SAMPLE APP
=====================

This sample is written in Swift 3, targeting iOS 10.3 and using Xcode 8.  If you have a different setup, the sample may not run
properly.  More samples (for Objective-C, and tested against older versions of iOS are coming soon.)

This sample runs against the actual service, so it is highly recommended that you use a test container, as you will be creating and deleting actual blobs.

### To run the sample:

###### Compile the framework
1. Acquire the source from https://github.com/Azure/azure-storage-ios.  
2. Before building the storage code, make one change in the project.  Go to 'Azure Storage Client Library' -> Build Settings, search for the "Defines Module" setting, and change it to 'YES'.
3. Build the library as normal (build the Azure Storage Client Library scheme, then build the Framework scheme.)  This will put the framework file on your desktop.
4. Open the sample application.  It should build out-of-the-box, although it expects to find the framework on your desktop.
5. Navigate to the BlobListTableViewController.swift file.  This is where you can enter your authentication details, required for your application to talk to Azure Storage.  There are two options:

###### Add your storage credentials
1. Using a SAS token.  The samples will work if you have a SAS token to a blob container, under the following constraints:
	- The SAS token is a token to a blob container, not a blob
	- The SAS token grants Read, Write, List, and Delete access
    - The container already exists.  (You cannot create containers with a container SAS token.)

    To use this method, replace the "containerURL" variable near the top of the 'BlobListTableViewController.swift' file with the full URL to the blob container, including the SAS token.

	Using a SAS token is always the better option with any mobile SDK, but you will need to use a different toolset to generate the token. The easiest option is to use the [Azure Storage Explorer](http://storageexplorer.com/). If you cannot / don't want to for the purposes of this demo, you can use the other auth method:

2. Use a connection string that specifies both your account name and account key.  Note that in this case, the sample will attempt to create the container if it does not exist.  To use Shared Key access in this manner, replace the "connectionString" variable near the top of the 'BlobListTableViewController.swift' file with your connection string, AND replace the "containerName" with the name of the container you wish to use.  Finally, uncomment the 'var usingSAS = false' line and comment out the 'var usingSAS = true' line.
6. Run the application.

### Using the Samples

This sample is a standalone application demonstrating a few simple use cases of the Storage Client.  When the sample loads, it will load up to the first 50 blobs in the container and display them on-screen.  You can add new blobs by tapping the '+' button, typing in the blob name and blob text you wish to have, and hitting 'Save'.  ('Save' will asynchronously upload a blob to the Azure Storage Service, and then refresh the main page with the updated blob list.)  You can also fetch and view a blob's contents as text by tapping on the blob, and you can delete a blob by hitting the 'Edit' button in the top left.

### Additional notes:
- Currently, the samples contain no error-handling code whatsoever.  The most likely sources of error are:
    - Bad network connection
    - Incorrect authentication
    - Blobs that are not text (this may confuse the sample)
  We will be updating these samples with more robust code shortly.
- Hopefully the code will be helpful, but the application certainly isn't pretty.  We will have a better-looking sample project in the future.
- The initialization code for creating the container (in the Shared Key case) is done synchronously, but this is generally a bad practice.  The other calls are all async, this is a pattern you likely want to follow.
- The samples, like the rest of the library, are in preview.  If anything goes wrong or doesn't work, please get in touch.
