//
//  YodleeScreenViewController.swift
//  BuySellUIKit
//
//  Created by Dimitrios Chatzieleftheriou on 11/12/2020.
//  Copyright © 2020 Blockchain Luxembourg S.A. All rights reserved.
//

import PlatformUIKit
import RIBs
import RxCocoa
import RxSwift
import UIKit
import WebKit

final class YodleeScreenViewController: BaseScreenViewController,
                                        YodleeScreenPresentable,
                                        YodleeScreenViewControllable {

    private let disposeBag = DisposeBag()
    private let closeTriggerred = PublishSubject<Void>()

    private let webview: WKWebView
    private let pendingView: YodleePendingView

    init(webConfiguration: WKWebViewConfiguration) {
        self.webview = WKWebView(frame: .zero, configuration: webConfiguration)
        self.pendingView = YodleePendingView()
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white

        setupUI()
    }

    override func navigationBarTrailingButtonPressed() {
        closeTriggerred.onNext(())
    }

    // MARK: - YodleeScreenPresentable

    func connect(action: Driver<YodleeScreen.Action>) -> Driver<YodleeScreen.Effect> {

        let requestAction = action
            .compactMap(\.request)

        let contentAction = action
            .compactMap(\.content)
            .distinctUntilChanged()

        requestAction
            .drive(weak: self) { (self, request) in
                self.webview.load(request)
            }
            .disposed(by: disposeBag)

        contentAction
            .drive(pendingView.rx.content)
            .disposed(by: disposeBag)

        contentAction
            .drive(weak: self) { (self, content) in
                self.toggle(visibility: true, of: self.pendingView)
                self.toggle(visibility: false, of: self.webview)
            }
            .disposed(by: disposeBag)

        webview.rx.observeWeakly(Bool.self, "loading", options: [.new])
            .compactMap { $0 }
            .observeOn(MainScheduler.asyncInstance)
            .subscribe(onNext: { [weak self] (loading) in
                guard let self = self else { return }
                self.toggle(visibility: loading, of: self.pendingView)
                self.toggle(visibility: !loading, of: self.webview)
            })
            .disposed(by: disposeBag)

        let closeTapped = closeTriggerred
            .map { _ in YodleeScreen.Effect.closeFlow }
            .asDriverCatchError()

        return .merge(closeTapped)
    }

    // MARK: - Private

    private func setupUI() {
        set(barStyle: .darkContent(),
            leadingButtonStyle: .none,
            trailingButtonStyle: .close)

        view.addSubview(webview)
        view.addSubview(pendingView)

        webview.layoutToSuperview(axis: .vertical)
        webview.layoutToSuperview(axis: .horizontal)
        pendingView.layoutToSuperview(.top)
        pendingView.layoutToSuperview(.leading)
        pendingView.layoutToSuperview(.trailing)
        pendingView.layoutToSuperview(.bottom)

    }

    private func toggle(visibility: Bool, of view: UIView) {
        let alpha: CGFloat = visibility ? 1.0 : 0.0
        let hidden = !visibility
        UIView.animate(
            withDuration: 0.2,
            animations: {
                view.alpha = alpha
            },
            completion: { completed in
                view.isHidden = hidden
            }
        )
    }
}
