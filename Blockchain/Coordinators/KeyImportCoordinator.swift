//
//  KeyImportCoordinator.swift
//  Blockchain
//
//  Created by Maurice A. on 5/22/18.
//  Copyright © 2018 Blockchain Luxembourg S.A. All rights reserved.
//

import BitcoinKit
import DIKit
import PlatformKit
import PlatformUIKit

@objc protocol PrivateKeyReaderDelegate: class {
    func didFinishScanning(_ privateKey: String, for address: String?)
    @objc optional func didFinishScanningWithError(_ error: PrivateKeyReaderError)
}

// TODO: remove once AccountsAndAddresses and SendBitcoinViewController are migrated to Swift
@objc protocol LegacyPrivateKeyDelegate: class {
    func didFinishScanning(_ privateKey: String)
    @objc optional func didFinishScanningWithError(_ error: PrivateKeyReaderError)
}

@objc enum PrivateKeyReaderError: Int {
    case badMetadataObject
    case unknownKeyFormat
    case unsupportedPrivateKey
}

// TODO: Refactor class to support other asset types (currently assumed to be Bitcoin)
@objc class KeyImportCoordinator: NSObject, Coordinator {

    enum KeyImportError: String {
        case presentInWallet
        case needsBip38
        case wrongBipPass
    }

    enum AddressImportError: String {
        case addressNotPresentInWallet
        case addressNotWatchOnly
        case privateKeyOfAnotherNonWatchOnlyAddress
    }

    static let shared = KeyImportCoordinator()
    
    //: Nil if device input is unavailable
    private var qrCodeScannerViewController: UIViewController?

    /// Observer key for notifications used throughout this class
    private let backupKey = Constants.NotificationKeys.backupSuccess

    private let walletManager: WalletManager
    private let loadingViewPresenter: LoadingViewPresenting
    
    @objc class func sharedInstance() -> KeyImportCoordinator {
        KeyImportCoordinator.shared
    }

    // TODO: Refactor class to support other asset types (currently assumed to be Bitcoin)
    private init(walletManager: WalletManager = WalletManager.shared,
                 loadingViewPresenter: LoadingViewPresenting = resolve()) {
        self.walletManager = walletManager
        self.loadingViewPresenter = loadingViewPresenter
        super.init()
        initialize()
    }

    @objc func initialize() {
        self.walletManager.keyImportDelegate = self
    }

    func start() { /* Tasks which do not require scanning should call this */ }
    
    func start(with delegate: PrivateKeyReaderDelegate,
               in viewController: UIViewController,
               assetType: CryptoCurrency = .bitcoin,
               loadingText: String = LocalizationConstants.AddressAndKeyImport.loadingImportKey,
               assetAddress: AssetAddress? = nil) {
        
        let privateKeyQRCodeParser = PrivateKeyQRCodeParser(
            walletManager: walletManager,
            loadingViewPresenter: loadingViewPresenter,
            assetAddress: assetAddress
        )

        qrCodeScannerViewController =
            QRCodeScannerViewControllerBuilder(
                parser: privateKeyQRCodeParser,
                textViewModel: PrivateKeyQRCodeTextViewModel(loadingText: loadingText),
                completed: { [weak self] result in
                    self?.handlePrivateKeyScan(result: result, delegate: delegate)
                }
            )
            .with(loadingViewPresenter: loadingViewPresenter)
            .build()
        
        guard let qrCodeScannerViewController = qrCodeScannerViewController else { return }

        viewController.present(qrCodeScannerViewController, animated: true, completion: nil)
    }
    
    // TODO: remove once LegacyPrivateKeyDelegate is deprecated
    @objc func start(with delegate: LegacyPrivateKeyDelegate,
                     in viewController: UIViewController,
                     assetType: LegacyAssetType = .bitcoin,
                     loadingText: String = LocalizationConstants.AddressAndKeyImport.loadingImportKey) {
        
        let privateKeyQRCodeParser = PrivateKeyQRCodeParser(
            walletManager: walletManager,
            loadingViewPresenter: loadingViewPresenter,
            assetAddress: nil
        )

        qrCodeScannerViewController =
            QRCodeScannerViewControllerBuilder(
                parser: privateKeyQRCodeParser,
                textViewModel: PrivateKeyQRCodeTextViewModel(loadingText: loadingText),
                completed: { [weak self] result in
                    self?.handlePrivateKeyScan(result: result, legacyDelegate: delegate)
                }
            )
            .with(loadingViewPresenter: loadingViewPresenter)
            .build()
        
        guard let qrCodeScannerViewController = qrCodeScannerViewController else { return }

        viewController.present(qrCodeScannerViewController, animated: true, completion: nil)
    }
    
    private func handlePrivateKeyScan(result: Result<PrivateKeyQRCodeParser.PrivateKey, PrivateKeyQRCodeParser.PrivateKeyQRCodeParserError>, delegate: PrivateKeyReaderDelegate) {
        handlePrivateKeyScanFinished()
        switch result {
        case .success(let privateKey):
            delegate.didFinishScanning(privateKey.scannedKey, for: privateKey.assetAddress?.publicKey)
        case .failure(let error):
            presentPrivateKeyScan(error: error.privateKeyReaderError)
            delegate.didFinishScanningWithError?(error.privateKeyReaderError)
        }
    }
    
    // TODO: remove once LegacyPrivateKeyDelegate is deprecated
    private func handlePrivateKeyScan(result: Result<PrivateKeyQRCodeParser.PrivateKey, PrivateKeyQRCodeParser.PrivateKeyQRCodeParserError>, legacyDelegate: LegacyPrivateKeyDelegate) {
        handlePrivateKeyScanFinished()
        switch result {
        case .success(let privateKey):
            legacyDelegate.didFinishScanning(privateKey.scannedKey)
        case .failure(let error):
            presentPrivateKeyScan(error: error.privateKeyReaderError)
            legacyDelegate.didFinishScanningWithError?(error.privateKeyReaderError)
        }
    }
    
    private func handlePrivateKeyScanFinished() {
        loadingViewPresenter.hide()
        qrCodeScannerViewController = nil
    }
    
    private func presentPrivateKeyScan(error: PrivateKeyReaderError) {
        switch error {
        case .badMetadataObject:
            AlertViewPresenter.shared.standardError(message: LocalizationConstants.Errors.error)
        case .unknownKeyFormat:
            AlertViewPresenter.shared.standardError(message: LocalizationConstants.AddressAndKeyImport.unknownKeyFormat)
        case .unsupportedPrivateKey:
            AlertViewPresenter.shared.standardError(message: LocalizationConstants.AddressAndKeyImport.unsupportedPrivateKey)
        }
    }

    // MARK: - Temporary Objective-C bridging methods for backwards compatibility

    @objc func on_add_private_key_start() {
        walletManager.wallet.isSyncing = true
        loadingViewPresenter.show(with: LocalizationConstants.AddressAndKeyImport.loadingImportKey)
    }

    @objc func on_add_key(address: String) {
        let validator = AddressValidator(context: WalletManager.shared.wallet.context)
        guard validator.validate(bitcoinAddress: address) else { return }
        walletManager.wallet.isSyncing = true
        walletManager.wallet.shouldLoadMetadata = true
        importKey(from: BitcoinAssetAddress(publicKey: address))
    }

    // TODO: unused parameter - confirm whether address param will be used in the future
    @objc func on_add_incorrect_private_key(address: String) {
        walletManager.wallet.isSyncing = true
        didImportIncorrectPrivateKey()
    }

    @objc func on_add_private_key_to_legacy_address(address: String) {
        walletManager.wallet.isSyncing = true
        walletManager.wallet.shouldLoadMetadata = true
        // TODO: change assetType parameter to `address.assetType` once it is directly called from Swift
        walletManager.wallet.subscribe(toAddress: address, assetType: .bitcoin)
        importedPrivateKeyToLegacyAddress()
    }

    @objc func on_error_adding_private_key(error: String) {
        failedToImportPrivateKey(errorDescription: error)
    }

    @objc func on_error_adding_private_key_watch_only(error: String) {
        failedToImportPrivateKeyForWatchOnlyAddress(errorDescription: error)
    }

    @objc func on_error_import_key_for_sending_from_watch_only(error: String) {
        failedToImportPrivateKeyForSendingFromWatchOnlyAddress(errorDescription: error)
    }
}

// MARK: - WalletKeyImportDelegate

extension KeyImportCoordinator: WalletKeyImportDelegate {
    func alertUserOfInvalidPrivateKey() {
        AlertViewPresenter.shared.standardError(message: LocalizationConstants.AddressAndKeyImport.incorrectPrivateKey)
    }

    @objc func alertUserOfImportedIncorrectPrivateKey() {
        NotificationCenter.default.removeObserver(self, name: backupKey, object: nil)
        let importedKeyButForIncorrectAddress = LocalizationConstants.AddressAndKeyImport.importedKeyButForIncorrectAddress
        let importedKeyDoesNotCorrespondToAddress = LocalizationConstants.AddressAndKeyImport.importedKeyDoesNotCorrespondToAddress
        let message = String(format: "%@\n\n%@", importedKeyButForIncorrectAddress, importedKeyDoesNotCorrespondToAddress)
        AlertViewPresenter.shared.standardNotify(title: LocalizationConstants.success, message: message, handler: nil)
    }

    @objc func alertUserOfImportedKey() {
        NotificationCenter.default.removeObserver(self, name: backupKey, object: nil)
        let isWatchOnly = walletManager.wallet.isWatchOnlyLegacyAddress(walletManager.wallet.lastImportedAddress)
        let importedAddressArgument = LocalizationConstants.AddressAndKeyImport.importedWatchOnlyAddressArgument
        let importedPrivateKeyArgument = LocalizationConstants.AddressAndKeyImport.importedPrivateKeyArgument
        let format = isWatchOnly ? importedAddressArgument : importedPrivateKeyArgument
        let message = String(format: format, walletManager.wallet.lastImportedAddress)
        AlertViewPresenter.shared.standardNotify(title: LocalizationConstants.success, message: message, handler: nil)
    }

    @objc func alertUserOfImportedPrivateKeyIntoLegacyAddress() {
        NotificationCenter.default.removeObserver(self, name: backupKey, object: nil)
        let importedKeySuccess = LocalizationConstants.AddressAndKeyImport.importedKeySuccess
        AlertViewPresenter.shared.standardNotify(title: LocalizationConstants.success, message: importedKeySuccess, handler: nil)
    }

    func askUserToAddWatchOnlyAddress(_ address: AssetAddress, then: @escaping () -> Void) {
        let firstLine = LocalizationConstants.AddressAndKeyImport.addWatchOnlyAddressWarning
        let secondLine = LocalizationConstants.AddressAndKeyImport.addWatchOnlyAddressWarningPrompt
        let message = String(format: "%@\n\n%@", firstLine, secondLine)
        let title = LocalizationConstants.Errors.warning
        let continueAction = UIAlertAction(title: LocalizationConstants.continueString, style: .default) { _ in
            then()
        }
        let cancelAction = UIAlertAction(title: LocalizationConstants.cancel, style: .cancel, handler: nil)
        AlertViewPresenter.shared.standardNotify(title: title, message: message, actions: [continueAction, cancelAction])
    }

    func didImportIncorrectPrivateKey() {
        loadingViewPresenter.show(with: LocalizationConstants.syncingWallet)
        NotificationCenter.default.addObserver(self, selector: #selector(alertUserOfImportedIncorrectPrivateKey), name: backupKey, object: nil)
    }

    func failedToImportPrivateKey(errorDescription: String) {
        NotificationCenter.default.removeObserver(self, name: backupKey, object: nil)
        loadingViewPresenter.hide()
        walletManager.wallet.isSyncing = false

        // TODO: improve JS error handling to avoid string comparison
        var error = LocalizationConstants.AddressAndKeyImport.unknownErrorPrivateKey
        if errorDescription.contains(KeyImportError.presentInWallet.rawValue) {
            error = LocalizationConstants.AddressAndKeyImport.keyAlreadyImported
        } else if errorDescription.contains(KeyImportError.needsBip38.rawValue) {
            error = LocalizationConstants.AddressAndKeyImport.keyNeedsBip38Password
        } else if errorDescription.contains(KeyImportError.wrongBipPass.rawValue) {
            error = LocalizationConstants.AddressAndKeyImport.incorrectBip38Password
        }

        AlertViewPresenter.shared.standardNotify(title: LocalizationConstants.Errors.error, message: error, handler: nil)
    }

    func failedToImportPrivateKeyForSendingFromWatchOnlyAddress(errorDescription: String) {
        walletManager.wallet.loading_stop()
        if errorDescription == Constants.JSErrors.addressAndKeyImportWrongPrivateKey {
            alertUserOfInvalidPrivateKey()
        } else if errorDescription == Constants.JSErrors.addressAndKeyImportWrongBipPass {
            AlertViewPresenter.shared.standardError(message: LocalizationConstants.AddressAndKeyImport.incorrectBip38Password)
        } else {
            // TODO: improve copy for all other errors
            AlertViewPresenter.shared.standardError(message: LocalizationConstants.Errors.error)
        }
    }

    func failedToImportPrivateKeyForWatchOnlyAddress(errorDescription: String) {
        loadingViewPresenter.hide()
        walletManager.wallet.isSyncing = false

        // TODO: improve JS error handling to avoid string comparisons
        var error = LocalizationConstants.AddressAndKeyImport.unknownErrorPrivateKey
        if errorDescription.contains(AddressImportError.addressNotPresentInWallet.rawValue) {
            error = LocalizationConstants.AddressAndKeyImport.addressNotPresentInWallet
        } else if errorDescription.contains(AddressImportError.addressNotWatchOnly.rawValue) {
            error = LocalizationConstants.AddressAndKeyImport.addressNotWatchOnly
        } else if errorDescription.contains(AddressImportError.privateKeyOfAnotherNonWatchOnlyAddress.rawValue) {
            error = LocalizationConstants.AddressAndKeyImport.keyBelongsToOtherAddressNotWatchOnly
        }

        let cancelAction = UIAlertAction(title: LocalizationConstants.cancel, style: .cancel, handler: nil)
        let tryAgainAction = UIAlertAction(title: LocalizationConstants.tryAgain, style: .default) { [unowned self] _ in
            let address = BitcoinAssetAddress(publicKey: self.walletManager.wallet.lastScannedWatchOnlyAddress)
            let validator = AddressValidator(context: WalletManager.shared.wallet.context)
            guard validator.validate(bitcoinAddress: address.publicKey) else { return }
            self.scanPrivateKeyForWatchOnlyAddress(address)
        }

        let title = LocalizationConstants.Errors.error
        AlertViewPresenter.shared.standardNotify(title: title, message: error, actions: [cancelAction, tryAgainAction])
    }

    func importKey(from address: AssetAddress) {
        if walletManager.wallet.isWatchOnlyLegacyAddress(address.publicKey) {
            // TODO: change assetType parameter to `address.assetType` once it is directly called from Swift
            walletManager.wallet.subscribe(toAddress: address.publicKey, assetType: .bitcoin)
        }

        loadingViewPresenter.show(with: LocalizationConstants.syncingWallet)
        walletManager.wallet.lastImportedAddress = address.publicKey

        NotificationCenter.default.addObserver(self, selector: #selector(alertUserOfImportedKey), name: backupKey, object: nil)
    }

    func importedPrivateKeyToLegacyAddress() {
        loadingViewPresenter.show(with: LocalizationConstants.syncingWallet)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(alertUserOfImportedPrivateKeyIntoLegacyAddress),
                                               name: backupKey,
                                               object: nil)
    }

    func scanPrivateKeyForWatchOnlyAddress(_ address: AssetAddress) {
        if !Reachability.hasInternetConnection() {
            AlertViewPresenter.shared.internetConnection()
            return
        }

        guard let topVC = UIApplication.shared.keyWindow?.rootViewController?.topMostViewController else {
            fatalError("topMostViewController is nil")
        }
        start(with: self, in: topVC, assetAddress: address)

        // TODO: `lastScannedWatchOnlyAddress` needs to be of type AssetAddress, not String
        walletManager.wallet.lastScannedWatchOnlyAddress = address.publicKey
    }
}

// MARK: - PrivateKeyReaderDelegate

extension KeyImportCoordinator: PrivateKeyReaderDelegate {
    func didFinishScanning(_ privateKey: String, for address: String?) {
        walletManager.wallet.addKey(privateKey, toWatchOnlyAddress: address)
    }
}
