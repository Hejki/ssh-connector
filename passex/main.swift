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
import Security

func printErr(_ msg: String) {
    if let data = msg.data(using: .utf8) {
        FileHandle.standardError.write(data)
    }
}

let argv = ProcessInfo.processInfo.arguments
if argv.count != 2 {
    printErr("Usage: \(ProcessInfo.processInfo.processName) ssh_account")
    exit(0)
}

let query: [NSString: AnyObject] = [
    kSecClass: kSecClassGenericPassword,
    kSecAttrAccount: argv[1] as NSString,
    kSecAttrService: "org.hejki.osx.sshce" as NSString,
    kSecReturnData: kCFBooleanTrue,
]

var result: CFTypeRef?
let status = SecItemCopyMatching(query as CFDictionary, &result)

if status != noErr {
    if status == errSecItemNotFound {
        exit(0)
    }
    
    if let error = SecCopyErrorMessageString(status, nil) as? String {
        printErr("Error code:\(status), message: \(error)")
    } else {
        printErr("Error code:\(status)")
    }
    exit(1)
}

if let data = result as? Data,
    let pass = String(data: data, encoding: .utf8) {
    print(pass, terminator: "")
}
