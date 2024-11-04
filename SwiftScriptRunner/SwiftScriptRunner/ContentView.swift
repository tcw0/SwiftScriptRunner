//
//  ContentView.swift
//  SwiftScriptRunner
//
//  Created by Tan-Colin Wei on 02.11.24.
//

import SwiftUI

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

#Preview {
    ContentView()
}
