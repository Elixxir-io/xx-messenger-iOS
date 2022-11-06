import UIKit
import Navigation
import DependencyInjection

public struct PresentOnboardingPhoneNavigator: TypedNavigator {
  @Dependency var navigator: Navigator
  var screen: () -> UIViewController
  var navigationController: () -> UINavigationController

  public func perform(_ action: PresentOnboardingPhone, completion: @escaping () -> Void) {
    let setStackAction = SetStack([screen()], on: navigationController(), animated: action.animated)
    navigator.perform(setStackAction, completion: completion)
  }

  public init(
    screen: @escaping () -> UIViewController,
    navigationController: @escaping () -> UINavigationController
  ) {
    self.screen = screen
    self.navigationController = navigationController
  }
}
