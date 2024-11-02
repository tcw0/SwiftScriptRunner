//
//  ContentView.swift
//  SwiftScriptRunner
//
//  Created by Tan-Colin Wei on 02.11.24.
//

import SwiftUI
import AppKit

struct SplitViewController<Primary: View, Secondary: View>: NSViewControllerRepresentable {
    let primaryView: Primary
    let secondaryView: Secondary

    init(@ViewBuilder primaryView: () -> Primary, @ViewBuilder secondaryView: () -> Secondary) {
        self.primaryView = primaryView()
        self.secondaryView = secondaryView()
    }

    func makeNSViewController(context: Context) -> NSSplitViewController {
        let splitViewController = NSSplitViewController()

        let primaryViewController = NSHostingController(rootView: primaryView)
        let primaryItem = NSSplitViewItem(contentListWithViewController: primaryViewController)
        primaryItem.minimumThickness = 200
        primaryItem.canCollapse = false
        splitViewController.addSplitViewItem(primaryItem)

        let secondaryViewController = NSHostingController(rootView: secondaryView)
        let secondaryItem = NSSplitViewItem(viewController: secondaryViewController)
        secondaryItem.minimumThickness = 200
        secondaryItem.canCollapse = true
        splitViewController.addSplitViewItem(secondaryItem)

        return splitViewController
    }

    func updateNSViewController(_ nsViewController: NSSplitViewController, context: Context) {
        // TODO:
    }
}

struct ContentView: View {
    @State private var scriptText: String = "// Enter your Swift script here"
    @State private var outputText: String = ""
    @State private var isRunning: Bool = false
    @State private var exitCode: Int32?

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
                }

                Spacer()
            }
            .padding(.vertical, 8)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            SplitViewController {
                TextEditor(text: $scriptText)
                    .font(.system(.body, design: .monospaced))
                    .padding()
                    .background(Color(NSColor.textBackgroundColor))
            } secondaryView: {
                ScrollView {
                    Text(outputText)
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
                .background(Color(NSColor.textBackgroundColor))
            }
            .frame(minWidth: 600, minHeight: 400)
        }
    }

    private func runScript() {
        // TODO: Script execution logic
        
        isRunning = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            isRunning = false
        }
    }
}


#Preview {
    ContentView()
}
