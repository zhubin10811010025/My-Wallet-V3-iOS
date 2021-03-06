//
//  BitcoinWalletAccount.swift
//  BitcoinKit
//
//  Created by Jack on 05/08/2019.
//  Copyright © 2019 Blockchain Luxembourg S.A. All rights reserved.
//

import PlatformKit

public struct BitcoinWalletAccount: WalletAccount, Codable, Hashable {

    public let index: Int

    public let publicKey: String

    public var label: String?

    public var archived: Bool

    public init(index: Int,
                publicKey: String,
                label: String?,
                archived: Bool) {
        self.index = index
        self.publicKey = publicKey
        self.label = label
        self.archived = archived
    }
}
