//
//  Wallet+Extensions.swift
//  Blockchain
//
//  Created by AlexM on 11/26/18.
//  Copyright © 2018 Blockchain Luxembourg S.A. All rights reserved.
//

import Foundation
import PlatformKit
import RxSwift
import StellarKit

/// `MnemonicAccessAPI` is part of the `bridge` that is used when injecting the `wallet` into
/// a `WalletAccountRepository`. This is how we check if the user needs to enter their
/// secondary password if their wallet is double encrypted.
extension Wallet: MnemonicAccessAPI {
    public var mnemonicPromptingIfNeeded: Maybe<Mnemonic> {
        mnemonic.ifEmpty(switchTo: mnemonicForcePrompt)
    }
    
    public func mnemonic(with secondPassword: String?) -> Single<Mnemonic> {
        var secondPassword = secondPassword
        if secondPassword?.isEmpty == true {
            secondPassword = nil
        }
        if needsSecondPassword(), secondPassword == nil {
            return .error(MnemonicAccessError.generic)
        }
        guard let mnemonic = getMnemonic(secondPassword) else {
            return .error(MnemonicAccessError.generic)
        }
        return .just(mnemonic)
    }

    public var mnemonic: Maybe<Mnemonic> {
        guard !self.needsSecondPassword() else {
            return Maybe.empty()
        }
        guard let mnemonic = self.getMnemonic(nil) else {
            return Maybe.empty()
        }
        return Maybe.just(mnemonic)
    }
    
    public var mnemonicForcePrompt: Maybe<Mnemonic> {
        Maybe.create(subscribe: { observer -> Disposable in
            AuthenticationCoordinator.shared.showPasswordScreen(
                type: .actionRequiresPassword,
                confirmHandler: { [weak self ] password in
                    guard let mnemonic = self?.getMnemonic(password) else {
                        observer(.completed)
                        return
                    }
                    observer(.success(mnemonic))
                },
                dismissHandler: {
                    observer(.error(StellarPaymentOperationError.cancelled))
                }
            )
            return Disposables.create()
        })
        .subscribeOn(MainScheduler.asyncInstance)
    }
}

/// `StellarWalletBridgeAPI` is part of the `bridge` that is used when injecting the `wallet` into
/// a `WalletAccountRepository`. This is how we save the users `StellarKeyPair`
extension Wallet: StellarWalletBridgeAPI {
    public func save(keyPair: StellarKit.StellarKeyPair, label: String, completion: @escaping StellarWalletBridgeAPI.KeyPairSaveCompletion) {
        self.saveXlmAccount(keyPair.accountID, label: label, sucess: {
            completion(nil)
        }, error: { errorMessage in
            completion(errorMessage)
        })
    }
    
    public func stellarWallets() -> [StellarKit.StellarWalletAccount] {
        guard let xlmAccountsRaw = self.getXlmAccounts() else {
            return []
        }
        
        guard !xlmAccountsRaw.isEmpty else {
            return []
        }
        
        return xlmAccountsRaw.castJsonObjects(type: StellarWalletAccount.self)
    }
}
