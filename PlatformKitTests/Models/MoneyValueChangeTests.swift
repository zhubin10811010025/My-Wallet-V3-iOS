//
//  MoneyValueChangeTests.swift
//  PlatformKitTests
//
//  Created by Daniel on 15/07/2020.
//  Copyright © 2020 Blockchain Luxembourg S.A. All rights reserved.
//

import XCTest
@testable import PlatformKit

final class MoneyValueChangeTests: XCTestCase {

    // Test value before 10% increase
    func testFiatValueBefore10PercentIncrease() {
        let value = FiatValue.create(minor: "1500", currency: .GBP)!
        let expected = FiatValue.create(minor: "1000", currency: .GBP)!
        let result = value.value(before: 0.5)
        XCTAssertEqual(result, expected)
    }

    // Test value before NaN
    func testFiatValueBeforeNaN() {
        let value = FiatValue.create(minor: "1500", currency: .GBP)!
        let expected = FiatValue.zero(currency: .GBP)
        let result = value.value(before: .nan)
        XCTAssertEqual(result, expected)
    }

    // Test value before 100 % Decrease
    func testFiatValueBefore100PercentDecrease() {
        let value = FiatValue.create(minor: "1500", currency: .GBP)!
        let expected = FiatValue.zero(currency: .GBP)
        let result = value.value(before: -1)
        XCTAssertEqual(result, expected)
    }
    
    // Test value before 10% increase
    func testMoneyValueBefore10PercentIncrease() {
        let value = MoneyValue.create(major: "1", currency: .crypto(.bitcoin))!
        let expected = MoneyValue.create(major: "0.9090909091", currency: .crypto(.bitcoin))!
        let result = value.value(before: 0.1)
        XCTAssertEqual(result, expected)
    }

    // Test value before NaN
    func testCryptoValueBeforeNaN() {
        let value = CryptoValue.create(major: "1", currency: .bitcoin)!
        let expected = CryptoValue.zero(currency: .bitcoin)
        let result = value.value(before: .nan)
        XCTAssertEqual(result, expected)
    }

    // Test value before 100 % Decrease
    func testCryptoValueBefore100PercentDecrease() {
        let value = CryptoValue.create(major: "1", currency: .bitcoin)!
        let expected = CryptoValue.zero(currency: .bitcoin)
        let result = value.value(before: -1)
        XCTAssertEqual(result, expected)
    }
    
    // Test value before 10% increase
    func testCryptoValueBefore10PercentIncrease() {
        let value = CryptoValue.create(major: "1", currency: .bitcoin)!
        let expected = CryptoValue.create(major: "0.9090909091", currency: .bitcoin)
        let result = value.value(before: 0.1)
        XCTAssertEqual(result, expected)
    }
    
    // Test value before 50% increase
    func testCryptoValueBefore50PercentIncrease() {
        let value = CryptoValue.create(major: "15", currency: .bitcoin)!
        let expected = CryptoValue.create(major: "10", currency: .bitcoin)
        let result = value.value(before: 0.5)
        XCTAssertEqual(result, expected)
    }
    
    func testMoneyValueInitializeWithMajor() {
        let value = MoneyValue.create(major: "0.072", currency: .fiat(.GBP))!
        let expected: Decimal = 0.07
        XCTAssertEqual(value.displayMajorValue, expected.roundTo(places: 2))
    }
    
    func testMinorString() {
        let expectedFiat = "7"
        let valueFiat = MoneyValue.create(major: "0.072", currency: .fiat(.GBP))!
        XCTAssertEqual(expectedFiat, valueFiat.minorString)
        
        let expectedCrypto = "72000000000000000"
        let valueCrypto = MoneyValue.create(major: "0.072", currency: .crypto(.ethereum))!
        XCTAssertEqual(expectedCrypto, valueCrypto.minorString)
    }
}
