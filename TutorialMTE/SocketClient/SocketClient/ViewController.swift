//
// ****************************************************************
// SocketClient
// ViewController.swift created on 3/30/21 by Greg Waggoner
// Copyright © 2021 Eclypses Inc. All rights reserved.
// ****************************************************************

import UIKit
import Network

class ViewController: UIViewController{

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
    
    // MARK: MTE Variables
    
    // Status.
    var status = mte_status_success
    
    // Edit to match your licence information
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

    
    // Initial Values
    var entropy: [UInt8]!
    
    // In this client tutorial, we set the encoder and decoder nonces differently so the encoded payloads will appear different
    // even though the data prior to encoding is the same. They are reversed on the Server so they match up.
    let encoderNonce: UInt64 = 1
    var decoderNonce: UInt64 = 0
    
    // Fixed-Length parameter needed for FLEN
    let fixedBytes = 8
    
    let personalizationString: String = "demo"
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
        // Set up the view
        bannerTextArea.text = "Eclypses Swift Socket \nClient Lab App \nVersion \(MteBase.getVersion())"
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
        setupMTE()
        setupClientSocket()
		useTheseSettingsButton.isHidden = true
		encodeButton.isHidden = false
		connectionStackView.isHidden = true
		mteStackView.isHidden = false
    }
	
	@IBAction func encodeButtonTapped(_ sender: Any) {
        if !connected {
            exit(EXIT_SUCCESS)
        }
		count += 1
        var message: String!
        do {
            dataStr = dataToEncodeTextField.text ?? dataStr
            let data = [UInt8](dataStr.utf8)
            
            // Use MTE to encode the data
            let encodeResult = encoder.encode(data)
            if encodeResult.status != mte_status_success {
                throw MTEError.encoderError(errorMessage: "MTE Encode ERROR: \(MteBase.getStatusName(self.status)) - \(MteBase.getStatusDescription(self.status))")
            }
            message = "\nEncoded data (as Ascii Hex only for display here): \n\t\([UInt8](encodeResult.encoded).bytesToHex())"

            // Send the length first
            let length = Int32(encodeResult.encoded.count)
            let dataLength = withUnsafeBytes(of: length.bigEndian, Array.init)
            
            // Send the data length first . . .
            nwConnection.send(content: dataLength, completion: .contentProcessed( { error in
                if let error = error {
                    self.connectionDidFail(error: error)
                }
            }))
            
            // Then, send the encoded data
            nwConnection.send(content: encodeResult.encoded, completion: .contentProcessed( { error in
                if let error = error {
                    self.connectionDidFail(error: error)
                    return
                }
                self.updateTextViewText(self.encodedTextView, message, .green)
                print(message!)
                
                // Listen for response from Server
                self.receive()
            }))
        } catch {
            self.updateTextViewText(self.encodedTextView,"Exception in MTE Encode. Error: \(error.localizedDescription)", .red)
        }
	}
    
    private func receive() {
        nwConnection.receive(minimumIncompleteLength: 4, maximumLength: 4) { (data, _, isComplete, error) in
            if isComplete {
                self.connectionDidEnd()
            } else if let error = error {
                self.connectionDidFail(error: error)
            }
            guard let data = data, !data.isEmpty else {
                print("Received no length prefix data")
                exit(EXIT_FAILURE)
            }
            
            // Retrieve the length of the incoming data in Big Endian format
            let length = data.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian}
            
            // Receive the Server response data
            self.nwConnection.receive(minimumIncompleteLength: Int(length), maximumLength: Int(length)) { (data, _, isComplete, error) in
                var message: String = ""
                do {
                    guard let data = data, !data.isEmpty else {
                        throw MTEError.decoderError(errorMessage: "Received no message data.")
                    }
                    message = "Server Response (as Ascii Hex only for display here): \n\t\(data.bytes.bytesToHex())"
                    
                    let decodeResult = self.decoder.decode(data.bytes)
                    if decodeResult.status != mte_status_success {
                        throw MTEError.encoderError(errorMessage: "MTE decode ERROR: \(MteBase.getStatusName(self.status)) - \(MteBase.getStatusDescription(self.status))")
                    }
                    
                    guard let decodedServerMessage = String(bytes: decodeResult.decoded, encoding: .utf8) else {
                        throw MTEError.encoderError(errorMessage: "Unable to retrieve text string from data.")
                    }
                    message = message + "\nDecoded response from Server: \n\t\(decodedServerMessage)"
                } catch {
                    self.updateTextViewText(self.decodedTextView,"Exception in MTE Decode. Error: \(error.localizedDescription)", .red)
                }
                self.updateTextViewText(self.decodedTextView, message, .green)
                print(message)
            }
        }
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
			let iteration = "Iteration: \(self.count)\n"
			textView.text = self.count > 0 ? iteration + text : text
		}
	}
    
    // MARK: Setup MTE
    func setupMTE() {
        var message: UpdateTextView
        do {
            print("MTE Version used: \(MteBase.getVersion())")
            
            // Check mte license
            // Edit class variables above with your licencen information
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
            
            // IMPORTANT! ** This is an entirely insecure way of setting Entropy
            // and MUST NOT be used in a "real" application. See MTE Developer's Guide for more information.
            // Get the minimum entropy length for the DRBG and set to repeating zeros.
            let entropyBytes = MteBase.getDrbgsEntropyMinBytes(encoder.getDrbg())
            entropy = [UInt8](repeating: Character("0").asciiValue!, count: entropyBytes)
            
            encoder.setEntropy(&entropy)
            encoder.setNonce(encoderNonce)
            status = encoder.instantiate([UInt8](personalizationString.utf8))
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
            
            // Refill entropy. (it is zeroized when setting entropy in the encoder)
            let entropyBytes = MteBase.getDrbgsEntropyMinBytes(decoder.getDrbg())
            entropy = [UInt8](repeating: Character("0").asciiValue!, count: entropyBytes)
            
            decoder.setEntropy(&entropy)
            decoder.setNonce(decoderNonce)
            status = decoder.instantiate([UInt8](personalizationString.utf8))
            if status != mte_status_success {
                throw MTEError.encoderError(errorMessage: "Decoder Instantiate ERROR: \(MteBase.getStatusName(status)) - \(MteBase.getStatusDescription(status))")
            } else {
                print("Decoder Instantiate SUCCESS")
                updateTextViewText(decodedTextView, "Decoder Ready!", .green)
            }
        } catch {
            updateTextViewText(decodedTextView, "Exception in Decoder Instantiation. Error: \(error.localizedDescription)", .red)
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

