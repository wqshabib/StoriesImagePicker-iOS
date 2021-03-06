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

class PhotosAlbumManager: NSObject, AlbumManager {
    
    private struct Constants {
        static let permissionsTitle = NSLocalizedString("Controllers/EmptyScreenViewController/PermissionDeniedTitle",
                                                        value: "Permissions Required",
                                                        comment: "Title shown when the photo library access has been disabled")
        static let permissionsMessage = NSLocalizedString("Controllers/EmptyScreenViewController/PermissionDeniedMessage",
                                                          value: "Photo access has been restricted.\nYou can turn it back on in the system settings.",
                                                          comment: "Message shown when the photo library access has been disabled")
        static let permissionsButtonTitle = NSLocalizedString("Controllers/StoriesviewController/PermissionDeniedSettingsButton",
                                                              value: "Open Settings",
                                                              comment: "Button title to direct the user to the app permissions screen in the phone settings")
    }
    
    var albums:[Album] = [Album]()
    var hasMoreAlbumsToLoad = false
    let title = NSLocalizedString("Albums/Title", value: "Albums", comment: "Title for the Albums screen")
    static let imageManager = PHCachingImageManager()
    
    override init() {
        super.init()
        PHPhotoLibrary.shared().register(self)
    }
    
    func loadAlbums(completionHandler: ((Error?) -> Void)?) {
        guard albums.isEmpty else { completionHandler?(nil); return }
        
        guard PHPhotoLibrary.authorizationStatus() == .authorized else {
            let errorMessage = ActionableErrorMessage(title: Constants.permissionsTitle, message: Constants.permissionsMessage, buttonTitle: Constants.permissionsButtonTitle, buttonAction: {
                if let appSettings = URL(string: UIApplicationOpenSettingsURLString) {
                    UIApplication.shared.open(appSettings, options: [:], completionHandler: nil)
                }
            }, dismissErrorPromptAfterAction: false)
            completionHandler?(errorMessage)
            return
        }
        
        DispatchQueue.global(qos: .background).async {
            var albums = [Album]()
            
            let options = PHFetchOptions()
            options.wantsIncrementalChangeDetails = false
            options.includeHiddenAssets = false
            options.includeAllBurstAssets = false
            
            // Get "All Photos" album
            let fetchedResult = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .smartAlbumUserLibrary, options: options)
            if let collection = fetchedResult.firstObject{
                let album = PhotosAlbum(collection)
                
                // Load assets here so that we know the number of assets in this album
                album.loadAssetsFromPhotoLibrary()
                if !album.assets.isEmpty {
                    albums.append(album)
                }
                
            }
            
            // Get Favorites album
            if let collection = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .smartAlbumFavorites, options: options).firstObject{
                let album = PhotosAlbum(collection)
                
                // Load assets here so that we know the number of assets in this album
                album.loadAssetsFromPhotoLibrary()
                if !album.assets.isEmpty {
                    albums.append(album)
                }
            }
            
            // Get Selfies album
            if let collection = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .smartAlbumSelfPortraits, options: options).firstObject{
                let album = PhotosAlbum(collection)
                
                // Load assets here so that we know the number of assets in this album
                album.loadAssetsFromPhotoLibrary()
                if !album.assets.isEmpty {
                    albums.append(album)
                }
            }
            
            // Get Portrait album
            if #available(iOS 10.2, *) {
                if let collection = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .smartAlbumDepthEffect, options: options).firstObject{
                    let album = PhotosAlbum(collection)
                    
                    // Load assets here so that we know the number of assets in this album
                    album.loadAssetsFromPhotoLibrary()
                    if !album.assets.isEmpty {
                        albums.append(album)
                    }
                }
            }
            
            // Get Panoramas album
            if let collection = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .smartAlbumPanoramas, options: options).firstObject{
                let album = PhotosAlbum(collection)
                
                // Load assets here so that we know the number of assets in this album
                album.loadAssetsFromPhotoLibrary()
                if !album.assets.isEmpty {
                    albums.append(album)
                }
            }
            
            // Get User albums
            let collections = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: options)
            collections.enumerateObjects({ (collection, _, _) in
                guard collection.estimatedAssetCount != 0 else { return }
                let album = PhotosAlbum(collection)
                albums.append(album)
            })
            
            self.albums = albums
            
            DispatchQueue.main.async(execute: {() -> Void in
                completionHandler?(nil)
            })
        }
    }
    
    func loadNextBatchOfAlbums(completionHandler: ((Error?) -> Void)?) {
        // Maybe we can use this to load user albums after showing the system ones
    }
    
    func stopCachingImagesForAllAssets() {
        PhotosAlbumManager.imageManager.stopCachingImagesForAllAssets()
    }
    
    func startCachingImages(for assets: [Asset], targetSize: CGSize) {
        PhotosAlbumManager.imageManager.startCachingImages(for: PhotosAsset.photosAssets(from: assets), targetSize: targetSize, contentMode: .aspectFill, options: nil)
    }
    
    func stopCachingImages(for assets: [Asset], targetSize: CGSize) {
        PhotosAlbumManager.imageManager.stopCachingImages(for: PhotosAsset.photosAssets(from: assets), targetSize: targetSize, contentMode: .aspectFill, options: nil)
    }
}

extension PhotosAlbumManager: PHPhotoLibraryChangeObserver {
    
    func photoLibraryDidChange(_ changeInstance: PHChange) {
        var albumChanges = [AlbumChange]()
        
        DispatchQueue.main.sync {
            for album in albums {
                guard let album = album as? PhotosAlbum else { continue }
                let (assetsInserted, assetsRemoved) = album.changedAssets(for: changeInstance)
                
                if let assetsInserted = assetsInserted, let assetsRemoved = assetsRemoved,
                    !assetsInserted.isEmpty || !assetsRemoved.isEmpty {
                    
                    var indexesRemoved = [Int]()
                    for assetRemoved in assetsRemoved {
                        if let index = album.assets.index(where: { $0.identifier == assetRemoved.identifier}) {
                            indexesRemoved.append(index)
                        }
                    }
                    
                    albumChanges.append(AlbumChange(album: album, assetsRemoved: assetsRemoved, indexesRemoved: indexesRemoved, assetsInserted: assetsInserted))
                }
            }
            
            if !albumChanges.isEmpty {
                let dispatchGroup = DispatchGroup()
                
                for albumChange in albumChanges {
                    dispatchGroup.enter()
                    albumChange.album.loadAssets(completionHandler: { _ in
                        dispatchGroup.leave()
                    })
                }
                
                dispatchGroup.notify(queue: DispatchQueue.main, execute: {
                   NotificationCenter.default.post(name: AssetsNotificationName.albumsWereUpdated, object: albumChanges)
                })
                
            }
        }
    }
}
