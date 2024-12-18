// RUN: heir-opt --verify-diagnostics --split-input-file %s

#encoding2 = #lwe.bit_field_encoding<
  cleartext_start=30,
  cleartext_bitwidth=3>

// expected-error@below {{cleartext starting bit index (30) is outside the legal range [0, 15]}}
func.func @test_invalid_lwe_attribute() -> tensor<2xi16, #encoding2> {
  %c0 = arith.constant 0 : index
  %two = arith.constant 2 : i16
  %coeffs1 = tensor.from_elements %two, %two : tensor<2xi16, #encoding2>
  return %coeffs1 : tensor<2xi16, #encoding2>
}

// -----

#encoding3 = #lwe.unspecified_bit_field_encoding<
  cleartext_bitwidth=8>

// expected-error@below {{tensor element type's bitwidth 4 is too small to store the cleartext, which has bit width 8}}
func.func @test_invalid_unspecified_lwe_attribute() -> tensor<2xi4, #encoding3> {
  %c0 = arith.constant 0 : index
  %two = arith.constant 2 : i4
  %coeffs1 = tensor.from_elements %two, %two : tensor<2xi4, #encoding3>
  return %coeffs1 : tensor<2xi4, #encoding3>
}

// -----

#coeff_encoding1 = #lwe.polynomial_coefficient_encoding<cleartext_start=15, cleartext_bitwidth=4>
func.func @test_invalid_coefficient_encoding_type(%a : i16, %b: i16) {
  // expected-error@below {{must have `polynomial.polynomial` element type}}
  %rlwe_ciphertext = tensor.from_elements %a, %b : tensor<2xi16, #coeff_encoding1>
  return
}

// -----

#generator2 = #polynomial.int_polynomial<1 + x**1024>
#ring2 = #polynomial.ring<coefficientType=!mod_arith.int<123:i16>, polynomialModulus=#generator2>
#coeff_encoding2 = #lwe.polynomial_coefficient_encoding<cleartext_start=30, cleartext_bitwidth=3>
func.func @test_invalid_coefficient_encoding_width(%coeffs1 : tensor<10xi16>, %coeffs2 : tensor<10xi16>) {
  %poly1 = polynomial.from_tensor %coeffs1 : tensor<10xi16> -> !polynomial.polynomial<ring=#ring2>
  %poly2 = polynomial.from_tensor %coeffs2 : tensor<10xi16> -> !polynomial.polynomial<ring=#ring2>
  // expected-error@below {{cleartext starting bit index (30) is outside the legal range [0, 15]}}
  %rlwe_ciphertext = tensor.from_elements %poly1, %poly2 : tensor<2x!polynomial.polynomial<ring=#ring2>, #coeff_encoding2>
  return
}

// -----

#eval_enc2 = #lwe.polynomial_evaluation_encoding<cleartext_start=14, cleartext_bitwidth=3>
func.func @test_invalid_evaluation_encoding_type() {
  // expected-error@below {{must have `polynomial.polynomial` element type}}
  %a = arith.constant dense<[2, 2, 5]> : tensor<3xi32, #eval_enc2>
  return
}

// -----

#inverse_canonical_enc2 = #lwe.inverse_canonical_embedding_encoding<cleartext_start=14, cleartext_bitwidth=4>
func.func @test_invalid_inverse_canonical_embedding_encoding() {
  // expected-error@below {{must have `polynomial.polynomial` element type}}
  %a = arith.constant dense<[2, 2, 5]> : tensor<3xi32, #inverse_canonical_enc2>
  return
}

// -----

// expected-error@below {{overflow must be either preserve_overflow or no_overflow, but found i1}}
#application = #lwe.application_data<message_type = i1, overflow = i1>

// -----

#poly = #polynomial.int_polynomial<x**1024 + 10>
#ring = #polynomial.ring<coefficientType=!mod_arith.int<65536:i32>, polynomialModulus=#poly>
#crt = #lwe.full_crt_packing_encoding<scaling_factor = 10000>
// expected-error@below {{polynomial modulus must be of the form x^n + 1}}
#plaintext_space = #lwe.plaintext_space<ring = #ring, encoding = #crt>

// -----

#poly = #polynomial.int_polynomial<x**1024 + 1>
#ring = #polynomial.ring<coefficientType=!mod_arith.int<12220:i32>, polynomialModulus=#poly>
#crt = #lwe.full_crt_packing_encoding<scaling_factor = 10000>
// expected-error@below {{modulus must be 1 mod n for full CRT packing}}
#plaintext_space = #lwe.plaintext_space<ring = #ring, encoding = #crt>

// -----

#key = #lwe.key<slot_index = 1>
#my_poly = #polynomial.int_polynomial<1 + x**1024>
#ring = #polynomial.ring<coefficientType = !mod_arith.int<12220:i32>, polynomialModulus=#my_poly>
!public_key = !lwe.new_lwe_public_key<key = #key, ring = #ring>

#preserve_overflow = #lwe.preserve_overflow<>
#application_data = #lwe.application_data<message_type = i1, overflow = #preserve_overflow>
#inverse_canonical_enc = #lwe.inverse_canonical_encoding<scaling_factor = 10000>
#plaintext_space = #lwe.plaintext_space<ring = #ring, encoding = #inverse_canonical_enc>
#ciphertext_space = #lwe.ciphertext_space<ring = #ring, encryption_type = msb, size = 3>
#modulus_chain = #lwe.modulus_chain<elements = <7917 : i32>, current = 0>

// expected-error@below {{a ciphertext with nontrivial slot rotation must have size 2, but found size 3}}
!new_lwe_ciphertext = !lwe.new_lwe_ciphertext<application_data = #application_data, plaintext_space = #plaintext_space, key = #key, ciphertext_space = #ciphertext_space, modulus_chain = #modulus_chain>
