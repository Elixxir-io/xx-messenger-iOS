import UIKit
import Theme
import Shared
import Combine
import XXModels
import DrawerFeature
import DependencyInjection

enum SearchSection {
    case stranger
    case connections
}

enum SearchItem: Equatable, Hashable {
    case stranger(Contact)
    case connection(Contact)
}

class SearchTableViewDiffableDataSource: UITableViewDiffableDataSource<SearchSection, SearchItem> {
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch snapshot().sectionIdentifiers[section] {
        case .stranger:
            return ""
        case .connections:
            return "CONNECTIONS"
        }
    }
}

public final class SearchContainerController: UIViewController {
    @Dependency var coordinator: SearchCoordinating
    @Dependency var statusBarController: StatusBarStyleControlling

    lazy private var screenView = SearchContainerView()

    private let qrController = SearchQRController()
    private var cancellables = Set<AnyCancellable>()
    private let viewModel = SearchContainerViewModel()
    private let emailController = SearchEmailController()
    private let phoneController = SearchPhoneController()
    private var drawerCancellables = Set<AnyCancellable>()
    private let usernameController = SearchUsernameController()

    public override func loadView() {
        view = screenView
        screenView.scrollView.delegate = self
        embedControllers()
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        statusBarController.style.send(.darkContent)

        navigationController?.navigationBar.customize(
            backgroundColor: Asset.neutralWhite.color
        )
    }

    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        viewModel.didAppear()
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        setupNavigationBar()
        setupBindings()
    }

    private func setupNavigationBar() {
        navigationItem.backButtonTitle = " "

        let titleLabel = UILabel()
        titleLabel.text = Localized.Ud.title
        titleLabel.textColor = Asset.neutralActive.color
        titleLabel.font = Fonts.Mulish.semiBold.font(size: 18.0)

        let backButton = UIButton.back()
        backButton.addTarget(self, action: #selector(didTapBack), for: .touchUpInside)

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            customView: UIStackView(arrangedSubviews: [backButton, titleLabel])
        )
    }

    private func setupBindings() {
        screenView.segmentedControl
            .actionPublisher
            .receive(on: DispatchQueue.main)
            .sink { [unowned self] in
                let page = CGFloat($0.rawValue)
                let point: CGPoint = CGPoint(x: screenView.frame.width * page, y: 0.0)
                screenView.scrollView.setContentOffset(point, animated: true)
            }.store(in: &cancellables)

        viewModel.coverTrafficPublisher
            .receive(on: DispatchQueue.main)
            .sink { [unowned self] in presentCoverTrafficDrawer() }
            .store(in: &cancellables)

    }

    @objc private func didTapBack() {
        navigationController?.popViewController(animated: true)
    }

    private func embedControllers() {
        addChild(qrController)
        addChild(emailController)
        addChild(phoneController)
        addChild(usernameController)

        screenView.scrollView.addSubview(qrController.view)
        screenView.scrollView.addSubview(emailController.view)
        screenView.scrollView.addSubview(phoneController.view)
        screenView.scrollView.addSubview(usernameController.view)

        usernameController.view.snp.makeConstraints {
            $0.top.equalTo(screenView.segmentedControl.snp.bottom)
            $0.width.equalTo(screenView)
            $0.bottom.equalTo(screenView)
            $0.left.equalToSuperview()
            $0.right.equalTo(emailController.view.snp.left)
        }

        emailController.view.snp.makeConstraints {
            $0.top.equalTo(screenView.segmentedControl.snp.bottom)
            $0.width.equalTo(screenView)
            $0.bottom.equalTo(screenView)
            $0.right.equalTo(phoneController.view.snp.left)
        }

        phoneController.view.snp.makeConstraints {
            $0.top.equalTo(screenView.segmentedControl.snp.bottom)
            $0.width.equalTo(screenView)
            $0.bottom.equalTo(screenView)
            $0.right.equalTo(qrController.view.snp.left)
        }

        qrController.view.snp.makeConstraints {
            $0.top.equalTo(screenView.segmentedControl.snp.bottom)
            $0.width.equalTo(screenView)
            $0.bottom.equalTo(screenView)
        }

        qrController.didMove(toParent: self)
        emailController.didMove(toParent: self)
        phoneController.didMove(toParent: self)
        usernameController.didMove(toParent: self)
    }
}

extension SearchContainerController: UIScrollViewDelegate {
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let pageOffset = scrollView.contentOffset.x / view.frame.width
        scrollSegmentedControlTrack(using: pageOffset)
        updateSegmentedControlButtonsColor(using: pageOffset)
    }

    private func scrollSegmentedControlTrack(using pageOffset: CGFloat) {
        let amountOfTabs = 4.0
        let tabWidth = screenView.bounds.width / amountOfTabs

        if let leftConstraint = screenView.segmentedControl.leftConstraint {
            leftConstraint.update(offset: pageOffset * tabWidth)
        }
    }

    private func updateSegmentedControlButtonsColor(using pageOffset: CGFloat) {
        let qrRate = highlightRateFor(page: 3, offset: pageOffset)
        let emailRate = highlightRateFor(page: 1, offset: pageOffset)
        let phoneRate = highlightRateFor(page: 2, offset: pageOffset)
        let usernameRate = highlightRateFor(page: 0, offset: pageOffset)

        screenView.segmentedControl.qrCodeButton.updateHighlighting(rate: qrRate)
        screenView.segmentedControl.emailButton.updateHighlighting(rate: emailRate)
        screenView.segmentedControl.phoneButton.updateHighlighting(rate: phoneRate)
        screenView.segmentedControl.usernameButton.updateHighlighting(rate: usernameRate)
    }

    private func highlightRateFor(page: CGFloat, offset: CGFloat) -> CGFloat {
        let lowerBound = page - 1
        let upperBound = page + 1

        if offset > lowerBound && offset < upperBound {
            if (offset - lowerBound) > 1 {
                return 1 - (offset - page)
            } else {
                return offset - lowerBound
            }
        } else {
            return 0
        }
    }
}

extension SearchContainerController {
    private func presentCoverTrafficDrawer() {
        let enableButton = CapsuleButton()
        enableButton.set(
            style: .brandColored,
            title: Localized.ChatList.Traffic.positive
        )

        let dismissButton = CapsuleButton()
        dismissButton.set(
            style: .seeThrough,
            title: Localized.ChatList.Traffic.negative
        )

        let drawer = DrawerController(with: [
            DrawerText(
                font: Fonts.Mulish.bold.font(size: 26.0),
                text: Localized.ChatList.Traffic.title,
                color: Asset.neutralActive.color,
                alignment: .left,
                spacingAfter: 19
            ),
            DrawerText(
                font: Fonts.Mulish.regular.font(size: 16.0),
                text: Localized.ChatList.Traffic.subtitle,
                color: Asset.neutralBody.color,
                alignment: .left,
                lineHeightMultiple: 1.1,
                spacingAfter: 39
            ),
            DrawerStack(
                axis: .horizontal,
                spacing: 20,
                distribution: .fillEqually,
                views: [enableButton, dismissButton]
            )
        ])

        enableButton
            .publisher(for: .touchUpInside)
            .receive(on: DispatchQueue.main)
            .sink {
                drawer.dismiss(animated: true) { [weak self] in
                    guard let self = self else { return }
                    self.drawerCancellables.removeAll()
                    self.viewModel.didEnableCoverTraffic()
                }
            }.store(in: &drawerCancellables)

        dismissButton
            .publisher(for: .touchUpInside)
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
