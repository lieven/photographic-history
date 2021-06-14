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
		case notAnalyzed
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

class Photo: Hashable {
	static func == (lhs: Photo, rhs: Photo) -> Bool {
		return lhs.asset.localIdentifier == rhs.asset.localIdentifier
	}
	
	let asset: PHAsset
	var classification: [VNClassificationObservation]?
	var faces: [VNFaceObservation]?
	
	init(asset: PHAsset) {
		self.asset = asset
	}
	
	func hash(into hasher: inout Hasher) {
		hasher.combine(asset.localIdentifier)
	}
}

class PhotoCollection {
	let photos: [Photo]
	var photosToAnalyze: [Photo]
	let imageManager: PHCachingImageManager
	
	var onUpdate: (() -> Void)?
	
	var isAnalyzing: Bool {
		return photosToAnalyze.count > 0
	}
	
	init(photos: [Photo], imageManager: PHCachingImageManager) {
		self.photos = photos
		self.photosToAnalyze = photos.reversed()
		self.imageManager = imageManager
		
		analyzeNext()
	}
	
	func analyzeNext() {
		guard let nextPhoto = photosToAnalyze.popLast() else {
			return
		}
		
		analyze(photo: nextPhoto) { [weak self] in
			self?.onUpdate?()
			self?.analyzeNext()
		}
	}
	
	func analyze(photo: Photo, completion: @escaping () -> Void) {
		guard photo.asset.location != nil else {
			photo.classification = []
			photo.faces = []
			completion()
			return
		}
		
		let options = PHImageRequestOptions()
		options.resizeMode = .none
		options.isNetworkAccessAllowed = true
		
		print("Requesting image...")
		imageManager.requestImageDataAndOrientation(for: photo.asset, options: options) { [weak self] (data, _, orientation, _) in
			guard let data = data else {
				print("Couldn't get image")
				return
			}
			
			print("Analyzing image...")
			
			self?.analyzeImage(photo: photo, data: data, orientation: orientation, completion: completion)
		}
	}
	
	func analyzeImage(photo: Photo, data: Data, orientation: CGImagePropertyOrientation, completion: @escaping () -> Void) {
		let imageRequestHandler = VNImageRequestHandler(data: data, orientation: orientation, options: [:])
		
		let group = DispatchGroup()
		
		group.enter()
		let classificationRequest = VNClassifyImageRequest { (request, error) in
			defer {
				group.leave()
			}
			
			guard let observations = request.results as? [VNClassificationObservation] else {
				print("no observations?")
				photo.classification = []
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
			
			photo.classification = confidentObservations
		}
		
		group.enter()
		let facesRequest = VNDetectFaceRectanglesRequest { (request, error) in
			defer {
				group.leave()
			}
			
			guard let faceObservations = request.results as? [VNFaceObservation] else {
				print("no face observations?")
				photo.faces = []
					
				return
			}
			
			photo.faces = faceObservations // FIXME .filter { $0.confidence > 0.1 }
		}
		
		do {
			try imageRequestHandler.perform([classificationRequest, facesRequest])
		} catch {
			print("Error performing classification request: \(error.localizedDescription)")
		}
		
		group.notify(queue: .main, execute: completion)
	}
}



class PhotoGridViewController: UIViewController, UICollectionViewDelegate {
	enum Section {
		case main
	}
	typealias DataSource = UICollectionViewDiffableDataSource<Section, Photo>
	typealias Snapshot = NSDiffableDataSourceSnapshot<Section, Photo>

	let collectionView: UICollectionView
	
	lazy var dataSource: DataSource = {
		let dataSource = DataSource(
			collectionView: collectionView,
			cellProvider: { [weak self] (collectionView, indexPath, photo) -> UICollectionViewCell? in
				return self?.provideCellFor(collectionView, indexPath: indexPath, photo: photo)
			}
		)
		return dataSource
	}()
	
	let photos: PhotoCollection
	var filteredPhotos: [Photo]
	
	var isFiltered: Bool = false {
		didSet {
			guard oldValue != isFiltered else {
				return
			}
			reload()
			updateTitle()
		}
	}
	
	let imageManager: PHCachingImageManager
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
		let imageManager = PHCachingImageManager()
		let allPhotos = assets.map { Photo(asset: $0) }
		let photos = PhotoCollection(photos: allPhotos, imageManager: imageManager)
		
		self.photos = photos
		self.imageManager = imageManager
		self.filteredPhotos = allPhotos
		
		self.collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
		
		super.init(nibName: nil, bundle: nil)
		
		photos.onUpdate = { [weak self] in
			self?.reload()
			self?.updateTitle()
		}
		updateTitle()
	}
	
	convenience init() {
		let options = PHFetchOptions()
		options.fetchLimit = 400
		options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
		
		let fetchResult = PHAsset.fetchAssets(with: options)
		
		self.init(fetchResult: fetchResult)
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	func reload() {
		if isFiltered {
			filteredPhotos = photos.photos.filter {
				if case .matches = $0.check() {
					return true
				} else {
					return false
				}
			}
		} else {
			filteredPhotos = photos.photos
		}
		
		var snapshot = Snapshot()
		snapshot.appendSections([.main])
		snapshot.appendItems(filteredPhotos)
		dataSource.apply(snapshot, animatingDifferences: true)
	}
	
	@objc func filterImages() {
		isFiltered = true
	}
	
	@objc func showAllImages() {
		isFiltered = false
	}
	
	@objc func showOnMap() {
		navigationController?.pushViewController(PhotoMapViewController(assets: filteredPhotos.map { $0.asset }), animated: false)
	}
	
	func updateTitle() {
		if isFiltered {
			title = "\(filteredPhotos.count) Filtered Photos"
			navigationItem.rightBarButtonItems = [
				UIBarButtonItem(title: "Show All", style: .plain, target: self, action: #selector(showAllImages)),
				UIBarButtonItem(title: "Map View", style: .plain, target: self, action: #selector(showOnMap))
			]
			
		} else {
			title = "\(filteredPhotos.count) Photos"
			navigationItem.rightBarButtonItems = [
				UIBarButtonItem(title: "Filter", style: .plain, target: self, action: #selector(filterImages)),
				UIBarButtonItem(title: "Map View", style: .plain, target: self, action: #selector(showOnMap))
			]
		}
	}
	
	override func loadView() {
		self.view = collectionView
	}
	
	
	override func viewDidLoad() {
		super.viewDidLoad()
		collectionView.insetsLayoutMarginsFromSafeArea = true
		collectionView.backgroundColor = .white
		
		collectionView.register(PhotoCell.self, forCellWithReuseIdentifier: PhotoCell.reuseIdentifier)
		
		collectionView.dataSource = dataSource
		collectionView.delegate = self
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
	
	func provideCellFor(_ collectionView: UICollectionView, indexPath: IndexPath, photo: Photo) -> UICollectionViewCell {
		guard let cell: PhotoCell = collectionView.dequeueReusableCell(withReuseIdentifier: PhotoCell.reuseIdentifier, for: indexPath) as? PhotoCell else {
			fatalError("no cell?")
		}
		
		let asset = photo.asset
		
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
	
	func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
		let photo = filteredPhotos[indexPath.item]
		let result = photo.check()
		
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
		present(alert, animated: true, completion: nil)
	}
}

extension Photo {
	func check() -> HistoricPhotoMatch {
		var reasons = [HistoricPhotoMatch.NoMatchReasons]()
		
		if let observations = classification {
			let containsPeople = observations.contains { $0.identifier == "people" }
			if containsPeople {
				if let faces = faces {
					if faces.count > 0 {
						reasons.append(.containsPeople)
					}
				} else {
					reasons.append(.containsPeople)
				}
			}
			
			let isOutdoors = observations.contains { $0.identifier == "outdoor" }
			if !isOutdoors {
				reasons.append(.notOutdoors)
			}
			let isDocument = observations.contains { $0.identifier == "document" }
			if isDocument {
				reasons.append(.isDocument)
			}
		} else {
			reasons.append(.notAnalyzed)
		}
		
		if reasons.count > 0 {
			return .noMatch(reasons)
		} else {
			return .matches
		}
	}
}

