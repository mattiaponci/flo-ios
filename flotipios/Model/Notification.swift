import Foundation

class Notification {
    // MARK: - Notification Type Enum
    enum NotificationType: Int, CustomStringConvertible {
        case follow = 0
        case newPost = 1
        case like = 2
        case comment = 3

        var description: String {
            switch self {
            case .follow: return "started following you"
            case .newPost: return "posted a new post"
            case .like: return "liked your post"
            case .comment: return "commented on your post"
            }
        }

        init(index: Int) {
            switch index {
            case 0: self = .follow
            case 1: self = .newPost
            case 2: self = .like
            case 3: self = .comment
            default: self = .follow
            }
        }
    }

    // MARK: - Properties
    var creationDate: Date
    var uid: String
    var postId: String?
    var post: Post?
    var user: User
    var notificationType: NotificationType
    var postImageUrl: String?
    var commentText: String?
    var didCheck: Bool

    // MARK: - Initializer
    init(user: User, post: Post? = nil, dictionary: [String: AnyObject]) {
        self.user = user
        self.post = post
        self.creationDate = Date(timeIntervalSince1970: dictionary["creationDate"] as? Double ?? 0)
        self.notificationType = NotificationType(index: dictionary["type"] as? Int ?? 0)
        self.uid = dictionary["uid"] as? String ?? ""
        self.postId = dictionary["postId"] as? String
        self.postImageUrl = dictionary["postImageUrl"] as? String
        self.commentText = dictionary["commentText"] as? String
        self.didCheck = (dictionary["checked"] as? Int ?? 0) != 0
    }

    // MARK: - Methods
    func markAsRead() {
        self.didCheck = true
        // Logica per aggiornare lo stato nel database può essere aggiunta qui
    }

    func isRelatedToPost() -> Bool {
        return postId != nil || postImageUrl != nil
    }

    func getFormattedCreationDate() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: creationDate)
    }

    func getNotificationDetails() -> String {
        switch notificationType {
        case .follow:
            return "\(user.username) \(notificationType.description)"
        case .newPost:
            return "\(user.username) \(notificationType.description)"
        case .like:
            return "\(user.username) \(notificationType.description)"
        case .comment:
            if let comment = commentText {
                return "\(user.username) \(notificationType.description): \"\(comment)\""
            } else {
                return "\(user.username) \(notificationType.description)"
            }
        }
    }
}
