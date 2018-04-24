//
//  BlockchainAPI+URL.swift
//  Blockchain
//
//  Created by Maurice A. on 4/23/18.
//  Copyright © 2018 Blockchain Luxembourg S.A. All rights reserved.
//

import Foundation

@objc
extension BlockchainAPI {
    var apiUrl: String? {
        guard let host = Bundle.main.infoDictionary!["API_URL"] as? String else {
            return nil
        }
        return "https://\(host)"
    }
    var walletUrl: String? {
        guard let host = Bundle.main.infoDictionary!["WALLET_SERVER"] as? String else {
            return nil
        }
        return "https://\(host)"
    }
    var buyWebViewUrl: String? {
        guard let hostAndPath = Bundle.main.infoDictionary!["BUY_WEBVIEW_URL"] as? String else {
            return nil
        }
        return "https://\(hostAndPath)"
    }
    var blockchairUrl: String {
        return "https://\(PartnerEndpoints.blockchair.rawValue)"
    }
    var blockchairBchTransactionUrl: String {
        return  "\(blockchairUrl)/bitcoin-cash/transaction/"
    }
    var etherscanUrl: String {
        return "https://\(PartnerEndpoints.etherscan.rawValue)"
    }
}
