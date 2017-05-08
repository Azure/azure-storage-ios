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
    // var usingSAS = false
    
    // MARK: Properties
    
    var blobs = [AZSCloudBlob]()
    var container : AZSCloudBlobContainer
    var continuationToken : AZSContinuationToken?
    
    // MARK: Initializers
    
    required init?(coder aDecoder: NSCoder) {
        if (usingSAS) {
            var error: NSError?
            self.container = AZSCloudBlobContainer(url: URL(string: containerURL)!, error: &error)
            if ((error) != nil) {
                print("Error in creating blob container object.  Error code = %ld, error domain = %@, error userinfo = %@", error!.code, error!.domain, error!.userInfo);
            }
        }
        else {
//            do {
                let storageAccount : AZSCloudStorageAccount;
                try! storageAccount = AZSCloudStorageAccount(fromConnectionString: connectionString)
                let blobClient = storageAccount.getBlobClient()
                self.container = blobClient.containerReference(fromName: containerName)
            
                let condition = NSCondition()
                var containerCreated = false
                
                self.container.createContainerIfNotExists { (error : Error?, created) -> Void in
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
//            } catch let error as NSError {
//                print("Error in creating blob container object.  Error code = %ld, error domain = %@, error userinfo = %@", error.code, error.domain, error.userInfo);
//            }
        }
        
        self.continuationToken = nil
        
        super.init(coder: aDecoder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.leftBarButtonItem = editButtonItem
        reloadBlobList()
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return blobs.count
    }

    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // Table view cells are reused and should be dequeued using a cell identifier.
        let cellIdentifier = "BlobListTableViewCell"
        
        let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath) as! BlobListViewCell
        let blob = blobs[indexPath.row]
        
        cell.nameLabel.text = blob.blobName
        
        return cell
    }
    
    // Override to support conditional editing of the table view.
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }
    
    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // Delete the row from the data source
            
            let blob = blobs[indexPath.row]
            
            blob.delete(completionHandler: { (error : Error?) -> Void in
                self.blobs.remove(at: indexPath.row)
                self.performSelector(onMainThread: #selector(BlobListTableViewController.deleteRowAtIndexPaths(_:)), with:[indexPath], waitUntilDone: false)
            })
            
        } else if editingStyle == .insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }    
    }
    
    func deleteRowAtIndexPaths(_ indexPaths: [IndexPath])
    {
        self.tableView.deleteRows(at: indexPaths, with: .fade)
    }

    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "ShowDetail" {
            let getBlobViewController = (segue.destination as! UINavigationController).topViewController as! GetBlobViewController
            
            if let selectedBlobCell = sender as? BlobListViewCell {
                let indexPath = tableView.indexPath(for: selectedBlobCell)!
                let selectedBlob = blobs[indexPath.row]
                getBlobViewController.blob = selectedBlob
            }
        }
        else if segue.identifier == "AddItem" {
            
            let addBlobViewController = (segue.destination as! UINavigationController).viewControllers[0] as! AddBlobViewController
            
            addBlobViewController.container = container
            addBlobViewController.viewToReloadOnBlobAdd = self;
        }
    }
    
    func reloadBlobList() {
        container.listBlobsSegmented(with: nil, prefix: nil, useFlatBlobListing: true, blobListingDetails: AZSBlobListingDetails(), maxResults: 50) { (error : Error?, results : AZSBlobResultSegment?) -> Void in
            
            self.blobs = [AZSCloudBlob]()
            
            for blob in results!.blobs!
            {
                self.blobs.append(blob as! AZSCloudBlob)
            }
            
            self.continuationToken = results!.continuationToken
            self.tableView.performSelector(onMainThread: #selector(UICollectionView.reloadData), with: nil, waitUntilDone: false)
        }
    }
    
    @IBAction func unwind(_ sender: UIStoryboardSegue) {        
    }
}






