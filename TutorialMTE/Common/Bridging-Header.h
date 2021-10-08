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

// This is a template bridging header that contains all necessary header
// includes. If your project has an existing bridging header, you can copy
// the relevant includes to that header. If your project does not have a
// bridging header, you can uncomment the relevant lines and use this file
// directly.
//
// Note that the headers listed here include other headers, so the entire SDK
// include directory should be kept in tact. Directly including these is enough
// to get the associated Swift classes to build. You should uncomment only the
// includes associated with the classes you need, and only include the classes
// you really need in your project. There is a derivation chain, so you need to
// include all base classes in your project as well.

// Base (MteBase) includes. These are required to use any part of MTE.
#include "mte_license.h"
#include "mte_base.h"

// ARM64 support (MteArm64).
//#include "mte_arm64.h"

// Core decoder (MteDec).
#include "mte_dec.h"

// Core encoder (MteEnc).
#include "mte_enc.h"

// Fixed-Length Add-On encoder (MteFlenEnc).
//#include "mte_flen_enc.h"

// Jailbreak Add-On (MteDecJail, MteEncJail, MteFlenEncJail, MteJail,
// MteMkeDecJail, MteMkeEncJail).
//#include "mte_jail.h"

// Managed-Key Encryption Add-On decoder (MteMkeDec).
//#include "mte_mke_dec.h"

// Managed-Key Encryption Add-On encoder (MteMkeEnc).
//#include "mte_mke_enc.h"

