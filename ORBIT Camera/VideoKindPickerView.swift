//
//  VideoKindPickerView.swift
//  ORBIT Camera
//
//  Created by Toby Harris on 31/03/2020.
//  Copyright © 2020 Toby Harris. All rights reserved.
//

import UIKit

/// A UIPickerView to select the video kind.
class VideoKindPickerView: UIPickerView, UIPickerViewDelegate, UIPickerViewDataSource {
    
    /// The kind currently selected.
    var kind: Video.Kind {
        get {
            let row = selectedRow(inComponent: 0)
            return Video.Kind.allCases[row]
        }
        set {
            let row = Array(Video.Kind.allCases).firstIndex(of: newValue)!
            selectRow(row, inComponent: 0, animated: true)
        }
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        dataSource = self
        delegate = self
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? { Video.Kind.allCases[row].description() }
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int { 1 }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int { Video.Kind.allCases.count }
}

class VideoKindPickerViewController: UIViewController, UIPopoverPresentationControllerDelegate {
    
    @IBOutlet weak var videoKindPicker: VideoKindPickerView!
    
    var dismissHandler: ( (Video.Kind)->Void )? = nil
    
    func presentationControllerWillDismiss(_ presentationController: UIPresentationController) {
        if let dismissHandler = dismissHandler {
            dismissHandler(videoKindPicker.kind)
        }
    }

    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle { .none }
}
