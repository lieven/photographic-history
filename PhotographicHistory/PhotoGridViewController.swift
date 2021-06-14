//
//  ViewController.swift
//  PhotographicHistory
//
//  Created by Lieven Dekeyser on 14/06/2021.
//

import UIKit
import Photos
import Vision

enum HistoricPhotoMatch {
	enum NoMatchReasons: String {
		case noLocation
		case containsPeople
		case notOutdoors
		case isDocument
		case containsLicensePlate
	}
	case matches
	case noMatch([NoMatchReasons])
}


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


class PhotoGridViewController: UICollectionViewController {
	let allAssets: [PHAsset]
	var remainingAssets: [PHAsset] = []
	
	var filteredAssets: [PHAsset] {
		didSet {
			collectionView.reloadData()
		}
	}
	
	let imageManager = PHCachingImageManager()
	var availableWidth: CGFloat = 0.0
	
	static let minThumbnailSize: CGFloat = 100.0
	
	let layout: UICollectionViewFlowLayout = {
		let layout = UICollectionViewFlowLayout()
		layout.itemSize = CGSize(width: PhotoGridViewController.minThumbnailSize, height: PhotoGridViewController.minThumbnailSize)
		layout.minimumLineSpacing = 8.0
		layout.minimumInteritemSpacing = 8.0
		layout.sectionInset = UIEdgeInsets(top: 8.0, left: 8.0, bottom: 8.0, right: 8.0)
		return layout
	}()
	
	convenience init(fetchResult: PHFetchResult<PHAsset>) {
		var assets = [PHAsset]()
		fetchResult.enumerateObjects { (asset, _, _) in
			assets.append(asset)
		}
		self.init(assets: assets)
	}
	
	init(assets: [PHAsset]) {
		self.allAssets = assets
		self.filteredAssets = assets
		super.init(collectionViewLayout: layout)
	}
	
	convenience init() {
		let options = PHFetchOptions()
		options.fetchLimit = 400
		options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
		
		let fetchResult = PHAsset.fetchAssets(with: options)
		
		self.init(fetchResult: fetchResult)
		
		navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Filter", style: .done, target: self, action: #selector(filterImages))
		navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Show on Map", style: .done, target: self, action: #selector(showOnMap))
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	@objc func filterImages() {
		remainingAssets = allAssets
		filteredAssets = []
		
		for _ in 0..<10 {
			filterNext()
		}
	}
	
	@objc func showOnMap() {
		navigationController?.pushViewController(PhotoMapViewController(assets: filteredAssets), animated: false)
	}
	
	func updateTitle() {
		if remainingAssets.count > 0 {
			title = "Filtering \(remainingAssets.count)/\(allAssets.count)"
		} else if filteredAssets.count == allAssets.count {
			title = "\(allAssets.count) Photos"
		} else {
			title = "\(filteredAssets.count) Filtered Photos"
		}
	}
	
	func filterNext() {
		guard let asset = remainingAssets.popLast() else  {
			print("done filtering")
			updateTitle()
			return
		}
		
		updateTitle()
		
		analyze(asset: asset) { [weak self] result in
			guard let self = self else {
				return
			}
			
			switch result {
			case .matches:
				self.filteredAssets.append(asset)
			case .noMatch(let reasons):
				print("hiding image because of \(reasons.map({$0.rawValue}).joined(separator: ", "))")
				break
			}
			
			self.filterNext()
		}
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
            let columnCount = (availableWidth / PhotoGridViewController.minThumbnailSize).rounded(.towardZero)
            let itemLength = (availableWidth - columnCount - 1) / columnCount
            layout.itemSize = CGSize(width: itemLength, height: itemLength)
            
            collectionView.reloadData()
        }
    }
	
	override func numberOfSections(in collectionView: UICollectionView) -> Int {
		return 1
	}
	
	override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
		return filteredAssets.count
	}
	
	override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
		guard let cell: PhotoCell = collectionView.dequeueReusableCell(withReuseIdentifier: PhotoCell.reuseIdentifier, for: indexPath) as? PhotoCell else {
			fatalError("no cell?")
		}
		
		let asset = filteredAssets[indexPath.item]
		
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
		
		
		let asset = filteredAssets[indexPath.item]
		analyze(asset: asset) { [weak self] result in
			var message = "Asset "
			switch result {
			case .matches:
				message.append("matches!")
			case .noMatch(let reasons):
				message.append("does not match:\n")
				for reason in reasons {
					message.append("- ")
					message.append(reason.rawValue)
				}
			}
			
			let alert = UIAlertController(title: "Photo", message: message, preferredStyle: .alert)
			alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
			self?.present(alert, animated: true, completion: nil)
		}
	}
	
	func analyze(asset: PHAsset, completion: @escaping (HistoricPhotoMatch) -> Void) {
		guard asset.location != nil else {
			completion(.noMatch([.noLocation]))
			return
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
			
			self?.analyzeImage(data: data, orientation: orientation, completion: completion)
		}
	}
	
	func analyzeImage(data: Data, orientation: CGImagePropertyOrientation, completion: @escaping (HistoricPhotoMatch) -> Void) {
		let imageRequestHandler = VNImageRequestHandler(data: data, orientation: orientation, options: [:])
		
		let classificationRequest = VNClassifyImageRequest { [weak self] (request, error) in
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
			
			self?.check(observations: confidentObservations, completion: completion)
		}
		
		do {
			try imageRequestHandler.perform([classificationRequest])
		} catch {
			print("Error performing classification request: \(error.localizedDescription)")
		}
	}
	
	func check(observations: [VNClassificationObservation], completion: @escaping (HistoricPhotoMatch) -> Void) {
		var reasons = [HistoricPhotoMatch.NoMatchReasons]()
		
		let containsPeople = observations.contains { $0.identifier == "people" }
		if containsPeople {
			// TODO: use Vision framework to see if their faces are recognizable
			reasons.append(.containsPeople)
		}
		
		let isOutdoors = observations.contains { $0.identifier == "outdoor" }
		if !isOutdoors {
			reasons.append(.notOutdoors)
		}
		let isDocument = observations.contains { $0.identifier == "document" }
		if isDocument {
			reasons.append(.isDocument)
		}
		
		if reasons.count > 0 {
			completion(.noMatch(reasons))
		} else {
			completion(.matches)
		}
	}
}

