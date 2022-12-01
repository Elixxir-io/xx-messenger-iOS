import AppCore
import Defaults
import Keychain
import Foundation
import Dependencies
import AppResources
import XXMessengerClient

final class SettingsDeleteViewModel {
  @Dependency(\.app.bgQueue) var bgQueue
  @Dependency(\.keychain) var keychain: KeychainManager
  @Dependency(\.app.dbManager) var dbManager: DBManager
  @Dependency(\.app.messenger) var messenger: Messenger
  @Dependency(\.app.hudManager) var hudManager: HUDManager
  @KeyObject(.username, defaultValue: nil) var username: String?

  private var isCurrentlyDeleting = false
  
  func didTapDelete() {
    guard isCurrentlyDeleting == false else { return }
    isCurrentlyDeleting = true

    hudManager.show()

    bgQueue.schedule { [weak self] in
      guard let self else { return }

      do {
        try self.cleanUD()
        try self.messenger.destroy()
        try self.keychain.destroy()
        try self.dbManager.removeDB()

        UserDefaults.resetStandardUserDefaults()
        UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier!)
        UserDefaults.standard.synchronize()

        self.hudManager.show(.init(
          title: Localized.Settings.Delete.Success.title,
          content: Localized.Settings.Delete.Success.subtitle
        ))
      } catch {
        DispatchQueue.main.async { [weak self] in
          guard let self else { return }
          self.hudManager.show(.init(error: error))
        }
      }
    }
  }
  
  private func cleanUD() throws {
    try messenger.ud.get()!.permanentDeleteAccount(
      username: .init(type: .username, value: username!)
    )
  }
}
