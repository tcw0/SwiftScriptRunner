//
//  CustomTextView.swift
//  SwiftScriptRunner
//
//  Created by Tan-Colin Wei on 04.11.24.
//

import AppKit

class CustomTextView: NSTextView {
    let matchingPairs: [Character: Character] = [
        "(": ")",
        "[": "]",
        "{": "}",
        "\"": "\"",
        "'": "'"
    ]
    
    override func keyDown(with event: NSEvent) {
        guard let characters = event.characters else {
            super.keyDown(with: event)
            return
        }
        
        if let firstChar = characters.first, matchingPairs.keys.contains(firstChar) {
            // Handle opening brackets and quotes
            if let matchingChar = matchingPairs[firstChar] {
                let newString = "\(firstChar)\(matchingChar)"
                let selectedRange = self.selectedRange()
                self.insertText(newString, replacementRange: selectedRange)
                self.setSelectedRange(NSRange(location: selectedRange.location + 1, length: 0))
                return
            }
        }
        
        super.keyDown(with: event)
    }
}
