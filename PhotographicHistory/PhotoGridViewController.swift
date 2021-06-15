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
			updateNavigationItems()
		}
	}
	
	var allowUnrecognizablePeople: Bool = false {
		didSet {
			reload()
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
		
		updateTitle()
		updateNavigationItems()
		
		photos.onUpdate = { [weak self] in
			self?.reload()
			self?.updateTitle()
		}
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
				if case .matches = $0.check(allowUnrecognizablePeople: allowUnrecognizablePeople) {
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
		var title: String
		if isFiltered {
			title = "\(filteredPhotos.count) Filtered Photos"
		} else {
			title = "\(filteredPhotos.count) Photos"
		}
		
		if photos.isAnalyzing {
			title.append(" - Analyzing \(photos.photosToAnalyze.count) of \(photos.photos.count)")
		}
		
		self.title = title
	}
	
	func updateNavigationItems() {
		if isFiltered {
			navigationItem.rightBarButtonItems = [
				UIBarButtonItem(title: "Show All", style: .plain, target: self, action: #selector(showAllImages)),
				UIBarButtonItem(title: "Map View", style: .plain, target: self, action: #selector(showOnMap))
			]
			
		} else {
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
		
		collectionView.register(PhotoGridCell.self, forCellWithReuseIdentifier: PhotoGridCell.reuseIdentifier)
		
		collectionView.dataSource = dataSource
		collectionView.delegate = self
		
		reload()
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
		guard let cell: PhotoGridCell = collectionView.dequeueReusableCell(withReuseIdentifier: PhotoGridCell.reuseIdentifier, for: indexPath) as? PhotoGridCell else {
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
		let result = photo.check(allowUnrecognizablePeople: true)
		
		var message = "Asset "
		switch result {
		case .matches:
			message.append("matches!")
		case .noMatch(let reasons):
			message.append("does not match:")
			for reason in reasons {
				message.append("\n- ")
				message.append(reason.rawValue)
			}
		}
		
		if let observations = photo.classification {
			message.append("\n\nclassification:")
			for observation in observations {
				message.append("\n- ")
				message.append(observation.identifier)
			}
		}
		
		let alert = UIAlertController(title: "Photo", message: message, preferredStyle: .alert)
		alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
		present(alert, animated: true, completion: nil)
	}
}

extension Photo {
	func check(allowUnrecognizablePeople: Bool) -> HistoricPhotoMatch {
		var reasons = [HistoricPhotoMatch.NoMatchReasons]()
		
		if let observations = classification {
			let containsPeople = observations.contains { $0.identifier == "people" }
			if containsPeople {
				if allowUnrecognizablePeople, let faces = faces {
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

