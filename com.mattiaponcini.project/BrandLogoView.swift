//
//  BrandLogoView.swift
//  Flotip
//
//  Logo del brand: una bandierina dorata + wordmark "Flotip".
//  Disegnata in vettoriale via CAShapeLayer — scala perfettamente
//  a qualsiasi dimensione, segue il colore di brand.
//

import UIKit

/// Vista che disegna la sola bandierina (asta + drappo). Vettoriale.
final class FlagIconView: UIView {

    /// Colore del drappo. Default bianco (ritagliato su sfondo giallo).
    var flagColor: UIColor = .white { didSet { setNeedsLayout() } }

    /// Colore dell'asta. Default bianco.
    var poleColor: UIColor = .white { didSet { setNeedsLayout() } }

    private let poleLayer = CAShapeLayer()
    private let flagLayer = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        // Sfondo giallo brand; la bandiera bianca appare "ritagliata" su di esso.
        backgroundColor = .Brand.goldOnDark
        layer.cornerRadius = 8
        layer.masksToBounds = true
        layer.addSublayer(flagLayer)
        layer.addSublayer(poleLayer)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()

        let w = bounds.width
        let h = bounds.height
        guard w > 0, h > 0 else { return }

        // Proporzioni in unità relative su una grid 100x100, poi scaliamo
        // perché la bandiera resti centrata anche se la view è quadrata.
        // Asta verticale a sinistra, drappo che parte dall'alto verso destra.
        let poleX = w * 0.30
        let poleTop = h * 0.10
        let poleBottom = h * 0.92
        let poleWidth = max(2, w * 0.06)

        // Asta arrotondata
        let polePath = UIBezierPath(
            roundedRect: CGRect(x: poleX - poleWidth / 2,
                                y: poleTop,
                                width: poleWidth,
                                height: poleBottom - poleTop),
            cornerRadius: poleWidth / 2
        )
        poleLayer.path = polePath.cgPath
        poleLayer.fillColor = poleColor.cgColor

        // Drappo: rettangolo con angolo destro tagliato in pesce (swallow tail)
        let flagLeft = poleX + poleWidth / 2 - 0.5  // si sovrappone leggermente all'asta
        let flagTop = poleTop
        let flagRight = w * 0.92
        let flagBottom = h * 0.55
        let tailDepth = (flagRight - flagLeft) * 0.18

        let flag = UIBezierPath()
        flag.move(to: CGPoint(x: flagLeft, y: flagTop))
        flag.addLine(to: CGPoint(x: flagRight, y: flagTop))
        flag.addLine(to: CGPoint(x: flagRight - tailDepth, y: (flagTop + flagBottom) / 2))
        flag.addLine(to: CGPoint(x: flagRight, y: flagBottom))
        flag.addLine(to: CGPoint(x: flagLeft, y: flagBottom))
        flag.close()

        flagLayer.path = flag.cgPath
        flagLayer.fillColor = flagColor.cgColor
    }

    override var intrinsicContentSize: CGSize {
        return CGSize(width: 28, height: 28)
    }
}

/// Logo completo: bandierina + wordmark "Flotip" affiancato.
final class BrandLogoView: UIView {

    /// Dimensione del lockup. Layout grande per splash, medio per nav bar.
    enum Size {
        case large    // 88pt high
        case medium   // 44pt high
        case small    // 28pt high

        var height: CGFloat {
            switch self {
            case .large:  return 88
            case .medium: return 44
            case .small:  return 28
            }
        }
        var fontSize: CGFloat {
            switch self {
            case .large:  return 38
            case .medium: return 22
            case .small:  return 16
            }
        }
    }

    let flag = FlagIconView()
    let label: UILabel = {
        let l = UILabel()
        l.text = "Flotip"
        l.textColor = .Brand.goldPrimary
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    init(size: Size = .large) {
        super.init(frame: .zero)
        flag.translatesAutoresizingMaskIntoConstraints = false
        addSubview(flag)
        addSubview(label)

        label.font = .systemFont(ofSize: size.fontSize, weight: .semibold)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: size.height),

            flag.leadingAnchor.constraint(equalTo: leadingAnchor),
            flag.centerYAnchor.constraint(equalTo: centerYAnchor),
            flag.widthAnchor.constraint(equalTo: heightAnchor),
            flag.heightAnchor.constraint(equalTo: heightAnchor),

            label.leadingAnchor.constraint(equalTo: flag.trailingAnchor, constant: size.height * 0.18),
            label.trailingAnchor.constraint(equalTo: trailingAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
