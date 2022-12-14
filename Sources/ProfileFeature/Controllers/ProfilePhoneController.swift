import HUD
import UIKit
import Shared
import Combine
import Theme
import DependencyInjection
import ScrollViewController

#warning("TODO: Merge ProfilePhoneController/ProfileEmailController")

public final class ProfilePhoneController: UIViewController {
    @Dependency private var hud: HUD
    @Dependency private var coordinator: ProfileCoordinating
    @Dependency private var statusBarController: StatusBarStyleControlling

    lazy private var screenView = ProfilePhoneView()
    lazy private var scrollViewController = ScrollViewController()

    private let viewModel = ProfilePhoneViewModel()
    private var cancellables = Set<AnyCancellable>()

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationItem.backButtonTitle = ""
        statusBarController.style.send(.darkContent)
        navigationController?.navigationBar
            .customize(backgroundColor: Asset.neutralWhite.color)
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        setupScrollView()
        setupBindings()
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
        viewModel.hud
            .receive(on: DispatchQueue.main)
            .sink { [hud] in hud.update(with: $0) }
            .store(in: &cancellables)

        screenView.inputField.textPublisher
            .sink { [unowned self] in viewModel.didInput($0) }
            .store(in: &cancellables)

        screenView.inputField.returnPublisher
            .sink { [unowned self] in screenView.inputField.endEditing(true) }
            .store(in: &cancellables)

        screenView.inputField.codePublisher
            .receive(on: DispatchQueue.main)
            .sink { [unowned self] in
                coordinator.toCountries(from: self) { viewModel.didChooseCountry($0) }
            }.store(in: &cancellables)

        viewModel.state
            .map(\.confirmation)
            .receive(on: DispatchQueue.main)
            .compactMap { $0 }
            .sink { [unowned self] in
                viewModel.clearUp()
                coordinator.toCode(with: $0, from: self) { _, _ in
                    if let viewControllers = navigationController?.viewControllers {
                        navigationController?.popToViewController(
                            viewControllers[viewControllers.count - 3],
                            animated: true
                        )
                    }
                }
            }.store(in: &cancellables)

        viewModel.state
            .map(\.country)
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [unowned self] in
                screenView.inputField.set(prefix: $0.prefixWithFlag)
                screenView.inputField.update(placeholder: $0.example)
            }
            .store(in: &cancellables)

        viewModel.state
            .map(\.status)
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [unowned self] in screenView.update(status: $0) }
            .store(in: &cancellables)

        screenView.saveButton.publisher(for: .touchUpInside)
            .sink { [unowned self] in viewModel.didTapNext() }
            .store(in: &cancellables)
    }
}
