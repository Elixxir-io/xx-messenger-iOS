import UIKit
import Shared
import Combine
import DrawerFeature
import DependencyInjection
import ScrollViewController

public final class OnboardingEmailController: UIViewController {
  @Dependency var barStylist: StatusBarStylist
  @Dependency var coordinator: OnboardingCoordinating

  lazy private var screenView = OnboardingEmailView()
  lazy private var scrollViewController = ScrollViewController()

  private var cancellables = Set<AnyCancellable>()
  private let viewModel = OnboardingEmailViewModel()
  private var drawerCancellables = Set<AnyCancellable>()

  public override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    barStylist.styleSubject.send(.darkContent)
    navigationController?.navigationBar.customize(translucent: true)
  }

  public override func viewDidLoad() {
    super.viewDidLoad()
    navigationItem.backButtonTitle = " "

    setupScrollView()
    setupBindings()

    screenView.didTapInfo = { [weak self] in
      self?.presentInfo(
        title: Localized.Onboarding.Email.Info.title,
        subtitle: Localized.Onboarding.Email.Info.subtitle,
        urlString: "https://links.xx.network/ud"
      )
    }
  }

  private func setupScrollView() {
    addChild(scrollViewController)
    view.addSubview(scrollViewController.view)
    scrollViewController.view.snp.makeConstraints { $0.edges.equalToSuperview() }
    scrollViewController.didMove(toParent: self)
    scrollViewController.contentView = screenView
    scrollViewController.scrollView.backgroundColor = Asset.neutralWhite.color
  }

  private func setupBindings() {
    screenView.inputField.textPublisher
      .sink { [unowned self] in viewModel.didInput($0) }
      .store(in: &cancellables)

    screenView.inputField.returnPublisher
      .sink { [unowned self] in screenView.inputField.endEditing(true) }
      .store(in: &cancellables)

    viewModel.state
      .map(\.confirmation)
      .receive(on: DispatchQueue.main)
      .compactMap { $0 }
      .sink { [unowned self] in
        viewModel.clearUp()
        coordinator.toEmailConfirmation(with: $0, from: self) { controller in
          let successModel = OnboardingSuccessModel(
            title: Localized.Onboarding.Success.Email.title,
            subtitle: nil,
            nextController: self.coordinator.toPhone(from:)
          )

          self.coordinator.toSuccess(with: successModel, from: controller)
        }
      }.store(in: &cancellables)

    viewModel.state
      .map(\.status)
      .removeDuplicates()
      .receive(on: DispatchQueue.main)
      .sink { [unowned self] in screenView.update(status: $0) }
      .store(in: &cancellables)

    screenView.nextButton.publisher(for: .touchUpInside)
      .sink { [unowned self] in viewModel.didTapNext() }
      .store(in: &cancellables)

    screenView.skipButton.publisher(for: .touchUpInside)
      .sink { [unowned self] in coordinator.toPhone(from: self) }
      .store(in: &cancellables)
  }

  private func presentInfo(
    title: String,
    subtitle: String,
    urlString: String = ""
  ) {
    let actionButton = CapsuleButton()
    actionButton.set(
      style: .seeThrough,
      title: Localized.Settings.InfoDrawer.action
    )

    let drawer = DrawerController(with: [
      DrawerText(
        font: Fonts.Mulish.bold.font(size: 26.0),
        text: title,
        color: Asset.neutralActive.color,
        alignment: .left,
        spacingAfter: 19
      ),
      DrawerLinkText(
        text: subtitle,
        urlString: urlString,
        spacingAfter: 37
      ),
      DrawerStack(views: [
        actionButton,
        FlexibleSpace()
      ])
    ])

    actionButton.publisher(for: .touchUpInside)
      .receive(on: DispatchQueue.main)
      .sink {
        drawer.dismiss(animated: true) { [weak self] in
          guard let self = self else { return }
          self.drawerCancellables.removeAll()
        }
      }.store(in: &drawerCancellables)

    coordinator.toDrawer(drawer, from: self)
  }
}
