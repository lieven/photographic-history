//
//  PhotoCollection.swift
//  PhotographicHistory
//
//  Created by Lieven Dekeyser on 14/06/2021.
//

import Photos
import Vision


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
		
		for _ in 0..<10 {
			analyzeNext()
		}
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
		
		DispatchQueue.global(qos: .background).async {
			do {
				try imageRequestHandler.perform([classificationRequest, facesRequest])
			} catch {
				print("Error performing classification request: \(error.localizedDescription)")
			}
		}
		
		group.notify(queue: .main, execute: completion)
	}
}

