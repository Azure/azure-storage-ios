// -----------------------------------------------------------------------------------------
// <copyright file="GetBlobViewController.swift" company="Microsoft">
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

class GetBlobViewController: UIViewController, UITextViewDelegate, UITextFieldDelegate, UINavigationControllerDelegate {

    // MARK: Properties
    
    @IBOutlet weak var TempTextField: UITextField!
    @IBOutlet weak var textview: UITextView!
    var blob: AZSCloudBlob?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        TempTextField.delegate = self
        textview.delegate = self
        
        if let blob = blob {
            TempTextField.text = blob.blobName
            textview.text = "Blob text loading..."
            
            blob.downloadToTextWithCompletionHandler({ (error : NSError?, blobText : String?) -> Void in
                self.performSelectorOnMainThread("setBlobText:", withObject: blobText, waitUntilDone: false)
            })
        }

        // Do any additional setup after loading the view.
    }
    
    func setBlobText(blobText : String) {
        self.textview.text = blobText
    }

    // MARK: - Navigation
    @IBAction func cancel(sender: UIBarButtonItem) {
        dismissViewControllerAnimated(true, completion: nil)
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
    }
}
