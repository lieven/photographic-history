//
//  PhotoMapViewController.swift
//  PhotographicHistory
//
//  Created by Lieven Dekeyser on 14/06/2021.
//

import UIKit
import MapKit
import Photos

class ClusterAnnotationView: MKAnnotationView {
	
	// MARK: Initialization
	private let countLabel = UILabel()
	
	override var annotation: MKAnnotation? {
		didSet {
			guard let annotation = annotation as? MKClusterAnnotation else {
				return
			}
			
			countLabel.text = annotation.memberAnnotations.count < 100 ? "\(annotation.memberAnnotations.count)" : "99+"
		}
	}
	
	override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
		super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
		
		displayPriority = .defaultHigh
		collisionMode = .rectangle
		
		frame = CGRect(x: 0, y: 0, width: 41, height: 41)
		centerOffset = CGPoint(x: 0, y: -frame.size.height / 2)
		
		countLabel.textAlignment = .center
		countLabel.backgroundColor = UIColor.white
		countLabel.frame = self.bounds
		countLabel.autoresizingMask = [.flexibleWidth, .flexibleHeight]
		addSubview(countLabel)
	}
	
	@available(*, unavailable)
	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
}

class PhotoAnnotationView: MKAnnotationView {
	let imageView = UIImageView()
	var currentAssetIdentifier: String?
	
	
	override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
		super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
		
		displayPriority = .defaultHigh
		collisionMode = .rectangle
		
		frame = CGRect(x: 0, y: 0, width: 41, height: 41)
		centerOffset = CGPoint(x: 0, y: -frame.size.height / 2)
		
		imageView.contentMode = .scaleAspectFill
		imageView.clipsToBounds = true
		imageView.frame = self.bounds
		imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
		addSubview(imageView)
	}
	
	@available(*, unavailable)
	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
}

class PhotoAnnotation: NSObject, MKAnnotation {
	let asset: PHAsset
	let coordinate: CLLocationCoordinate2D
	
	init?(asset: PHAsset) {
		guard let location = asset.location else {
			return nil
		}
		
		self.asset = asset
		self.coordinate = location.coordinate
		
		super.init()
	}
}


class PhotoMapViewController: UIViewController, MKMapViewDelegate {
	let mapView = MKMapView(frame: .zero)
	let assets: [PHAsset]
	
	let imageManager = PHCachingImageManager()
	
	init(assets: [PHAsset]) {
		self.assets = assets
		super.init(nibName: nil, bundle: nil)
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		mapView.frame = view.bounds
		mapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
		view.addSubview(mapView)
		
		mapView.register(ClusterAnnotationView.self, forAnnotationViewWithReuseIdentifier: MKMapViewDefaultClusterAnnotationViewReuseIdentifier)
		mapView.register(PhotoAnnotationView.self, forAnnotationViewWithReuseIdentifier: MKMapViewDefaultAnnotationViewReuseIdentifier)
		
		mapView.delegate = self
		
		mapView.addAnnotations(assets.compactMap { PhotoAnnotation(asset: $0) })
	
	}
	
	func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
		if annotation is MKClusterAnnotation {
			return mapView.dequeueReusableAnnotationView(withIdentifier: MKMapViewDefaultClusterAnnotationViewReuseIdentifier, for: annotation)
		} else if let photoAnnotation = annotation as? PhotoAnnotation {
			guard let annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: MKMapViewDefaultAnnotationViewReuseIdentifier, for: annotation) as? PhotoAnnotationView else {
				fatalError("unexpected annotation view")
			}
			
			annotationView.clusteringIdentifier = "cluster"
			
			
			var targetSize = annotationView.imageView.frame.size
			targetSize.width *= 2.0
			targetSize.height *= 2.0
			
			annotationView.currentAssetIdentifier = photoAnnotation.asset.localIdentifier
			imageManager.requestImage(for: photoAnnotation.asset, targetSize: targetSize, contentMode: .aspectFill, options: nil) { [weak annotationView] image, _ in
				if let annotationView = annotationView, annotationView.currentAssetIdentifier == photoAnnotation.asset.localIdentifier {
					annotationView.imageView.image = image
				}
			}
			
			return annotationView
		} else {
			fatalError("Unexpected annotation type")
		}
	}
	
	func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
		guard let annotation = view.annotation else {
			return
		}
		
		if let clusterAnnotation = annotation as? MKClusterAnnotation {
			let assets = clusterAnnotation.memberAnnotations
				.compactMap { $0 as? PhotoAnnotation }
				.map { $0.asset }
			
			let gridView = PhotoGridViewController(assets: assets)
			navigationController?.pushViewController(gridView, animated: true)
		} else if let photoAnnotation = annotation as? PhotoAnnotation {
			let gridView = PhotoGridViewController(assets: [photoAnnotation.asset])
			navigationController?.pushViewController(gridView, animated: true)
		}
	}
}
