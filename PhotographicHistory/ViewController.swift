//
//  ViewController.swift
//  PhotographicHistory
//
//  Created by Lieven Dekeyser on 14/06/2021.
//

import UIKit
import Photos
import Vision


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
	var availableWidth: CGFloat = 0.0
	
	static let minThumbnailSize: CGFloat = 100.0
	
	let layout: UICollectionViewFlowLayout = {
		let layout = UICollectionViewFlowLayout()
		layout.itemSize = CGSize(width: ViewController.minThumbnailSize, height: ViewController.minThumbnailSize)
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
		options.fetchLimit = 1000
		options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
		
		let fetchResult = PHAsset.fetchAssets(with: options)
		
		self.init(fetchResult: fetchResult)
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		collectionView.insetsLayoutMarginsFromSafeArea = true
		collectionView.backgroundColor = .white
		
		collectionView.register(PhotoCell.self, forCellWithReuseIdentifier: PhotoCell.reuseIdentifier)
	}
	
	override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        let width = view.bounds.inset(by: view.safeAreaInsets).width
        // Adjust the item size if the available width has changed.
        if availableWidth != width {
            availableWidth = width
            let columnCount = (availableWidth / ViewController.minThumbnailSize).rounded(.towardZero)
            let itemLength = (availableWidth - columnCount - 1) / columnCount
            layout.itemSize = CGSize(width: itemLength, height: itemLength)
            
            collectionView.reloadData()
        }
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
        var targetSize = layout.itemSize
        targetSize.width *= 2.0
        targetSize.height *= 2.0
        
        imageManager.requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFill, options: nil) { image, _ in
            if cell.currentAssetIdentifier == asset.localIdentifier {
                cell.imageView.image = image
            }
        }
		return cell
	}
	
	override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
		
		
		let asset = fetchResult.object(at: indexPath.item)
		
		if let location = asset.location {
			let alert = UIAlertController(title: "Photo", message: "Latitude: \(location.coordinate.latitude)\nLongitude: \(location.coordinate.longitude)", preferredStyle: .alert)
			alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
			present(alert, animated: true, completion: nil)
		}
		let options = PHImageRequestOptions()
		options.resizeMode = .none
		options.isNetworkAccessAllowed = true
		
		print("Requesting image...")
		imageManager.requestImageDataAndOrientation(for: asset, options: options) { [weak self] (data, _, orientation, _) in
			guard let data = data else {
				print("Couldn't get image")
				return
			}
			
			print("Analyzing image...")
			
			self?.analyzeImage(asset: asset, data: data, orientation: orientation)
		}
	}
	
	func analyzeImage(asset: PHAsset, data: Data, orientation: CGImagePropertyOrientation) {
		let imageRequestHandler = VNImageRequestHandler(data: data, orientation: orientation, options: [:])
		
		let classificationRequest = VNClassifyImageRequest { (request, error) in
			guard let observations = request.results as? [VNClassificationObservation] else {
				print("no observations?")
				return
			}
			
			let confidentObservations = observations.filter {
				$0.hasMinimumRecall(0.0, forPrecision: 0.9)
			}
			
			print("Confident observations:")
			for observation in confidentObservations {
				print("- \(observation.identifier)")
			}
			print("")
		}
		
		do {
			try imageRequestHandler.perform([classificationRequest])
		} catch {
			print("Error performing classification request: \(error.localizedDescription)")
		}
		
	}
}

