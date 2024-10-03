//
//  Post.swift
//  flotipios
//
//  Created by mattia poncini on 29.09.2024.
//

import Firebase
import Foundation

class Post {
    var caption: String!
    var likes: Int!
    var imageUrl: String!
    var ownerUid: String!
    var creationDate: Date!
    var postId: String!
    var user: User?
    var didLike = false
    var link: String? // Field for the saved site's link

    init(postId: String!, user: User, dictionary: Dictionary<String, AnyObject>) {
        self.postId = postId
        self.user = user

        if let caption = dictionary["caption"] as? String {
            self.caption = caption
        }

        if let likes = dictionary["likes"] as? Int {
            self.likes = likes
        }

        if let imageUrl = dictionary["imageUrl"] as? String {
            self.imageUrl = imageUrl
        }

        if let ownerUid = dictionary["ownerUid"] as? String {
            self.ownerUid = ownerUid
        }

        if let creationDate = dictionary["creationDate"] as? Double {
            self.creationDate = Date(timeIntervalSince1970: creationDate)
        }

        // Assign the saved link if available
        if let link = dictionary["pageURL"] as? String {
            self.link = link
        }
    }

    func adjustLikes(addLike: Bool, completion: @escaping (Int) -> ()) {
        guard let currentUid = Auth.auth().currentUser?.uid else { return }
        guard let postId = self.postId else { return }

        if addLike {
            USER_LIKES_REF.child(currentUid).updateChildValues([postId: 1], withCompletionBlock: { (err, ref) in
                self.sendLikeNotificationToServer()

                POST_LIKES_REF.child(self.postId).updateChildValues([currentUid: 1], withCompletionBlock: { (err, ref) in
                    self.likes += 1
                    self.didLike = true
                    POSTS_REF.child(self.postId).child("likes").setValue(self.likes)
                    completion(self.likes)
                })
            })
        } else {
            USER_LIKES_REF.child(currentUid).child(postId).observeSingleEvent(of: .value, with: { (snapshot) in
                if let notificationID = snapshot.value as? String {
                    NOTIFICATIONS_REF.child(self.ownerUid).child(notificationID).removeValue(completionBlock: { (err, ref) in
                        self.removeLike(withCompletion: { (likes) in
                            completion(likes)
                        })
                    })
                } else {
                    self.removeLike(withCompletion: { (likes) in
                        completion(likes)
                    })
                }
            })
        }
    }

    func removeLike(withCompletion completion: @escaping (Int) -> ()) {
        guard let currentUid = Auth.auth().currentUser?.uid else { return }
        guard let postId = self.postId else { return }

        USER_LIKES_REF.child(currentUid).child(postId).removeValue(completionBlock: { (err, ref) in
            POST_LIKES_REF.child(postId).child(currentUid).removeValue(completionBlock: { (err, ref) in
                guard self.likes > 0 else { return }
                self.likes -= 1
                self.didLike = false
                POSTS_REF.child(self.postId).child("likes").setValue(self.likes)
                completion(self.likes)
            })
        })
    }

    func deletePost() {
        guard let currentUid = Auth.auth().currentUser?.uid else { return }
        guard let postId = self.postId else { return }

        // Delete the image from Firebase Storage
        Storage.storage().reference(forURL: self.imageUrl).delete(completion: nil)

        // Remove post from user and followers' feeds
        USER_FOLLOWER_REF.child(currentUid).observe(.childAdded) { (snapshot) in
            let followerUid = snapshot.key
            USER_FEED_REF.child(followerUid).child(postId).removeValue()
        }

        USER_FEED_REF.child(currentUid).child(postId).removeValue()

        // Remove post references in user and database nodes
        USER_POSTS_REF.child(currentUid).child(postId).removeValue()
        POSTS_REF.child(postId).removeValue()

        POST_LIKES_REF.child(postId).observe(.childAdded) { (snapshot) in
            let uid = snapshot.key

            USER_LIKES_REF.child(uid).child(postId).observeSingleEvent(of: .value, with: { (snapshot) in
                guard let notificationId = snapshot.value as? String else { return }

                NOTIFICATIONS_REF.child(self.ownerUid).child(notificationId).removeValue(completionBlock: { (err, ref) in
                    POST_LIKES_REF.child(postId).removeValue()
                    USER_LIKES_REF.child(uid).child(postId).removeValue()
                })
            })
        }

        // Remove hashtags related to the post
        let words = caption.components(separatedBy: .whitespacesAndNewlines)
        for var word in words {
            if word.hasPrefix("#") {
                word = word.trimmingCharacters(in: .punctuationCharacters)
                word = word.trimmingCharacters(in: .symbols)
                HASHTAG_POST_REF.child(word).child(postId).removeValue()
            }
        }

        COMMENT_REF.child(postId).removeValue()
    }

    func sendLikeNotificationToServer() {
        guard let currentUid = Auth.auth().currentUser?.uid else { return }
        let creationDate = Int(NSDate().timeIntervalSince1970)

        if currentUid != self.ownerUid {
            let values = ["checked": 0,
                          "creationDate": creationDate,
                          "uid": currentUid,
                          "type": LIKE_INT_VALUE,
                          "postId": postId] as [String: Any]

            let notificationRef = NOTIFICATIONS_REF.child(self.ownerUid).childByAutoId()
            notificationRef.updateChildValues(values, withCompletionBlock: { (err, ref) in
                USER_LIKES_REF.child(currentUid).child(self.postId).setValue(notificationRef.key)
            })
        }
    }
}

