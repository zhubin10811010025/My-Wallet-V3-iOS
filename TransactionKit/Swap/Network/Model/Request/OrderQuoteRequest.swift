//
//  OrderQuoteRequest.swift
//  TransactionKit
//
//  Created by Alex McGregor on 10/13/20.
//  Copyright © 2020 Blockchain Luxembourg S.A. All rights reserved.
//

struct OrderQuoteRequest: Encodable {
    let product: Product
    let direction: OrderDirection
    let pair: OrderPair
    
    enum CodingKeys: CodingKey {
        case product
        case direction
        case pair
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(product, forKey: .product)
        try container.encode(direction, forKey: .direction)
        try container.encode(pair.rawValue, forKey: .pair)
    }
}
