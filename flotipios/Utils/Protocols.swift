//
//  Protocols.swift
//  flotipios
//
//  Created by mattia poncini on 26.09.2024.
//

import Foundation

protocol FeedCellDelegate {
    func handleUsernameTapped(for cell: FeedCell)
    func handleOptionsTapped(for cell: FeedCell)
    func handleLikeTapped(for cell: FeedCell, isDoubleTap: Bool)
    func handleCommentTapped(for cell: FeedCell)
    func handleConfigureLikeButton(for cell: FeedCell)
    func handleShowLikes(for cell: FeedCell)
    func configureCommentIndicatorView(for cell: FeedCell)
    func handleSaveTapped(for cell: FeedCell)  // Aggiungi questo metodo al protocollo
    func handleImageTapped(url: URL)  // Aggiungi questo metodo */
    func handleFlagToLike(for cell: FeedCell)



}
protocol PhotoCellDelegate {
    func handleUsernameTapped(for cell: PhotoCell)
    func handleOptionsTapped(for cell: PhotoCell)
    func handleLikeTapped(for cell: PhotoCell, isDoubleTap: Bool)
    func handleCommentTapped(for cell: PhotoCell)
    func handleConfigureLikeButton(for cell: PhotoCell)
    func handleShowLikes(for cell: PhotoCell)
    func configureCommentIndicatorView(for cell: PhotoCell)
    func handleSaveTapped(for cell: PhotoCell)  // Metodo aggiunto al protocollo
    func handleImageTapped(url: URL)  // Metodo aggiunto al protocollo
}
protocol UserCellDelegate{
    func handleCommentTapped(for cell: UserPostCell)
    func handleImageclicked(url: URL)  // Aggiungi questo metodo
    func handleLikeTapped(for cell: UserPostCell, isDoubleTap: Bool)
    func handleFlagToLike(for cell: UserPostCell, isDoubleTap: Bool)
    
    func handleOptionsTapped(for cell: UserPostCell, isDoubleTap: Bool)

}


protocol UserProfileHeaderDelegate {
    func handleEditFollowTapped(for header: UserProfileHeader)
    func setUserStats(for header: UserProfileHeader)
    func handleFollowersTapped(for header: UserProfileHeader)
    func handleFollowingTapped(for header: UserProfileHeader)
    func didTapBackToSearch() // Aggiungi questo metodo

}

protocol NotificationCellDelegate {
    func handleFollowTapped(for cell: NotificationCell)
    func handlePostTapped(for cell: NotificationCell)
}

protocol CommentInputAccesoryViewDelegate {
    func didSubmit(forComment comment: String)
}

protocol MessageInputAccesoryViewDelegate {
    func handleUploadMessage(message: String)
    func handleSelectImage()
}

protocol FollowCellDelegate {
    func handleFollowTapped(for cell: FollowLikeCell)
}

protocol ChatCellDelegate {
    func handlePlayVideo(for cell: ChatCell)
}

protocol MessageCellDelegate {
    func configureUserData(for cell: MessageCell)
}

protocol Printable {
    var description: String { get }
}






