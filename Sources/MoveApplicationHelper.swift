//
//  MoveApplicationHelper.swift
//  SSH Connector
//
//  Created by Hejki on 13/10/2016.
//  Copyright © 2016 Hejki. All rights reserved.
//

import Cocoa
import Security

class MoveApplicationHelper {
    fileprivate let fileManager = FileManager.default
    let bundleURL: URL
    let targetURL: URL
    
    init() {
        let appName = NSRunningApplication.current.localizedName ?? "SSH Connector"
        var appTargetURL = try! FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
        
        appTargetURL.appendPathComponent(appName, isDirectory: true)
        appTargetURL.appendPathComponent(appName, isDirectory: false)
        appTargetURL.appendPathExtension("app")
        
        targetURL = appTargetURL.standardizedFileURL
        bundleURL = Bundle.main.bundleURL.standardizedFileURL
    }
    
    /// Copy application to target url, relaunch and remove origin app
    public func moveApplication() throws {
        if targetURL == bundleURL {
            return // app is already in right place
        }
        
        exterminateOthers()
        if fileManager.fileExists(atPath: targetURL.path) {
            try? fileManager.removeItem(at: targetURL)
        }
        
        try fileManager.createDirectory(at: targetURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try fileManager.copyItem(at: bundleURL, to: targetURL)
        try? fileManager.removeItem(atPath: translocateOriginPath())
        
        showInstallSuccessAlert()
        relaunch()
        exit(0);
    }
}

private extension MoveApplicationHelper {
    
    /// Show alert dialog with success install message
    func showInstallSuccessAlert() {
        let alert = NSAlert()
        
        alert.alertStyle = .informational
        alert.messageText = "SSH Connector was installed successfully."
        alert.runModal()
    }
    
    /// Terminate all running application isntances other than current.
    /// If deleteApp is true then instance application will be deleted
    func exterminateOthers() {
        let currentInstance = NSRunningApplication.current
        let otherConnectors = NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier!).filter({ $0 != currentInstance })
        
        for connectorInstance in otherConnectors {
            connectorInstance.terminate()
            
            if waitForTermination(of: connectorInstance) {
                connectorInstance.forceTerminate()
                waitForTermination(of: connectorInstance)
            }
        }
    }
    
    /// Wait 2 sec for terminating runnint application instance
    /// returns true if application is terminated
    @discardableResult
    func waitForTermination(of instance: NSRunningApplication) -> Bool {
        for _ in 0..<20 {
            if instance.isTerminated {
                return true
            }
            Thread.sleep(forTimeInterval: 0.1)
        }
        return instance.isTerminated
    }
    
    /// Kill current process, remove quarantine extended attributes 
    /// and launch target URL
    func relaunch() {
        let pid = ProcessInfo.processInfo.processIdentifier
        let path = "\"\(targetURL.path)\""
        let removeXAttrCommand = "/usr/bin/xattr -d -r com.apple.quarantine \(path)"
        let openScript = "(while /bin/kill -0 \(pid) >&/dev/null; do /bin/sleep 0.1; done; \(removeXAttrCommand); /usr/bin/open \(path)) &"
        
        Process.launchedProcess(launchPath: "/bin/sh", arguments: ["-c", openScript])
    }
    
    /// Get origin path for translocate path (only for macOS 10.12)
    /// For older os versions returns bundle path
    func translocateOriginPath() -> String {
        guard ProcessInfo.processInfo.isOperatingSystemAtLeast(OperatingSystemVersion(majorVersion: 10, minorVersion: 12, patchVersion: 0)) else {
            return bundleURL.path
        }
        
        let process = Process()
        let output = Pipe()
        
        process.launchPath = "/usr/bin/security"
        process.arguments = ["translocate-original-path", bundleURL.path]
        process.standardOutput = output
        process.launch()
        process.waitUntilExit()
        
        let data = output.fileHandleForReading.readDataToEndOfFile()
        if let outputText = String(data: data, encoding: .utf8),
            let pathIndex = outputText.index(of: "/") {
            return outputText[pathIndex...].trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return bundleURL.path
    }
}
