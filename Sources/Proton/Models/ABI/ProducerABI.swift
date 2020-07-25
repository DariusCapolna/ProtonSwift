//
//  ProducerABI.swift
//  Proton
//
//  Created by Jacob Davis on 7/24/20.
//  Copyright (c) 2020 Proton Chain LLC, Delaware
//

import EOSIO
import Foundation

struct ProducerABI: Codable {

    let owner: Name
    let total_votes: Float64
//    let is_active: Bool
//    let url: String

}
