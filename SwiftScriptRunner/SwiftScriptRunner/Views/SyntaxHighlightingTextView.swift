//
//  SyntaxHighlightingTextView.swift
//  SwiftScriptRunner
//
//  Created by Tan-Colin Wei on 04.11.24.
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
        let textView = CustomTextView()
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
        let stringPattern = "(\"(\\\\.|[^\"\\\\])*\"|'(\\\\.|[^'\\\\])*')"        // String literals
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

