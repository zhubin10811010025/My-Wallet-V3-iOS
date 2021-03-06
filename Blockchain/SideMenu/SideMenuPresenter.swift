//
//  SideMenuPresenter.swift
//  Blockchain
//
//  Created by Chris Arriola on 8/17/18.
//  Copyright © 2018 Blockchain Luxembourg S.A. All rights reserved.
//

import DIKit
import PlatformKit
import PlatformUIKit
import RxCocoa
import RxSwift
import ToolKit

/// Protocol definition for a view that displays a list of
/// SideMenuItem objects.
protocol SideMenuView: class {
    func setMenu(items: [SideMenuItem])
    func presentBuySellNavigationPlaceholder(controller: UINavigationController)
}

/// Presenter for the side menu of the app. This presenter
/// will handle the logic as to what side menu items should be
/// presented in the SideMenuView.
class SideMenuPresenter {
    
    // MARK: Public Properties
    
    var sideMenuItems: Observable<[SideMenuItem]> {
        reactiveWallet.waitUntilInitialized
            .flatMap(weak: self) { (self, _: ()) in
                self.featureFetcher
                    .fetchBool(for: .simpleBuyEnabled)
                    .asObservable()
                    .map { isSimpleBuyEnabled in
                        self.menuItems(showSimpleBuy: isSimpleBuyEnabled)
                    }
            }
            .startWith([])
            .observeOn(MainScheduler.instance)
    }
    
    var itemSelection: Signal<SideMenuItem> {
        itemSelectionRelay.asSignal()
    }

    private weak var view: SideMenuView?
    private var introductionSequence = WalletIntroductionSequence()
    private let introInterator: WalletIntroductionInteractor
    private let featureFetcher: FeatureFetching
    private let introductionRelay = PublishRelay<WalletIntroductionEventType>()
    private let itemSelectionRelay = PublishRelay<SideMenuItem>()
    
    // MARK: - Services
    
    private let wallet: Wallet
    private let walletService: WalletOptionsAPI
    private let reactiveWallet: ReactiveWalletAPI
    private let exchangeConfiguration: AppFeatureConfiguration
    private let analyticsRecorder: AnalyticsEventRecording
    private let disposeBag = DisposeBag()
    private var disposable: Disposable?
    
    init(
        view: SideMenuView,
        wallet: Wallet = WalletManager.shared.wallet,
        walletService: WalletOptionsAPI = resolve(),
        reactiveWallet: ReactiveWalletAPI = WalletManager.shared.reactiveWallet,
        featureFetcher: FeatureFetching = resolve(),
        exchangeConfiguration: AppFeatureConfiguration = { () -> AppFeatureConfigurator in
            resolve()
        }().configuration(for: .exchangeLinking),
        onboardingSettings: BlockchainSettings.Onboarding = .shared,
        analyticsRecorder: AnalyticsEventRecording = resolve()
    ) {
        self.view = view
        self.wallet = wallet
        self.walletService = walletService
        self.reactiveWallet = reactiveWallet
        self.exchangeConfiguration = exchangeConfiguration
        self.introInterator = WalletIntroductionInteractor(onboardingSettings: onboardingSettings, screen: .sideMenu)
        self.analyticsRecorder = analyticsRecorder
        self.featureFetcher = featureFetcher
    }

    deinit {
        disposable?.dispose()
        disposable = nil
    }

    func loadSideMenu() {
        let startingLocation = introInterator.startingLocation
            .map { [weak self] location -> [WalletIntroductionEvent] in
                self?.startingWithLocation(location) ?? []
            }
            .catchErrorJustReturn([])
        
        startingLocation
            .subscribe(onSuccess: { [weak self] events in
                guard let self = self else { return }
                self.execute(events: events)
                }, onError: { [weak self] error in
                    guard let self = self else { return }
                    self.introductionRelay.accept(.none)
            })
            .disposed(by: disposeBag)
    }
    
    /// The only reason this is here is for handling the pulse that
    /// is displayed on `buyBitcoin`.
    func onItemSelection(_ item: SideMenuItem) {
        itemSelectionRelay.accept(item)
    }
    
    private func startingWithLocation(_ location: WalletIntroductionLocation) -> [WalletIntroductionEvent] {
        let screen = location.screen
        guard screen == .sideMenu else { return [] }
        return []
    }
    
    private func triggerNextStep() {
        guard let next = introductionSequence.next() else {
            introductionRelay.accept(.none)
            return
        }
        /// We track all introduction events that have an analyticsKey.
        /// This happens on presentation.
        if let trackable = next as? WalletIntroductionAnalyticsEvent {
            analyticsRecorder.record(event: trackable.eventType)
        }
        introductionRelay.accept(next.type)
    }
    
    private func execute(events: [WalletIntroductionEvent]) {
        introductionSequence.reset(to: events)
        triggerNextStep()
    }

    private func menuItems(showSimpleBuy: Bool) -> [SideMenuItem] {
        var items: [SideMenuItem] = [.accountsAndAddresses]
        
        if wallet.isLockboxEnabled() {
            items.append(.lockbox)
        }

        if wallet.isInitialized() {
            if wallet.didUpgradeToHd() {
                items.append(.backup)
            } else {
                items.append(.upgrade)
            }
        }

        if showSimpleBuy {
            items.append(contentsOf: [.buy, .sell])
        }

        items += [.support, .airdrops, .settings]
        
        if exchangeConfiguration.isEnabled {
            items.append(.exchange)
        }
        
        return items
    }
}
