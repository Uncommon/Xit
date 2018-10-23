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

  override func setUp()
  {
    deleteKeychain(at: path)
    keychain = Keychain(path: path, password: "", promptUser: false)
    if keychain == nil {
      continueAfterFailure = false
      XCTFail("Could not create keychain")
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
      _ = SecKeychainDelete(keychain)
    }
  }
  
  func testAddAccount()
  {
    let url = URL(string: "https://api.github.com")!
    let account = Account(type: .gitHub, user: "myself",
                          location: url)
    let password = "string"
    
    XCTAssertNoThrow(try manager.add(account, password: password))
    dumpKeychain()
    
    XCTAssertEqual(1, manager.accounts.count)
    XCTAssertEqual(account, manager.accounts[0])
    XCTAssertEqual(password, passwordStorage.find(host: url.host!, path: url.path,
                                                  port: 80, account: account.user))
  }
}
