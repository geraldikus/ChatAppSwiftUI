//
//  ChatLogViewModel.swift
//  ChatAppSwiftUI
//
//  Created by Anton on 02.08.23.
//

import Foundation
import Firebase

class ChatLogViewModel: ObservableObject {
    @Published var chatText = ""
    @Published var chatMessages = [ChatMessage]()
    @Published var count = 0
    
    var chatUser: ChatUser?
    
    init(chatUser: ChatUser?) {
        self.chatUser = chatUser
        fetchMessages()
    }
    
    var firestoreListener: ListenerRegistration?
    
    func fetchMessages() {
        guard let fromId = FirebaseManager.shared.auth.currentUser?.uid else { return }
        guard let toId = chatUser?.uid else { return }
        firestoreListener?.remove()
        chatMessages.removeAll()
        
        firestoreListener = FirebaseManager.shared.firestore
            .collection("messages")
            .document(fromId)
            .collection(toId)
            .order(by: "timestamp")
            .addSnapshotListener { querySnapshot, error in
                if let error = error {
                    print("Error with querySnapshot: \(error)")
                    return
                }
                
                querySnapshot?.documentChanges.forEach({ change in
                    if change.type == .added {
                        let data = change.document.data()
                        self.chatMessages.append(.init(documentId: change.document.documentID, data: data))
                        print("Appending chat message in ChatLogView: \(Date())")
                    }
                })
                self.count += 1
            }
    }
    
    func handleSend() {
        print(chatText)
        
        guard let fromId = FirebaseManager.shared.auth.currentUser?.uid else { return }
        
        guard let toId = chatUser?.uid else { return }
        
        let document = FirebaseManager.shared.firestore
            .collection("messages")
            .document(fromId)
            .collection(toId)
            .document()
        
        let messageData = [FirebaseConstants.fromId: fromId,
                           FirebaseConstants.toId: toId,
                           FirebaseConstants.text: self.chatText,
                           FirebaseConstants.timestamp: Timestamp()] as [String : Any]
        
        document.setData(messageData) {error in
            if let error = error {
                print(error)
                print("Failed to save message into Firestore: \(error)")
                return
            }
            print("Save in Firestore current user sending message")
            
            self.persistRecentMessage()
            self.chatText = ""
            self.count += 1
        }
        
        let recipientMessageDocument = FirebaseManager.shared.firestore
            .collection("messages")
            .document(toId)
            .collection(fromId)
            .document()
        
        
        recipientMessageDocument.setData(messageData) {error in
            if let error = error {
                print(error)
                print("Failed to save message into Firestore: \(error)")
                return
            }
            print("Recipient saved message as well")
        }
    }
    
    private func persistRecentMessage() { // Myabe bug with scrollView here
        guard let chatUser = chatUser else { return }
        
        guard let uid = FirebaseManager.shared.auth.currentUser?.uid else { return }
        guard let toId = self.chatUser?.uid else { return }
        
        let document = FirebaseManager.shared.firestore
            .collection("recent_messages")
            .document(uid)
            .collection("messages")
            .document(toId)
        
        let data = [
            FirebaseConstants.timestamp: Timestamp(),
            FirebaseConstants.text: self.chatText,
            FirebaseConstants.fromId: uid,
            FirebaseConstants.toId: toId,
            FirebaseConstants.profileImageURL: chatUser.profileImageURL,
            FirebaseConstants.email: chatUser.email
        ] as [String : Any]
        
        // save for recipient
        
        document.setData(data) { error in
            if let error = error {
                print("Error with persistRecentMessage: \(error)")
                return
            }
        }
        
        guard let currentUser = FirebaseManager.shared.currentUser else { return }
        let recipientRecentMessageDictionary = [
            FirebaseConstants.timestamp: Timestamp(),
            FirebaseConstants.text: self.chatText,
            FirebaseConstants.fromId: uid,
            FirebaseConstants.toId: toId,
            FirebaseConstants.profileImageURL: currentUser.profileImageURL,
            FirebaseConstants.email: currentUser.email
        ] as [String : Any]
        
        FirebaseManager.shared.firestore
            .collection(FirebaseConstants.recentMessages)
            .document(toId)
            .collection(FirebaseConstants.messages)
            .document(currentUser.uid)
            .setData(recipientRecentMessageDictionary) { error in
                if let error = error {
                    print("Failed to save recipient recent message: \(error)")
                    return
                }
            }
    }
}
