//
//  TelegramManager.swift
//  ProctorX
//
//  Created by Eddie Gao on 6/4/25.
//

import Foundation
import AppKit

class TelegramManager {
    private let botToken: String
    private let chatID: String
    private let baseURL = "https://api.telegram.org/bot"
    
    init(botToken: String, chatID: String) {
        self.botToken = botToken
        self.chatID = chatID
    }
    
    func sendPhoto(image: NSImage, completion: @escaping (Result<Void, Error>) -> Void) {
        // Convert NSImage to Data
        guard let tiffData = image.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData),
              let jpegData = bitmapImage.representation(using: .jpeg, properties: [:]) else {
            completion(.failure(NSError(domain: "TelegramError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image"])))
            return
        }
        
        // Create URL request
        let url = URL(string: "\(baseURL)\(botToken)/sendPhoto")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // Create multipart form data
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        // Add chat_id field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"chat_id\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(chatID)\r\n".data(using: .utf8)!)
        
        // Add photo field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"photo\"; filename=\"screenshot.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(jpegData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        // Send request
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse,
               !(200...299).contains(httpResponse.statusCode) {
                completion(.failure(NSError(domain: "TelegramError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server returned status code \(httpResponse.statusCode)"])))
                return
            }
            
            completion(.success(()))
        }.resume()
    }
    
    func fetchLatestMessage(completion: @escaping (Result<String, Error>) -> Void) {
        let url = URL(string: "\(baseURL)\(botToken)/getUpdates")!
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "TelegramError", code: 3, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let result = json["result"] as? [[String: Any]],
                   let lastMessage = result.last,
                   let message = lastMessage["message"] as? [String: Any],
                   let text = message["text"] as? String {
                    completion(.success(text))
                } else {
                    completion(.success("No messages found"))
                }
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
}
