//
//  CollectionsTableViewController.swift
//  PhotographicHistory
//
//  Created by Lieven Dekeyser on 14/06/2021.
//

import UIKit
import Photos

class CollectionsTableViewController: UITableViewController {
	let collections: PHFetchResult<PHCollection>
	
	init() {
		collections = PHCollection.fetchTopLevelUserCollections(with: nil)
		
		super.init(style: .plain)
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return collections.count
	}
	
	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
		cell.textLabel?.text = collections[indexPath.row].localizedTitle
		return cell
	}
	
	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		tableView.deselectRow(at: indexPath, animated: true)
		
		if let collection = collections[indexPath.row] as? PHAssetCollection {
			let assets = PHAsset.fetchAssets(in: collection, options: nil)
			let gridView = PhotoGridViewController(fetchResult: assets)
			navigationController?.pushViewController(gridView, animated: true)
		}
	}
}
