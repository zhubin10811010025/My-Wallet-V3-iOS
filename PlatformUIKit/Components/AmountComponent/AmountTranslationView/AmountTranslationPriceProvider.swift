//
//  AmountTranslationPriceProvider.swift
//  PlatformUIKit
//
//  Created by Paulo on 15/12/2020.
//  Copyright © 2020 Blockchain Luxembourg S.A. All rights reserved.
//

import DIKit
import PlatformKit
import RxSwift

public protocol AmountTranslationPriceProviding {
    // Amount is in Fiat, must return an MoneyValuePair of base `amount` in `fiatCurrency` and the quoted crypto value.
    func pairFromFiatInput(cryptoCurrency: CryptoCurrency, fiatCurrency: FiatCurrency, amount: String) -> Single<MoneyValuePair>
    // Amount is in Crypto, must return an MoneyValuePair of base `amount` in `cryptoCurrency` and the quoted fiat value.
    func pairFromCryptoInput(cryptoCurrency: CryptoCurrency, fiatCurrency: FiatCurrency, amount: String) -> Single<MoneyValuePair>
}

public final class AmountTranslationPriceProvider: AmountTranslationPriceProviding {
    private let priceService: PriceServiceAPI

    public init(priceService: PriceServiceAPI = resolve()) {
        self.priceService = priceService
    }

    public func pairFromCryptoInput(cryptoCurrency: CryptoCurrency, fiatCurrency: FiatCurrency, amount: String) -> Single<MoneyValuePair> {
        priceService
            .price(for: cryptoCurrency, in: fiatCurrency)
            .map { exchangeRate in
                let amount = amount.isEmpty ? "0" : amount
                return try MoneyValuePair(
                    base: CryptoValue.create(major: amount, currency: cryptoCurrency)!.moneyValue,
                    exchangeRate: exchangeRate.moneyValue
                )
            }
    }

    public func pairFromFiatInput(cryptoCurrency: CryptoCurrency, fiatCurrency: FiatCurrency, amount: String) -> Single<MoneyValuePair> {
        let amount = amount.isEmpty ? "0" : amount
        let fiatValue = FiatValue.create(major: amount, currency: fiatCurrency)!
        return priceService.moneyValuePair(base: fiatValue, cryptoCurrency: cryptoCurrency, usesFiatAsBase: true)
    }
}
