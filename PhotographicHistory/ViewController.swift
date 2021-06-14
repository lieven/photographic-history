//
//  ViewController.swift
//  PhotographicHistory
//
//  Created by Lieven Dekeyser on 14/06/2021.
//

import UIKit
import Photos

class PhotoCell: UICollectionViewCell {
	static let reuseIdentifier = "PhotoCell"
	
	let imageView: UIImageView = {
		let imageView = UIImageView()
		imageView.contentMode = .scaleAspectFill
		imageView.clipsToBounds = true
		imageView.backgroundColor = .lightGray
		imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
		return imageView
	}()
	
	var currentAssetIdentifier: String?
	
	override init(frame: CGRect) {
		super.init(frame: frame)
		imageView.frame = contentView.bounds
		contentView.addSubview(imageView)
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
}


class ViewController: UICollectionViewController {
	let fetchResult: PHFetchResult<PHAsset>
	let imageManager = PHCachingImageManager()
	    
	let layout: UICollectionViewFlowLayout = {
		let layout = UICollectionViewFlowLayout()
		layout.itemSize = CGSize(width: 80.0, height: 80.0)
		layout.minimumLineSpacing = 8.0
		layout.minimumInteritemSpacing = 8.0
		layout.sectionInset = UIEdgeInsets(top: 8.0, left: 8.0, bottom: 8.0, right: 8.0)
		return layout
	}()

	init(fetchResult: PHFetchResult<PHAsset>) {
		self.fetchResult = fetchResult
		
		super.init(collectionViewLayout: layout)
	}
	
	convenience init() {
		let options = PHFetchOptions()
		options.fetchLimit = 100
		options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
		
		let fetchResult = PHAsset.fetchAssets(with: options)
		
		self.init(fetchResult: fetchResult)
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		collectionView.backgroundColor = .white
		
		collectionView.register(PhotoCell.self, forCellWithReuseIdentifier: PhotoCell.reuseIdentifier)
	}
	
	override func numberOfSections(in collectionView: UICollectionView) -> Int {
		return 1
	}
	
	override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
		return fetchResult.count
	}
	
	override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
		guard let cell: PhotoCell = collectionView.dequeueReusableCell(withReuseIdentifier: PhotoCell.reuseIdentifier, for: indexPath) as? PhotoCell else {
			fatalError("no cell?")
		}
		
		let asset = fetchResult.object(at: indexPath.item)
		
		cell.imageView.alpha = asset.location == nil ? 0.5 : 1.0
        cell.currentAssetIdentifier = asset.localIdentifier
        imageManager.requestImage(for: asset, targetSize: CGSize(width: 160.0, height: 160.0), contentMode: .aspectFill, options: nil) { image, _ in
            if cell.currentAssetIdentifier == asset.localIdentifier {
                cell.imageView.image = image
            }
        }
		return cell
	}


}

