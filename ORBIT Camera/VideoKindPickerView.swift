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
    
    /// The kind currently selected. If no choice has been made, kind is nil.
    var kind: Video.Kind? {
        get {
            let row = selectedRow(inComponent: 0)
            return (row == 0) ? nil : Video.Kind.allCases[row - 1]
        }
        set {
            let row: Int
            if newValue == nil {
                row = 0
            } else {
                row = 1 + Array(Video.Kind.allCases).firstIndex(of: newValue)!
            }
            selectRow(row, inComponent: 0, animated: true)
        }
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        dataSource = self
        delegate = self
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        row == 0 ? "Choose..." : Video.Kind.allCases[row - 1].description()
    }
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int { 1 }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int { 1 + Video.Kind.allCases.count }
}
