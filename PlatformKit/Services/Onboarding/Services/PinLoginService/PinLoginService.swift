//
//  PinLoginService.swift
//  Blockchain
//
//  Created by Daniel Huri on 03/12/2019.
//  Copyright © 2019 Blockchain Luxembourg S.A. All rights reserved.
//

import DIKit
import RxSwift
import ToolKit

public final class PinLoginService: PinLoginServiceAPI {
    
    // MARK: - Types
    
    public typealias PasscodeRepositoryAPI = SharedKeyRepositoryAPI & GuidRepositoryAPI & PasswordRepositoryAPI

    /// Potential errors
    public enum ServiceError: Error {
        case missingEncryptedPassword
        case walletDecryption
        case emptyDecryptedPassword
        case missingGuid
        case missingSharedKey
    }

    // MARK: - Properties

    private let settings: AppSettingsAuthenticating
    private let service: WalletPayloadServiceAPI
    private let walletRepository: PasscodeRepositoryAPI
    private let walletCryptoService: WalletCryptoServiceAPI
    
    // MARK: - Setup
    
    public init(jsContextProvider: JSContextProviderAPI = resolve(),
                settings: AppSettingsAuthenticating,
                service: WalletPayloadServiceAPI,
                walletRepository: PasscodeRepositoryAPI,
                recoder: Recording = resolve(tag: "CrashlyticsRecorder")) {
        self.service = service
        self.settings = settings
        self.walletRepository = walletRepository
        self.walletCryptoService = WalletCryptoService(
            contextProvider: jsContextProvider,
            recorder: recoder
        )
    }
    
    public func password(from pinDecryptionKey: String) -> Single<String> {
        service
            .requestUsingSharedKey()
            .flatMapSingle(weak: self) { (self) -> Single<PasscodePayload> in
                self.passcodePayload(from: pinDecryptionKey)
            }
            .flatMap(weak: self) { (self, payload) -> Single<String> in
                self
                    .cache(passcodePayload: payload)
                    .andThen(Single.just(payload.password))
            }
    }

    private func passcodePayload(from pinDecryptionKey: String) -> Single<PasscodePayload> {
        Single
            .zip(
                self.walletRepository.guid,
                self.walletRepository.sharedKey,
                self.decrypt(pinDecryptionKey: pinDecryptionKey)
            )
            .map { payload -> PasscodePayload in
                guard let guid = payload.0, !guid.isEmpty else {
                    throw ServiceError.missingGuid
                }
                guard let sharedKey = payload.1, !sharedKey.isEmpty else {
                    throw ServiceError.missingSharedKey
                }
                return PasscodePayload(
                    guid: guid,
                    password: payload.2,
                    sharedKey: sharedKey
                )
            }
    }
    
    /// Caches the passcode payload using wallet repository
    private func cache(passcodePayload: PasscodePayload) -> Completable {
        Completable
            .zip(
                walletRepository.set(sharedKey: passcodePayload.sharedKey),
                walletRepository.set(password: passcodePayload.password),
                walletRepository.set(guid: passcodePayload.guid)
            )
    }

    private var encryptedPinPassword: Single<String> {
        settings
            .encryptedPinPassword
            .map {
                guard let encryptedPinPassword = $0 else {
                    throw ServiceError.missingEncryptedPassword
                }
                return encryptedPinPassword
            }
    }

    /// Decrypt the password using the PIN decryption key
    private func decrypt(pinDecryptionKey: String) -> Single<String> {
        encryptedPinPassword
            .map { KeyDataPair<String, String>(key: pinDecryptionKey, data: $0) }
            .flatMap(weak: self) { (self, keyDataPair) -> Single<String> in
                self.walletCryptoService.decrypt(pair: keyDataPair, pbkdf2Iterations: WalletCryptoPBKDF2Iterations.pinLogin)
            }
    }
}
