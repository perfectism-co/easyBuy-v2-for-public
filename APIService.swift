import Foundation
import FirebaseAuth
import UIKit


// MARK: - APIError

enum APIError: Error, LocalizedError {
    case invalidURL, invalidResponse, unauthorized, other(String)
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "無效的網址"
        case .invalidResponse: return "伺服器回應錯誤"
        case .unauthorized: return "未授權，請重新登入"
        case .other(let msg): return msg
        }
    }
}

// MARK: - APIService class

@MainActor
final class APIService {
    static let shared = APIService()
    private init() {}

    private let baseURL = "https://easybuy-v2.onrender.com"
    private let service = "easyBuy"


    // MARK: - makeRequest    
    private func makeRequest(path: String,
                             method: String = "GET",
                             body: Data? = nil,
                             auth: Bool = false,
                             contentType: String = "application/json") async throws -> URLRequest {
        guard let url = URL(string: baseURL + path) else {
            fatalError("Invalid URL")
        }

        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue(contentType, forHTTPHeaderField: "Content-Type") // ✅ 改為使用參數


        if let body = body {
            req.httpBody = body
        }

        // 🔑 如果需要驗證，就自動去 Firebase 拿最新的 ID Token
        if auth {
            guard let firebaseUser = Auth.auth().currentUser else {
                throw APIError.unauthorized
            }

            let idToken: String = try await withCheckedThrowingContinuation { continuation in
                firebaseUser.getIDTokenForcingRefresh(false) { token, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else if let token = token {
                        continuation.resume(returning: token)
                    } else {
                        continuation.resume(throwing: APIError.unauthorized)
                    }
                }
            }

            req.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        }

        return req
    }



    // MARK: - JSONDecoder with Fractional-Seconds ISO8601
    private func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let str = try container.decode(String.self)
            
            let fmt = ISO8601DateFormatter()
            fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = fmt.date(from: str) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container,
                debugDescription: "無法解析日期字串：\(str)")
        }
        return decoder
    }



    // MARK: - Fetch User
    func fetchUser() async throws -> User {
        print("👤 fetchUser call (Firebase 自動處理 Token)")

        let req = try await makeRequest(path: "/me", auth: true)
        let (data, resp) = try await URLSession.shared.data(for: req)

        let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
        if let s = String(data: data, encoding: .utf8) {
            print("[DEBUG] /me JSON:\n\(s)")
        }

        guard status == 200 else {
            print("⛔️ fetchUser fail, status:\(status)")
            throw APIError.unauthorized
        }

        return try makeDecoder().decode(User.self, from: data)
    }


    // MARK: - Add / Update / Delete Order
    func submitOrder(order: OrderRequest) async throws {
        let body = try JSONEncoder().encode(order)
        
        // 這裡 auth: true 會自動帶上 Firebase ID Token
        let req = try await makeRequest(path: "/order", method: "POST", body: body, auth: true)

        let (_, resp) = try await URLSession.shared.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else {
            throw APIError.unauthorized
        }
    }


    func updateOrder(orderId: String, order: OrderRequest) async throws  {
        let body = try JSONEncoder().encode(order)
        let req = try await makeRequest(path: "/order/\(orderId)", method: "PUT", body: body, auth: true)
        let (_, resp) = try await URLSession.shared.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else {
            throw APIError.unauthorized
        }
    }

    func deleteOrder(orderId: String) async throws {
        print("✋deleteOrder called:\(orderId)")
        let req = try await makeRequest(path: "/order/\(orderId)", method: "DELETE", auth: true)
        let (_, resp) = try await URLSession.shared.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else {
            throw APIError.unauthorized
        }
    }
    
    
    // MARK: - Add / Update / Delete Cart
    func submitCart(add: CartRequest) async throws -> [Product] {
        let body = try JSONEncoder().encode(add)
        let req = try await makeRequest(path: "/cart", method: "POST", body: body, auth: true)
        
        let (data, resp) = try await URLSession.shared.data(for: req)
        print("🪵 Response JSON:")
        print(String(data: data, encoding: .utf8) ?? "⚠️ 無法轉為字串")

        guard (resp as? HTTPURLResponse)?.statusCode == 200 else {
            throw APIError.unauthorized
        }
        
        let response = try makeDecoder().decode(CartResponse.self, from: data)
        return response.cart.products
    }

    func updateCart(productId: String, quantity: Int) async throws  {
        print("🛒 💘PUT /cart/\(productId)")
        let body = try JSONEncoder().encode(["quantity": quantity])
        let req = try await makeRequest(path: "/cart/\(productId)", method: "PUT", body: body, auth: true)
        let (_, resp) = try await URLSession.shared.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else {
            throw APIError.unauthorized
        }
        print("🥳PUT /cart/\(productId) - refreshed")
    }

    func deleteCart(productIds: DeleteCartRequest) async throws {
        let body = try JSONEncoder().encode(productIds)
        let req = try await makeRequest(path: "/cart", method: "DELETE", body: body,auth: true)
        let (_, resp) = try await URLSession.shared.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else {
            throw APIError.unauthorized
        }
    }
    
    // MARK: - Add / Delete Review
    func submitReview(add: AddReviewRequest) async throws {
        
        let boundary = "Boundary-\(UUID().uuidString)"
        let body = createMultipartBody(comment: add.comment,
                                       rating: add.rating,
                                       images: add.images,
                                       boundary: boundary)

        var request = try await makeRequest(
            path: "/order/\(add.orderId)/review",
            method: "POST",
            body: body,
            auth: true,
            contentType: "multipart/form-data; boundary=\(boundary)"
        )

        let (data, resp) = try await URLSession.shared.data(for: request)
        print("🪵 Response JSON:")
        print(String(data: data, encoding: .utf8) ?? "⚠️ 無法轉為字串")

        guard (resp as? HTTPURLResponse)?.statusCode == 200 else {
            throw APIError.unauthorized
        }
    }

    private func createMultipartBody(comment: String, rating: Int, images: [UIImage], boundary: String) -> Data {
            var body = Data()
            let lineBreak = "\r\n"

            func appendFormField(name: String, value: String) {
                body.append("--\(boundary)\(lineBreak)")
                body.append("Content-Disposition: form-data; name=\"\(name)\"\(lineBreak)\(lineBreak)")
                body.append("\(value)\(lineBreak)")
            }

            func appendImageField(name: String, image: UIImage, index: Int) {
                guard let imageData = image.jpegData(compressionQuality: 0.8) else { return }

                body.append("--\(boundary)\(lineBreak)")
                body.append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"image\(index).jpg\"\(lineBreak)")
                body.append("Content-Type: image/jpeg\(lineBreak)\(lineBreak)")
                body.append(imageData)
                body.append(lineBreak)
            }

            appendFormField(name: "comment", value: comment)
            appendFormField(name: "rating", value: String(rating))

            for (i, image) in images.prefix(5).enumerated() {
                appendImageField(name: "images", image: image, index: i)
            }

            body.append("--\(boundary)--\(lineBreak)")
            return body
        }

    func deleteReview(orderId: String) async throws {
        print("✋deleteReview called:\(orderId)")
        let req = try await makeRequest(path: "/order/\(orderId)/review", method: "DELETE", auth: true)
        let (_, resp) = try await URLSession.shared.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else {
            throw APIError.unauthorized
        }
    }
      
}


// 🔧 Used to directly append a string.
extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            self.append(data)
        }
    }
}



