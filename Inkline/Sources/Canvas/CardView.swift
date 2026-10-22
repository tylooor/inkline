import UIKit

/// A page card on the whiteboard. Lives below the ink so you can draw across cards;
/// finger gestures on the canvas hit-test cards manually.
final class CardView: UIView {
    private(set) var cardID = UUID()
    private let imageView = UIImageView()
    private let caption = PaddedLabel()
    private let frozenBadge = UIImageView(image: UIImage(systemName: "snowflake"))

    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.cornerRadius = 14
        layer.cornerCurve = .continuous
        layer.shadowOffset = CGSize(width: 0, height: 4)
        layer.shadowRadius = 14
        layer.borderWidth = 0.5
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 14
        imageView.layer.cornerCurve = .continuous
        caption.font = .systemFont(ofSize: 11, weight: .semibold)
        caption.layer.cornerRadius = 8
        caption.layer.masksToBounds = true
        frozenBadge.contentMode = .scaleAspectFit
        [imageView, caption, frozenBadge].forEach(addSubview)
        isAccessibilityElement = true
        accessibilityIdentifier = "card"
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(_ render: CardRender, theme: Theme) {
        cardID = render.id
        imageView.image = render.image
        caption.text = render.title
        frozenBadge.isHidden = !render.frozen
        accessibilityLabel = render.title
        backgroundColor = theme.surface
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = theme.isDark ? 0.6 : 0.18
        layer.borderColor = (theme.isDark ? UIColor.white.withAlphaComponent(0.12) : UIColor.black.withAlphaComponent(0.08)).cgColor
        caption.textColor = theme.isDark ? .white : UIColor(hex: 0x2B2B30)
        caption.backgroundColor = (theme.isDark ? UIColor(hex: 0x2A2A2E) : UIColor.white).withAlphaComponent(0.9)
        frozenBadge.tintColor = theme.isDark ? .white : UIColor(hex: 0x2457C5)
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        imageView.frame = bounds
        let size = caption.sizeThatFits(CGSize(width: bounds.width - 16, height: 24))
        caption.frame = CGRect(x: 8, y: bounds.height - size.height - 8, width: min(size.width, bounds.width - 16), height: size.height)
        frozenBadge.frame = CGRect(x: bounds.width - 26, y: 8, width: 18, height: 18)
        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: 14).cgPath
    }
}

private final class PaddedLabel: UILabel {
    private let insets = UIEdgeInsets(top: 3, left: 7, bottom: 3, right: 7)

    override func drawText(in rect: CGRect) { super.drawText(in: rect.inset(by: insets)) }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let s = super.sizeThatFits(size)
        return CGSize(width: s.width + insets.left + insets.right, height: s.height + insets.top + insets.bottom)
    }
}
