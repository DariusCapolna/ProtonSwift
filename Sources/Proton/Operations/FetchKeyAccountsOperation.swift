//
//  FetchKeyAccountsOperation.swift
//  Proton
//
//  Created by Jacob Davis on 3/18/20.
//  Copyright © 2020 Needly, Inc. All rights reserved.
//

import Foundation

class FetchKeyAccountsOperation: AbstractOperation {
    
    var publicKey: String
    var chainProvider: ChainProvider
    
    init(publicKey: String, chainProvider: ChainProvider) {
        self.publicKey = publicKey
        self.chainProvider = chainProvider
    }
    
    override func main() {
        
        let path = "\(chainProvider.stateHistoryUrl)/v2/state/get_key_accounts?public_key=\(self.publicKey)"
        
        WebServices.shared.getRequest(withPath: path) { (result: Result<[String: [String]], Error>) in
            
            var accountNames = Set<String>()
            
            switch result {
            case .success(let res):
                
                if let names = res["account_names"] {
                    
                    for name in names {
                        if !name.contains(".") {
                            accountNames.update(with: name)
                        }
                    }
                    
                }
                
                if accountNames.count > 0 {
                    self.finish(retval: accountNames, error: nil)
                } else {
                    self.finish(retval: nil, error: WebServiceError.error("No Accounts found"))
                }
                
            case .failure(let error):
                
                self.finish(retval: nil, error: WebServiceError.error("Error fetching accounts: \(error.localizedDescription)"))
                
            }
            
        }
        
    }
    
}
