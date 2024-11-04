//
//  ScriptError.swift
//  SwiftScriptRunner
//
//  Created by Tan-Colin Wei on 04.11.24.
//

import Foundation

// Represents a script error, with the message, line, and column number
struct ScriptError: Identifiable {
    let id = UUID()
    let message: String
    let lineNumber: Int
    let columnNumber: Int
    let range: NSRange?
}
