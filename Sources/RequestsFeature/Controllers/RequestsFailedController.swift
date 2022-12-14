import HUD
import UIKit
import Shared
import Combine
import DependencyInjection

final class RequestsFailedController: UIViewController {
    @Dependency private var hud: HUD

    lazy private var screenView = RequestsFailedView()
    private var cancellables = Set<AnyCancellable>()
    private let viewModel = RequestsFailedViewModel()
    private var dataSource: UICollectionViewDiffableDataSource<Section, Request>?

    override func loadView() {
        view = screenView
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        screenView.collectionView.register(RequestCell.self)
        dataSource = UICollectionViewDiffableDataSource<Section, Request>(
            collectionView: screenView.collectionView
        ) { collectionView, indexPath, request in

            let cell: RequestCell = collectionView.dequeueReusableCell(forIndexPath: indexPath)
            cell.setupFor(requestFailed: request)
            cell.didTapStateButton = { [weak self] in
                guard let self = self else { return }
                self.viewModel.didTapStateButtonFor(request: request)
            }
            return cell
        }

        viewModel.itemsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [unowned self] in
                dataSource?.apply($0, animatingDifferences: false)
                screenView.collectionView.isHidden = $0.numberOfItems == 0
            }.store(in: &cancellables)

        viewModel.hudPublisher
            .receive(on: DispatchQueue.main)
            .sink { [hud] in hud.update(with: $0) }
            .store(in: &cancellables)
    }
}
