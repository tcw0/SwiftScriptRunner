# SwiftScriptRunner
An interactive Swift scripting environment for macOS, featuring syntax highlighting, error navigation, and more.

This repository is part of the internship project 2025 *Extending Swift Support for Fleet* at JetBrains. Thank you for considering my application!


---


## Table of Contents

- [Project Description](#project-description)
- [Project Structure](#project-structure)
- [Live Demo](#live-demo)
- [Requirements](#requirements)
- [Installation](#installation)
- [Usage](#usage)
- [Features](#features)
- [Future Enhancements](#future-enhancements)
- [Contact Information](#contact-information)


---


## Project Description
This project is a macOS Swift GUI tool that allows users to write and execute Swift scripts. The application provides an editor pane where users can enter Swift code, an output pane that shows the real-time output and errors from the script execution, and indicators to display the script's running status and exit code.

The tool is built using SwiftUI and AppKit and supports features like syntax highlighting, real-time output streaming, and clickable error messages for easy navigation to error locations in the script.



---


## Project Structure

This project structure focuses on the most important files in this project.

```
SwiftScriptRunner/
├── SwiftScriptRunnerApp.swift            -> Main application
├── ContentView.swift                     -> Main SwiftUI View
├── Views/
│   ├── SyntaxHighlightingTextView.swift  -> Syntax highlighting logic
├── Models/
│   ├── ScriptError.swift                 -> Error handling structures
└── Utilities/
    ├── CustomTextView.swift              -> Custom NSTextView subclass for editor
    └── Notifications.swift               -> Notification extensions

```


---


## Live Demo

This live demonstration showcases a snippet of the most important features.

[![JetBrains Internship Project](https://img.youtube.com/vi/8apHwaQvxek/default.jpg)](https://youtu.be/8apHwaQvxek)

---


## Requirements

- **macOS**: 10.15 Catalina or later
- **Xcode**: Version 12.0 or later
- **Swift**: Version 5.0 or later

---

## Installation

1. **Clone the Repository** `git clone https://github.com/tcw0/SwiftScriptRunner.git`

2. **Open the Project**

   Navigate to the cloned directory and open `SwiftScriptRunner.xcodeproj`.
3. **Build and Run**
    - Select the target device (e.g., "My Mac")
    - Build the project by selecting **Product > Build** in Xcode or pressing `Cmd+B`.
    - Run the application by selecting **Product > Run** or pressing `Cmd+R`.



---


## Usage

1. Enter your Swift script in the Editor Pane on the left side of the window.
2. Click the Run button at the top-right to execute the script
3. The Output Pane on the right will display the live output of the script.
4. The Progress Indicator will show when the script is running, and the Exit Code will be shown once the script finishes.
5. To terminate a running script, click the Stop button


---

## Features

- **Editor Pane**:

  A text editor where users can write Swift code.

- **Output Pane**:

  Displays the real-time output of the script as it runs, as well as any errors encountered.

- **Running Status Indicator**:

  A progress indicator is shown when the script is currently running.

- **Exit Code Indicator**:

  After the script finishes, the exit code is displayed.

- **Syntax Highlighting**:

  Real-time syntax highlighting for Swift code, including keywords, strings, and comments.

- **Error Navigation**:

  Parses compiler error messages and allows quick navigation to the exact line and column where the error occurred.

- **Automatic Color Theme**:

  The app automatically adjusts its color theme to match the system's light or dark mode.

- **Run and Stop Scripts**:

  Provides intuitive controls to run the script or terminate execution at any time.

- **Interactive Input Support**:

  Handles scripts requiring user input via `readLine()`, with an input field integrated into the UI (output buffering might require `fflush(stdout)`).

- **Undo/Redo Functionality**:

  Full support for undoing `Cmd + Z` and redoing `Cmd + Shift + Z` text changes in the editor pane.

- **Bracket and Quotation Mark Matching**:

  Automatically inserts matching brackets and quotes.


---


## Future Enhancements

- **Extend Syntax Highlighting**: Easily extend syntax highlighting to cover all Swift language features comprehensively

- **Line Numbers**: Add dynamic line numbers in the editor pane for easier navigation and error tracking.

- **Automatic Indentation** Implement auto-indentation to maintain consistent formatting when writing code, especially in blocks.

- **Enhanced Keyboard Shortcuts**: Introduce more shortcuts for actions like commenting, line duplication, code formatting, and moving lines to improve coding efficiency.

- **Script Saving and Loading**: Implement functionality to save scripts to files and open existing scripts for editing and execution.

- **Code Completion**: Integrate code completion features to suggest Swift keywords, functions, and variable names as the user types.


---

## Contact Information

For any questions, suggestions, or feedback, please contact:

- **Name**: Tan-Colin Wei
- **Email**: tan-colin.wei@gmx.de
- **LinkedIn**: [https://www.linkedin.com/in/tan-colin-wei](https://www.linkedin.com/in/tan-colin-wei)
- **GitHub**: [https://github.com/tcw0](https://github.com/tcw0)

---

