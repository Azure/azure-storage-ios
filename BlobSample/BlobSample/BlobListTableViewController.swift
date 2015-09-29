// -----------------------------------------------------------------------------------------
// <copyright file="BlobListTableViewController.swift" company="Microsoft">
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


import UIKit

class BlobListTableViewController: UITableViewController {

    // MARK: Authentication
    
    // If using a SAS token, fill it in here.  If using Shared Key access, comment out the following line.
    var containerURL = "https://myaccount.blob.core.windows.net/mysampleioscontainer?sv=2015-02-21&st=2009-01-01&se=2100-01-01&sr=c&sp=rwdl&sig=mylongsig="
    var usingSAS = true
    
    // If using Shared Key access, fill in your credentials here and un-comment the "UsingSAS" line:
    var connectionString = "DefaultEndpointsProtocol=https;AccountName=myaccount;AccountKey=myAccountKey=="
    var containerName = "sampleioscontainer"
    //var usingSAS = false
    
    // MARK: Properties
    
    var blobs = [AZSCloudBlob]()
    var container : AZSCloudBlobContainer
    var continuationToken : AZSContinuationToken?
    
    // MARK: Initializers
    
    required init?(coder aDecoder: NSCoder) {
        
        if (usingSAS) {
            self.container = AZSCloudBlobContainer(url: NSURL(string: containerURL)!)
        }
        else {
            let storageAccount = AZSCloudStorageAccount(fromConnectionString: connectionString)
        
            let blobClient = storageAccount.getBlobClient()
            self.container = blobClient.containerReferenceFromName(containerName)
        
            let condition = NSCondition()
            var containerCreated = false
        
            self.container.createContainerIfNotExistsWithCompletionHandler { (error : NSError?, created) -> Void in
                condition.lock()
                containerCreated = true
                condition.signal()
                condition.unlock()
            }
        
            condition.lock()
            while (!containerCreated) {
                condition.wait()
            }
            condition.unlock()
        }
        
        self.continuationToken = nil
        
        super.init(coder: aDecoder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.leftBarButtonItem = editButtonItem()
        reloadBlobList()
    }

    // MARK: - Table view data source

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return blobs.count
    }

    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        // Table view cells are reused and should be dequeued using a cell identifier.
        let cellIdentifier = "BlobListTableViewCell"
        
        let cell = tableView.dequeueReusableCellWithIdentifier(cellIdentifier, forIndexPath: indexPath) as! BlobListViewCell
        let blob = blobs[indexPath.row]
        
        cell.nameLabel.text = blob.blobName
        
        return cell
    }
    
    // Override to support conditional editing of the table view.
    override func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }
    
    // Override to support editing the table view.
    override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        if editingStyle == .Delete {
            // Delete the row from the data source
            
            let blob = blobs[indexPath.row]
            
            blob.deleteWithCompletionHandler({ (error : NSError?) -> Void in
                self.blobs.removeAtIndex(indexPath.row)
                self.performSelectorOnMainThread("deleteRowAtIndexPaths:", withObject:[indexPath], waitUntilDone: false)
            })
            
        } else if editingStyle == .Insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }    
    }
    
    func deleteRowAtIndexPaths(indexPaths: [NSIndexPath])
    {
        self.tableView.deleteRowsAtIndexPaths(indexPaths, withRowAnimation: .Fade)
    }

    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "ShowDetail" {
            let getBlobViewController = (segue.destinationViewController as! UINavigationController).topViewController as! GetBlobViewController
            
            if let selectedBlobCell = sender as? BlobListViewCell {
                let indexPath = tableView.indexPathForCell(selectedBlobCell)!
                let selectedBlob = blobs[indexPath.row]
                getBlobViewController.blob = selectedBlob
            }
        }
        else if segue.identifier == "AddItem" {
            
            let addBlobViewController = (segue.destinationViewController as! UINavigationController).viewControllers[0] as! AddBlobViewController
            
            addBlobViewController.container = container
            addBlobViewController.viewToReloadOnBlobAdd = self;
        }
    }
    
    func reloadBlobList() {
        container.listBlobsSegmentedWithContinuationToken(nil, prefix: nil, useFlatBlobListing: true, blobListingDetails: AZSBlobListingDetails.None, maxResults: 50) { (error : NSError?, results : AZSBlobResultSegment?) -> Void in
            
            self.blobs = [AZSCloudBlob]()
            
            for blob in results!.blobs!
            {
                self.blobs.append(blob as! AZSCloudBlob)
            }
            
            self.continuationToken = results!.continuationToken
            self.tableView.performSelectorOnMainThread("reloadData", withObject: nil, waitUntilDone: false)
        }
    }
    
    @IBAction func unwind(sender: UIStoryboardSegue) {        
    }
}






