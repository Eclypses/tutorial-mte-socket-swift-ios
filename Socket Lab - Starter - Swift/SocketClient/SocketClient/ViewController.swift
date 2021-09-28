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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set up the view
        bannerTextArea.text = "Eclypses Swift Socket \nStarter (no MTE)"
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
        
        dataStr = dataToEncodeTextField.text ?? dataStr
        let data = [UInt8](dataStr.utf8)
        
        // This is where we would use MTE to encode the data
        
        message = "\n'Encoded' data (as Ascii Hex only for display here): \n\t\(data.bytesToHex())"
        
        // Send the length first
        let length = Int32(data.count)
        let dataLength = withUnsafeBytes(of: length.bigEndian, Array.init)
        
        // Send the data length first . . .
        nwConnection.send(content: dataLength, completion: .contentProcessed( { error in
            if let error = error {
                self.connectionDidFail(error: error)
            }
        }))
        
        // Then, send the encoded data
        nwConnection.send(content: data, completion: .contentProcessed( { error in
            if let error = error {
                self.connectionDidFail(error: error)
                return
            }
            self.updateTextViewText(self.encodedTextView, message, .green)
            print(message!)
            
            // Listen for response from Server
            self.receive()
        }))
        
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
                    
                    // This is where we would decode the server response with MTE
                    
                    guard let decodedServerMessage = String(bytes: data, encoding: .utf8) else {
                        throw MTEError.encoderError(errorMessage: "Unable to retrieve text string from data.")
                    }
                    message = message + "\n'Decoded' response from Server: \n\t\(decodedServerMessage)"
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
        updateTextViewText(encodedTextView, "'Encoder' Ready!", .green)
        updateTextViewText(decodedTextView, "'Decoder' Ready!", .green)
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

