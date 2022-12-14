import UIKit
import Shared
import SnapKit

final class CreateGroupView: UIView {
    let stackView = UIStackView()
    let tableView = UITableView()
    let searchComponent = SearchComponent()
    lazy var collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)

    let layout: UICollectionViewFlowLayout = {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 45
        layout.itemSize = CGSize(width: 56, height: 100)
        layout.scrollDirection = .horizontal
        return layout
    }()

    init() {
        super.init(frame: .zero)
        backgroundColor = Asset.neutralWhite.color

        tableView.separatorStyle = .none
        tableView.tintColor = Asset.brandPrimary.color
        tableView.backgroundColor = Asset.neutralWhite.color
        tableView.allowsMultipleSelectionDuringEditing = true
        tableView.setEditing(true, animated: true)

        searchComponent.set(
            placeholder: "Search connections",
            imageAtRight: UIImage.color(.clear)
        )

        collectionView.backgroundColor = Asset.neutralWhite.color
        collectionView.contentInset = UIEdgeInsets(top: 0, left: 30, bottom: 0, right: 30)

        stackView.spacing = 31
        stackView.axis = .vertical
        stackView.addArrangedSubview(collectionView)
        stackView.addArrangedSubview(tableView)

        addSubview(stackView)
        addSubview(searchComponent)

        searchComponent.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(20)
            make.left.equalToSuperview().offset(20)
            make.right.equalToSuperview().offset(-20)
        }

        stackView.snp.makeConstraints { make in
            make.top.equalTo(searchComponent.snp.bottom).offset(20)
            make.left.equalToSuperview()
            make.right.equalToSuperview()
            make.bottom.equalToSuperview()
        }

        collectionView.snp.makeConstraints { $0.height.equalTo(100) }
    }

    required init?(coder: NSCoder) { nil }
}
