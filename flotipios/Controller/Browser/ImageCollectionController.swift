//
//  ImageCollectionController.swift
//  flotipios
//
//  Created by mattia poncini on 07.10.2024.
//

import UIKit

private let reuseIdentifier = "ImageCell"

class ImageCollectionController: UICollectionViewController {
    
    // MARK: - Properties
    let imageNames = ["google", "yahoo", "bing"]
    
    // MARK: - Init
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        configureCollectionView()
    
    }
    
    func configureCollectionView() {
        collectionView?.backgroundColor = .white
        collectionView?.register(ImageCell.self, forCellWithReuseIdentifier: reuseIdentifier)
        
        if let flowLayout = collectionView?.collectionViewLayout as? UICollectionViewFlowLayout {
            flowLayout.scrollDirection = .horizontal
            flowLayout.itemSize = CGSize(width: 150, height: 150) // Dimensioni adatte per le immagini
        }
        
        collectionView.showsHorizontalScrollIndicator = false
    }
}
extension ImageCollectionController {
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return imageNames.count
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier, for: indexPath) as! ImageCell
        let imageName = imageNames[indexPath.item]
        cell.imageView.image = UIImage(named: imageName)
        return cell
    }
}
