//
// MIT License
//
// Copyright (c) 2016 Hejki (www.hejki.org)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    let connectScriptPath = Bundle.main.path(forResource: "connect", ofType: "sh")!
    
    /// Register URL handler, move application package to ApplicationSupport directory and run Sparkle updater
    func applicationWillFinishLaunching(_ notification: Notification) {
        NSAppleEventManager.shared().setEventHandler(self,
                                                     andSelector: #selector(handleGetURLEvent(_:replyEvent:)),
                                                     forEventClass: AEEventClass(kInternetEventClass),
                                                     andEventID: AEEventID(kAEGetURL))
        LSSetDefaultHandlerForURLScheme("sshconnect" as CFString, Bundle.main.bundleIdentifier! as CFString)
        
        if ProcessInfo.processInfo.environment["placementAlert"] != "false" {
            checkAppPlacement()
        }
    }
    
    /// Handle URL passed to application and open ssh connection
    func handleGetURLEvent(_ event: NSAppleEventDescriptor?, replyEvent: NSAppleEventDescriptor?) {
        if let eventDescriptor = event?.paramDescriptor(forKeyword: AEKeyword(keyDirectObject)),
            let urlString = eventDescriptor.stringValue,
            let url = ConnectionHelperURL(url: URL(string: urlString)) {
            openConnection(to: url)
        }
    }
}

private extension AppDelegate {
    
    /// Get script for desired terminal application and run script inside it.
    /// For connection with password executes connect.sh script
    /// For connection without password runs "ssh host_alias"
    func openConnection(to url: ConnectionHelperURL) {
        let script = getScript(forBundleId: url.terminal)
        let formattedScript: String
        
        if let account = url.account {
            formattedScript = String(format: script, "\\\"\(connectScriptPath)\\\" \(url.alias) \(account)")
        } else {
            formattedScript = String(format: script, "ssh \(url.alias)")
        }
        
        var errorDict: NSDictionary?
        NSAppleScript(source: formattedScript)?.executeAndReturnError(&errorDict)
        
        if let errorDict = errorDict {
            sendAlert(info: errorDict, url: url)
        }
        NSApp.terminate(self)
    }
    
    /// Get Apple Script for specified terminal, if desired terminal not found uses default macOS Terminal.app
    func getScript(forBundleId bundleId: String!) -> String {
        if let configurations = Bundle.main.infoDictionary?[R.bundleKeyConfigs] as? [[String: String]],
            let config = configurations.first(where: { $0[R.bundleKeyId] == bundleId }),
            let script = config[R.bundleKeyScript] {
            return script
        }
        
        return getScript(forBundleId: R.systemTerminalBundleId)
    }
    
    /// Show error alert to user with ability to send error to authors
    func sendAlert(info: NSDictionary?, url: ConnectionHelperURL) {
        let alert = NSAlert()
        var message = ""
        
        alert.alertStyle = .critical
        alert.messageText = "Application cannot open connection to ssh server \(url.alias). Please send us following error and we try fix it ;)"
        
        if let info = info {
            for key in info.allKeys {
                if let value = info[key] {
                    message += "\(key): \(value)\n"
                }
            }
            alert.informativeText = message
        }
        alert.addButton(withTitle: "Report Error")
        alert.addButton(withTitle: "Close")
        
        if alert.runModal() == NSAlertFirstButtonReturn {
            var mailBody = "Error from SSH Connector\n\n"
            
            if let terminal = url.terminal {
                mailBody += "terminal: \(terminal)\n"
            }
            mailBody += "version: \(Bundle.main.infoDictionary?[kCFBundleVersionKey as String] ?? "")\n"
            mailBody += "error: \(message)"
            
            if let feedbackURL = URL(string: R.mailto(body: mailBody)) {
                NSWorkspace.shared().open(feedbackURL)
            }
        }
    }
    
    func checkAppPlacement() {
        guard let appURL = NSRunningApplication.current().bundleURL else {
            return
        }
        
        let alert = NSAlert()
        
        alert.alertStyle = .informational
        if appURL.path.hasPrefix("/Applications") {
            alert.messageText = "SSH Connector is properly set."
        } else {
            alert.messageText = "SSH Connector cannot work properly if is not placed in /Applications directory."
            alert.informativeText = "Please move it to /Applications directory."
        }
        
        alert.runModal()
        NSApp.terminate(self)
    }
}

private enum R {
    static let bundleKeyConfigs = "SSHCE_TERMINAL_CONFIGURATIONS"
    static let bundleKeyId = "bundleId"
    static let bundleKeyScript = "script"
    
    static let systemTerminalBundleId = "com.apple.Terminal"
    
    static func mailto(body: String) -> String {
        let body = body.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? ""
        return "mailto:support@hejki.org?subject=SSH%20Connector%20Error&body=\(body)"
    }
}
