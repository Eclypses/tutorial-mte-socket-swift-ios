//
// ****************************************************************
// SocketLabs/Common
// Extensions.swift created on 3/22/21 by Greg Waggoner
// Copyright © 2021 Eclypses Inc. All rights reserved.
// ****************************************************************

import Foundation
import os.log


public extension OSLog {
	private static var subsystem = Bundle.main.bundleIdentifier!
	static let MTEMobileLog = OSLog(subsystem: subsystem, category: "MTEMobileLog")
}

extension Date {
	func toSeconds() -> Int64! {
		return Int64(self.timeIntervalSince1970)
	}
}

extension String {
	// String to Base64 String
	func toBase64() -> String {
		return Data(self.utf8).base64EncodedString()
	}
	
	// B64 String to String
	func fromBase64() -> String? {
		guard let data = Data(base64Encoded: self) else { return nil }
		return String(data: data, encoding: .utf8)
	}
	
	// B64String to Byte Array
	func Base64toUTF8() -> String {
		let data = NSData.init(base64Encoded: self, options: []) ?? NSData()
		return String(data: data as Data, encoding: String.Encoding.utf8) ?? ""
	}
}

//Byte Array to B64 String
extension Array where Element == UInt8 {
	func UTF8toBase64() -> String {
		return Data(self).base64EncodedString()
	}
}

// Data to Byte Array
extension Data {
	var bytes : [UInt8]{
		return [UInt8](self)
	}
}

//Byte Array to Data
extension Array where Element == UInt8 {
	var data : Data {
		return Data(self)
	}
    
    func bytesToHex(spacing: String = "") -> String {
        var hexString: String = ""
        var count = self.count
        for byte in self
        {
            hexString.append(String(format:"%02X", byte))
            count = count - 1
            if count > 0
            {
                hexString.append(spacing)
            }
        }
        return hexString
    }
}
