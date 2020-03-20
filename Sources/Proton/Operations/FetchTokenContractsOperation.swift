//
//  FetchTokenContractsOperation.swift
//  Proton
//
//  Created by Jacob Davis on 3/18/20.
//  Copyright © 2020 Needly, Inc. All rights reserved.
//

import Foundation

class FetchTokenContractsOperation: AbstractOperation {
    
    override func main() {
        
        guard let path = Proton.config?.tokenContractsUrl else {
            fatalError("Must provider chainProvidersUrl in ProtonWalletManager config")
        }
        
        WebServices.shared.getRequest(withPath: path) { (result: Result<[String: TokenContract], Error>) in
            
            switch result {
            case .success(let tokenContracts):
                
                var retval = Set<TokenContract>()
                
                if tokenContracts.count > 0 {
                    for tokenContract in tokenContracts {
                        retval.update(with: tokenContract.value)
                    }
                }
                
                self.finish(retval: retval, error: nil)
                
            case .failure(let error):
                self.finish(retval: nil, error: WebServiceError.error("Error fetching token contracts: \(error.localizedDescription)"))
            }
            
        }

    }
    
}
