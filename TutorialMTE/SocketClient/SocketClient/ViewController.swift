// The MIT License (MIT)
//
// Copyright (c) Eclypses, Inc.
//
// All rights reserved.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import UIKit
import Network
import EcdhP256

class ViewController: UIViewController {
    
    // MARK: UI variables
    @IBOutlet weak var connectionStackView: UIStackView!
    @IBOutlet weak var mteStackView: UIStackView!
    @IBOutlet weak var bannerTextArea: UITextView!
    @IBOutlet weak var ipAddressTextField: UITextField!
    @IBOutlet weak var portTextField: UITextField!
    @IBOutlet weak var dataToEncodeTextField: UITextField!
    @IBOutlet weak var encodeLabel: UILabel!
    @IBOutlet weak var encodedTextView: UITextView!
    @IBOutlet weak var decodeLabel: UILabel!
    @IBOutlet weak var decodedTextView: UITextView!
    @IBOutlet weak var useTheseSettingsButton: UIButton!
    @IBOutlet weak var encodeButton: UIButton!
    
    // MARK: Variables
    var nwConnection: NWConnection!
    
    var dataStr: String = "Super Secret Data!"
    var connected = true
    var count = 0
    var iteration = 0
    
    // MARK: MTE Variables
    
    // Status.
    var status = mte_status_success
    
    // Edit to match your license information
    let licenseCompanyName = "licenseCompanyName"
    let licenseKey = "licenseKey"
    
    // Uncomment the appropriate encoder and decoder
    // and don't forget that this Client Application and the Server Application being
    // called must implement the same encoder and decoder
    var encoder: MteEnc!
    //    var encoder: MteMkeEnc!
    //    var encoder: MteFlenEnc!
    
    var decoder: MteDec!
    //var decoder: MteMkeDec!
    
    // MARK: ECDH Variables
    private var clientEncEcdh: EcdhP256!
    private var clientDecEcdh: EcdhP256!
    private var clientEncPersonalizationString: String!
    private var clientDecPersonalizationString: String!
    private var serverEncPublicKey: [UInt8]!
    private var serverDecPublicKey: [UInt8]!
    private var serverEncNonce: [UInt8]!
    private var serverDecNonce: [UInt8]!
    
    // Fixed-Length parameter needed for FLEN
    let fixedBytes = 8
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set up the view
        bannerTextArea.text = "Eclypses Swift Socket \nClient Tutorial App \nVersion \(MteBase.getVersion())"
        ipAddressTextField.text = Settings.ipAddress
        portTextField.text = Settings.port
        dataToEncodeTextField.text = dataStr
        useTheseSettingsButton.isHidden = false
        encodeButton.isHidden = true
        mteStackView.isHidden = true
        initializeHideKeyboard()
    }
    
    @IBAction func useTheseSettingsButtonTapped(_ sender: Any) {
        Settings.ipAddress = ipAddressTextField.text ?? "localhost"
        Settings.port = portTextField.text ?? "27015"
        setupClientSocket()
        exchangeKeys()
    }
    
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
    
    
    @IBAction func encodeButtonTapped(_ sender: Any) {
        self.iteration += 1
        if !connected {
            exit(EXIT_SUCCESS)
        }
        dataStr = dataToEncodeTextField.text ?? dataStr
        let data = [UInt8](dataStr.utf8)
        
        // Use MTE to encode the data
        let encodeResult = encoder.encode(data)
        if encodeResult.status != mte_status_success {
            self.updateTextViewText(self.encodedTextView,"MTE encode ERROR: \(MteBase.getStatusName(encodeResult.status)) - \(MteBase.getStatusDescription(encodeResult.status))", .red)
            return
        }
        send(header: "m", outgoingMessage: [UInt8](encodeResult.encoded))
    }
    
    func clientResponse(_ response: UpdateTextView) {
        updateTextViewText(encodedTextView, response.text, response.bgColor)
    }
    
    func serverDidRespond(_ response: UpdateTextView) {
        updateTextViewText(decodedTextView, response.text, response.bgColor)
    }
    
    func updateTextViewText(_ textView: UITextView, _ text: String, _ bgColor: UIColor) {
        DispatchQueue.main.async {
            textView.backgroundColor = bgColor
            textView.text = self.iteration > 0 ? "Iteration: \(String(self.iteration))\n" + text : text
        }
    }
    
    
    
    // MARK: Setup MTE
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
    
    //MARK: Setup Client
    func setupClientSocket() {
        let nwHost = NWEndpoint.Host(Settings.ipAddress)
        let nwPort = NWEndpoint.Port(rawValue: UInt16(Settings.port)!)!
        nwConnection = NWConnection(host: nwHost, port: nwPort, using: .tcp)
        let queue = DispatchQueue(label: "Client connection Q")
        nwConnection.stateUpdateHandler = stateDidChange(to:)
        nwConnection.start(queue: queue)
    }
    
    // MARK: Keyboard Functions
    
    /// Dismisses the keyboard when tapping outside the keyboard
    @objc func dismissMyKeyboard(){
        //endEditing causes the view (or one of its embedded text fields) to resign the first responder status.
        //In short- Dismiss the active keyboard.
        view.endEditing(true)
    }
    
    /// Initializes the HideKeyboard functionality
    func initializeHideKeyboard(){
        //Declare a Tap Gesture Recognizer which will trigger our dismissMyKeyboard() function
        let tap: UITapGestureRecognizer = UITapGestureRecognizer(
            target: self,
            action: #selector(dismissMyKeyboard))
        
        //Add this tap gesture recognizer to the parent view
        view.addGestureRecognizer(tap)
    }
    
    // MARK: Network Functions
    
    private func stateDidChange(to state: NWConnection.State) {
        switch state {
        case .waiting(_):
            updateTextViewText(encodedTextView, "No Server listening at \(Settings.ipAddress) on Port \(Settings.port). Tap 'Quit', start Server and try again.", .yellow)
            connected = false
            DispatchQueue.main.async {
                self.encodeButton.setTitle("QUIT", for: .normal)
            }
        case .ready:
            print("Client connected to Server.")
        case .failed(let error):
            connectionDidFail(error: error)
        default:
            break
        }
    }
    
    func stop() {
        print("Connection with Server will stop")
        stop(error: nil)
    }
    
    private func connectionDidFail(error: Error) {
        print("Connection with Server did fail, error: \(error)")
        stop(error: error)
    }
    
    private func connectionDidEnd() {
        print("Connection with Server did end")
        stop(error: nil)
    }
    
    private func stop(error: Error?) {
        nwConnection.stateUpdateHandler = nil
        nwConnection.cancel()
        exit(EXIT_SUCCESS)
    }
    
}

