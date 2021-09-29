//
// ******************************************************
// SocketClient Project
// SocketClientTests.swift created on 9/29/21 by Greg Waggoner
// Copyright © 2021 Eclypses Inc. All rights reserved.
// ******************************************************


import XCTest
@testable import SocketClient

class SocketClientTests: XCTestCase {
    
    var vc: ViewController!

    override func setUpWithError() throws {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        
        vc = storyboard.instantiateInitialViewController()
        vc .loadViewIfNeeded()
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testMTE() throws {
        let plaintext = "This is our secret data"
        
        // Because we are encoding and decoding in the same test, we need to set the decder nonce
        // property tqual to the encoder nonce property.
        vc.decoderNonce = vc.encoderNonce
        vc.useTheseSettingsButtonTapped(self)
        
        let data = [UInt8](plaintext.utf8)
        
        // Use MTE to encode the plaintext
        let encodeResult = vc.encoder.encode(data)
        XCTAssertEqual(encodeResult.status, mte_status_success)
        
        // Use MTE to decode the encoded plaintext
        let decodeResult = vc.decoder.decode(encodeResult.encoded)
        XCTAssertEqual(decodeResult.status, mte_status_success)
        
        XCTAssertEqual(String(bytes: decodeResult.decoded, encoding: .utf8), plaintext)
        print("SocketClient Test SUCCESS!")
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        measure {
            // Put the code you want to measure the time of here.
        }
    }

}
