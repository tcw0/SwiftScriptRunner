//
//  ContentView.swift
//  SwiftScriptRunner
//
//  Created by Tan-Colin Wei on 02.11.24.
//

import SwiftUI
import AppKit

struct SyntaxHighlightingTextView: NSViewRepresentable {
    @Binding var text: String

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let textView = NSTextView()
        textView.delegate = context.coordinator
        context.coordinator.textView = textView
        textView.isEditable = true
        textView.isRichText = false
        textView.font = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = true
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainerInset = NSSize(width: 5, height: 5)
        textView.backgroundColor = NSColor.textBackgroundColor

        
        let scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.backgroundColor = NSColor.textBackgroundColor
        
        
        textView.minSize = NSSize(width: 0.0, height: scrollView.contentSize.height)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        if let textView = nsView.documentView as? NSTextView {
            if textView.string != text {
                textView.string = text
            }
            applySyntaxHighlighting(to: textView)
        }
    }

    func applySyntaxHighlighting(to textView: NSTextView) {
        let textStorage = textView.textStorage
        let text = textView.string
        let fullRange = NSRange(location: 0, length: (text as NSString).length)

        textStorage?.setAttributes([
            .font: NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular),
            .foregroundColor: NSColor.textColor
        ], range: fullRange)

        let patterns: [(pattern: String, color: NSColor)] = [
            // Keywords
            ("\\b(class|struct|enum|protocol|extension|func|let|var|if|else|for|while|repeat|return|import|break|continue|switch|case|default|do|try|catch|throw|as|is|in|out|where|super|self|guard|defer|nil|true|false)\\b", NSColor.systemPink),
            // Strings
            ("\"(\\\\.|[^\"\\\\])*\"", NSColor.systemRed),
            // Single-line comments
            ("//.*", NSColor.systemGreen),
            // Multi-line comments
            ("/\\*(.|\n)*?\\*/", NSColor.systemGreen)
        ]
        
        for (pattern, color) in patterns {
            let regex = try? NSRegularExpression(pattern: pattern, options: [])
            regex?.enumerateMatches(in: text, options: [], range: fullRange) { match, _, _ in
                if let matchRange = match?.range {
                    textStorage?.addAttribute(.foregroundColor, value: color, range: matchRange)
                }
            }
        }
    }


    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: SyntaxHighlightingTextView
        var textView: NSTextView?

        init(_ parent: SyntaxHighlightingTextView) {
            self.parent = parent
            super.init()

            NotificationCenter.default.addObserver(self, selector: #selector(navigateToLine(_:)), name: .navigateToLine, object: nil)
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
            parent.applySyntaxHighlighting(to: textView)
        }

        @objc func navigateToLine(_ notification: Notification) {
            guard let lineNumber = notification.userInfo?["lineNumber"] as? Int,
                  let columnNumber = notification.userInfo?["columnNumber"] as? Int,
                  let textView = textView else { return }

            let nsString = textView.string as NSString

            var lineStartIndex = 0
            var lineEndIndex = 0
            var contentEndIndex = 0
            var currentLineNumber = 1

            while lineEndIndex < nsString.length {
                nsString.getLineStart(&lineStartIndex, end: &lineEndIndex, contentsEnd: &contentEndIndex, for: NSRange(location: lineEndIndex, length: 0))

                if currentLineNumber == lineNumber {
                    break
                }
                currentLineNumber += 1
            }

            if currentLineNumber == lineNumber {
                let lineRange = NSRange(location: lineStartIndex, length: contentEndIndex - lineStartIndex)
                let lineText = nsString.substring(with: lineRange)

                let columnIndex = max(0, min(columnNumber - 1, lineText.count))

                let characterIndex = lineStartIndex + columnIndex

                DispatchQueue.main.async {
                    textView.setSelectedRange(NSRange(location: characterIndex, length: 0))

                    textView.scrollRangeToVisible(NSRange(location: characterIndex, length: 0))

                    textView.showFindIndicator(for: NSRange(location: lineStartIndex, length: contentEndIndex - lineStartIndex))
                }
            }
        }
    }
}

struct ScriptError: Identifiable {
    let id = UUID()
    let message: String
    let lineNumber: Int
    let columnNumber: Int
    let range: NSRange?
}

struct ContentView: View {
    @State private var scriptText: String = "// Enter your Swift script here"
    @State private var outputText: String = ""
    @State private var isRunning: Bool = false
    @State private var exitCode: Int32?

    // Add properties for Process and Pipes
    @State private var process: Process?
    @State private var outputPipe: Pipe?
    @State private var errorPipe: Pipe?
    
    @State private var scriptErrors: [ScriptError] = []
    
    private func navigateToLine(_ lineNumber: Int, columnNumber: Int) {
        NotificationCenter.default.post(name: .navigateToLine, object: nil, userInfo: ["lineNumber": lineNumber, "columnNumber": columnNumber])
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: {
                    runScript()
                }) {
                    Text("Run")
                }
                .keyboardShortcut(.return, modifiers: [])
                .padding(.leading)
                .disabled(isRunning)
                
                Button(action: {
                    stopScript()
                }) {
                    Text("Stop")
                }
                .keyboardShortcut(.escape, modifiers: [])
                .disabled(!isRunning)

                Spacer()

                if isRunning {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(0.7)
                    Text("Running...")
                } else {
                    Text("Idle")
                }

                if let exitCode = exitCode {
                    Text("Exit Code: \(exitCode)")
                        .foregroundColor(exitCode == 0 ? .green : .red)
                }

                Spacer()
            }
            .padding(.vertical, 8)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            HSplitView {
                SyntaxHighlightingTextView(text: $scriptText)
                    .frame(minWidth: 200)
                
                ScrollView {
                    VStack(alignment: .leading) {
                        Text(outputText)
                            .textSelection(.enabled)
                            .font(.system(.body, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()

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
            }
            .frame(minWidth: 600, minHeight: 400)
        }
    }
    
    private func parseErrorMessages(_ errorOutput: String) {
        let pattern = #"(?m)(.*):(\d+):(\d+):\s(error|warning):\s(.*)$"#

        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return }

        let matches = regex.matches(in: errorOutput, options: [], range: NSRange(location: 0, length: (errorOutput as NSString).length))

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


    private func runScript() {
        isRunning = true
        outputText = ""
        exitCode = nil
        scriptErrors = []

        print("Create a temporary directory")
        let tempDirectory = FileManager.default.temporaryDirectory
        let scriptURL = tempDirectory.appendingPathComponent("foo.swift")

        print("Temporary Directory: \(tempDirectory.path)")

        print("Write the scriptText to the file")
        do {
            try scriptText.write(to: scriptURL, atomically: true, encoding: .utf8)
        } catch {
            outputText = "Failed to write script: \(error.localizedDescription)"
            isRunning = false
            return
        }

        print("Set up the Process")
        process = Process()
        guard let process = process else {
            outputText = "Failed to create process"
            isRunning = false
            return
        }
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["swift", scriptURL.path]
        process.currentDirectoryURL = tempDirectory

        print("Set up Pipes")
        outputPipe = Pipe()
        errorPipe = Pipe()
        guard let outputPipe = outputPipe, let errorPipe = errorPipe else {
            outputText = "Failed to create pipes"
            isRunning = false
            return
        }
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        print("Handle output")
        outputPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if let output = String(data: data, encoding: .utf8), !output.isEmpty {
                DispatchQueue.main.async {
                    self.outputText += output
                    print("Output: \(output)")
                }
            }
        }

        print("Handle errors")
        errorPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if let errorOutput = String(data: data, encoding: .utf8), !errorOutput.isEmpty {
                DispatchQueue.main.async {
                    self.outputText += errorOutput

                    self.parseErrorMessages(errorOutput)
                }
            }
        }

        print("Termination handler")
        process.terminationHandler = { process in
            DispatchQueue.main.async {
                self.isRunning = false
                self.exitCode = process.terminationStatus

                print("Exit Code: \(process.terminationStatus)")

                self.outputPipe?.fileHandleForReading.readabilityHandler = nil
                self.errorPipe?.fileHandleForReading.readabilityHandler = nil
                self.process = nil
                self.outputPipe = nil
                self.errorPipe = nil
            }
        }

        print("Run the process")
        do {
            try process.run()
        } catch {
            outputText = "Failed to execute script: \(error.localizedDescription)"
            isRunning = false
        }
    }
    
    private func stopScript() {
        guard let process = process else { return }

        process.terminate()
        isRunning = false
        outputText += "\nScript execution was terminated by the user.\n"
    }
}


extension Notification.Name {
    static let navigateToLine = Notification.Name("navigateToLine")
}

#Preview {
    ContentView()
}
