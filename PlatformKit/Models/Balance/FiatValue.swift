//
//  FiatValue.swift
//  PlatformKit
//
//  Created by Chris Arriola on 1/17/19.
//  Copyright © 2019 Blockchain Luxembourg S.A. All rights reserved.
//

import Foundation

public struct FiatComparisonError: Error {
    let currencyCode1: String
    let currencyCode2: String
}

public struct FiatValue {
    /// The currency code (e.g. "USD")
    public let currencyCode: String
    public let amount: Decimal
}

extension FiatValue {
    /// Creates a FiatValue from a provided amount in String and currency code.
    /// If the amountString is invalid, the resulting FiatValue amount will be 0.
    ///
    /// - Parameters:
    ///   - amountString: the amount as a String
    ///   - currencyCode: the currency code
    /// - Returns: the FiatValue
    public static func create(amountString: String, currencyCode: String) -> FiatValue {
        let amount = Decimal(string: amountString) ?? 0
        return FiatValue(currencyCode: currencyCode, amount: amount)
    }
}

extension FiatValue: Money {
    public var isZero: Bool {
        return amount == 0
    }

    public var isPositive: Bool {
        return amount > 0
    }

    public var symbol: String {
        let locale = NSLocale(localeIdentifier: currencyCode)
        return locale.displayName(forKey: NSLocale.Key.currencySymbol, value: currencyCode) ?? ""
    }

    public var maxDecimalPlaces: Int {
        return 2
    }

    public var maxDisplayableDecimalPlaces: Int {
        return maxDecimalPlaces
    }

    public func toDisplayString(includeSymbol: Bool = true, locale: Locale = Locale.current) -> String {
        let formatter = FiatFormatterProvider.shared.formatter(locale: locale, fiatValue: self, includeSymbol: includeSymbol)
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "\(amount)"
    }
}

// MARK: - Operators

extension FiatValue: Hashable, Equatable {
    private static func ensureComparable(value: FiatValue, other: FiatValue) throws {
        if value.currencyCode != other.currencyCode {
            throw FiatComparisonError(currencyCode1: value.currencyCode, currencyCode2: other.currencyCode)
        }
    }

    public static func +(lhs: FiatValue, rhs: FiatValue) throws -> FiatValue {
        try ensureComparable(value: lhs, other: rhs)
        return FiatValue(currencyCode: lhs.currencyCode, amount: lhs.amount + rhs.amount)
    }

    public static func -(lhs: FiatValue, rhs: FiatValue) throws -> FiatValue {
        try ensureComparable(value: lhs, other: rhs)
        return FiatValue(currencyCode: lhs.currencyCode, amount: lhs.amount - rhs.amount)
    }

    public static func *(lhs: FiatValue, rhs: FiatValue) throws -> FiatValue {
        try ensureComparable(value: lhs, other: rhs)
        return FiatValue(currencyCode: lhs.currencyCode, amount: lhs.amount * rhs.amount)
    }

    public static func +=(lhs: inout FiatValue, rhs: FiatValue) throws {
        lhs = try lhs + rhs
    }

    public static func -=(lhs: inout FiatValue, rhs: FiatValue) throws {
        lhs = try lhs - rhs
    }

    public static func *= (lhs: inout FiatValue, rhs: FiatValue) throws {
        lhs = try lhs * rhs
    }
}

// MARK: FiatFormatterProvider

private class FiatFormatterProvider {

    static let shared = FiatFormatterProvider()

    private var formatterMap = [String: NumberFormatter]()

    func formatter(locale: Locale, fiatValue: FiatValue, includeSymbol: Bool = true) -> NumberFormatter {
        let mapKey = key(locale: locale, fiatValue: fiatValue, includeSymbol: includeSymbol)
        guard let matchingFormatter = formatterMap[mapKey] else {
            let formatter = createNumberFormatter(locale: locale, fiatValue: fiatValue, includeSymbol: includeSymbol)
            formatterMap[mapKey] = formatter
            return formatter
        }
        return matchingFormatter
    }

    private func key(locale: Locale, fiatValue: FiatValue, includeSymbol: Bool) -> String {
        return "\(locale.identifier)_\(fiatValue.currencyCode)_\(includeSymbol)"
    }

    private func createNumberFormatter(locale: Locale, fiatValue: FiatValue, includeSymbol: Bool) -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.usesGroupingSeparator = true
        formatter.minimumFractionDigits = fiatValue.maxDecimalPlaces
        formatter.maximumFractionDigits = fiatValue.maxDecimalPlaces
        formatter.roundingMode = .down
        formatter.locale = locale
        formatter.currencyCode = fiatValue.currencyCode

        if includeSymbol {
            formatter.numberStyle = .currency
        } else {
            formatter.numberStyle = .decimal
        }

        return formatter
    }
}