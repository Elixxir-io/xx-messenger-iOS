import UIKit
import Shared
import InputField

final class OnboardingCodeView: UIView {
  let titleLabel = UILabel()
  let subtitleView = TextWithInfoView()
  let inputField = InputField()
  let nextButton = CapsuleButton()
  let resendButton = UIButton()
  let stackView = UIStackView()
  var didTapInfo: (() -> Void)?

  init() {
    super.init(frame: .zero)
    backgroundColor = Asset.neutralWhite.color

    setupTitle(Localized.Onboarding.EmailConfirmation.title)

    inputField.setup(
      placeholder: Localized.Onboarding.EmailConfirmation.input,
      subtitleColor: Asset.neutralWeak.color,
      allowsEmptySpace: false,
      keyboardType: .numberPad,
      autocapitalization: .none,
      contentType: .oneTimeCode
    )

    resendButton.setTitleColor(Asset.brandPrimary.color, for: .normal)
    resendButton.setTitleColor(Asset.neutralWeak.color, for: .disabled)
    resendButton.titleLabel?.font = Fonts.Mulish.semiBold.font(size: 14.0)
    resendButton.setTitle(Localized.Onboarding.EmailConfirmation.resend(""), for: .normal)

    nextButton.set(style: .brandColored, title: Localized.Onboarding.EmailConfirmation.next)
    nextButton.isEnabled = false

    stackView.spacing = 15
    stackView.axis = .vertical
    stackView.addArrangedSubview(nextButton)
    stackView.addArrangedSubview(resendButton)

    addSubview(titleLabel)
    addSubview(subtitleView)
    addSubview(inputField)
    addSubview(stackView)

    titleLabel.snp.makeConstraints {
      $0.top.equalToSuperview().offset(30)
      $0.left.equalToSuperview().offset(38)
      $0.right.equalToSuperview().offset(-41)
    }
    subtitleView.snp.makeConstraints {
      $0.top.equalTo(titleLabel.snp.bottom).offset(8)
      $0.left.equalToSuperview().offset(38)
      $0.right.equalToSuperview().offset(-41)
    }
    inputField.snp.makeConstraints {
      $0.top.equalTo(subtitleView.snp.bottom).offset(24)
      $0.left.equalToSuperview().offset(38)
      $0.right.equalToSuperview().offset(-38)
    }
    stackView.snp.makeConstraints {
      $0.top.greaterThanOrEqualTo(inputField.snp.bottom).offset(20)
      $0.left.equalToSuperview().offset(40)
      $0.right.equalToSuperview().offset(-40)
      $0.bottom.equalTo(safeAreaLayoutGuide).offset(-50)
    }
  }

  required init?(coder: NSCoder) { nil }

  func update(status: InputField.ValidationStatus) {
    inputField.update(status: status)

    switch status {
    case .valid:
      nextButton.isEnabled = true
    case .invalid, .unknown:
      nextButton.isEnabled = false
    }
  }

  private func setupTitle(_ title: String) {
    let attString = NSMutableAttributedString(string: title)
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .left
    paragraph.lineHeightMultiple = 1.0

    attString.addAttribute(.paragraphStyle, value: paragraph)
    attString.addAttribute(.foregroundColor, value: Asset.neutralActive.color)
    attString.addAttribute(.font, value: Fonts.Mulish.bold.font(size: 34.0) as Any)

    attString.addAttributes(attributes: [
      .font: Fonts.Mulish.bold.font(size: 34.0) as Any,
      .foregroundColor: Asset.brandPrimary.color
    ], betweenCharacters: "#")

    titleLabel.numberOfLines = 0
    titleLabel.attributedText = attString
  }

  public func setupSubtitle(_ subtitle: String) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .left
    paragraph.lineHeightMultiple = 1.15

    subtitleView.setup(
      text: subtitle,
      attributes: [
        .foregroundColor: Asset.neutralBody.color,
        .font: Fonts.Mulish.regular.font(size: 16.0) as Any,
        .paragraphStyle: paragraph
      ],
      didTapInfo: { [weak self] in self?.didTapInfo?() }
    )
  }
}