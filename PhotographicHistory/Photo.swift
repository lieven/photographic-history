//
//  Photo.swift
//  PhotographicHistory
//
//  Created by Lieven Dekeyser on 14/06/2021.
//

import Photos
import Vision


class Photo: Hashable {
	let asset: PHAsset
	var classification: [VNClassificationObservation]?
	var faces: [VNFaceObservation]?
	
	init(asset: PHAsset) {
		self.asset = asset
	}
	
	func hash(into hasher: inout Hasher) {
		hasher.combine(asset.localIdentifier)
	}
	
	static func == (lhs: Photo, rhs: Photo) -> Bool {
		return lhs.asset.localIdentifier == rhs.asset.localIdentifier
	}
}
