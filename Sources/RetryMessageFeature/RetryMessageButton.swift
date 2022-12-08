import UIKit
import Shared
import AppResources

final class RetryMessageButton: UIControl {
  let titleLabel = UILabel()
  let imageView = UIImageView()

  init() {
    super.init(frame: .zero)

    titleLabel.textColor = Asset.neutralBody.color
    titleLabel.font = Fonts.Mulish.bold.font(size: 14.0)

    addSubview(titleLabel)
    addSubview(imageView)

    imageView.snp.makeConstraints {
      $0.left.equalToSuperview().offset(40)
      $0.centerY.equalToSuperview()
    }

    titleLabel.snp.makeConstraints {
      $0.left.equalToSuperview().offset(84)
      $0.centerY.equalToSuperview()
      $0.top.equalToSuperview().offset(16)
    }
  }

  required init?(coder: NSCoder) { nil }
}