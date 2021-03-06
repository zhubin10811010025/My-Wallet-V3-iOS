//
//  AutoPairingService.swift
//  Blockchain
//
//  Created by Daniel Huri on 17/01/2020.
//  Copyright © 2020 Blockchain Luxembourg S.A. All rights reserved.
//

import RxSwift
import ToolKit

/// A service that is responsible for the auto pairing process
public final class AutoWalletPairingService: AutoWalletPairingServiceAPI {

    // MARK: - Properties
    
    private let walletCryptoService: WalletCryptoServiceAPI
    private let parsingService = SharedKeyParsingService()
    
    private let walletPairingClient: AutoWalletPairingClientAPI
    private let walletPayloadService: WalletPayloadServiceAPI
    
    // MARK: - Setup
    
    public init(repository: WalletRepositoryAPI,
                walletPayloadClient: WalletPayloadClientAPI = WalletPayloadClient(),
                walletPairingClient: AutoWalletPairingClientAPI = AutoWalletPairingClient(),
                jsContextProvider: JSContextProviderAPI,
                recorder: Recording) {
        self.walletPairingClient = walletPairingClient
        walletPayloadService = WalletPayloadService(
            client: walletPayloadClient,
            repository: repository
        )
        walletCryptoService = WalletCryptoService(
            contextProvider: jsContextProvider,
            recorder: recorder
        )
    }
    
    /// Maps a QR pairing code of a wallet into its password, retrieve and cache the wallet data.
    /// Finally returns the password of the wallet
    /// 1. Receives a pairing code (guid, encrypted shared-key)
    /// 2. Sends the wallet `guid` -> receives a passphrase that can be used to decrypt the shared key.
    /// 3. Decrypt the shared key
    /// 4. Parse the shared key and the password
    /// 5. Request the wallet payload using the wallet GUID and the shared key
    /// 6. Returns the password.
    /// - Parameter pairingData: A pairing code comprises GUID and an encrypted shared key.
    /// - Returns: The wallet password - decrypted and ready for usage.
    public func pair(using pairingData: PairingData) -> Single<String> {
        walletPairingClient.request(guid: pairingData.guid)
            .map { KeyDataPair<String, String>(key: $0, data: pairingData.encryptedSharedKey) }
            .flatMap(weak: self) { (self, keyDataPair) -> Single<String> in
                self.walletCryptoService.decrypt(pair: keyDataPair, pbkdf2Iterations: WalletCryptoPBKDF2Iterations.autoPair)
            }
            .observeOn(ConcurrentDispatchQueueScheduler(qos: .background))
            .map(parsingService.parse)
            .flatMap(weak: self) { (self, pair) in
                self.walletPayloadService.request(
                    guid: pairingData.guid,
                    sharedKey: pair.data
                )
                .andThen(.just(pair.key))
            }
    }
}
