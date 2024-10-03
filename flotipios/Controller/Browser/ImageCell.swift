//
//  ImageCell.swift
//  flotipios
//
//  Created by mattia poncini on 30.09.2024.
//

import UIKit


class ImageCell: UICollectionViewCell {
    
    var imageView: UIImageView!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setupViews() {
        imageView = UIImageView(frame: self.bounds)
        imageView.contentMode = .scaleAspectFit
        contentView.addSubview(imageView)
    }
}
