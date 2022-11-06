import Navigation

public struct PresentOnboardingPhone: Navigation.Action {
  public var animated: Bool = true

  public init(animated: Bool = true) {
    self.animated = animated
  }
}