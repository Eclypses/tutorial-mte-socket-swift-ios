![Eclypses Logo alt text](./Eclypses_H_C_M-R.png =500x)

<div align="center" style="font-size:40pt; font-weight:900; font-family:arial; margin-top:300px; " >
Swift MacOS Server and Client Socket Tutorials</div>

<div align="center" style="font-size:28pt; font-family:arial; " >
MTE Implementation Tutorials </div>
<div align="center" style="font-size:15pt; font-family:arial; " >
Using MTE version 2.X.X</div>

[Introduction](#introduction)

[Socket Lab Server and Client](#socket-lab-server-and-client)<br>
- [Add MTE Files](#add-mte-files)<br>
- [Create Initial values](#create-initial-values)<br>
- [Check For License](#check-for-license)<br>
- [Create Encoder and/or Decoder](#create-encoder-and/or-decoder)<br>
- [Encode and Decode Sample Calls](#encode-and-decode-sample-calls)<br>

[Contact Eclypses](#contact-eclypses)


<div style="page-break-after: always; break-after: page;"></div>

# Introduction

This tutorial is sending messages via a socket connection. This is only a sample, the MTE does NOT require the usage of sockets, you can use whatever communication protocol that is needed.

This tutorial demonstrates how to use Mte Core, Mte MKE and Mte Fixed Length. Depending on what your needs are, these three different implementations can be used in the same application OR you can use any one of them. They are not dependent on each other and can run simultaneously in the same application if needed. 

The SDK that you received from Eclypses may not include the MKE or MTE FLEN add-ons. If your SDK contains either the MKE or the Fixed Length add-ons, the name of the SDK will contain "-MKE" or "-FLEN". If these add-ons are not there and you need them please work with your sales associate. If there is no need, please just ignore the MKE and FLEN options.

Here is a short explanation of when to use each, but it is encouraged to either speak to a sales associate or read the dev guide if you have additional concerns or questions.

***MTE Core:*** This is the recommended version of the MTE to use. Unless payloads are large or sequencing is needed this is the recommended version of the MTE and the most secure.

***MTE MKE:*** This version of the MTE is recommended when payloads are very large, the MTE Core would, depending on the token byte size, be multiple times larger than the original payload. Because this uses the MTE technology on encryption keys and encrypts the payload, the payload is only enlarged minimally.

***MTE Fixed Length:*** This version of the MTE is very secure and is used when the resulting payload is desired to be the same size for every transmission. The Fixed Length add-on is mainly used when using the sequencing verifier with MTE. In order to skip dropped packets or handle asynchronous packets the sequencing verifier requires that all packets be a predictable size. If you do not wish to handle this with your application then the Fixed Length add-on is a great choice. This is ONLY an encoder change - the decoder that is used is the MTE Core decoder.

In this tutorial we are creating an MTE Encoder and an MTE Decoder in the server as well as the client because we are sending secured messages in both directions. This is only needed when there are secured messages being sent from both sides, the server as well as the client. If only one side of your application is sending secured messages, then the side that sends the secured messages should have an Encoder and the side receiving the messages needs only a Decoder.

These steps should be followed on the server side as well as on the client side of the program.

**IMPORTANT**
>Please note the solution provided in this tutorial does NOT include the MTE library or supporting MTE library files. If you have NOT been provided an MTE library and supporting files, please contact Eclypses Inc. The solution will only work AFTER the MTE library and MTE library files have been incorporated.
  

# Socket Lab Server and Client Setup

To existing server and client projects, ...
## Add MTE Files

<ol>
<li>At the root of the project, add a new MTE directory to hold the desired MTE files</li>
<br>
<li>Using the Mte library and language wrapper files you received from your sales associate ...
<br>
<li>Copy and paste the MTE “include” and “libs” directories into the new MTE directory you just created.</li>
<br>
<li>Copy and paste the Swift Language Wrapper Files into this deirectory as well.</li>
</ol>

# Implement MTE

## Create Initial Values
```swift
var personalizationString: String = "demo"

// In this Lab, we set the encoder and decoder nonces differently so the encoded payloads will appear different
// even though the data prior to encoding is the same. They are reversed on the Client so they match up with
// the Server
var encoderNonce: UInt64 = 1
var decoderNonce: UInt64 = 0
```


## Check For License
```swift
// Check mte license
// Edit class variables above with your license information 
if !MteBase.initLicense(licenseCompanyName, licenseKey) {
    print("MTE License Check ERROR (\(MteBase.getStatusName(status))): " +
            MteBase.getStatusDescription(status))
    exit(EXIT_FAILURE)
} else {
    print("MTE License Check SUCCESS")
}
```

## Create Encoder and/or Decoder
Create MTE Encoder and Decoder Instances as necessary. After initializing each class, you must set the entropy and nonce before making the encoder/decoder.instantiate(personalizationString) call. After the instantiation call, check the status to confirm correct instantiation. See sample function below.

**IMPORTANT NOTE**  - This  Tutorial is designed to work with libraries containing Core MTE functionality as well as the MKE, FLEN and JAIL add-ons, however, to use the add-ons, you will need to comment/uncomment class variables for encoder and decoder and the encoder and decoder functions as well as #includes in Common/Bridging-Header as appropriate. Don't forget that the Server needs to be set up to match.

```swift
// Initialize Encoder
do {

    // Along with encoder variables above, uncomment the encoder you wish to use
    encoder = try MteEnc()
    // encoder = try MteMkeEnc()
    // encoder = try MteFlenEnc()
    
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
    decoder = try MteDec()
    // decoder = try MteMkeDec()
    
    // Refill entropy. (it is 'zeroed out' when setting entropy in the encoder
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
```
*(For further info on Encoder and Decoder initialization – See the MTE DevelopersGuide)*<br>
***When the above steps are completed on both the server and the client, the MTE will be ready for use.***

## Encode and Decode Sample Calls
Here are encode and decode sample calls 

```swift
// encode 
let encodeResult = encoder.encode(data)
if encodeResult.status != mte_status_success {
    throw MTEError.encoderError(errorMessage: "MTE Encode ERROR: \(MteBase.getStatusName(self.status)) - \(MteBase.getStatusDescription(self.status))")
}

// decode
let decodeResult = self.decoder.decode(data.bytes)
if decodeResult.status != mte_status_success {
    throw MTEError.encoderError(errorMessage: "MTE decode ERROR: \(MteBase.getStatusName(self.status)) - \(MteBase.getStatusDescription(self.status))")
}
```
<div style="page-break-after: always; break-after: page;"></div>

# Contact Eclypses

<p align="center" style="font-weight: bold; font-size: 22pt;">For more information, please contact:</p>
<p align="center" style="font-weight: bold; font-size: 22pt;"><a href="mailto:info@eclypses.com">info@eclypses.com</a></p>
<p align="center" style="font-weight: bold; font-size: 22pt;"><a href="https://www.eclypses.com">www.eclypses.com</a></p>
<p align="center" style="font-weight: bold; font-size: 22pt;">+1.719.323.6680</p>

<p style="font-size: 8pt; margin-bottom: 0; margin: 300px 24px 30px 24px; " >
<b>All trademarks of Eclypses Inc.</b> may not be used without Eclypses Inc.'s prior written consent. No license for any use thereof has been granted without express written consent. Any unauthorized use thereof may violate copyright laws, trademark laws, privacy and publicity laws and communications regulations and statutes. The names, images and likeness of the Eclypses logo, along with all representations thereof, are valuable intellectual property assets of Eclypses, Inc. Accordingly, no party or parties, without the prior written consent of Eclypses, Inc., (which may be withheld in Eclypses' sole discretion), use or permit the use of any of the Eclypses trademarked names or logos of Eclypses, Inc. for any purpose other than as part of the address for the Premises, or use or permit the use of, for any purpose whatsoever, any image or rendering of, or any design based on, the exterior appearance or profile of the Eclypses trademarks and or logo(s).
</p>
