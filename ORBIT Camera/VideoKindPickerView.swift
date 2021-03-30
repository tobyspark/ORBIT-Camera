//
//  VideoKindPickerView.swift
//  ORBIT Camera
//
//  Created by Toby Harris on 31/03/2020.
//  https://tobyz.net
//
//  Copyright © 2020 City, University of London. All rights reserved.
//  https://hcid.city
//

import UIKit

/// A UIPickerView to select the video kind.
class VideoKindPickerView: UIPickerView, UIPickerViewDelegate, UIPickerViewDataSource, UIPickerViewAccessibilityDelegate {
    
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
    
    func incrementSelection() {
        let row = selectedRow(inComponent: 0)
        let count = pickerView(self, numberOfRowsInComponent: 0)
        let candidateValue = row + 1
        if candidateValue < count {
            selectRow(candidateValue, inComponent: 0, animated: true)
        }
    }
    
    func decrementSelection() {
        let row = selectedRow(inComponent: 0)
        let candidateValue = row - 1
        if candidateValue >= 0 {
            selectRow(candidateValue, inComponent: 0, animated: true)
        }
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        dataSource = self
        delegate = self
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? { Video.Kind.allCases[row].description }
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int { 1 }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int { Video.Kind.allCases.count }
    
    func pickerView(_ pickerView: UIPickerView, accessibilityLabelForComponent component: Int) -> String? { "Kind of video" }
    
    func pickerView(_ pickerView: UIPickerView, accessibilityHintForComponent component: Int) -> String? { "Sets whether this is a training or test video" }
}

/// A view controller that hosts a VideoKindPickerView
/// To be used as a popover element regardless of size class
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
