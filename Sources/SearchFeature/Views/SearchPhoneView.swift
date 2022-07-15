import UIKit
import Shared

final class SearchPhoneView: UIView {
    let inputField = SearchComponent()

    init() {
        super.init(frame: .zero)

        inputField.set(
            placeholder: Localized.Ud.Search.Phone.input,
            imageAtRight: nil
        )

        addSubview(inputField)

        inputField.snp.makeConstraints {
            $0.top.equalToSuperview().offset(15)
            $0.left.equalToSuperview().offset(15)
            $0.right.equalToSuperview().offset(-15)
            $0.bottom.lessThanOrEqualToSuperview()
        }
    }

    required init?(coder: NSCoder) { nil }
}
