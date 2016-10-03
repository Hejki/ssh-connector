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
                                                     andSelector: #selector(handleAppleEvent(_:withReplyEvent:)),
                                                     forEventClass: AEEventClass(kInternetEventClass),
                                                     andEventID: AEEventID(kAEGetURL))
        LSSetDefaultHandlerForURLScheme("sshconnect" as CFString, Bundle.main.bundleIdentifier! as CFString)
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        let appURL = NSRunningApplication.current().bundleURL!
        let fileManager = FileManager.default
        let appName = NSRunningApplication.current().localizedName ?? "SSH Connector"
        var appTargetURL = try! fileManager.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
        
        appTargetURL.appendPathComponent(appName, isDirectory: true)
        appTargetURL.appendPathComponent(appName, isDirectory: false)
        appTargetURL.appendPathExtension("app")
        
        if appTargetURL != appURL {
            do {
                try fileManager.createDirectory(at: appTargetURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                
                if fileManager.fileExists(atPath: appTargetURL.path) {
                    let _ = try fileManager.replaceItem(at: appTargetURL, withItemAt: appURL, backupItemName: nil, options: [.usingNewMetadataOnly], resultingItemURL: nil)
                } else {
                    try fileManager.moveItem(at: appURL, to: appTargetURL)
                }
            } catch {
                showAlert(message: "Cannot correctly setup SSH Connector.", informativeText: error.localizedDescription)
            }
        }
        
        checkLoginItems(appTargetURL)
    }
    
    /// Handle URL passed to application and open ssh connection
    func handleAppleEvent(_ event: NSAppleEventDescriptor?, withReplyEvent replyEvent: NSAppleEventDescriptor?) {
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
        // If apple script not found then call ssh url
        guard let script = getScript(forBundleId: url.terminal) else {
            
            if let sshURL = URL(string: "ssh://\(url.alias)") {
                if let terminalBundleIdentifier = url.terminal {
                    NSWorkspace.shared().open([sshURL], withAppBundleIdentifier: terminalBundleIdentifier, options: [], additionalEventParamDescriptor: nil, launchIdentifiers: nil)
                } else {
                    NSWorkspace.shared().open(sshURL)
                }
            }
            return
        }
        
        let formattedScript: String
        if let account = url.account {
            formattedScript = String(format: script, "\\\"\(connectScriptPath)\\\" \(url.alias) \(account)")
        } else {
            formattedScript = String(format: script, "ssh \(url.alias)")
        }
        
        var errorDict: NSDictionary?
        NSAppleScript(source: formattedScript)?.executeAndReturnError(&errorDict)
        
        if let errorDict = errorDict {
            showExecError(info: errorDict, url: url)
        }
    }
    
    /// Get Apple Script for specified terminal, if desired terminal not found returns nil
    func getScript(forBundleId bundleId: String!) -> String? {
        if let configurations = Bundle.main.infoDictionary?[R.bundleKeyConfigs] as? [[String: String]],
            let config = configurations.first(where: { $0[R.bundleKeyId] == bundleId }),
            let script = config[R.bundleKeyScript] {
            return script
        }
        
        return nil
    }
    
    /// Show error alert for bad AppleScript execution
    func showExecError(info: NSDictionary?, url: ConnectionHelperURL) {
        var infoText = ""
        
        if let info = info {
            for key in info.allKeys {
                if let value = info[key] {
                    infoText += "\(key): \(value)\n"
                }
            }
        }
        
        showAlert(message: "Application cannot open connection to ssh server \(url.alias). Please send us following error and we try fix it ;)",
            informativeText: infoText, url: url)
    }
    
    /// Show error alert to user with ability to send error to authors
    func showAlert(message: String, informativeText: String? = nil, url: ConnectionHelperURL? = nil) {
        let alert = NSAlert()
        
        alert.alertStyle = .critical
        alert.messageText = message
        alert.informativeText = informativeText ?? ""
        alert.addButton(withTitle: "Report Error")
        alert.addButton(withTitle: "Close")
        
        if alert.runModal() == NSAlertFirstButtonReturn {
            var mailBody = "Error from SSH Connector\n\n"
            
            if let terminal = url?.terminal {
                mailBody += "terminal: \(terminal)\n"
            }
            mailBody += "version: \(Bundle.main.infoDictionary?[kCFBundleVersionKey as String] ?? "")\n"
            mailBody += "error: \(message)\n"
            if let infoText = informativeText {
                mailBody += "info: \(infoText)"
            }
            
            if let feedbackURL = URL(string: R.mailto(body: mailBody)) {
                NSWorkspace.shared().open(feedbackURL)
            }
        }
    }
    
    /// Add application to "Login Items" if not already there
    func checkLoginItems(_ appURL: URL) {
        if let loginItems = LSSharedFileListCreate(nil, kLSSharedFileListSessionLoginItems.takeRetainedValue(), nil) {
            
            let loginItemsArray = LSSharedFileListCopySnapshot(loginItems.takeRetainedValue(), nil).takeRetainedValue() as! [LSSharedFileListItem]
            
            for loginItem in loginItemsArray {
                if let url = LSSharedFileListItemCopyResolvedURL(loginItem, 0, nil)?.takeRetainedValue() as? URL, url == appURL {
                    return // App found in login items
                }
            }
            
            if let loginItems = LSSharedFileListCreate(nil, kLSSharedFileListSessionLoginItems.takeRetainedValue(), nil) {
                
                LSSharedFileListInsertItemURL(loginItems.takeRetainedValue(), loginItemsArray.last, nil, nil, appURL as CFURL, nil, nil)
            }
        }
    }
}

private enum R {
    static let bundleKeyConfigs = "SSHCE_TERMINAL_CONFIGURATIONS"
    static let bundleKeyId = "bundleId"
    static let bundleKeyScript = "script"
    
    static func mailto(body: String) -> String {
        let body = body.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? ""
        return "mailto:support@hejki.org?subject=SSH%20Connector%20Error&body=\(body)"
    }
}
