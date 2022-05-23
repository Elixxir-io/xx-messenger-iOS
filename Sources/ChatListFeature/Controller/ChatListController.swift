import HUD
import DrawerFeature
import UIKit
import Theme
import Shared
import Combine
import MenuFeature
import DependencyInjection

public final class ChatListController: UIViewController {
    @Dependency private var hud: HUDType
    @Dependency private var coordinator: ChatListCoordinating
    @Dependency private var statusBarController: StatusBarStyleControlling

    lazy private var menu = UIButton()
    lazy private var cancel = UIButton()
    lazy private var menuBadge = UILabel()
    lazy private var titleLabel = UILabel()
    lazy private var screenView = ChatListView()
    lazy private var menuView = ChatListMenuView()
    lazy private var contactListButton = UIButton()
    lazy private var contactSearchButton = UIButton()
    lazy private var tableController = ChatListTableController(viewModel)

    private var shouldPresentMenu = false
    private let viewModel = ChatListViewModel()
    private var cancellables = Set<AnyCancellable>()
    private var drawerCancellables = Set<AnyCancellable>()

    public override var canBecomeFirstResponder: Bool { true }

    public override var inputAccessoryView: UIView? {
        if shouldPresentMenu {
            tableController.numberOfSelectedRows = 0
        }

        return shouldPresentMenu ? menuView : nil
    }

    public init() {
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { nil }

    public override func loadView() {
        view = screenView

        addChild(tableController)
        screenView.insertSubview(tableController.view, belowSubview: screenView)

        tableController.view.snp.makeConstraints { make in
            make.top.equalTo(screenView.searchView.snp.bottom)
            make.left.equalToSuperview()
            make.right.equalToSuperview()
            make.bottom.equalToSuperview()
        }

        tableController.didMove(toParent: self)
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        statusBarController.style.send(.darkContent)
        updateNavigationItems(false)

        navigationController?.navigationBar.customize(backgroundColor: Asset.neutralWhite.color)
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        setupNavigationBar()
        setupBindings()
    }

    private func setupNavigationBar() {
        navigationItem.backButtonTitle = ""

        contactSearchButton.tintColor = Asset.neutralDark.color
        contactSearchButton.setImage(Asset.contactListSearch.image, for: .normal)
        contactSearchButton.addTarget(self, action: #selector(didTapContactSearchButton), for: .touchUpInside)

        contactListButton.tintColor = Asset.neutralDark.color
        contactListButton.setImage(Asset.chatListNew.image, for: .normal)
        contactListButton.addTarget(self, action: #selector(didTapContactListButton), for: .touchUpInside)

        titleLabel.text = Localized.ChatList.title
        titleLabel.textColor = Asset.neutralActive.color
        titleLabel.font = Fonts.Mulish.semiBold.font(size: 18.0)

        menu.tintColor = Asset.neutralDark.color
        menu.setImage(Asset.chatListMenu.image, for: .normal)
        menu.addTarget(self, action: #selector(didTapMenu), for: .touchUpInside)
        menu.snp.makeConstraints { $0.width.equalTo(50) }

        menu.addSubview(menuBadge)
        menuBadge.layer.cornerRadius = 5
        menuBadge.layer.masksToBounds = true
        menuBadge.snp.makeConstraints { make in
            make.centerY.equalTo(menu.snp.top)
            make.centerX.equalTo(menu.snp.right).multipliedBy(0.8)
        }

        menuBadge.textColor = Asset.neutralWhite.color
        menuBadge.backgroundColor = Asset.brandPrimary.color
        menuBadge.font = Fonts.Mulish.bold.font(size: 14.0)

        cancel.setTitleColor(Asset.neutralActive.color, for: .normal)
        cancel.titleLabel?.font = Fonts.Mulish.semiBold.font(size: 14.0)
        cancel.setTitle(Localized.ChatList.NavigationBar.cancel, for: .normal)

        menu.accessibilityIdentifier = Localized.Accessibility.ChatList.menu
    }

    private func setupBindings() {
        viewModel.hud
            .receive(on: DispatchQueue.main)
            .sink { [hud] in hud.update(with: $0) }
            .store(in: &cancellables)

        viewModel.chatsRelay
            .receive(on: DispatchQueue.main)
            .sink { [unowned self] in
                screenView.stackView.isHidden = !$0.isEmpty

                if $0.isEmpty {
                    screenView.bringSubviewToFront(screenView.stackView)
                }
            }.store(in: &cancellables)

        screenView.contactsButton
            .publisher(for: .touchUpInside)
            .receive(on: DispatchQueue.main)
            .sink { [unowned self] in coordinator.toContacts(from: self) }
            .store(in: &cancellables)

        screenView.searchView.textPublisher
            .removeDuplicates()
            .sink { [unowned self] in viewModel.searchQueryRelay.send($0) }
            .store(in: &cancellables)

        screenView.searchView.rightPublisher
            .receive(on: DispatchQueue.main)
            .sink { [unowned self] in coordinator.toScan(from: self) }
            .store(in: &cancellables)

        tableController.deletePublisher
            .receive(on: DispatchQueue.main)
            .sink { [unowned self] ip in
                if viewModel.isGroup(indexPath: ip) {
                    presentDrawer(
                        title: Localized.ChatList.DeleteGroup.title,
                        subtitle: Localized.ChatList.DeleteGroup.subtitle,
                        actionTitle: Localized.ChatList.DeleteGroup.action) { [weak self] in
                            self?.viewModel.deleteAndLeaveGroupFrom(indexPath: ip)
                        }
                } else {
                    presentDrawer(
                        title: Localized.ChatList.Delete.title,
                        subtitle: Localized.ChatList.Delete.subtitle,
                        actionTitle: Localized.ChatList.Delete.delete) { [weak self] in
                            self?.viewModel.delete(indexPaths: [ip])
                        }
                }
            }.store(in: &cancellables)

        viewModel.badgeCount
            .receive(on: DispatchQueue.main)
            .sink { [unowned self] in
                menuBadge.text = " \($0) "
                menuBadge.isHidden = $0 < 1
            }.store(in: &cancellables)

        viewModel.isOnline
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak screenView] in screenView?.displayNetworkIssue(!$0) }
            .store(in: &cancellables)
    }

    private func updateNavigationItems(_ isEditing: Bool) {
        let leftStack = UIStackView()
        leftStack.addArrangedSubview(titleLabel)

        let rightStack = UIStackView()
        rightStack.spacing = 10
        rightStack.addArrangedSubview(contactListButton)
        rightStack.addArrangedSubview(contactSearchButton)

        contactListButton.snp.makeConstraints { $0.width.equalTo(40) }
        contactSearchButton.snp.makeConstraints { $0.width.equalTo(40) }

        if !isEditing {
            leftStack.insertArrangedSubview(menu, at: 0)
            navigationItem.leftBarButtonItem = UIBarButtonItem(customView: leftStack)
        } else {
            navigationItem.leftBarButtonItem = UIBarButtonItem(
                customView: leftStack.pinning(at: .left(10))
            )
        }

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            customView: isEditing ? cancel : rightStack
        )
    }

    @objc private func didTapContactListButton() {
        coordinator.toContacts(from: self)
    }

    @objc private func didTapContactSearchButton() {
        coordinator.toSearch(from: self)
    }

    @objc private func didTapMenu() {
        coordinator.toSideMenu(from: self)
    }

    private func presentDrawer(
        title: String,
        subtitle: String,
        actionTitle: String,
        action: @escaping () -> Void
    ) {
        let actionButton = DrawerCapsuleButton(model: .init(
            title: actionTitle,
            style: .red
        ))

        let drawer = DrawerController(with: [
            DrawerText(
                font: Fonts.Mulish.bold.font(size: 26.0),
                text: title,
                color: Asset.neutralActive.color,
                alignment: .left,
                spacingAfter: 19
            ),
            DrawerText(
                font: Fonts.Mulish.regular.font(size: 16.0),
                text: subtitle,
                color: Asset.neutralBody.color,
                alignment: .left,
                lineHeightMultiple: 1.1,
                spacingAfter: 39
            ),
            actionButton
        ])

        actionButton.action.receive(on: DispatchQueue.main)
            .sink {
                drawer.dismiss(animated: true) { [weak self] in
                    guard let self = self else { return }
                    self.drawerCancellables.removeAll()
                    action()
                }
            }.store(in: &drawerCancellables)

        coordinator.toDrawer(drawer, from: self)
    }
}
