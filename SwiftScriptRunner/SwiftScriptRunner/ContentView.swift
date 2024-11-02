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

    func makeNSView(context: Context) -> NSTextView {
        let textView = NSTextView()
        textView.delegate = context.coordinator
        textView.isEditable = true
        textView.isRichText = false
        textView.font = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        textView.backgroundColor = NSColor.textBackgroundColor
        textView.autoresizingMask = [.width]
        textView.isVerticallyResizable = true
        textView.textContainer?.widthTracksTextView = true
        textView.textContainerInset = NSSize(width: 5, height: 5)
        return textView
    }

    func updateNSView(_ textView: NSTextView, context: Context) {
        if textView.string != text {
            textView.string = text
            applySyntaxHighlighting(to: textView)
        }
    }

    func applySyntaxHighlighting(to textView: NSTextView) {
        let keywords = [
            "class", "func", "let", "var", "if", "else", "for", "while", "return", "import", "struct"
        ]
        let textStorage = textView.textStorage
        let text = textView.string
        let fullRange = NSRange(location: 0, length: (text as NSString).length)

        textStorage?.setAttributes([
            .font: NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular),
            .foregroundColor: NSColor.textColor
        ], range: fullRange)

        for keyword in keywords {
            let pattern = "\\b" + NSRegularExpression.escapedPattern(for: keyword) + "\\b"
            let regex = try? NSRegularExpression(pattern: pattern, options: [])
            regex?.enumerateMatches(in: text, options: [], range: fullRange) { match, _, _ in
                if let matchRange = match?.range {
                    textStorage?.addAttribute(.foregroundColor, value: NSColor.systemPink, range: matchRange)
                }
            }
        }
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: SyntaxHighlightingTextView

        init(_ parent: SyntaxHighlightingTextView) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
            parent.applySyntaxHighlighting(to: textView)
        }
    }
}

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
                .disabled(isRunning)

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
                SyntaxHighlightingTextView(text: $scriptText)
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
