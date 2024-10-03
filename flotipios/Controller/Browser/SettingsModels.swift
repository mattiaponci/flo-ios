//
//  SettingsModels.swift
//  flotipios
//
//  Created by mattia poncini on 30.09.2024.
//

import Foundation
import UIKit

struct SettingsSection {
    let title: String
    let options: [SettingOption]
}

struct SettingOption {
    let title: String
    let image: UIImage?
    let color: UIColor
    let handler: (() -> Void)
}
