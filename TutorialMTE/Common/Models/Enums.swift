//
// ******************************************************
// SocketClient Project
// Enums.swift created on 6/17/21 by Greg Waggoner
// Copyright © 2021 Eclypses Inc. All rights reserved.
// ******************************************************


import Foundation

enum MTEError: Error {
    case encoderError(errorMessage: String)
    case decoderError(errorMessage: String)
}
