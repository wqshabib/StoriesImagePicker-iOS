//
//  MIT License
//
//  Copyright (c) 2010-2018 Kite Tech Ltd. https://www.kite.ly
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

import UIKit
import Photos

protocol ChangeManager {
    func details(for fetchResult: PHFetchResult<PHAsset>) -> PHFetchResultChangeDetails<PHAsset>?
}

extension PHChange: ChangeManager {
    func details(for fetchResult: PHFetchResult<PHAsset>) -> PHFetchResultChangeDetails<PHAsset>? {
        return changeDetails(for: fetchResult)
    }
}

class PhotosAlbum: Album {
    
    let assetCollection: PHAssetCollection
    var assets = [Asset]()
    var hasMoreAssetsToLoad = false

    private var fetchedAssets: PHFetchResult<PHAsset>?
    lazy var assetManager: AssetManager = DefaultAssetManager()
    
    init(_ assetCollection: PHAssetCollection) {
        self.assetCollection = assetCollection
    }
    
    /// Returns the estimated number of assets for this album, which might not be available without calling loadAssets. It might differ from the actual number of assets. NSNotFound if not available.
    var numberOfAssets: Int {
        return !assets.isEmpty ? assets.count : assetCollection.estimatedAssetCount
    }
    
    var localizedName: String? {
        return assetCollection.localizedTitle
    }
    
    var identifier: String {
        return assetCollection.localIdentifier
    }
    
    func loadAssets(completionHandler: ((Error?) -> Void)?) {
        DispatchQueue.global(qos: .background).async { [weak welf = self] in
            welf?.loadAssetsFromPhotoLibrary()
            DispatchQueue.main.async {
                completionHandler?(nil)
            }
        }
    }
    
    func loadAssetsFromPhotoLibrary() {
        let fetchOptions = PHFetchOptions()
        fetchOptions.wantsIncrementalChangeDetails = true
        fetchOptions.includeHiddenAssets = false
        fetchOptions.includeAllBurstAssets = false
        fetchOptions.sortDescriptors = [ NSSortDescriptor(key: "creationDate", ascending: false) ]
        let fetchedAssets = assetManager.fetchAssets(in: assetCollection, options: fetchOptions)
        var assets = [Asset]()
        fetchedAssets.enumerateObjects({ (asset, _, _) in
            assets.append(PhotosAsset(asset, albumIdentifier: self.identifier))
        })
        
        self.assets = assets
        self.fetchedAssets = fetchedAssets
    }
    
    func coverAsset(completionHandler: @escaping (Asset?, Error?) -> Void) {
        assetCollection.coverAsset(useFirstImageInCollection: false, completionHandler: completionHandler)
    }
    
    func loadNextBatchOfAssets(completionHandler: ((Error?) -> Void)?) {}
    
    func changedAssets(for changeInstance: ChangeManager) -> ([Asset]?, [Asset]?) {
        guard let fetchedAssets = fetchedAssets,
            let changeDetails = changeInstance.details(for: fetchedAssets)
        else { return (nil, nil) }
        
        let insertedObjects = PhotosAsset.assets(from: changeDetails.insertedObjects, albumId: identifier)
        let removedObjects = PhotosAsset.assets(from: changeDetails.removedObjects, albumId: identifier)
        return (insertedObjects, removedObjects)
    }
}
