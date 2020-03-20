import XCTest
@testable import Xit

class KeychainTest: XCTestCase
{
  let path = NSString.path(withComponents: ["private",
                                            NSTemporaryDirectory(),
                                            "test.keychain"])
  var keychain: Keychain!
  var passwordStorage: XTKeychain!
  var manager: AccountsManager!
  
  static let baseURLString = "https://api.github.com"
  
  let baseURL = URL(string: KeychainTest.baseURLString)!
  let baseAccount = Account(type: .gitHub, user: "myself",
                            location: URL(string: KeychainTest.baseURLString)!)
  let basePassword = "basePassword"

  override func setUp()
  {
    deleteKeychain(at: path)
    keychain = Keychain(path: path, password: "", promptUser: false)
    if keychain == nil {
      continueAfterFailure = false
      XCTFail("Could not create keychain")
      return
    }
    
    let keychainStorage = XTKeychain()
    
    keychainStorage.keychain = keychain.keychainRef
    passwordStorage = keychainStorage
    
    let defaults = UserDefaults(suiteName: "com.uncommonplace.xit.tests")!
    
    for key in defaults.dictionaryRepresentation().keys {
      defaults.removeObject(forKey: key)
    }
    
    manager = AccountsManager(defaults: defaults,
                              passwordStorage: passwordStorage)
  }
  
  override func tearDown()
  {
    if let storage = passwordStorage {
      _ = SecKeychainDelete(storage.keychain)
    }
    passwordStorage = nil
    keychain = nil
    if FileManager.default.fileExists(atPath: path) {
      XCTAssertNoThrow(try FileManager.default.removeItem(atPath: path))
    }
  }
  
  private func dumpKeychain()
  {
    let query: [CFString: Any] = [kSecUseKeychain: keychain.keychainRef,
                                  kSecClass: kSecClassInternetPassword,
                                  kSecMatchLimit: kSecMatchLimitAll,
                                  kSecReturnAttributes: true,
                                  kSecMatchSearchList: [keychain.keychainRef]]
    var result: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    guard status == noErr,
          let finalResult = result
    else {
      print("can't fetch passwords: error \(status)")
      return
    }
    
    print("\(String(describing: CFCopyDescription(finalResult)))")
  }
  
  private func deleteKeychain(at path: String)
  {
    var keychain: SecKeychain?
    let status = SecKeychainOpen(path, &keychain)
    
    if status == noErr {
      SecKeychainDelete(keychain)
    }
  }
  
  func addBaseAccount()
  {
    XCTAssertNoThrow(try manager.add(baseAccount, password: basePassword))
  }
  
  func testAddAccount()
  {
    addBaseAccount()
    
    XCTAssertEqual(1, manager.accounts.count)
    XCTAssertEqual(baseAccount, manager.accounts[0])
    XCTAssertEqual(basePassword,
                   passwordStorage.find(host: baseURL.host!, path: baseURL.path,
                                        protocol: nil,
                                        port: 80, account: baseAccount.user))
  }
  
  func assertModify(newAccount: Account, password: String?)
  {
    dumpKeychain()
    XCTAssertEqual(basePassword,
                   passwordStorage.find(url: baseAccount.location,
                                        account: baseAccount.user))
    XCTAssertNoThrow(try manager.modify(oldAccount: baseAccount,
                                        newAccount: newAccount,
                                        newPassword: password))
    print("**")
    dumpKeychain()
    XCTAssertEqual(password ?? basePassword,
                   passwordStorage.find(host: newAccount.location.host!,
                                        path: newAccount.location.path,
                                        protocol: nil,
                                        port: 80, account: newAccount.user))
  }
  
  func testChangeAccountURL()
  {
    addBaseAccount()

    let account2 = Account(type: baseAccount.type, user: baseAccount.user,
                           location: URL(string: "https://other.github.com")!)
    
    assertModify(newAccount: account2, password: nil)
  }
  
  func testChangeAccountUser()
  {
    addBaseAccount()
    
    let account2 = Account(type: baseAccount.type, user: "other",
                           location: baseURL)
    
    assertModify(newAccount: account2, password: nil)
  }
  
  func testChangePassword()
  {
    addBaseAccount()
    
    assertModify(newAccount: baseAccount, password: "other password")
  }
  
  func testChangeUserAndPassword()
  {
    addBaseAccount()
    
    let account2 = Account(type: baseAccount.type, user: "other",
                           location: baseURL)
    
    assertModify(newAccount: account2, password: "other password")
  }
  
  // No delete test: deleting an account does not delete the keychain item

  func testImpliedUserName()
  {
    let data: [(URL, String?)] =
          [(URL(string: "http://github.com/Uncommon/repo")!, "Uncommon"),
           (URL(string: "http://that.github.com/guy/repo")!, "guy"),
           (URL(string: "http://gitlab.com/Uncommon1/repo")!, "Uncommon1"),
           (URL(string: "http://other.com/something/else")!, nil)]

    for (url, user) in data {
      XCTAssertEqual(url.impliedUserName, user, "for URL \(url)")
    }
  }
}
