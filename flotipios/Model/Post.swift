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
    var didFlag = false // Stato di flagging
    var link: String? // Link del sito salvato
    var category: String? // Add this property

    

    init(postId: String, user: User?, dictionary: [String: AnyObject]) {
            self.postId = postId
            self.user = user

            self.caption = dictionary["caption"] as? String
            self.likes = dictionary["likes"] as? Int ?? 0
            self.imageUrl = dictionary["imageUrl"] as? String
            self.ownerUid = dictionary["ownerUid"] as? String
            if let creationDate = dictionary["creationDate"] as? Double {
                self.creationDate = Date(timeIntervalSince1970: creationDate)
            }
            self.link = dictionary["pageURL"] as? String
            self.category = dictionary["category"] as? String
        }

    func adjustLikes(addLike: Bool, completion: @escaping (Int) -> Void) {
        guard let currentUid = Auth.auth().currentUser?.uid, let postId = self.postId else { return }

        if addLike {
            USER_LIKES_REF.child(currentUid).updateChildValues([postId: 1]) { _, _ in
                POST_LIKES_REF.child(postId).updateChildValues([currentUid: 1]) { _, _ in
                    self.likes += 1
                    self.didLike = true
                    POSTS_REF.child(postId).child("likes").setValue(self.likes)
                    completion(self.likes)
                }
            }
        } else {
            USER_LIKES_REF.child(currentUid).child(postId).removeValue { _, _ in
                POST_LIKES_REF.child(postId).child(currentUid).removeValue { _, _ in
                    guard self.likes > 0 else { return }
                    self.likes -= 1
                    self.didLike = false
                    POSTS_REF.child(postId).child("likes").setValue(self.likes)
                    completion(self.likes)
                }
            }
        }
    }

    func deletePost(postId: String, completion: @escaping (Error?) -> Void) {
        guard let currentUid = Auth.auth().currentUser?.uid else {
            completion(NSError(domain: "PostErrorDomain", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"]))
            return
        }

        let databaseRef = Database.database().reference()
        let storageRef = Storage.storage().reference()

        let postRef = databaseRef.child("user_posts_sites").child(currentUid).child(postId)

        postRef.observeSingleEvent(of: .value) { snapshot in
            guard let postData = snapshot.value as? [String: AnyObject],
                  let imageUrlString = postData["imageUrl"] as? String else {
                completion(NSError(domain: "PostErrorDomain", code: 404, userInfo: [NSLocalizedDescriptionKey: "Post not found"]))
                return
            }

            // Delete the image from Firebase Storage
            storageRef.storage.reference(forURL: imageUrlString).delete { error in
                if let error = error {
                    print("Error deleting image: \(error.localizedDescription)")
                }
            }

            // Remove the post
            postRef.removeValue { error, _ in
                if let error = error {
                    completion(error)
                } else {
                    self.cleanupPostReferences(postId: postId, databaseRef: databaseRef)
                    completion(nil)
                }
            }
        }
    }

    private func cleanupPostReferences(postId: String, databaseRef: DatabaseReference) {
        // Remove likes
        databaseRef.child("post-likes").child(postId).removeValue { error, _ in
            if let error = error {
                print("Error removing likes: \(error.localizedDescription)")
            }
        }

        // Remove hashtags
        databaseRef.child("hashtags").observeSingleEvent(of: .value) { snapshot in
            if let hashtags = snapshot.value as? [String: [String: AnyObject]] {
                hashtags.forEach { hashtag, posts in
                    if posts[postId] != nil {
                        databaseRef.child("hashtags").child(hashtag).child(postId).removeValue { error, _ in
                            if let error = error {
                                print("Error removing hashtag \(hashtag): \(error.localizedDescription)")
                            }
                        }
                    }
                }
            }
        }

        // Remove from feeds
        databaseRef.child("user_feeds").observe(.childAdded) { snapshot in
            let userId = snapshot.key
            databaseRef.child("user_feeds").child(userId).child(postId).removeValue { error, _ in
                if let error = error {
                    print("Error removing from feed: \(error.localizedDescription)")
                }
            }
        }

        // Remove comments
        databaseRef.child("comments").child(postId).removeValue { error, _ in
            if let error = error {
                print("Error removing comments: \(error.localizedDescription)")
            }
        }
    }
}
