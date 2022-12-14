import UIKit
import Shared
import Combine
import Permissions
import CombineSchedulers
import DependencyInjection

final class ScanController: UIViewController {
    @Dependency private var coordinator: ScanCoordinating
    @Dependency private var permissions: PermissionHandling

    lazy private var screenView = ScanView()

    var backgroundScheduler: AnySchedulerOf<DispatchQueue> = DispatchQueue.global().eraseToAnyScheduler()

    private var status: ScanStatus?
    private let camera: CameraType
    private let viewModel = ScanViewModel()
    private var cancellables = Set<AnyCancellable>()

    init(camera: CameraType = Camera()) {
         #if DEBUG
         self.camera = MockCamera()
         #else
        self.camera = camera
         #endif

        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { nil }

    override func loadView() {
        view = screenView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        screenView.layer.insertSublayer(camera.previewLayer, at: 0)
        setupBindings()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        camera.previewLayer.frame = screenView.bounds
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        viewModel.resetScanner()
        startCamera()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        backgroundScheduler.schedule { [weak self] in
            guard let self = self else { return }
            self.camera.stop()
        }
    }

    private func startCamera() {
        permissions.requestCamera { [weak self] granted in
            guard let self = self else { return }

            if granted {
                self.backgroundScheduler.schedule {
                    self.camera.start()
                }
            } else {
                DispatchQueue.main.async {
                    self.status = .failed(.cameraPermission)
                    self.screenView.update(with: .failed(.cameraPermission))
                }
            }
        }
    }

    private func setupBindings() {
        viewModel.contactPublisher
            .receive(on: DispatchQueue.main)
            .delay(for: 1, scheduler: DispatchQueue.main)
            .sink { [unowned self] in coordinator.toContact($0, from: self) }
            .store(in: &cancellables)

        viewModel.state
            .map(\.status)
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [unowned self] in
                status = $0
                screenView.update(with: $0)
            }.store(in: &cancellables)

        screenView.actionButton.publisher(for: .touchUpInside)
            .receive(on: DispatchQueue.main)
            .sink { [unowned self] in
                switch status {
                case .failed(.cameraPermission):
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                    UIApplication.shared.open(url, options: [:])
                case .failed(.requestOpened):
                    coordinator.toRequests(from: self)
                case .failed(.alreadyFriends):
                    coordinator.toContacts(from: self)
                default:
                    break
                }
            }.store(in: &cancellables)

        camera
            .dataPublisher
            .receive(on: DispatchQueue.main)
            .sink { [unowned self] data in viewModel.didScanData(data) }
            .store(in: &cancellables)
    }
}
