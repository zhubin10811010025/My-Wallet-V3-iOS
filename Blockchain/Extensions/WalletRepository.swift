//
//  WalletRepository.swift
//  Blockchain
//
//  Created by Daniel Huri on 15/11/2019.
//  Copyright © 2019 Blockchain Luxembourg S.A. All rights reserved.
//

import RxSwift
import RxRelay
import ToolKit
import PlatformKit

/// TODO: Remove `NSObject` when `Wallet` is killed
/// A bridge to `Wallet` since it is an ObjC object.
@objc
final class WalletRepository: NSObject, WalletRepositoryAPI, WalletCredentialsProviding {
    
    // MARK: - Types
    
    private struct JSSetter {
        
        struct Password {
            static let change = "MyWalletPhone.changePassword(\"%@\")"
            static let success = "objc_on_change_password_success"
            static let error = "objc_on_change_password_error"
        }
        
        /// Accepts "true" / "false" as parameter
        static let syncPubKeys = "MyWalletPhone.setSyncPubKeys(%@)"
        
        /// Accepts a String representing the language
        static let language = "MyWalletPhone.setLanguage(\"%@\")"
        
        /// Accepts a String representing the wallet payload
        static let payload = "MyWalletPhone.setEncryptedWalletData(\"%@\")"
    }
    
    private let authenticatorTypeRelay = BehaviorRelay<AuthenticatorType>(value: .standard)
    private let sessionTokenRelay = BehaviorRelay<String?>(value: nil)
    private let passwordRelay = BehaviorRelay<String?>(value: nil)

    // MARK: - Properties
    
    /// Streams the session token if exists
    var sessionToken: Single<String?> {
        sessionTokenRelay
            .take(1)
            .asSingle()
    }
    
    /// Streams the GUID if exists
    var guid: Single<String?> {
        Single.deferred { [weak self] in
            guard let self = self else {
                return .error(ToolKitError.nullReference(Self.self))
            }
            return .just(self.settings.guid)
        }
    }

    /// Streams the shared key if exists
    var sharedKey: Single<String?> {
        Single.deferred { [weak self] in
            guard let self = self else {
                return .error(ToolKitError.nullReference(Self.self))
            }
            return .just(self.settings.sharedKey)
        }
    }

    /// Streams the password if exists
    var password: Single<String?> {
        passwordRelay
            .take(1)
            .asSingle()
    }

    var authenticatorType: Single<AuthenticatorType> {
        authenticatorTypeRelay
            .take(1)
            .asSingle()
    }

    private let jsScheduler = MainScheduler.instance
    private let settings: AppSettingsAPI

    private unowned let jsContextProvider: JSContextProviderAPI
    
    // MARK: - Setup
    
    init(jsContextProvider: JSContextProviderAPI, settings: AppSettingsAPI) {
        self.jsContextProvider = jsContextProvider
        self.settings = settings
        super.init()
    }
    
    // MARK: - Wallet Setters
    
    /// Sets GUID
    func set(guid: String) -> Completable {
        perform { [weak self] in
            self?.settings.guid = guid
        }
    }

    /// Sets the session token
    func set(sessionToken: String) -> Completable {
        perform { [weak sessionTokenRelay] in
            sessionTokenRelay?.accept(sessionToken)
        }
    }
    
    /// Cleans the session token
    func cleanSessionToken() -> Completable {
        perform { [weak sessionTokenRelay] in
            sessionTokenRelay?.accept(nil)
        }
    }
    
    /// Sets Shared-Key
    func set(sharedKey: String) -> Completable {
        perform { [weak self] in
            self?.settings.sharedKey = sharedKey
        }
    }
    
    /// Sets Password
    func set(password: String) -> Completable {
        perform { [weak passwordRelay] in
            passwordRelay?.accept(password)
        }
    }
    
    func sync() -> Completable {
        Completable
            .create { [weak self] observer -> Disposable in
                guard let self = self else {
                    observer(.error(PasswordRepositoryError.syncFailed))
                    return Disposables.create()
                }
                guard let password = self.passwordRelay.value else {
                    observer(.error(PasswordRepositoryError.unavailable))
                    return Disposables.create()
                }
                let script = String(format: JSSetter.Password.change, password)
                
                self.jsContextProvider.jsContext.invokeOnce(functionBlock: {
                    observer(.completed)
                }, forJsFunctionName: JSSetter.Password.success as NSString)
                
                self.jsContextProvider.jsContext.invokeOnce(functionBlock: {
                    observer(.error(PasswordRepositoryError.syncFailed))
                }, forJsFunctionName: JSSetter.Password.error as NSString)
                
                self.jsContextProvider.jsContext.evaluateScript(script)
            return Disposables.create()
        }
    }
    
    /// Sets Authenticator Type
    func set(authenticatorType: AuthenticatorType) -> Completable {
        perform { [weak authenticatorTypeRelay] in
            authenticatorTypeRelay?.accept(authenticatorType)
        }
    }
    
    // MARK: - JS Setters
    
    /// Sets a boolean indicating whether the public keys should sync to the wallet
    func set(syncPubKeys: Bool) -> Completable {
        perform { [weak jsContextProvider] in
            let value = syncPubKeys ? "true" : "false"
            let script = String(format: JSSetter.syncPubKeys, value)
            jsContextProvider?.jsContext.evaluateScript(script)
        }
    }
    
    /// Sets the language
    func set(language: String) -> Completable {
        perform { [weak jsContextProvider] in
            let escaped = language.escapedForJS()
            let script = String(format: JSSetter.language, escaped)
            jsContextProvider?.jsContext.evaluateScript(script)
        }
    }
    
    /// Sets the wallet payload
    func set(payload: String) -> Completable {
        perform { [weak jsContextProvider] in
            let escaped = payload.escapedForJS()
            let script = String(format: JSSetter.payload, escaped)
            jsContextProvider?.jsContext.evaluateScript(script)
        }
    }
    
    // MARK: - Accessors
    
    private func perform(_ operation: @escaping () -> Void) -> Completable {
        Completable
            .create { observer -> Disposable in
                operation()
                observer(.completed)
                return Disposables.create()
            }
            .subscribeOn(jsScheduler)
    }
    
    // MARK: - Legacy: PLEASE DONT USE THESE UNLESS YOU MUST HOOK LEGACY OBJ-C CODE

    @available(*, deprecated, message: "Please do not use this unless you absolutely need direct access")
    @objc
    var legacySessionToken: String? {
        set {
            sessionTokenRelay.accept(newValue)
        }
        get {
            sessionTokenRelay.value
        }
    }

    @available(*, deprecated, message: "Please do not use this unless you absolutely need direct access")
    @objc
    var legacyPassword: String? {
        set {
            passwordRelay.accept(newValue)
        }
        get {
            passwordRelay.value
        }
    }
}
