//
//  Protocols.swift
//  flotipios
//
//  Created by mattia poncini on 26.09.2024.
//

import Foundation

protocol FeedCellDelegate {
  /*  func handleUsernameTapped(for cell: FeedCell)
    func handleOptionsTapped(for cell: FeedCell)
    func handleLikeTapped(for cell: FeedCell, isDoubleTap: Bool)
    func handleCommentTapped(for cell: FeedCell)
    func handleConfigureLikeButton(for cell: FeedCell)
    func handleShowLikes(for cell: FeedCell)
    func configureCommentIndicatorView(for cell: FeedCell)
    func handleSaveTapped(for cell: FeedCell)  // Aggiungi questo metodo al protocollo
    func handleImageTapped(url: URL)  // Aggiungi questo metodo */



}

protocol UserCellDelegate {
    
    
    func handleImageclicked(url: URL)  // Aggiungi questo metodo

}


protocol UserProfileHeaderDelegate {
    func handleEditFollowTapped(for header: UserProfileHeader)
    func setUserStats(for header: UserProfileHeader)
    func handleFollowersTapped(for header: UserProfileHeader)
    func handleFollowingTapped(for header: UserProfileHeader)
}

protocol NotificationCellDelegate {
    //func handleFollowTapped(for cell: NotificationCell)
    //func handlePostTapped(for cell: NotificationCell)
}

protocol CommentInputAccesoryViewDelegate {
    func didSubmit(forComment comment: String)
}

protocol MessageInputAccesoryViewDelegate {
    func handleUploadMessage(message: String)
    func handleSelectImage()
}

/*protocol FollowCellDelegate {
    func handleFollowTapped(for cell: FollowLikeCell)
}

protocol ChatCellDelegate {
    func handlePlayVideo(for cell: ChatCell)
}

protocol MessageCellDelegate {
    func configureUserData(for cell: MessageCell)
}*/

protocol Printable {
    var description: String { get }
}






