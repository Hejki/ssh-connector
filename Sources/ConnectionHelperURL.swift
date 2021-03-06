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

import Foundation

class ConnectionHelperURL {
    static let systemTerminalBundleId = "com.apple.Terminal"
    
    let host: String
    let sshComandHost: String
    let terminal: String?
    let account: String?
    let requiredVersion: Int
    
    init?(url: URL?) {
        guard let url = url, let host = url.host else {
            return nil
        }
        
        var account: String?
        var terminal: String?
        var reqver: Int?
        
        if let query = url.query {
            let pairs = query.components(separatedBy: "&")
            
            for pair in pairs {
                if let indexOfValue = pair.range(of: "=")?.upperBound {
                    let value = pair[indexOfValue...]
                    
                    if pair.hasPrefix("account") {
                        account = String(value)
                    } else if pair.hasPrefix("terminal") {
                        terminal = String(value)
                    } else if pair.hasPrefix("reqver") {
                        reqver = Int(value)
                    }
                }
            }
        }
        
        var targetHost = ""
        var sshCommand = ""
        
        if let user = url.user {
            targetHost += "\(user)@"
        }
        
        targetHost += host
        sshCommand = targetHost
        
        if let port = url.port {
            targetHost += ":\(port)"
            sshCommand += " -p \(port)"
        }
        
        self.host = targetHost
        self.sshComandHost = sshCommand
        self.account = account
        self.terminal = terminal
        self.requiredVersion = reqver ?? 0
    }
}
