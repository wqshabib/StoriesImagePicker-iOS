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

protocol AlbumSearchResultsTableViewControllerDelegate: class {
    func searchDidSelect(_ album:Album)
}

class AlbumSearchResultsTableViewController: UITableViewController {
    
    var albums: [Album]? {
        didSet{
            filteredAlbums = albums
        }
    }
    private var filteredAlbums: [Album]?
    weak var searchBar: UISearchBar?
    weak var delegate: AlbumSearchResultsTableViewControllerDelegate?
}

extension AlbumSearchResultsTableViewController{
    // MARK: UITableViewDataSource

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filteredAlbums?.count ?? 0
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "AlbumSearchResultsTableViewCell", for: indexPath) as? AlbumSearchResultsTableViewCell,
            let album = filteredAlbums?[indexPath.item]
            else { return UITableViewCell() }
        
        cell.albumId = album.identifier
        
        album.coverAsset(completionHandler: {(asset, _) in
            cell.albumCoverImageView.setImage(from: asset, size: CGSize(width: tableView.rowHeight, height: tableView.rowHeight), validCellCheck: {
                return cell.albumId == album.identifier
            })
        })
        
        cell.imageCountLabel.text = "\(album.numberOfAssets)"
        
        // Color the matched part of the name black and gray out the rest
        if let searchQuery = self.searchBar?.text?.lowercased(), searchQuery != "", let albumName = album.localizedName, let matchRange = albumName.lowercased().range(of: searchQuery){
            let attributedString = NSMutableAttributedString(string: albumName, attributes: [.foregroundColor: UIColor.gray])
            attributedString.addAttribute(.foregroundColor, value: UIColor.black, range: NSRange(matchRange, in: albumName))
            
            cell.albumNameLabel.attributedText = attributedString
        }
        else{
            cell.albumNameLabel.text = album.localizedName
        }
        
        return cell
    }
}

extension AlbumSearchResultsTableViewController{
    // MARK: UITableViewDelegate
    
    override func tableView(_ tableView: UITableView, didEndDisplaying cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard let cell = cell as? AlbumSearchResultsTableViewCell else { return }
        cell.albumCoverImageView.image = nil
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let filteredAlbums = filteredAlbums else { return }
        
        self.delegate?.searchDidSelect(filteredAlbums[indexPath.row])
    }

}

extension AlbumSearchResultsTableViewController: UISearchResultsUpdating {
    // MARK: UISearchResultsUpdating Delegate
    
    func updateSearchResults(for searchController: UISearchController) {
        filteredAlbums = albums?.filter({(album) -> Bool in
            guard let albumName = album.localizedName?.lowercased() else { return false }
            guard let searchQuery = self.searchBar?.text?.lowercased(), searchQuery != "" else { return true }
            
            return albumName.contains(searchQuery)
        })
        
        // Avoid reloading when this vc is first shown
        let albumsCount = albums?.count ?? 0
        let filteredAlbumsCount = filteredAlbums?.count ?? 0
        if !(tableView.numberOfRows(inSection: 0) == albumsCount && albumsCount == filteredAlbumsCount){
            tableView.reloadSections(IndexSet(integer: 0), with: .automatic)
        }
        searchController.searchResultsController?.view.isHidden = false
    }
}
