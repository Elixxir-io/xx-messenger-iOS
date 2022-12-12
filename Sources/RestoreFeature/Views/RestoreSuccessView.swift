import UIKit
import Shared
import AppResources

final class RestoreSuccessView: UIView {
  let iconImageView = UIImageView()
  let titleLabel = UILabel()
  let subtitleLabel = UILabel()
  let nextButton = CapsuleButton()

  init() {
    super.init(frame: .zero)

    iconImageView.contentMode = .center
    iconImageView.image = Asset.onboardingSuccess.image
    nextButton.set(style: .white, title: Localized.Onboarding.Success.Action.next)

    subtitleLabel.numberOfLines = 0
    subtitleLabel.textColor = Asset.neutralWhite.color
    subtitleLabel.font = Fonts.Mulish.regular.font(size: 16.0)

    addSubview(iconImageView)
    addSubview(titleLabel)
    addSubview(subtitleLabel)
    addSubview(nextButton)

    iconImageView.snp.makeConstraints { make in
      make.top.equalTo(safeAreaLayoutGuide).offset(40)
      make.left.equalToSuperview().offset(40)
    }

    titleLabel.snp.makeConstraints { make in
      make.top.equalTo(iconImageView.snp.bottom).offset(40)
      make.left.equalToSuperview().offset(40)
      make.right.equalToSuperview().offset(-90)
    }

    subtitleLabel.snp.makeConstraints { make in
      make.top.equalTo(titleLabel.snp.bottom).offset(30)
      make.left.equalToSuperview().offset(40)
      make.right.equalToSuperview().offset(-90)
    }

    nextButton.snp.makeConstraints { make in
      make.left.equalToSuperview().offset(24)
      make.right.equalToSuperview().offset(-24)
      make.bottom.equalToSuperview().offset(-60)
    }

    setTitle(Localized.AccountRestore.Success.title)
    setSubtitle(Localized.AccountRestore.Success.subtitle)
  }

  required init?(coder: NSCoder) { nil }

  private func setTitle(_ title: String) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .left
    paragraph.lineHeightMultiple = 1.1

    let attrString = NSMutableAttributedString(string: title)

    attrString.addAttribute(.font, value: Fonts.Mulish.bold.font(size: 39.0))
    attrString.addAttribute(.foregroundColor, value: Asset.neutralWhite.color)

    attrString.addAttribute(
      name: .foregroundColor,
      value: Asset.neutralBody.color,
      betweenCharacters: "#"
    )

    titleLabel.numberOfLines = 0
    titleLabel.attributedText = attrString
  }

  private func setSubtitle(_ subtitle: String?) {
    subtitleLabel.text = subtitle
  }
}
