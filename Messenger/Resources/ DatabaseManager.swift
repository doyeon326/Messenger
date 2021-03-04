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
        database.child("users").observeSingleEvent(of: .value, with: { snapshot in
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
    public func createNewConversation(with otherUserEmail: String, firstMessage: Message, completion: @escaping (Bool)-> Void){
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
            
            let newConversationData: [String:Any] = [
                "id": "conversation_\(firstMessage.messageId)",
                "other_user_email" : otherUserEmail,
                "latest_message": [
                    "date": dateString,
                    "message": message,
                    "is_read":false
                ]
            ]
            
            if var conversation = userNode["conversations"] as? [[String: Any]] {
                //conversation array exists for current user
                //you should append
                
                conversation.append(newConversationData)
                userNode["conversation"] = conversation
                ref.setValue(userNode, withCompletionBlock: { error, _ in
                    guard error == nil else {
                        completion(false)
                        return
                    }
                    completion(true)
                })
            }
            else {
                //conversation array does not exists,
                //create it
                userNode["conversations"] = [
                    newConversationData
                ]
                
                ref.setValue(userNode, withCompletionBlock: { error, _ in
                    guard error == nil else {
                        completion(false)
                        return
                    }
                    completion(true)
                })
            }
            
        })
        
        
    }
    
    private func finishCreatingConversation(conversationID: String, firstMessage: Message, completion: @escaping (Bool) -> Void) {
        
    }
    //Fetches and returns all conversations for the user with passed in email
    public func getAllConversation(for email: String, completion: @escaping (Result<String, Error>)-> Void){
        
    }
    // Gets all messages for a given conversationn
    public func getAllMessagesForConversation(with id: String, completion: @escaping(Result<String, Error> ) -> Void){
        
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
