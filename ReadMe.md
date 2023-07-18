![Eclypses Logo alt text](./Eclypses_H_C_M-R.png =500x)

<div align="center" style="font-size:40pt; font-weight:900; font-family:arial; margin-top:300px; " >
Swift iOS Server and Client Socket Tutorials</div>

<<div align="center" style="font-size:28pt; font-family:arial; " >
MTE Implementation Tutorial (MTE Core, MKE, MTE Fixed Length)</div>
<br>
<div align="center" style="font-size:15pt; font-family:arial; " >
Using MTE version 3.1.x</div>

[Introduction](#introduction)

[Socket Tutorial Server and Client](#socket-tutorial-server-and-client)


<div style="page-break-after: always; break-after: page;"></div>

# Introduction

This tutorial is sending messages via a socket connection. This is only a sample, the MTE does NOT require the usage of sockets, you can use whatever communication protocol that is needed.

This tutorial demonstrates how to use Mte Core, Mte MKE and Mte Fixed Length. For this application, only one type can be used at a time; however, it is possible to implement any and all at the same time depending on needs.

This tutorial contains two main programs, a client and a server, and also for Windows and Linux. Note that any of the available languages can be used for any available platform as long as communication is possible. It is just recommended that a server program is started first and then a client program can be started.

The MTE Encoder and Decoder need several pieces of information to be the same in order to function properly. This includes entropy, nonce, and personalization. If this information must be shared, the entropy MUST be passed securely. One way to do this is with a Diffie-Hellman approach. Each side will then be able to create two shared secrets to use as entropy for each pair of Encoder/Decoder. The two personalization values will be created by the client and shared to the other side. The two nonce values will be created by the server and shared.

The SDK that you received from Eclypses may not include the MKE or MTE FLEN add-ons. If your SDK contains either the MKE or the Fixed Length add-ons, the name of the SDK will contain "-MKE" or "-FLEN". If these add-ons are not there and you need them please work with your sales associate. If there is no need, please just ignore the MKE and FLEN options.

Here is a short explanation of when to use each, but it is encouraged to either speak to a sales associate or read the dev guide if you have additional concerns or questions.

***MTE Core:*** This is the recommended version of the MTE to use. Unless payloads are large or sequencing is needed this is the recommended version of the MTE and the most secure.

***MTE MKE:*** This version of the MTE is recommended when payloads are very large, the MTE Core would, depending on the token byte size, be multiple times larger than the original payload. Because this uses the MTE technology on encryption keys and encrypts the payload, the payload is only enlarged minimally.

***MTE Fixed Length:*** This version of the MTE is very secure and is used when the resulting payload is desired to be the same size for every transmission. The Fixed Length add-on is mainly used when using the sequencing verifier with MTE. In order to skip dropped packets or handle asynchronous packets the sequencing verifier requires that all packets be a predictable size. If you do not wish to handle this with your application then the Fixed Length add-on is a great choice. This is ONLY an encoder change - the decoder that is used is the MTE Core decoder.

***IMPORTANT NOTE***
>If using the fixed length MTE (FLEN), all messages that are sent that are longer than the set fixed length will be trimmed by the MTE. The other side of the MTE will NOT contain the trimmed portion. Also messages that are shorter than the fixed length will be padded by the MTE so each message that is sent will ALWAYS be the same length. When shorter message are "decoded" on the other side the MTE takes off the extra padding when using strings and hands back the original shorter message, BUT if you use the raw interface the padding will be present as all zeros. Please see official MTE Documentation for more information.

In this tutorial, there is an MTE Encoder on the client that is paired with an MTE Decoder on the server. Likewise, there is an MTE Encoder on the server that is paired with an MTE Decoder on the client. Secured messages wil be sent to and from both sides. If a system only needs to secure messages one way, only one pair could be used.

**IMPORTANT**
>Please note the solution provided in this tutorial does NOT include the MTE library or supporting MTE library files. If you have NOT been provided an MTE library and supporting files, please contact Eclypses Inc. The solution will only work AFTER the MTE library and MTE library files have been incorporated.
  

# Socket Tutorial Server and Client

## MTE Directory and File Setup
<ol>
<li>
Navigate to the "tutorial-mte-socket-swift-ios/TutorialMTE" directory.
</li>
<li>
Create a directory named "MTE". This will contain all needed MTE files.
</li>
<li>
Copy the "lib" directory and the xcframework it contains from the MTE SDK into the "MTE" directory.
</li>
<li>
Copy the "include" directory and contents from the MTE SDK into the "MTE" directory.
</li>
<li>
Copy the "src" directory and contents from the MTE SDK into the "MTE" directory. Then delete all subdirectories except the swift directory. 
</li>
<li>
Within the "swift" directory, open the Bridging-Header.h file and uncomment all the #includes. If your SDK does not include all add-ons, you will get a compile-time error showing that one or more files are not found, which means, comment those #includes out again.  
</li>
<li>
If when you attempt to compile, you get over a hundred errors, it's a good sign that the mte.xcframework is not linked. To correct this, in the Xcode Project Navigator, select the 'SocketClient' root directory, then the Socket Client Target, and select the 'General' tab. Scroll down to 'Frameworks, Libraries, and Embedded Content' section. mte.xcframework should be there. If it's not, add it.
</li>
</ol>

## ECDH Swift Package Manager Package

### This Swift tutorial uses the Swift Package Manager (SPM) EcdhP256 package. It is available at https://github.com/Eclypses/package-swift-ecdhp256.git but should already be part of this tutorial. If it's not, ...
<ol>
<li>
Right-click in the Project Navigator and select 'Add Packages'.
</li>
<li>
In the dialog window that opens, paste https://github.com/Eclypses/package-swift-ecdhp256.git in the search bar and add the package from the 'public' branch.
</li>
<li>
Make sure the EcdhP256 module is in the 'Frameworks, Libraries, and Embedded Content' section as you did with the mte.xcframework above.
</li>
</ol>

# Elliptic-Curve Diffie-Hellman Key Exchange With Server

## Socket Communication
### Socket communication is set up in these tutorials to always prepend 4 bytes of data length in Big Endian format, and a 5 byte as a header byte to the actual data. This allows the socket server to first listen for 5 bytes, extract the header byte and the length bytes to know what kind of data is coming and how many bytes it is. The code examples below demonstrate that.

## Create Client public keys and Personalization Strings and Send To Server
```swift
    func exchangeKeys() {
        
        // Key exchange for Encoder
        clientEncPersonalizationString = UUID().uuidString.lowercased()
        clientEncEcdh = EcdhP256(name: "Encoder")
        let encResult: (status:Int , publicKey:[UInt8]?) = clientEncEcdh.createKeyPair()
        if encResult.status != EcdhP256.ResultCodes.success || encResult.publicKey == nil {
            return
        }
        
        // Key exchange for Decoder
        clientDecPersonalizationString = UUID().uuidString.lowercased()
        clientDecEcdh = EcdhP256(name: "Decoder")
        let decResult: (status:Int , publicKey:[UInt8]?) = clientDecEcdh.createKeyPair()
        if decResult.status != EcdhP256.ResultCodes.success || decResult.publicKey == nil {
            return
        }
        
        // Send out information to the server.
        // 1 - client Encoder public key (to server Decoder)
        // 2 - client Encoder personalization string (to server Decoder)
        // 3 - client Decoder public key (to server Encoder)
        // 4 - client Decoder personalization string (to server Encoder)
        send(header: "1", outgoingMessage: encResult.publicKey!)
        send(header: "2", outgoingMessage: [UInt8](clientEncPersonalizationString.utf8))
        send(header: "3", outgoingMessage: decResult.publicKey!)
        send(header: "4", outgoingMessage: [UInt8](clientDecPersonalizationString.utf8))
        
        // Listen for Acknowledgement
        print("\nListening for Acknowledgement from Server")
        receive()
    }
    
    func send(header: Character, outgoingMessage: [UInt8]) {
        var message = ""
        if !connected {
            exit(EXIT_SUCCESS)
        }
        
        // Send the length first
        let length = Int32(outgoingMessage.count)
        let headerValue = UInt8(header.asciiValue!)
        let dataLength = withUnsafeBytes(of: length.bigEndian, Array.init) + withUnsafeBytes(of: headerValue, Array.init)
        
        // Send the data length first . . .
        nwConnection.send(content: [UInt8](dataLength), completion: .contentProcessed( { error in
            if let error = error {
                self.connectionDidFail(error: error)
            }
        }))
        
        // Then, send the encoded data
        nwConnection.send(content: outgoingMessage, completion: .contentProcessed( { error in
            if let error = error {
                self.connectionDidFail(error: error)
                return
            }
            message = message + "Data we are sending (as Ascii Hex only for display here): \n\t\([UInt8](outgoingMessage).bytesToHex())"
            self.updateTextViewText(self.encodedTextView, message, .green)
        }))
    }
```

## Receive Server Public Keys and Nonces
```swift
    private func receive() {
        nwConnection.receive(minimumIncompleteLength: 5, maximumLength: 5) { (data, _, isComplete, error) in
            if isComplete {
                self.connectionDidEnd()
            } else if let error = error {
                self.connectionDidFail(error: error)
            }
            guard let data = data, !data.isEmpty else {
                self.updateTextViewText(self.decodedTextView,"Received no data from Server", .red)
                return
            }
            
            // Get Header byte ...
            let header = Character(UnicodeScalar(data.bytes[4]))
            
            // Then get just the length data
            let subData = data.subdata(in: 0..<4)
            
            // Extract the length of the incoming data in Big Endian format
            let length = subData.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
            
            // Receive the Server response data
            self.nwConnection.receive(minimumIncompleteLength: Int(length), maximumLength: Int(length)) { (data, _, isComplete, error) in
                var message: String = ""
                guard let data = data, !data.isEmpty else {
                    self.updateTextViewText(self.decodedTextView,"Received no message data from Server", .red)
                    return
                }
                // Evaluate the header.
                // 1 - client Decoder public key (from server Encoder)
                // 2 - client Decoder nonce (from server Encoder)
                // 3 - client Encoder public key (from server Decoder)
                // 4 - client Encoder nonce (from server Decoder)
                switch header {
                case "A":
                    message = "Server Acknowledged receipt of ECDH Keys"
                case "1":
                    self.serverEncPublicKey = data.bytes
                    self.count += 1
                case "2":
                    self.serverEncNonce = data.bytes
                    self.count += 1
                case "3":
                    self.serverDecPublicKey = data.bytes
                    self.count += 1
                case "4":
                    self.serverDecNonce = data.bytes
                    self.count += 1
                case "m":
                    message = "Server Response (as Ascii Hex only for display here): \n\t\(data.bytes.bytesToHex())"
                    
                    let decodeResult = self.decoder.decode(data.bytes)
                    if decodeResult.status != mte_status_success {
                        self.updateTextViewText(self.decodedTextView,"MTE decode ERROR: \(MteBase.getStatusName(decodeResult.status)) - \(MteBase.getStatusDescription(decodeResult.status))", .red)
                    }
                    
                    guard let decodedServerMessage = String(bytes: decodeResult.decoded, encoding: .utf8) else {
                        self.updateTextViewText(self.decodedTextView,"Unable to retrieve text string from data.", .red)
                        return
                    }
                    message = message + "\nDecoded response from Server: \n\t\(decodedServerMessage)"
                    self.updateTextViewText(self.decodedTextView, message, .green)
                default:
                    self.updateTextViewText(self.decodedTextView,"Received an unknown response header from Server", .red)
                    return
                }
                print(message)
                
                // if we have received all 4 ECDH valus from server and
                // we have not yest set up the encoder and decoder, send an
                // acknowledgement to the Server and set up the MTE
                if self.count == 4 && self.encoder == nil && self.decoder == nil {
                    self.send(header: "A", outgoingMessage: Array("ACK".utf8))
                    self.setupMTE()
                }
                self.receive()
            }
        }
    }
```

# Implement MTE

### After Mte is set up, subsequent calls are made the same as the 'runDiagnosticTest' function and responses are received in the same 'Receive' function. These calls will have an 'm' header bytes and will be decoded by Mte.

``` swift
    func setupMTE() {
        var message: UpdateTextView
        do {
            print("MTE Version used: \(MteBase.getVersion())")
            
            // Check mte license
            // Edit class variables above with your license information
            if !MteBase.initLicense(licenseCompanyName, licenseKey) {
                throw MTEError.encoderError(errorMessage: "License Check ERROR: \(MteBase.getStatusName(status)) - \(MteBase.getStatusDescription(status))")
            } else {
                print("License Check SUCCESS")
            }
        } catch {
            message = UpdateTextView(text: "Exception in MTE Setup. Error: \(error.localizedDescription)", bgColor: .red)
            updateTextViewText(encodedTextView, message.text, .red)
            return
        }
        
        // Initialize Encoder
        do {
            
            // Along with encoder variables above, uncomment the encoder you wish to use
            encoder = try MteEnc()
//            encoder = try MteMkeEnc()
//            encoder = try MteFlenEnc(fixedBytes)
            
            var encEntropy = [UInt8]()
            let encResult = clientEncEcdh.getSharedSecret(remotePublicKeyBytes: serverDecPublicKey, entropyBuffer: &encEntropy)
            if encResult != EcdhP256.ResultCodes.success {
                print("Unable to get encoder shared secret")
                return
            }
            encoder.setEntropy(&encEntropy)
            encoder.setNonce(serverDecNonce)
            status = encoder.instantiate([UInt8](clientEncPersonalizationString.utf8))
            if status != mte_status_success {
                throw MTEError.encoderError(errorMessage: "Encoder Instantiate ERROR: \(MteBase.getStatusName(status)) - \(MteBase.getStatusDescription(status))")
            } else {
                updateTextViewText(encodedTextView, "Encoder Ready!", .green)
                print("Encoder Instantiate SUCCESS")
            }
        } catch {
            updateTextViewText(encodedTextView,"Exception in Encoder Instantiation. Error: \(error.localizedDescription)", .red)
            return
        }
        
        // Initialize Decoder
        do {
            
            // Along with decoder variables above, uncomment the decoder you wish to use
            // For FLEN encoder on server, use MteDec()
            decoder = try MteDec()
//            decoder = try MteMkeDec()
            
            var decEntropy = [UInt8]()
            let decResult = clientDecEcdh.getSharedSecret(remotePublicKeyBytes: serverEncPublicKey, entropyBuffer: &decEntropy)
            if decResult != EcdhP256.ResultCodes.success {
                print("Unable to get decoder shared secret")
                return
            }
            decoder.setEntropy(&decEntropy)
            decoder.setNonce(serverEncNonce)
            status = decoder.instantiate([UInt8](clientDecPersonalizationString.utf8))
            if status != mte_status_success {
                throw MTEError.encoderError(errorMessage: "Decoder Instantiate ERROR: \(MteBase.getStatusName(status)) - \(MteBase.getStatusDescription(status))")
            } else {
                print("Decoder Instantiate SUCCESS")
                updateTextViewText(decodedTextView, "Decoder Ready!", .green)
            }
        } catch {
            updateTextViewText(decodedTextView, "Exception in Decoder Instantiation. Error: \(error.localizedDescription)", .red)
        }
        
        // Test the pairing as the Server is expecting, in this case.
        runDiagnosticTest()
        DispatchQueue.main.async {
            self.useTheseSettingsButton.isHidden = true
            self.encodeButton.isHidden = false
            self.connectionStackView.isHidden = true
            self.mteStackView.isHidden = false
        }
    }
    
    func runDiagnosticTest() {
        dataStr = "ping"
        let data = [UInt8](dataStr.utf8)
        
        // Use MTE to encode the data
        let encodeResult = encoder.encode(data)
        if encodeResult.status != mte_status_success {
            self.updateTextViewText(self.encodedTextView,"MTE Encode ERROR: \(MteBase.getStatusName(self.status)) - \(MteBase.getStatusDescription(self.status))", .red)
        }
        send(header: "m", outgoingMessage: [UInt8](encodeResult.encoded))
    }
```
<div style="page-break-after: always; break-after: page;"></div>

# Contact Eclypses

<img src="Eclypses.png" style="width:8in;"/>

<p align="center" style="font-weight: bold; font-size: 22pt;">For more information, please contact:</p>
<p align="center" style="font-weight: bold; font-size: 22pt;"><a href="mailto:info@eclypses.com">info@eclypses.com</a></p>
<p align="center" style="font-weight: bold; font-size: 22pt;"><a href="https://www.eclypses.com">www.eclypses.com</a></p>
<p align="center" style="font-weight: bold; font-size: 22pt;">+1.719.323.6680</p>

<p style="font-size: 8pt; margin-bottom: 0; margin: 300px 24px 30px 24px; " >
<b>All trademarks of Eclypses Inc.</b> may not be used without Eclypses Inc.'s prior written consent. No license for any use thereof has been granted without express written consent. Any unauthorized use thereof may violate copyright laws, trademark laws, privacy and publicity laws and communications regulations and statutes. The names, images and likeness of the Eclypses logo, along with all representations thereof, are valuable intellectual property assets of Eclypses, Inc. Accordingly, no party or parties, without the prior written consent of Eclypses, Inc., (which may be withheld in Eclypses' sole discretion), use or permit the use of any of the Eclypses trademarked names or logos of Eclypses, Inc. for any purpose other than as part of the address for the Premises, or use or permit the use of, for any purpose whatsoever, any image or rendering of, or any design based on, the exterior appearance or profile of the Eclypses trademarks and or logo(s).
</p>
