//
//  Proton.swift
//  Proton
//
//  Created by Jacob Davis on 4/20/20.
//  Copyright (c) 2020 Proton Chain LLC, Delaware
//

import EOSIO
import secp256k1
import Foundation
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif
import KeychainAccess
import WebOperations

/**
 The Proton class is the heart of the ProtonSwift SDK.
 */
public class Proton {
    
    /**
     The proton config object which is a required param for initialisation of Proton
    */
    public struct Config {
        
        public enum Environment: String {
            case testnet = "https://api-dev.protonchain.com"
            case mainnet = "https://api.protonchain.com"
        }
        
        /// The base url used for api requests to proton sdk api's
        public var baseUrl: String
        
        /**
         Use this function as your starting point to initialize the singleton class Proton
         - Parameter baseUrl: The base url used for api requests to proton sdk api's
         */
        public init(baseUrl: String = Environment.testnet.rawValue) {
            self.baseUrl = baseUrl
        }
        
        /**
         Use this function as your starting point to initialize the singleton class Proton
         - Parameter environment: The environment used for api requests to proton sdk api's
         */
        public init(environment: Environment = Environment.testnet) {
            self.baseUrl = environment.rawValue
        }
        
    }
    
    /**
     Proton typealias of the EOSIO.Name
    */
    public typealias Name = EOSIO.Name
    
    /**
     Proton typealias of the EOSIO.PrivateKey
    */
    public typealias PrivateKey = EOSIO.PrivateKey
    
    /**
     The proton config which gets set during initialisation
    */
    public static var config: Config?
    
    /**
     Use this function as your starting point to initialize the singleton class Proton
     - Parameter config: The configuration object that includes urls for chainProviders
     - Returns: Initialized Proton singleton
     */
    @discardableResult
    public static func initialize(_ config: Config) -> Proton {
        Proton.config = config
        return self.shared
    }
    
    /**
     The shared instance of the Proton class.
     Use this for accessing functionality after initialisation of Proton
    */
    public static let shared = Proton()
    
    /**
     Internal pointer to various storage structures
    */
    var storage: Persistence!
    
    static let operationQueueSeq = "proton.swift.seq"
    static let operationQueueMulti = "proton.swift.multi"
    
    /**
     Private init
     */
    private init() {
        
        guard let _ = Proton.config else {
            fatalError("ERROR: You must call setup before accessing Proton.shared")
        }
        
        let operationQueueSeq = OperationQueue()
        operationQueueSeq.qualityOfService = .utility
        operationQueueSeq.maxConcurrentOperationCount = 1
        
        let operationQueueMulti = OperationQueue()
        operationQueueMulti.qualityOfService = .utility
        
        WebOperations.shared.addCustomQueue(operationQueueSeq, forKey: Proton.operationQueueSeq)
        WebOperations.shared.addCustomQueue(operationQueueMulti, forKey: Proton.operationQueueMulti)
        
        self.storage = Persistence()
        
        self.loadAll()
        
        print("🧑‍💻 LOAD COMPLETED")
        print("ACTIVE ACCOUNT => \(String(describing: self.account?.name.stringValue))")
        print("TOKEN CONTRACTS => \(self.tokenContracts.count)")
        print("TOKEN BALANCES => \(self.tokenBalances.count)")
        print("TOKEN TRANSFER ACTIONS => \(self.tokenTransferActions.count)")
        print("ESR SESSIONS => \(self.esrSessions.count)")
        
    }
    
    /**
     Data object container notifcation names. Use these to subscribe to changes via NotificationCenter.default
    */
    public enum Notifications {
        /// Use this notification name to be notified right before chainProviders are updated.
        public static let chainProviderWillSet = Notification.Name("chainProviderWillSet")
        /// Use this notification name to be notified after chainProviders are updated.
        public static let chainProviderDidSet = Notification.Name("chainProviderDidSet")
        /// Use this notification name to be notified right before tokenContracts are updated.
        public static let tokenContractsWillSet = Notification.Name("tokenContractsWillSet")
        /// Use this notification name to be notified after tokenContracts are updated.
        public static let tokenContractsDidSet = Notification.Name("tokenContractsDidSet")
        /// Use this notification name to be notified right before tokenBalances are updated
        public static let tokenBalancesWillSet = Notification.Name("tokenBalancesWillSet")
        /// Use this notification name to be notified after tokenBalances are updated.
        public static let tokenBalancesDidSet = Notification.Name("tokenBalancesDidSet")
        /// Use this notification name to be notified right before tokenTransferActions are updated
        public static let tokenTransferActionsWillSet = Notification.Name("tokenTransferActionsWillSet")
        /// Use this notification name to be notified after tokenTransferActions are updated.
        public static let tokenTransferActionsDidSet = Notification.Name("tokenTransferActionsDidSet")
        /// Use this notification name to be notified right before contacts are updated
        public static let contactsWillSet = Notification.Name("contactsWillSet")
        /// Use this notification name to be notified after contacts are updated.
        public static let contactsDidSet = Notification.Name("contactsDidSet")
        /// Use this notification name to be notified right before esrSessions are updated
        public static let esrSessionsWillSet = Notification.Name("esrSessionsWillSet")
        /// Use this notification name to be notified after esrSessions are updated.
        public static let esrSessionsDidSet = Notification.Name("esrSessionsDidSet")
        /// Use this notification name to be notified right before the active esr is updated
        public static let esrWillSet = Notification.Name("esrWillSet")
        /// Use this notification name to be notified after the active esr is updated.
        public static let esrDidSet = Notification.Name("esrDidSet")
        /// Use this notification name to be notified right before the active acount is set
        public static let accountWillSet = Notification.Name("accountWillSet")
        /// Use this notification name to be notified right after the active acount is set
        public static let accountDidSet = Notification.Name("accountDidSet")
        /// Use this notification name to be notified right after the active acount is updated
        public static let accountDidUpdate = Notification.Name("accountDidUpdate")
    }
    
    // MARK: - Data Containers
    
    /**
     Live updated chainProvider. You can observe changes via NotificaitonCenter: chainProviderWillSet, chainProviderDidSet
     */
    public var chainProvider: ChainProvider? = nil {
        willSet {
            NotificationCenter.default.post(name: Notifications.chainProviderWillSet, object: nil,
                                            userInfo: newValue != nil ? ["newValue": newValue!] : nil)
        }
        didSet {
            NotificationCenter.default.post(name: Notifications.chainProviderDidSet, object: nil)
        }
    }

    /**
     Live updated array of tokenContracts. You can observe changes via NotificaitonCenter: tokenContractsWillSet, tokenContractsDidSet
     */
    public var tokenContracts: [TokenContract] = [] {
        willSet {
            NotificationCenter.default.post(name: Notifications.tokenContractsWillSet, object: nil,
                                            userInfo: ["newValue": newValue])
        }
        didSet {
            NotificationCenter.default.post(name: Notifications.tokenContractsDidSet, object: nil)
        }
    }
    
    /**
     Live updated array of tokenBalances. You can observe changes via NotificaitonCenter: tokenBalancesWillSet, tokenBalancesDidSet
     */
    public var tokenBalances: [TokenBalance] = [] {
        willSet {
            NotificationCenter.default.post(name: Notifications.tokenBalancesWillSet, object: nil,
                                            userInfo: ["newValue": newValue])
        }
        didSet {
            NotificationCenter.default.post(name: Notifications.tokenBalancesDidSet, object: nil)
        }
    }
    
    /**
     Live updated array of tokenTransferActions. You can observe changes via NotificaitonCenter: tokenTransferActionsWillSet, tokenTransferActionsDidSet
     */
    public var tokenTransferActions: [TokenTransferAction] = [] {
        willSet {
            NotificationCenter.default.post(name: Notifications.tokenTransferActionsWillSet, object: nil,
                                            userInfo: ["newValue": newValue])
        }
        didSet {
            NotificationCenter.default.post(name: Notifications.tokenTransferActionsDidSet, object: nil)
        }
    }
    
    /**
     Live updated array of contacts. You can observe changes via NotificaitonCenter: contactsWillSet, contactsDidSet
     */
    public var contacts: [Contact] = [] {
        willSet {
            NotificationCenter.default.post(name: Notifications.contactsWillSet, object: nil,
                                            userInfo: ["newValue": newValue])
        }
        didSet {
            NotificationCenter.default.post(name: Notifications.contactsDidSet, object: nil)
        }
    }
    
    /**
     Live updated array of esrSessions. You can observe changes via NotificaitonCenter: esrSessionsWillSet, esrSessionsDidSet
     */
    public var esrSessions: [ESRSession] = [] {
        willSet {
            NotificationCenter.default.post(name: Notifications.esrSessionsWillSet, object: nil,
                                            userInfo: ["newValue": newValue])
        }
        didSet {
            NotificationCenter.default.post(name: Notifications.esrSessionsDidSet, object: nil)
        }
    }
    
    /**
     Live updated esr. You can observe changes via NotificaitonCenter: esrWillSet, esrDidSet
     */
    public var esr: ESR? = nil {
        willSet {
            NotificationCenter.default.post(name: Notifications.esrWillSet, object: nil,
                                            userInfo: newValue != nil ? ["newValue": newValue!] : nil)
        }
        didSet {
            NotificationCenter.default.post(name: Notifications.esrDidSet, object: nil)
        }
    }
    
    /**
     Live updated array of accounts. You can observe changes via NotificaitonCenter: accountsWillSet, accountsDidSet
     */
    public var account: Account? = nil {
        willSet {
            NotificationCenter.default.post(name: Notifications.accountWillSet, object: nil,
                                            userInfo: newValue != nil ? ["newValue": newValue!] : nil)
        }
        didSet {
            NotificationCenter.default.post(name: Notifications.accountDidSet, object: nil)
        }
    }
    
    // MARK: - Data Functions
    
    /**
     Loads all data objects from disk into memory
     */
    public func loadAll() {

        self.account = Account.create(dictionary: self.storage.getDefaultsItem(forKey: "account"))
        self.chainProvider = self.storage.getDefaultsItem(ChainProvider.self, forKey: "chainProvider") ?? nil
        self.tokenContracts = self.storage.getDefaultsItem([TokenContract].self, forKey: "tokenContracts") ?? []
        self.tokenBalances = self.storage.getDefaultsItem([TokenBalance].self, forKey: "tokenBalances") ?? []
        self.tokenTransferActions = self.storage.getDefaultsItem([TokenTransferAction].self, forKey: "tokenTransferActions") ?? []
        self.esrSessions = self.storage.getDefaultsItem([ESRSession].self, forKey: "esrSessions") ?? []
        
    }
    
    /**
     Saves all current data objects that are in memory to disk
     */
    public func saveAll() {
        
        self.storage.setDefaultsItem(self.account, forKey: "account")
        self.storage.setDefaultsItem(self.chainProvider, forKey: "chainProvider")
        self.storage.setDefaultsItem(self.tokenContracts, forKey: "tokenContracts")
        self.storage.setDefaultsItem(self.tokenBalances, forKey: "tokenBalances")
        self.storage.setDefaultsItem(self.tokenTransferActions, forKey: "tokenTransferActions")
        self.storage.setDefaultsItem(self.esrSessions, forKey: "esrSessions")
        
    }
    
    /**
     Sets the active account, fetchs and updates. This includes, account names, avatars, balances, etc
      Use this for switching accounts when you know the private key has already been stored.
     - Parameter forAccountName: Proton account name not including @
     - Parameter chainId: chainId for the account
     - Parameter completion: Closure returning Result
     */
    public func setAccount(forAccountName accountName: String, chainId: String,
                           completion: @escaping ((Result<Account, Error>) -> Void)) {
        
        self.setAccount(Account(chainId: chainId, name: accountName)) { result in
            switch result {
            case .success(let account):
                completion(.success(account))
            case .failure(let error):
                completion(.failure(error))
            }
        }
        
    }
    
    /**
     Fetchs all required data objects from external data sources. This should be done at startup
     - Parameter completion: Closure returning Result
     */
    public func fetchRequirements(completion: @escaping ((Result<Bool, Error>) -> Void)) {
        
        WebOperations.shared.add(FetchChainProviderOperation(), toCustomQueueNamed: Proton.operationQueueSeq) { result in
            
            switch result {
                
            case .success(let chainProvider):
                
                if let chainProvider = chainProvider as? ChainProvider {
                    self.chainProvider = chainProvider
                    
                    let tokenContracts = chainProvider.tokenContracts
                    
                    WebOperations.shared.add(FetchTokenContractsOperation(chainProvider: chainProvider, tokenContracts: tokenContracts),
                                             toCustomQueueNamed: Proton.operationQueueSeq) { result in
                        
                        switch result {
                            
                        case .success(let tokenContracts):
                            
                            if let tokenContracts = tokenContracts as? [TokenContract] {
                                
                                for var tokenContract in tokenContracts {
                                    if let idx = self.tokenContracts.firstIndex(of: tokenContract) {
                                        tokenContract.rates = self.tokenContracts[idx].rates
                                        self.tokenContracts[idx] = tokenContract
                                    } else {
                                        self.tokenContracts.append(tokenContract)
                                    }
                                }
                                
                            }
                            
                        case .failure: break
                        }
                        
                        self.updateExchangeRates { _ in }
                        
                        completion(.success(true))
                        
                    }
                    
                }
                
            case .failure(let error):
                completion(.failure(error))
            }
            
        }
        
    }
    
    /**
     Updates all TokenContract data objects with latest exchange rates from external data sources.
     - Parameter completion: Closure returning Result
     */
    public func updateExchangeRates(completion: @escaping ((Result<Bool, Error>) -> Void)) {
        
        guard let chainProvider = self.chainProvider else {
            completion(.failure(ProtonError.error("MESSAGE => Missing ChainProvider")))
            return
        }
        
        WebOperations.shared.add(FetchExchangeRatesOperation(chainProvider: chainProvider),
                                 toCustomQueueNamed: Proton.operationQueueMulti) { result in
            
            switch result {
                
            case .success(let tokens):
                
                if let tokens = tokens as? [[String: Any]] {
                    
                    for token in tokens {
                        
                        guard let contract = token["contract"] as? String else { return }
                        guard let symbol = token["symbol"] as? String else { return }
                        guard let rates = token["rates"] as? [String: Double] else { return }
                        if let idx = self.tokenContracts.firstIndex(where: { $0.id == "\(contract):\(symbol)" }) {
                            self.tokenContracts[idx].rates = rates
                        }
                        
                    }
                    
                }
                
            case .failure: break
            }
            
            completion(.success(true))
            
        }
        
    }
    
    /**
     Fetchs and updates the active account. This includes, account names, avatars, balances, etc
     - Parameter completion: Closure returning Result
     */
    public func updateAccount(completion: @escaping ((Result<Account, Error>) -> Void)) {
        
        guard var account = self.account else {
            completion(.failure(ProtonError.error("MESSAGE => No active account")))
            return
        }
        
        self.updateExchangeRates { _ in }
        
        self.fetchAccount(account) { result in
            
            switch result {
            case .success(let returnAccount):
                
                account = returnAccount
                self.account = account
                NotificationCenter.default.post(name: Notifications.accountDidUpdate, object: nil)
                
                self.fetchAccountUserInfo(forAccount: account) { result in
                    
                    switch result {
                    case .success(let returnAccount):
                        
                        account = returnAccount
                        self.account = account
                        NotificationCenter.default.post(name: Notifications.accountDidUpdate, object: nil)
                        
                        self.fetchBalances(forAccount: account) { result in
                            
                            switch result {
                            case .success(let tokenBalances):
                                
                                for tokenBalance in tokenBalances {
                                    if let idx = self.tokenBalances.firstIndex(of: tokenBalance) {
                                        self.tokenBalances[idx] = tokenBalance
                                    } else {
                                        self.tokenBalances.append(tokenBalance)
                                    }
                                }
                                
                                let tokenBalancesCount = self.tokenBalances.count
                                var tokenBalancesProcessed = 0
                                
                                if tokenBalancesCount > 0 {
                                    
                                    for tokenBalance in self.tokenBalances {
                                        
                                        self.fetchTransferActions(forTokenBalance: tokenBalance) { result in
                                            
                                            tokenBalancesProcessed += 1
                                            
                                            switch result {
                                            case .success(let transferActions):
                                                
                                                for transferAction in transferActions {
                                                    
                                                    if let idx = self.tokenTransferActions.firstIndex(of: transferAction) {
                                                        self.tokenTransferActions[idx] = transferAction
                                                    } else {
                                                        self.tokenTransferActions.append(transferAction)
                                                    }
                                                    
                                                }

                                            case .failure: break
                                            }
                                            
                                            if tokenBalancesProcessed == tokenBalancesCount {

                                                self.fetchContacts(forAccount: account) { result in
                                                    
                                                    switch result {
                                                    case .success(let contacts):
                                                        
                                                        for contact in contacts {
                                                            if let idx = self.contacts.firstIndex(of: contact) {
                                                                self.contacts[idx] = contact
                                                            } else {
                                                                self.contacts.append(contact)
                                                            }
                                                        }
                                                        
                                                    case .failure: break
                                                    }

                                                    completion(.success(account))
                                                    self.saveAll()
                                                    NotificationCenter.default.post(name: Notifications.accountDidUpdate, object: nil)
                                                     
                                                    print("🧑‍💻 UPDATE COMPLETED")
                                                    print("ACCOUNT => \(String(describing: self.account?.name))")
                                                    print("TOKEN CONTRACTS => \(self.tokenContracts.count)")
                                                    print("TOKEN BALANCES => \(self.tokenBalances.count)")
                                                    print("TOKEN TRANSFER ACTIONS => \(self.tokenTransferActions.count)")
                                                    print("CONTACTS => \(self.contacts.count)")
                                                    print("ESR SESSIONS => \(self.esrSessions.count)")
                                                    
                                                }

                                            }

                                        }
                                        
                                    }
                                    
                                } else {
                                    completion(.failure(ProtonError.error("MESSAGE => No TokenBalances found for account: \(account.name)")))
                                }
                                
                            case .failure(let error):
                                completion(.failure(error))
                            }

                        }
                        
                    case .failure(let error):
                        completion(.failure(error))
                    }
                    
                }
                
            case .failure(let error):
                completion(.failure(error))
            }

        }
        
    }
    
    /**
     Changes the account's userdefined name on chain
     - Parameter userDefinedName: New user defined name
     - Parameter completion: Closure returning Result
     */
    public func updateAccountUserDefinedName(userDefinedName: String, completion: @escaping ((Result<Account, Error>) -> Void)) {
        
        guard var account = self.account else {
            completion(.failure(ProtonError.error("MESSAGE => No active account")))
            return
        }
        
        guard let chainProvider = self.account?.chainProvider else {
            completion(.failure(ProtonError.error("MESSAGE => Unable to find chain provider")))
            return
        }
        
        signforAccountUpdate { result in
            
            switch result {
            case .success(let signature):
                
                WebOperations.shared.add(UpdateUserAccountNameOperation(account: account, chainProvider: chainProvider, signature: signature.stringValue, userDefinedName: userDefinedName), toCustomQueueNamed: Proton.operationQueueSeq) { result in
                    
                    switch result {
                    case .success:
                        
                        self.fetchAccountUserInfo(forAccount: account) { result in
                            switch result {
                            case .success(let returnAccount):
                                account = returnAccount
                                self.account = account
                                NotificationCenter.default.post(name: Notifications.accountDidUpdate, object: nil)
                                completion(.success(account))
                            case .failure(let error):
                                completion(.failure(error))
                            }
                        }

                    case .failure(let error):
                        completion(.failure(error))
                    }
                    
                }
                
            case .failure(let error):
                completion(.failure(error))
            }
            
        }
        
    }
    
    /**
     Changes the account's avatar on chain
     - Parameter image: AvatarImage which is platform dependent alias. UIImage for iOS, NSImage for macOS
     - Parameter completion: Closure returning Result
     */
    public func updateAccountAvatar(image: AvatarImage, completion: @escaping ((Result<Account, Error>) -> Void)) {
        
        guard var account = self.account else {
            completion(.failure(ProtonError.error("MESSAGE => No active account")))
            return
        }
        
        guard let chainProvider = account.chainProvider else {
            completion(.failure(ProtonError.error("MESSAGE => Unable to find chain provider")))
            return
        }
        
        signforAccountUpdate { result in
            
            switch result {
            case .success(let signature):
                
                WebOperations.shared.add(UpdateUserAccountAvatarOperation(account: account, chainProvider: chainProvider, signature: signature.stringValue, image: image), toCustomQueueNamed: Proton.operationQueueSeq) { result in
                    
                    switch result {
                    case .success:
                        
                        self.fetchAccountUserInfo(forAccount: account) { result in
                            switch result {
                            case .success(let returnAccount):
                                account = returnAccount
                                self.account = account
                                NotificationCenter.default.post(name: Notifications.accountDidUpdate, object: nil)
                                completion(.success(account))
                            case .failure(let error):
                                completion(.failure(error))
                            }
                        }

                    case .failure(let error):
                        completion(.failure(error))
                    }
                    
                }
                
            case .failure(let error):
                completion(.failure(error))
            }
            
        }
        
    }
    
    /**
     Changes the account's userdefined name and avatar on chain
     - Parameter userDefinedName: New user defined name
     - Parameter completion: Closure returning Result
     */
    public func updateAccountUserDefinedNameAndAvatar(userDefinedName: String, image: AvatarImage, completion: @escaping ((Result<Account, Error>) -> Void)) {
        
        guard var account = self.account else {
            completion(.failure(ProtonError.error("MESSAGE => No active account")))
            return
        }
        
        guard let chainProvider = self.account?.chainProvider else {
            completion(.failure(ProtonError.error("MESSAGE => Unable to find chain provider")))
            return
        }
        
        signforAccountUpdate { result in
            
            switch result {
            case .success(let signature):
                
                WebOperations.shared.add(UpdateUserAccountNameOperation(account: account, chainProvider: chainProvider, signature: signature.stringValue, userDefinedName: userDefinedName), toCustomQueueNamed: Proton.operationQueueSeq) { result in
                    
                    switch result {
                    case .success:
                        
                        WebOperations.shared.add(UpdateUserAccountAvatarOperation(account: account, chainProvider: chainProvider, signature: signature.stringValue, image: image), toCustomQueueNamed: Proton.operationQueueSeq) { result in
                            
                            switch result {
                            case .success:
                                
                                self.fetchAccountUserInfo(forAccount: account) { result in
                                    switch result {
                                    case .success(let returnAccount):
                                        account = returnAccount
                                        self.account = account
                                        NotificationCenter.default.post(name: Notifications.accountDidUpdate, object: nil)
                                        completion(.success(account))
                                    case .failure(let error):
                                        completion(.failure(error))
                                    }
                                }

                            case .failure(let error):
                                completion(.failure(error))
                            }
                            
                        }

                    case .failure(let error):
                        completion(.failure(error))
                    }
                    
                }
                
            case .failure(let error):
                completion(.failure(error))
            }
            
        }
        
    }
    
    /**
     Use this function to store the private key and set the account after finding the account you want to save via findAccounts
     - Parameter privateKey: Wif formated private key
     - Parameter forAccount: Account object, normally retrieved via findAccounts
     - Parameter completion: Closure returning Result
     */
    public func storePrivateKey(privateKey: String, forAccount account: Account, completion: @escaping ((Result<Account, Error>) -> Void)) {
        
        do {
            
            let pk = try PrivateKey(stringValue: privateKey)
            let publicKey = try pk.getPublic()
            
            if account.isKeyAssociated(publicKey: publicKey.stringValue) {
                
                self.storage.setKeychainItem(privateKey, forKey: publicKey.stringValue) { result in
                    
                    switch result {
                    case .success:
                        self.setAccount(account) { result in
                            switch result {
                            case .success(let account):
                                completion(.success(account))
                            case .failure(let error):
                                completion(.failure(error))
                            }
                        }
                    case .failure(let error):
                        completion(.failure(error))
                    }
                    
                }

            } else {
                completion(.failure(ProtonError.error("MESSAGE => Key not associated with Account")))
            }

        } catch {
            completion(.failure(ProtonError.error(error.localizedDescription)))
        }
        
    }
    
    /**
     Use this function to obtain a list of Accounts which match a given private key. These accounts are not stored. If you want to store the Account and private key, you should then call storePrivateKey function
     - Parameter forPrivateKey: Wif formated private key
     - Parameter completion: Closure returning Result
     */
    public func findAccounts(forPrivateKey privateKey: String, completion: @escaping ((Result<Set<Account>, Error>) -> Void)) {
        
        do {
            
            let pk = try PrivateKey(stringValue: privateKey)
            let publicKey = try pk.getPublic()
            
            findAccounts(forPublicKey: publicKey.stringValue) { result in
                switch result {
                case .success(let accounts):
                    completion(.success(accounts))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
            
        } catch {
            completion(.failure(ProtonError.error("MESSAGE => Unable to parse Private Key")))
        }
        
    }
    
    /**
     Creates a transfer, signs and pushes that transfer to the chain
     - Parameter to: The account to be transfered to
     - Parameter quantity: The amount to be transfered
     - Parameter tokenContract: The TokenContract that's being transfered
     - Parameter memo: The memo for the transfer
     - Parameter completion: Closure returning Result
     */
    public func transfer(to: Name, quantity: Double, tokenContract: TokenContract, memo: String = "", completion: @escaping ((Result<TokenTransferAction, Error>) -> Void)) {
        
        guard let account = self.account else {
            completion(.failure(ProtonError.error("MESSAGE => No active account")))
            return
        }
        
        guard let chainProvider = account.chainProvider else {
            completion(.failure(ProtonError.error("MESSAGE => Unable to find chain provider")))
            return
        }
        
        guard let tokenBalance = self.tokenBalances.first(where: { $0.tokenContractId == tokenContract.id }) else {
            completion(.failure(ProtonError.error("MESSAGE => Account has no token balance for \(tokenContract.name)")))
            return
        }
        
        if quantity > tokenBalance.amount.value {
            completion(.failure(ProtonError.error("MESSAGE => Account balance insufficient")))
            return
        }
        
        account.privateKey(forPermissionName: "active") { result in
            
            switch result {
            case .success(let privateKey):
                
                guard let privateKey = privateKey else {
                    completion(.failure(ProtonError.error("MESSAGE => Unable to retrive active private key")))
                    return
                }
                
                let transfer = TransferActionABI(from: account.name, to: to, quantity: Asset(quantity, tokenContract.symbol), memo: memo)
                
                guard let action = try? Action(account: tokenContract.contract, name: "transfer", authorization: [PermissionLevel(account.name, "active")], value: transfer) else {
                    completion(.failure(ProtonError.error("MESSAGE => Unable to create action")))
                    return
                }
                
                WebOperations.shared.add(SignTransactionOperation(account: account, chainProvider: chainProvider, actions: [action], privateKey: privateKey), toCustomQueueNamed: Proton.operationQueueSeq) { result in
                    
                    switch result {
                    case .success(let signedTransaction):
                        
                        if let signedTransaction = signedTransaction as? SignedTransaction {
                            
                            WebOperations.shared.add(PushTransactionOperation(account: account, chainProvider: chainProvider, signedTransaction: signedTransaction), toCustomQueueNamed: Proton.operationQueueSeq) { result in
                                
                                switch result {
                                case .success(let response):
                                    
                                    if let response = response as? API.V1.Chain.PushTransaction.Response {
                                        
                                        let tokenTransferAction = TokenTransferAction(chainId: chainProvider.chainId, accountId: account.id, tokenBalanceId: tokenBalance.id, tokenContractId: tokenContract.id, name: action.name.stringValue, contract: action.account, trxId: String(response.transactionId), date: Date(), sent: true, from: account.name, to: to, quantity: transfer.quantity, memo: transfer.memo)
                                        
                                        self.tokenTransferActions.append(tokenTransferAction)
                                        
                                        completion(.success(tokenTransferAction))
                                        
                                    } else {
                                        completion(.failure(ProtonError.error("MESSAGE => Unable to push transaction")))
                                    }
                                case .failure(let error):
                                    completion(.failure(error))
                                }
                                
                            }
                            
                        } else {
                            completion(.failure(ProtonError.error("MESSAGE => Unable to sign transaction")))
                        }
                        
                    case .failure(let error):
                        completion(.failure(error))
                    }
                    
                }
                
            case .failure(let error):
                
                completion(.failure(ProtonError.error("MESSAGE => Unable to sign transaction \(error.localizedDescription)")))
                
            }
            
        }

    }
    
    /**
     Use this function generate a k1 PrivateKey object. See PrivateKey inside of EOSIO for more details
     */
    public func generatePrivateKey() -> PrivateKey? {
        var bytes = [UInt8](repeating: 0, count: 33)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        guard status == errSecSuccess else {
            fatalError("Unable to create secure random data")
        }
        bytes[0] = 0x80
        return try? PrivateKey(fromK1Data: Data(bytes))
    }
    
    /**
     :nodoc:
    Creates signature for updating avatar and userdefined name
     - Parameter completion: Closure returning Result
     */
    private func signforAccountUpdate(completion: @escaping ((Result<Signature, Error>) -> Void)) {
        
        guard let account = self.account else {
            completion(.failure(ProtonError.error("MESSAGE => No active account")))
            return
        }

        account.privateKey(forPermissionName: "active") { result in
            
            switch result {
            case .success(let privateKey):
                
                guard let privateKey = privateKey else {
                    completion(.failure(ProtonError.error("MESSAGE => Unable to fetch private key")))
                    return
                }
                
                guard let signingData = account.name.stringValue.data(using: String.Encoding.utf8) else {
                    completion(.failure(ProtonError.error("MESSAGE => Unable generate signing string data")))
                    return
                }
                
                do {
                    let signature = try privateKey.sign(signingData)
                    completion(.success(signature))
                    return
                } catch {
                    completion(.failure(ProtonError.error("MESSAGE => \(error.localizedDescription)")))
                    return
                }
                
            case .failure(let error):
                
                completion(.failure(ProtonError.error("MESSAGE => \(error.localizedDescription)")))
            }
            
        }

    }
    
    /**
     :nodoc:
     Use this function to obtain a list of Accounts which match a given public key. These accounts are not stored. If you want to store the Account and private key, you should then call storePrivateKey function
     - Parameter forPublicKey: Wif formated public key
     - Parameter completion: Closure returning Result
     */
    private func findAccounts(forPublicKey publicKey: String, completion: @escaping ((Result<Set<Account>, Error>) -> Void)) {
        
        self.fetchKeyAccounts(forPublicKey: publicKey) { result in
            
            switch result {
            case .success(var accounts):
                
                if accounts.count > 0 {
                    
                    let accountCount = accounts.count
                    var accountsProcessed = 0
                    
                    for var account in accounts {
                        
                        self.fetchAccount(account) { result in
                            
                            switch result {
                            case .success(let acc):
                                account = acc
                                accounts.update(with: acc)
                            case .failure: break
                            }
                            
                            self.fetchAccountUserInfo(forAccount: account) { result in
                                switch result {
                                case .success(let acc):
                                    accounts.update(with: acc)
                                case .failure: break
                                }
                                
                                accountsProcessed += 1
                                
                                if accountCount == accountsProcessed {
                                    completion(.success(accounts))
                                }
                            }
                            
                        }
                        
                    }

                } else {
                    completion(.failure(ProtonError.error("MESSAGE => No accounts found for publicKey: \(publicKey)")))
                }
            case .failure(let error):
                completion(.failure(error))
            }

        }
        
    }
    
    /**
     :nodoc:
     Sets the active account, fetchs and updates. This includes, account names, avatars, balances, etc
     - Parameter account: Account
     - Parameter completion: Closure returning Result
     */
    private func setAccount(_ account: Account, completion: @escaping ((Result<Account, Error>) -> Void)) {
        
        var account = account
        
        if let activeAccount = self.account, activeAccount == account {
            account = activeAccount
        } else {
            self.account = account
            self.tokenBalances.removeAll()
            self.tokenTransferActions.removeAll()
            self.esrSessions.removeAll() // TODO: Actually loop through call the remove session callbacks, etc
            self.esr = nil
        }

        self.updateAccount { result in
            switch result {
            case .success(let account):
                self.account = account
                completion(.success(account))
            case .failure(let error):
                completion(.failure(error))
            }
        }
        
    }
    
    /**
     :nodoc:
     Fetches token balance for the active account
     - Parameter forTokenBalance: TokenBalance
     - Parameter completion: Closure returning Result
     */
    private func fetchTransferActions(forTokenBalance tokenBalance: TokenBalance, completion: @escaping ((Result<Set<TokenTransferAction>, Error>) -> Void)) {
        
        var retval = Set<TokenTransferAction>()
        
        guard let account = tokenBalance.account else {
            completion(.failure(ProtonError.error("MESSAGE => TokenBalance missing Account")))
            return
        }
        
        guard let chainProvider = account.chainProvider else {
            completion(.failure(ProtonError.error("MESSAGE => Account missing ChainProvider")))
            return
        }
        
        guard let tokenContract = tokenBalance.tokenContract else {
            completion(.failure(ProtonError.error("MESSAGE => TokenBalance missing TokenContract")))
            return
        }
        
        WebOperations.shared.add(FetchTokenTransferActionsOperation(account: account, tokenContract: tokenContract,
                                                                       chainProvider: chainProvider, tokenBalance: tokenBalance), toCustomQueueNamed: Proton.operationQueueMulti) { result in
            
            switch result {
            case .success(let transferActions):
                
                if let transferActions = transferActions as? Set<TokenTransferAction> {
                    retval = transferActions
                }
                
                completion(.success(retval))

            case .failure(let error):
                completion(.failure(error))
            }
            
        }
        
    }
    
    /**
     :nodoc:
     Fetches the accounts found for the publickey passed
     - Parameter forPublicKey: Wif formated public key
     - Parameter completion: Closure returning Result
     */
    private func fetchKeyAccounts(forPublicKey publicKey: String, completion: @escaping ((Result<Set<Account>, Error>) -> Void)) {
        
        guard let chainProvider = self.chainProvider else {
            completion(.failure(ProtonError.error("MESSAGE => Missing ChainProvider")))
            return
        }
        
        WebOperations.shared.add(FetchKeyAccountsOperation(publicKey: publicKey,
                                                              chainProvider: chainProvider), toCustomQueueNamed: Proton.operationQueueMulti) { result in
            
            var accounts = Set<Account>()
                                                                
            switch result {
            case .success(let accountNames):
                
                if let accountNames = accountNames as? Set<String>, accountNames.count > 0 {
                    for accountName in accountNames {
                        accounts.update(with: Account(chainId: chainProvider.chainId, name: accountName))
                    }
                }
                
            case .failure: break
            }
            
            if accounts.count > 0 {
                completion(.success(accounts))
            } else {
                completion(.failure(ProtonError.error("MESSAGE => No accounts found for \(publicKey)")))
            }
            
        }
        
    }
    
    /**
     :nodoc:
     Fetches the account found for the publickey passed
     - Parameter forPublicKey: Wif formated public key
     - Parameter completion: Closure returning Result
     */
    private func fetchAccount(_ account: Account, completion: @escaping ((Result<Account, Error>) -> Void)) {
        
        var account = account
        
        if let chainProvider = account.chainProvider {
            
            WebOperations.shared.add(FetchAccountOperation(accountName: account.name.stringValue, chainProvider: chainProvider), toCustomQueueNamed: Proton.operationQueueMulti) { result in
                
                switch result {
                case .success(let acc):
                    
                    if let acc = acc as? API.V1.Chain.GetAccount.Response {
                        account.permissions = acc.permissions
                    }
                    
                    completion(.success(account))
                    
                case .failure(let error):
                    completion(.failure(error))
                }
                
            }
            
        } else {
            completion(.failure(ProtonError.error("MESSAGE => Account missing chainProvider")))
        }
        
    }
    
    /**
     :nodoc:
     Fetches the account info from chain table rows.
     This includes stuff like avatar base64 string, name, etc
     - Parameter forAccount: Account
     - Parameter completion: Closure returning Result
     */
    private func fetchAccountUserInfo(forAccount account: Account, completion: @escaping ((Result<Account, Error>) -> Void)) {
        
        var account = account
        
        if let chainProvider = account.chainProvider {
            
            WebOperations.shared.add(FetchUserAccountInfoOperation(account: account, chainProvider: chainProvider), toCustomQueueNamed: Proton.operationQueueMulti) { result in
                
                switch result {
                case .success(let updatedAccount):
                    
                    if let updatedAccount = updatedAccount as? Account {
                        account = updatedAccount
                    }
                    
                    completion(.success(account))
                    
                case .failure(let error):
                    completion(.failure(error))
                }
                
            }
            
        } else {
            completion(.failure(ProtonError.error("MESSAGE => Account missing chainProvider")))
        }
        
    }
    
    /**
     :nodoc:
     Fetches all balances for the active account.
     - Parameter forAccount: Account
     - Parameter completion: Closure returning Result
     */
    private func fetchBalances(forAccount account: Account, completion: @escaping ((Result<Set<TokenBalance>, Error>) -> Void)) {
        
        var retval = Set<TokenBalance>()
        
        if let chainProvider = account.chainProvider {
            
            WebOperations.shared.add(FetchTokenBalancesOperation(account: account, chainProvider: chainProvider), toCustomQueueNamed: Proton.operationQueueMulti) { result in
                
                switch result {
                case .success(let tokenBalances):
                    
                    if let tokenBalances = tokenBalances as? Set<TokenBalance> {
                        
                        for tokenBalance in tokenBalances {
                            
                            if self.tokenContracts.first(where: { $0.id == tokenBalance.tokenContractId }) == nil {
                                
                                let unknownTokenContract = TokenContract(chainId: tokenBalance.chainId, contract: tokenBalance.contract, issuer: "",
                                                                         resourceToken: false, systemToken: false, name: tokenBalance.amount.symbol.name,
                                                                         desc: "", iconUrl: "", supply: Asset(0.0, tokenBalance.amount.symbol),
                                                                         maxSupply: Asset(0.0, tokenBalance.amount.symbol),
                                                                         symbol: tokenBalance.amount.symbol, url: "", isBlacklisted: true)
                                
                                self.tokenContracts.append(unknownTokenContract)
                                
                            }
                            
                        }
                        
                        retval = tokenBalances
                        
                    }
                    
                    completion(.success(retval))
                    
                case .failure(let error):
                    completion(.failure(error))
                }
                
            }
            
        } else {
            completion(.failure(ProtonError.error("MESSAGE => Account missing chainProvider")))
        }
        
    }
    
    /**
     :nodoc:
     Fetches all known accounts in which the active account has interated with via transfers, etc.
     - Parameter forAccount: Account
     - Parameter completion: Closure returning Result
     */
    private func fetchContacts(forAccount account: Account, completion: @escaping ((Result<Set<Contact>, Error>) -> Void)) {
        
        var retval = Set<Contact>()

        guard let chainProvider = account.chainProvider else {
            completion(.failure(ProtonError.error("MESSAGE => Account missing chainProvider")))
            return
        }

        let contactNames: [String] = tokenTransferActions.map { transferAction in
            return transferAction.other.stringValue
        }.reduce([]) { $0.contains($1) ? $0 : $0 + [$1] }
        
        
        if contactNames.count == 0 {
            completion(.success(retval))
            return
        }
        
        var contactNamesProcessed = 0
        
        for contactName in contactNames {
            
            WebOperations.shared.add(FetchContactInfoOperation(account: account, contactName: contactName, chainProvider: chainProvider), toCustomQueueNamed: Proton.operationQueueMulti) { result in
                
                switch result {
                case .success(let contact):
                    if let contact = contact as? Contact {
                        retval.update(with: contact)
                    }
                case .failure: break
                }
                
                contactNamesProcessed += 1
                
                if contactNamesProcessed == contactNames.count {
                    completion(.success(retval))
                }
                
            }
            
        }

    }
    
    // MARK: - ESR Functions 🚧 UNDER CONSTRUCTION
    

    
}


public enum ProtonError: Error, LocalizedError {
    
    case error(String)
    case chain(String)
    case history(String)
    case esr(String)
    case keychain(String)

    public var errorDescription: String? {
        switch self {
        case .error(let message):
            return "⚛️ PROTON ERROR\n======================\n\(message)\n======================\n"
        case .chain(let message):
            return "⚛️⛓️ PROTON CHAIN ERROR\n======================\n\(message)\n======================\n"
        case .history(let message):
            return "⚛️📜 PROTON HISTORY ERROR\n======================\n\(message)\n======================\n"
        case .esr(let message):
            return "⚛️✍️ PROTON SIGNING REQUEST ERROR\n======================\n\(message)\n======================\n"
        case .keychain(let message):
            return "⚛️✍️ PROTON KEYCHAIN ERROR\n======================\n\(message)\n======================\n"
        }
    }
    
}
