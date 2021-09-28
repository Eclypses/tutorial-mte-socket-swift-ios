![Eclypses Logo alt text](./Eclypses_H_C_M-R.png =500x)

<div align="center" style="font-size:40pt; font-weight:900; font-family:arial; margin-top:300px; " >
Swift MacOS Server and Client Socket Labs</div>

<div align="center" style="font-size:28pt; font-family:arial; " >
MTE Implementation Lab </div>
<div align="center" style="font-size:15pt; font-family:arial; " >
Using MTE version 1.4</div>

[Introduction](#introduction)

[Socket Lab Server and Client](#socket-lab-server-and-client)<br>
- [Add MTE Files](#add-mte-files)<br>
- [Create Initial values](#create-initial-values)<br>
- [Create Options](#create-options)<br>
- [Check For License](#check-for-license)<br>
- [Check For Build-Time Options](#check-for-build-time-options)<br>
- [Self-Test the DRBG](#self-test-the-drbg)<br>
- [Create Encoder and/or Decoder](#create-encoder-and/or-decoder)<br>
- [Encode and Decode Sample Calls](#encode-and-decode-sample-calls)<br>

[Contact Eclypses](#contact-eclypses)


<div style="page-break-after: always; break-after: page;"></div>

# Introduction

These labs are communicating via socket connections, however, the MTE is communication-agnostic and any communication protocol may be used. 
In these Labs, both an MTE Encoder and a MTE Decoder are created in the server and in the client because the responses from the server to the client are also encoded. If only the client were sending messages, then only the client need have an Encoder and the only server need have a Decoder.


The following steps should be followed on the server as well as on the client.  

# Socket Lab Server and Client Setup

To existing server and client projects, ...
## Add MTE Files

<ol>
<li>Add a new MTE directory to hold the desired MTE files</li>
<br>
<li>To this, add the MTE “include” and “libs” directories.</li>
<br>
<li>Add the MteBase.swift, MteEnc.swift, MteDec.swift”, and Bridging-Header.h  files to this directory as well.</li>
<br>
<li>Within Xcode, set the path to the Bridging-Header.h in the Build Settings Objective-C Bridging Header property.</li>
</ol>

# Implement MTE

## Create Initial Values
```swift
// IMPORTANT! ** This is an entirely insecure way of setting Entropy and MUST NOT be used in a "real" application
// Get the minimum entropy length for the DRBG and set to repeating zeros.
let entropyBytes = MteBase.getDrbgsEntropyMinBytes(drbg)
var entropy = [UInt8](repeating: 0, count: entropyBytes)

var personalizationString: String = "demo"

// In this Lab, we set the encoder and decoder nonces differently so the encoded payloads will appear different
// even though the data prior to encoding is the same. They are reversed on the Client so they match up with
// the Server
var encoderNonce: UInt64 = 1
var decoderNonce: UInt64 = 0
```

## Create Options
```swift
var drbg: mte_drbgs = mte_drbgs_ctr_aes256_df
var tokenBytes: Int = 8 // Number of payload bytes each packet byte is expanded to.
var byteValMin: Int = 0
var byteValCount: Int = 256
var verifier: mte_verifiers = mte_verifiers_none
let timeStampWindow: UInt64 = 1 // number of seconds in-transit permitted if timestamp verification is turned on.
let sequenceWindow: Int = 0 // number of dropped packets permitted if sequencing verification is turned on.
```
*(For further information on MTE options – See MTE Developers Guide)*


## Check For License
```swift
// Check mte license
if !MteBase.initLicense("LicenseCompanyName", "LicenseKey") {
    print("MTE License Check ERROR (\(MteBase.getStatusName(status))): " +
            MteBase.getStatusDescription(status))
    exit(EXIT_FAILURE)
} else {
    print("MTE License Check SUCCESS")
}
```

## Check For Build-Time Options
If the MTE Library includes BuildTime Options, they must be used when initializing the Encoder and Decoder. Included below is a code sample to check the MTE Library for build time Options.
```swift
// Set Options to the buildtime Options if they exist
if MteBase.hasBuildtimeOpts() {
    
    // Set our Options varibles
    print("This MTE library has BuildTime Options so we will load them")
    drbg = MteBase.getBuildtimeDrbg()
    tokenBytes = MteBase.getBuildtimeTokBytes()
    byteValMin = MteBase.getBuildtimeByteValMin()
    byteValCount = MteBase.getBuildtimeByteValCount()
    verifier = MteBase.getBuildtimeVerifiers()
    print("BuildTime Options set")
}
```

## Self-Test the DRBG
```swift
status = MteBase.drbgsSelfTest(drbg)
if status != mte_status_success {
    print("DRBG SelfTest ERROR (\(MteBase.getStatusName(status))): " +
            MteBase.getStatusDescription(status))
    exit(EXIT_FAILURE)
} else {
    print("DRBG SelfTest SUCCESS")
}
```

## Create Encoder and/or Decoder
Create MTE Encoder and Decoder Instances as necessary. After initializing each class, you must set the entropy and nonce before making the encoder/decoder.instantiate(personalizationString) call. After the instantiation call, check the status to confirm correct instantiation. See sample function below.

```swift
// Initialize Encoder
do {
    encoder = try MteEnc(drbg, tokenBytes, byteValMin, byteValCount, verifier)
    encoder.setEntropy(entropy)
    encoder.setNonce(encoderNonce)
    status = encoder.instantiate([UInt8](personalizationString.utf8))
    if status != mte_status_success {
        print("Encoder Instantiate error (\(MteBase.getStatusName(status))): " +
                MteBase.getStatusDescription(status))
        exit(EXIT_FAILURE)
    } else {
        print("Encoder Instantiate SUCCESS")
    }
} catch {
    print("Exception in Encoder. Error: \(error.localizedDescription)")
    exit(EXIT_FAILURE)
}

// Initialize Decoder
do {
    decoder = try MteDec(drbg, tokenBytes, byteValMin, byteValCount, verifier, timeStampWindow, sequenceWindow)
    decoder.setEntropy(entropy)
    decoder.setNonce(decoderNonce)
    status = decoder.instantiate([UInt8](personalizationString.utf8))
    if status != mte_status_success {
        print("Decoder Instantiate error (\(MteBase.getStatusName(status))): " +
                MteBase.getStatusDescription(status))
        exit(EXIT_FAILURE)
    } else {
        print("Decoder Instantiate SUCCESS")
    }
} catch {
    print("Exception in Decoder. Error: \(error.localizedDescription)")
    exit(EXIT_FAILURE)
}
```
*(For further info on Encoder and Decoder initialization – See the MTE DevelopersGuide)*<br>
***When the above steps are completed on both the server and the client, the MTE will be ready for use.***

## Encode and Decode Sample Calls
Here are encode and decode sample calls 

```swift
// encode [UInt8] data 
let encodeResult = encoder.encode(data)
if encodeResult.status != mte_status_success {
	print("MTE encode ERROR (\(MteBase.getStatusName(status))): " +
			MteBase.getStatusDescription(status))
	exit(EXIT_FAILURE)
}

// decode  UInt8] data
let decodeResult = decoder.decode(data.bytes)
if decodeResult.status != mte_status_success {
	print("MTE decode ERROR (\(MteBase.getStatusName(status))): " +
			MteBase.getStatusDescription(status))
	exit(EXIT_FAILURE)
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
