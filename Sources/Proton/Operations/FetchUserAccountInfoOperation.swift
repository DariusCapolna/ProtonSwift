//
//  FetchUserAccountInfoOperation.swift
//  Proton
//
//  Created by Jacob Davis on 3/18/20.
//  Copyright © 2020 Needly, Inc. All rights reserved.
//

import EOSIO
import Foundation

class FetchUserAccountInfoOperation: AbstractOperation {

    var account: Account
    var chainProvider: ChainProvider

    init(account: Account, chainProvider: ChainProvider) {
        self.account = account
        self.chainProvider = chainProvider
    }

    override func main() {

        guard let url = URL(string: chainProvider.chainUrl) else {
            self.finish(retval: nil, error: ProtonError.error("MESSAGE => Missing chainProvider url"))
            return
        }

        let client = Client(address: url)
        var req = API.V1.Chain.GetTableRows<UserInfoABI>(code: Name(stringValue: "eosio.proton"),
                                                         table: Name(stringValue: "usersinfo"),
                                                         scope: "eosio.proton")
        req.lowerBound = account.name.stringValue
        req.upperBound = account.name.stringValue

        do {

            let res = try client.sendSync(req).get()

            if let userInfo = res.rows.first {
                account.base64Avatar = userInfo.avatar
                account.nickName = userInfo.name
                account.verified = userInfo.verified
            }

            finish(retval: account, error: nil)

        } catch {
            finish(retval: nil, error: ProtonError.chain("RPC => \(API.V1.Chain.GetTableRows<UserInfoABI>.path)\nERROR => \(error.localizedDescription)"))
        }

    }

}
