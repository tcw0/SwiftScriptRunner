//
//  ContentView.swift
//  SwiftScriptRunner
//
//  Created by Tan-Colin Wei on 02.11.24.
//

import SwiftUI
import AppKit

// Custom text view for syntax highlighting using NSViewRepresentable
struct SyntaxHighlightingTextView: NSViewRepresentable {
    @Binding var text: String

    // Coordinator handling NSTextViewDelegate methods
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // Create NSView (NSTextView wrapped in NSScrollView)
    func makeNSView(context: Context) -> NSScrollView {
        let textView = NSTextView()
        textView.delegate = context.coordinator     // Set the coordinator as the delegate
        context.coordinator.textView = textView
        textView.isEditable = true                  // Make the text view editable
        textView.isRichText = false                 // Disable rich text formatting
        textView.font = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular) // Use a monospaced font
        textView.isVerticallyResizable = true       // Allow vertical resizing
        textView.isHorizontallyResizable = true     // Allow horizontal resizing
        textView.autoresizingMask = [.width]        // Allow the width to adjust
        textView.textContainer?.widthTracksTextView = true          // Text container resizes with the text view
        textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainerInset = NSSize(width: 5, height: 5)   // Add padding inside the text container
        textView.backgroundColor = NSColor.textBackgroundColor      // Set the background color
        textView.isAutomaticQuoteSubstitutionEnabled = false        // Disable automatic smart quotes
        textView.isAutomaticDashSubstitutionEnabled = false         // Disable smart dashes
        textView.isAutomaticTextReplacementEnabled = false          // Disable automatic text replacements
        textView.isAutomaticDashSubstitutionEnabled = false         // Disable dash replacement (e.g., "..." to "…")
        textView.allowsUndo = true                                  // Enable Undo Support
        
        // Wrap textView in NSScrollView to allow scrolling
        let scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true       // Add a vertical scroller
        scrollView.hasHorizontalScroller = false    // No horizontal scroller needed
        scrollView.autohidesScrollers = true        // Scrollers will auto-hide when not needed
        scrollView.borderType = .noBorder
        scrollView.backgroundColor = NSColor.textBackgroundColor
        
        
        textView.minSize = NSSize(width: 0.0, height: scrollView.contentSize.height)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)

        return scrollView
    }
    
    // Update view whenever bound text changes
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        if let textView = nsView.documentView as? NSTextView {
            if textView.string != text {            // Update only if the content differs
                textView.string = text
            }
            applySyntaxHighlighting(to: textView)   // Apply syntax highlighting after update
        }
    }

    // Apply syntax highlighting
    func applySyntaxHighlighting(to textView: NSTextView) {
        guard let textStorage = textView.textStorage else { return }
        let text = textView.string
        let fullRange = NSRange(location: 0, length: (text as NSString).length)

        // Begin editing and disable undo registration
        textStorage.beginEditing()
        textView.undoManager?.disableUndoRegistration()
        
        // Reset text attributes (font and color)
        textStorage.setAttributes([
            .font: NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular),
            .foregroundColor: NSColor.textColor
        ], range: fullRange)

        // Highlight comments (both single-line and multi-line)
        let singleLineCommentPattern = "//.*"               // Single-line comments
        let multiLineCommentPattern = "/\\*(.|\n)*?\\*/"    // Multi-line comments
        let commentPatterns = [singleLineCommentPattern, multiLineCommentPattern]
        for pattern in commentPatterns {
            let regex = try? NSRegularExpression(pattern: pattern, options: [])
            regex?.enumerateMatches(in: text, options: [], range: fullRange) { match, _, _ in
                if let matchRange = match?.range {
                    textStorage.addAttribute(.foregroundColor, value: NSColor.systemGreen, range: matchRange)
                }
            }
        }


        // Highlight string literals, outside of comment ranges
        let stringPattern = "\"(\\\\.|[^\"\\\\])*\""        // String literals
        let stringRegex = try? NSRegularExpression(pattern: stringPattern, options: [])
        stringRegex?.enumerateMatches(in: text, options: [], range: fullRange) { match, _, _ in
            if let matchRange = match?.range {
                // Ensure that the string literal is not part of a comment
                let attributes = textStorage.attributes(at: matchRange.location, effectiveRange: nil)
                if let foregroundColor = attributes[.foregroundColor] as? NSColor, foregroundColor != NSColor.systemGreen {
                    // Apply red color for string literals only if they are not part of a comment
                    textStorage.addAttribute(.foregroundColor, value: NSColor.systemRed, range: matchRange)
                }
            }
        }

        // Highlight keywords in non-comment and non-string areas
        let keywordPattern = "\\b(class|struct|enum|protocol|extension|func|let|var|if|else|for|while|repeat|return|import|break|continue|switch|case|default|do|try|catch|throw|as|is|in|out|where|super|self|guard|defer|nil|true|false)\\b"
        let keywordRegex = try? NSRegularExpression(pattern: keywordPattern, options: [])
        keywordRegex?.enumerateMatches(in: text, options: [], range: fullRange) { match, _, _ in
            if let matchRange = match?.range {
                // Ensure that the keyword is not part of a comment or string
                let attributes = textStorage.attributes(at: matchRange.location, effectiveRange: nil)
                if let foregroundColor = attributes[.foregroundColor] as? NSColor, foregroundColor != NSColor.systemGreen && foregroundColor != NSColor.systemRed {
                    // Apply pink color for keywords only if they are not part of a comment or string
                    textStorage.addAttribute(.foregroundColor, value: NSColor.systemMint, range: matchRange)
                }
            }
        }
        
        // Re-enable undo registration and end editing
        textView.undoManager?.enableUndoRegistration()
        textStorage.endEditing()
    }


    // Coordinator class that acts as a delegate to handle text changes and notifications
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: SyntaxHighlightingTextView
        var textView: NSTextView?

        init(_ parent: SyntaxHighlightingTextView) {
            self.parent = parent
            super.init()
            
            // Register for line navigation notifications
            NotificationCenter.default.addObserver(self, selector: #selector(navigateToLine(_:)), name: .navigateToLine, object: nil)
        }

        deinit {
            // Unregister observer when the coordinator is deallocated
            NotificationCenter.default.removeObserver(self)
        }

        // Delegate method called when text changes
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
            parent.applySyntaxHighlighting(to: textView)
        }

        // Handles navigation to a specific line in the text
        @objc func navigateToLine(_ notification: Notification) {
            guard let lineNumber = notification.userInfo?["lineNumber"] as? Int,
                  let columnNumber = notification.userInfo?["columnNumber"] as? Int,
                  let textView = textView else { return }

            let nsString = textView.string as NSString

            var lineStartIndex = 0
            var lineEndIndex = 0
            var contentEndIndex = 0
            var currentLineNumber = 1

            // Loop through lines to find the specified line
            while lineEndIndex < nsString.length {
                nsString.getLineStart(&lineStartIndex, end: &lineEndIndex, contentsEnd: &contentEndIndex, for: NSRange(location: lineEndIndex, length: 0))

                if currentLineNumber == lineNumber {
                    break
                }
                currentLineNumber += 1
            }
            
            // Navigate to the specified line and column
            if currentLineNumber == lineNumber {
                let lineRange = NSRange(location: lineStartIndex, length: contentEndIndex - lineStartIndex)
                let lineText = nsString.substring(with: lineRange)

                let columnIndex = max(0, min(columnNumber - 1, lineText.count))

                let characterIndex = lineStartIndex + columnIndex

                // Move the cursor and scroll to the specified location
                DispatchQueue.main.async {
                    textView.setSelectedRange(NSRange(location: characterIndex, length: 0))

                    textView.scrollRangeToVisible(NSRange(location: characterIndex, length: 0))

                    textView.showFindIndicator(for: NSRange(location: lineStartIndex, length: contentEndIndex - lineStartIndex))
                }
            }
        }
    }
}

// Represents a script error, with the message, line, and column number
struct ScriptError: Identifiable {
    let id = UUID()
    let message: String
    let lineNumber: Int
    let columnNumber: Int
    let range: NSRange?
}

// Main view of the app, displaying the script editor, output, and controls for running/stopping scripts
struct ContentView: View {
    @State private var scriptText: String = "// Enter your Swift script here"
    @State private var outputText: String = ""
    @State private var isRunning: Bool = false
    @State private var exitCode: Int32?

    // Process and pipe-related state variables
    @State private var process: Process?
    @State private var outputPipe: Pipe?
    @State private var errorPipe: Pipe?
    
    // Script errors
    @State private var scriptErrors: [ScriptError] = []

    // Interactive input
    @State private var inputPipe: Pipe?
    @State private var userInput: String = ""
    @State private var isInputFieldDisabled: Bool = true

    // Notification handler to navigate to a specific line in the script
    private func navigateToLine(_ lineNumber: Int, columnNumber: Int) {
        NotificationCenter.default.post(name: .navigateToLine, object: nil, userInfo: ["lineNumber": lineNumber, "columnNumber": columnNumber])
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {            // Top bar
                HStack {        // Progress
                    Spacer()
                    
                    if isRunning {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(0.7)
                        Text("Running...")
                    } else {
                        Text("Idle")
                    }
                }
                
                HStack {        // Run/Stop buttons & exit code
                    Spacer()
                    
                    if let exitCode = exitCode {
                        Text("Exit Code: \(exitCode)")
                            .foregroundColor(exitCode == 0 ? .green : .red)
                    }
                    
                    Button(action: {
                        runScript()
                    }) {
                        Text("Run")
                    }
                    .keyboardShortcut(.return, modifiers: [])
                    .disabled(isRunning)
                    
                    Button(action: {
                        stopScript()
                    }) {
                        Text("Stop")
                    }
                    .keyboardShortcut(.escape, modifiers: [])
                    .padding(.trailing)
                    .disabled(!isRunning)
                }
            }
            .padding(.vertical, 8)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            HSplitView {
                // Script editor on the left
                SyntaxHighlightingTextView(text: $scriptText)
                    .frame(minWidth: 200)

                // Output and error display on the right
                VStack {
                    ScrollView {
                        VStack(alignment: .leading) {
                            Text(outputText)        // Output text
                                .textSelection(.enabled)
                                .font(.system(.body, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()

                            // Display script errors
                            ForEach(scriptErrors) { error in
                                Button(action: {
                                    navigateToLine(error.lineNumber, columnNumber: error.columnNumber)
                                }) {
                                    Text("Error on line \(error.lineNumber), column \(error.columnNumber): \(error.message)")
                                        .foregroundColor(.red)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .padding(.horizontal)
                            }
                        }
                    }
                    .background(Color(NSColor.textBackgroundColor))
                    .frame(minWidth: 200)

                    Spacer()

                    // User input
                    if isRunning {
                        HStack {
                            TextField("Enter input...", text: $userInput, onCommit: {
                                sendInput()
                            })
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .disabled(isInputFieldDisabled)

                            Button(action: {
                                sendInput()
                            }) {
                                Text("Send")
                            }
                            .disabled(userInput.isEmpty || isInputFieldDisabled)
                        }
                        .padding()
                    }
                }
            }
            .frame(minWidth: 600, minHeight: 400)
        }
    }
    
    // Parse error messages from script execution output
    private func parseErrorMessages(_ errorOutput: String) {
        let pattern = #"(?m)(.*):(\d+):(\d+):\s(error|warning):\s(.*)$"#

        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return }

        let matches = regex.matches(in: errorOutput, options: [], range: NSRange(location: 0, length: (errorOutput as NSString).length))

        // Extract error details (line, column, and message) from matches
        for match in matches {
            let lineNumberRange = match.range(at: 2)
            let columnNumberRange = match.range(at: 3)
            let messageRange = match.range(at: 5)

            if let lineNumberString = (errorOutput as NSString).substring(with: lineNumberRange) as String?,
               let columnNumberString = (errorOutput as NSString).substring(with: columnNumberRange) as String?,
               let lineNumber = Int(lineNumberString),
               let columnNumber = Int(columnNumberString),
               let message = (errorOutput as NSString).substring(with: messageRange) as String? {

                let scriptError = ScriptError(message: message, lineNumber: lineNumber, columnNumber: columnNumber, range: nil)
                scriptErrors.append(scriptError)
            }
        }
    }

    // Run the Swift script by creating a temporary file and launching a process
    private func runScript() {
        isRunning = true
        outputText = ""
        exitCode = nil
        scriptErrors = []
        userInput = ""
        isInputFieldDisabled = false

        // Create a temporary directory & file
        let tempDirectory = FileManager.default.temporaryDirectory
        let scriptURL = tempDirectory.appendingPathComponent("foo.swift")

        // Write the scriptText to the file
        do {
            try scriptText.write(to: scriptURL, atomically: true, encoding: .utf8)
        } catch {
            outputText = "Failed to write script: \(error.localizedDescription)"
            isRunning = false
            isInputFieldDisabled = true
            return
        }

        // Set up the Process
        process = Process()
        guard let process = process else {
            outputText = "Failed to create process"
            isRunning = false
            isInputFieldDisabled = true
            return
        }
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["swift", scriptURL.path]
        process.currentDirectoryURL = tempDirectory
        
        // Set environment variable to disable buffering
        var environment = ProcessInfo.processInfo.environment
        environment["NSUnbufferedIO"] = "YES"
        process.environment = environment

        // Set up Pipes
        outputPipe = Pipe()
        errorPipe = Pipe()
        inputPipe = Pipe()
        guard let outputPipe = outputPipe, let errorPipe = errorPipe, let inputPipe = inputPipe else {
            outputText = "Failed to create pipes"
            isRunning = false
            isInputFieldDisabled = true
            return
        }
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        process.standardInput = inputPipe

        // Handle output
        outputPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if let output = String(data: data, encoding: .utf8), !output.isEmpty {
                DispatchQueue.main.async {
                    self.outputText += output
                }
            }
        }

        // Handle errors
        errorPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if let errorOutput = String(data: data, encoding: .utf8), !errorOutput.isEmpty {
                DispatchQueue.main.async {
                    self.outputText += errorOutput

                    self.parseErrorMessages(errorOutput)
                }
            }
        }

        // Termination handler
        process.terminationHandler = { process in
            DispatchQueue.main.async {
                self.isRunning = false
                self.exitCode = process.terminationStatus

                self.outputPipe?.fileHandleForReading.readabilityHandler = nil
                self.errorPipe?.fileHandleForReading.readabilityHandler = nil
                self.process = nil
                self.outputPipe = nil
                self.errorPipe = nil
                self.inputPipe = nil
                self.isInputFieldDisabled = true
            }
        }

        // Run the process
        do {
            try process.run()
        } catch {
            outputText = "Failed to execute script: \(error.localizedDescription)"
            isRunning = false
            isInputFieldDisabled = true
        }
    }

    // Stop the running script
    private func stopScript() {
        guard let process = process else { return }

        process.terminate()
        isRunning = false
        isInputFieldDisabled = true
        outputText += "\nScript execution was terminated by the user.\n"
    }
    
    // Send input from the user to the running script
    private func sendInput() {
        guard let inputPipe = inputPipe else { return }

        let input = userInput + "\n"

        if let inputData = input.data(using: .utf8) {
            inputPipe.fileHandleForWriting.write(inputData)
        }

        userInput = ""
    }
}

// Extension to handle line navigation notifications
extension Notification.Name {
    static let navigateToLine = Notification.Name("navigateToLine")
}

#Preview {
    ContentView()
}
