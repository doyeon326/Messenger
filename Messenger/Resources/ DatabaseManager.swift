//
//   DatabaseManager.swift
//  Messenger
//
//  Created by Tony Jung on 2021/01/28.
//

import Foundation
import FirebaseDatabase

final class DatabaseManager {
    static let shared = DatabaseManager()
    
    private let database = Database.database().reference()

    static func safeEmail(emailAddress: String) -> String{
        var safeEmail = emailAddress.replacingOccurrences(of: ".", with: "-")
        safeEmail = safeEmail.replacingOccurrences(of: "@", with: "-")
        return safeEmail
    }
  
}
// MARK: - Account Management
extension DatabaseManager {
    public func userExists(with email: String, completion: @escaping ((Bool)-> Void) ) {
        
        var safeEmail = email.replacingOccurrences(of: ".", with: "-")
        safeEmail = safeEmail.replacingOccurrences(of: "@", with: "-")
        print("\(safeEmail)")
        
        database.child(safeEmail).observeSingleEvent(of: .value) { (snapshot) in
            guard snapshot.value as? String != nil else {
              completion(false)
                return
            }
            completion(true)
        }
    }
    ///Insert new user to databse
    public func insertUser(with user: ChatAppUser, completion: @escaping (Bool) -> Void){
        print("insert : \(user.safeEmail)")
        database.child(user.safeEmail).setValue([
            "first_name": user.firstName,
            "last_name": user.lastName
        ], withCompletionBlock: { error, _ in
            guard error == nil else {
                print("failed to write to database")
                completion(false)
                return
            }
      
            self.database.child("users").observeSingleEvent(of: .value, with: { snapshot in
                if var usersCollection = snapshot.value as? [[String: String]] {
                    //append to user dictionary
                    let newElement = [
                        "name" : user.firstName + " " + user.lastName,
                        "email" : user.safeEmail
                    ]
                    
                    usersCollection.append(newElement)
                    
                    self.database.child("users").setValue(usersCollection, withCompletionBlock: { error, _ in
                        guard error == nil else {
                            completion(false)
                            return
                        }
                        completion(true)
                    })
                }
                else {
                    //create that array
                    let newCollection: [[String: String]] = [
                        ["name" : user.firstName + " " + user.lastName,
                         "email" : user.safeEmail
                        ]
                    ]
                    self.database.child("users").setValue(newCollection, withCompletionBlock: { error, _ in
                        guard error == nil else {
                            return
                        }
                        completion(true)
                        
                    })
                }
            })
            
        })
    }
    public func getAllUsers(completion: @escaping (Result<[[String:String]], Error>)-> Void) {
        database.child("users").observeSingleEvent(of: .value, with: { [weak self] snapshot in
            guard let value = snapshot.value as? [[String: String]] as? [[String:String]] else {
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            completion(.success(value))
        })
    }
    
    public enum DatabaseError: Error {
        case failedToFetch
    }
}




// MARK: - sendidng messages / conversations
extension DatabaseManager {
    /*
    Users=>  [
        [
            "어나ㅣ런ㅇㄹㄴ "  {
            "messages": [
                    {
                    "id": String
                    "type": text, photo, video,
                    "content": String,
                    "date": Date(),
                    "sender_email": String,
                    "isRead": true/false
                    }
                ]
            }
            "conversation_id":
            "other_user_email":
            "latest_message": => {
                "date" : Date()
                "latest_message": "message"
                "is_read": true / false
            }
        ],
        [
        ]
     
     ]*/
    
    //creates a new conversation with target user email and first message sent
    public func createNewConversation(with otherUserEmail: String,name: String, firstMessage: Message, completion: @escaping (Bool)-> Void){
        guard let currentEmail = UserDefaults.standard.value(forKey: "email") as? String else {
            return
        }
        let safeEmail = DatabaseManager.safeEmail(emailAddress: currentEmail)
        let ref = database.child("\(safeEmail)")
        ref.observeSingleEvent(of: .value, with: { snapshot in
            guard var userNode = snapshot.value as? [String: Any] else {
                completion(false)
                print("user not fofund")
                return
                
            }
            
            let messageDate = firstMessage.sentDate
            let dateString = ChatViewController.dateFormatter.string(from: messageDate)
            var message = ""
            
            switch firstMessage.kind {
           
            case .text(let messageText):
                message = messageText
            case .attributedText(_):
                break
            case .photo(_):
                break
            case .video(_):
                break
            case .location(_):
                break
            case .emoji(_):
                break
            case .audio(_):
                break
            case .contact(_):
                break
            case .linkPreview(_):
                break
            case .custom(_):
                break
            }
            let conversationId = "conversaion_\(firstMessage.messageId)"
            
            let newConversationData: [String:Any] = [
                "id": conversationId,
                "other_user_email" : otherUserEmail,
                "name": name,
                "latest_message": [
                    "date": dateString,
                    "message": message,
                    "is_read":false
                ]
            ]
            
            
            
            let recipient_newConversationData: [String:Any] = [
                "id": conversationId,
                "other_user_email" : safeEmail,
                "name": "Self",
                "latest_message": [
                    "date": dateString,
                    "message": message,
                    "is_read":false
                ]
            ]
            //Update recipient conversationn entry
            self.database.child("\(otherUserEmail)/conversations").observeSingleEvent(of: .value, with: { [weak self] snapshot in
                if var conversations = snapshot.value as? [[String: Any]] {
                    //append
                    conversations.append(recipient_newConversationData)
    
                    self?.database.child("\(otherUserEmail)/conversations").setValue(conversationId)
                }
                else {
                    //create
                    self?.database.child("\(otherUserEmail)/conversations").setValue([recipient_newConversationData])
                }
            })
            //Update current user converesation entry
            if var conversation = userNode["conversations"] as? [[String: Any]] {
                //conversation array exists for current user
                //you should append
                
                conversation.append(newConversationData)
                userNode["conversation"] = conversation
                ref.setValue(userNode, withCompletionBlock: { [weak self] error, _ in
                    guard error == nil else {
                        completion(false)
                        return
                    }
                    self?.finishCreatingConversation(conversationID: conversationId, firstMessage: firstMessage, name: name, completion: completion)
                })
            }
            else {
                //conversation array does not exists,
                //create it
                userNode["conversations"] = [
                    newConversationData
                ]
                
                ref.setValue(userNode, withCompletionBlock: { [weak self] error, _ in
                    guard error == nil else {
                        completion(false)
                        return
                    }
                    self?.finishCreatingConversation(conversationID: conversationId, firstMessage: firstMessage, name: name, completion: completion)

                })
            }
            
        })
        
        
    }
    
    
    private func finishCreatingConversation(conversationID: String, firstMessage: Message, name: String, completion: @escaping (Bool) -> Void) {
        var message = ""
        
        switch firstMessage.kind {
        
        case .text(let messageText):
            message = messageText
        case .attributedText(_):
            break
        case .photo(_):
            break
        case .video(_):
            break
        case .location(_):
            break
        case .emoji(_):
            break
        case .audio(_):
            break
        case .contact(_):
            break
        case .linkPreview(_):
            break
        case .custom(_):
            break
        }
        
        
        
        let messageDate = firstMessage.sentDate
        let dateString = ChatViewController.dateFormatter.string(from: messageDate)
        
        guard let myEmail = UserDefaults.standard.value(forKey: "email") as? String else {
            completion(false)
            return
        }
        let  currentUserEmail = DatabaseManager.safeEmail(emailAddress: myEmail)
        
        let collectionMessage: [String: Any] = [
            "id": firstMessage.messageId,
            "type": firstMessage.kind.messageKindString,
            "content": message,
            "date": dateString,
            "sender_email": currentUserEmail,
            "is_read": false,
            "name": name
        ]
        let value: [String: Any] = [
            "messages": [
                collectionMessage
            ]
        ]
        database.child("\(conversationID)").setValue(value, withCompletionBlock: { error, snapshot in
            guard error == nil else {
                completion(false)
                return
            }
            completion(true)
        })
    }
    //Fetches and returns all conversations for the user with passed in email
    public func getAllConversation(for email: String, completion: @escaping (Result<[Conversation], Error>)-> Void){
        database.child("\(email)/conversations").observe(.value, with: { snapshot in
            guard let value = snapshot.value as? [[String : Any]] else {
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            let conversations: [Conversation] = value.compactMap({ dictionary in
                guard let conversationId = dictionary["id"] as? String,
                      let name = dictionary["name"] as? String,
                      let otherUserEmail = dictionary["other_user_email"] as? String,
                      let latestMessage = dictionary["latest_message"] as? [String: Any],
                      let date = latestMessage["date"] as? String,
                      let message = latestMessage["message"] as? String,
                      let isRead = latestMessage["is_read"] as? Bool else {
                        return nil
                }
                
                let latestMessageObject = LatestMessage(date: date, text: message, isRead: isRead)
                return Conversation(id: conversationId, name: name, otherUserEmail: otherUserEmail, latestMessage: latestMessageObject)
            })
            completion(.success(conversations))
        })
    }
    // Gets all messages for a given conversationn
    public func getAllMessagesForConversation(with id: String, completion: @escaping(Result<[Message], Error> ) -> Void){
        database.child("\(id)/messages").observe(.value, with: { snapshot in
            guard let value = snapshot.value as? [[String : Any]] else {
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            let messages: [Message] = value.compactMap({ dictionary in
                guard let name = dictionary["name"] as? String,
                      let isRead = dictionary["is_read"] as? Bool,
                      let messageID = dictionary["id"] as? String,
                      let content = dictionary["content"] as? String,
                      let senderEmail = dictionary["sender_email"] as? String,
                      let type = dictionary["type"] as? String,
                      let dateString = dictionary["date"] as? String,
                      let date = ChatViewController.dateFormatter.date(from: dateString) else {
                    return nil
                }
                let sender = Sender(photoURL: "", senderId: senderEmail, displayName: name)
                return Message(sender: sender, messageId: messageID, sentDate: date, kind: .text(content))
            })
            completion(.success(messages))
        })
    }
    // Sends a message with target conversation and message
    public func sendMessage(to conversation: String, message: Message, completion: @escaping (Bool) -> Void) {
        
    }
    
}
struct ChatAppUser {
    let firstName: String
    let lastName: String
    let emailAddress: String
    
    var safeEmail: String{
        var safeEmail = emailAddress.replacingOccurrences(of: ".", with: "-")
        safeEmail = safeEmail.replacingOccurrences(of: "@", with: "-")
        return safeEmail
    }
    
    var profilePictureFileName: String{
        //afraz9-gmail-com_profile_picture.png
        return "\(safeEmail)_profile_picture.png"
    }
    
}
