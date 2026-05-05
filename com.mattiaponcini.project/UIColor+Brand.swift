//
//  UIColor+Brand.swift
//  Flotip
//
//  Palette di brand: oro scuro su superfici crema chiare.
//  Tutti i colori usati nell'app dovrebbero passare da qui.
//

import UIKit

extension UIColor {

    enum Brand {
        /// Oro principale — usato per CTA, link, accent attivi.
        /// Scelto scuro per garantire contrasto AA su sfondo bianco.
        static let goldPrimary = UIColor(red: 0.435, green: 0.318, blue: 0.043, alpha: 1)   // #6F510B

        /// Oro secondario — usato per highlight, icone, badge.
        static let goldSecondary = UIColor(red: 0.722, green: 0.525, blue: 0.043, alpha: 1) // #B8860B

        /// Oro caldo — usato su sfondi scuri (feed, anteprima cattura) dove serve luminosità.
        static let goldOnDark = UIColor(red: 0.855, green: 0.647, blue: 0.125, alpha: 1)    // #DAA520

        /// Superficie crema — fondo morbido per campi e card.
        static let creamSurface = UIColor(red: 0.984, green: 0.965, blue: 0.906, alpha: 1)  // #FBF6E7

        /// Bordo crema — separatori sottili, bordi 0.5/1pt.
        static let creamBorder = UIColor(red: 0.925, green: 0.906, blue: 0.839, alpha: 1)   // #ECE7D6

        /// Rosso destructive (logout, errori).
        static let danger = UIColor(red: 0.639, green: 0.176, blue: 0.176, alpha: 1)        // #A32D2D
    }
}
