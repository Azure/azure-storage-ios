// -----------------------------------------------------------------------------------------
// <copyright file="AddBlobViewController.swift" company="Microsoft">
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

class AddBlobViewController: UIViewController, UITextFieldDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    // MARK: Properties
    @IBOutlet weak var nameTextField: UITextField!
    @IBOutlet weak var saveButton: UIBarButtonItem!
    @IBOutlet weak var textTextField: UITextField!
    
    var container: AZSCloudBlobContainer?
    var viewToReloadOnBlobAdd : BlobListTableViewController?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Handle the text field's user input through delegate callbacks.
        
        nameTextField.delegate = self
        textTextField.delegate = self
        
        checkValidBlobName()
    }

    // MARK: UITextFieldDelegate
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        // Hide the keyboard
        textField.resignFirstResponder()
        
        return true
    }
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        saveButton.isEnabled = false
    }
    
    func checkValidBlobName() {
        // Disable save if text field is empty.
        let text = nameTextField.text ?? ""
        saveButton.isEnabled = !text.isEmpty
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        checkValidBlobName()
        if (textField === nameTextField) {
            navigationItem.title = textField.text
        }
    }
    
    // MARK: UIImagePickerControllerDelegate
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true, completion: nil)
    }
    
    // MARK: Navigation
    @IBAction func cancel(_ sender: UIBarButtonItem) {
        dismiss(animated: true, completion: nil)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if saveButton.isEqual(sender) {
            let name = nameTextField.text ?? ""
          
            if (!name.isEmpty)
            {
                let blob = container!.blockBlobReference(fromName: name)
                
                blob.upload(fromText: textTextField.text ?? "",  completionHandler: { (error: Error?) -> Void in
                    if (self.viewToReloadOnBlobAdd != nil) {
                        self.viewToReloadOnBlobAdd!.reloadBlobList()
                    }
                })
            }
        }
    }
}

