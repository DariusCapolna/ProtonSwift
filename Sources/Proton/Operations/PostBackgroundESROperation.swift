//
//  PostBackgroundESROperation.swift
//  Proton
//
//  Created by Jacob Davis on 4/20/20.
//  Copyright (c) 2020 Proton Chain LLC, Delaware
//

import EOSIO
import Foundation
import WebOperations

class PostBackgroundESROperation: BaseOperation {
    
    var esr: ESR
    var sig: Signature
    var blockNum: BlockNum?
    
    init(esr: ESR, sig: Signature, blockNum: BlockNum?) {
        self.esr = esr
        self.sig = sig
        self.blockNum = blockNum
    }
    
    override func main() {
        
        super.main()
        
        guard let resolved = self.esr.resolved else {
            self.finish(retval: nil, error: ProtonError.esr("MESSAGE => Issue getting resolved esr\nESR => \(esr.signingRequest)\nSIG => \(sig.stringValue)"))
            return
        }
        guard let callback = resolved.getCallback(using: [self.sig], blockNum: self.blockNum) else {
            self.finish(retval: nil, error: ProtonError.esr("MESSAGE => Issue getting esr callback\nESR => \(esr.signingRequest)\nSIG => \(sig.stringValue)"))
            return
        }
        
        do {
            
            let payloadData = try callback.getPayload(extra: ["sid": self.esr.sid])
            
            guard let parameters = try JSONSerialization.jsonObject(with: payloadData, options: []) as? [String: Any] else {
                self.finish(retval: nil, error: ProtonError.esr("MESSAGE => Issue getting payload data\nESR => \(esr.signingRequest)\nSIG => \(sig.stringValue)"))
                return
            }
            
            guard let url = URL(string: callback.url) else {
                self.finish(retval: nil, error: ProtonError.error("MESSAGE => Unable to form proper url for ESR callback"))
                return
            }
            
            WebOperations.shared.request(method: WebOperations.RequestMethod.post, url: url, parameters: parameters) { result in
                
                switch result {
                case .success:
                    self.finish(retval: nil, error: nil)
                case .failure(let error):
                    self.finish(retval: nil, error: ProtonError.esr("MESSAGE => Issue posting callback\nESR => \(self.esr.signingRequest)\nSIG => \(self.sig.stringValue)\nERROR => \(error.localizedDescription)"))
                }
                
            }
            
        } catch {
            self.finish(retval: nil, error: ProtonError.esr("MESSAGE => Issue posting callback\nESR => \(esr.signingRequest)\nSIG => \(sig.stringValue)\nERROR => \(error.localizedDescription)"))
        }
        
    }
    
}
