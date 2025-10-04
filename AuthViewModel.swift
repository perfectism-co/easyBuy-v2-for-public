
import SwiftUI
import UIKit
import FirebaseCore
import FirebaseAuth
import GoogleSignIn
import GoogleSignInSwift

enum AuthenticationState {
  case unauthenticated
  case authenticating
  case authenticated
}

enum AuthenticationError: Error {
  case tokenError(message: String)
}

@MainActor
class AuthViewModel: ObservableObject {
    // 🔑 追蹤目前登入狀態
    @Published var authenticationState: AuthenticationState = .unauthenticated
        
    @Published var user: User?
    @Published var email: String = ""
    @Published var password: String = ""
    @Published var newOrderRequest: OrderRequest = .empty
    @Published var isAutoLoading: Bool = false
    @Published var isLoading: Bool = false
    @Published var message: String?
    
    @Published var comment = ""
    @Published var rating = 0
    @Published var selectedImages: [UIImage] = []
  
    @Published var selectedTab: Int = 0

 
    var isLoggedIn: Bool { user != nil }

    init() {
        registerAuthStateHandler()
    }
    
    private var authStateHandler: AuthStateDidChangeListenerHandle?

    func registerAuthStateHandler() {
        isAutoLoading = true

        if authStateHandler == nil {
            authStateHandler = Auth.auth().addStateDidChangeListener { auth, firebaseUser in
                if firebaseUser != nil {
                    // Firebase 有使用者 -> 認定為已登入
                    Task { @MainActor in
                        await self.fetchUser()  // ✅ 在 Task 裡呼叫 async 函數
                        self.authenticationState = .authenticated
                        self.isAutoLoading = false   // ✅ 登入成功後才結束 loading
                    }
                } else {
                    // Firebase 沒有使用者 -> 未登入
                    self.authenticationState = .unauthenticated
                    self.user = nil
                    self.isAutoLoading = false   // ✅ 登入失敗/未登入也要結束 loading
                }
            }
        }
    }

    private func wait() async {
        do {
          print("Wait")
          try await Task.sleep(nanoseconds: 1_000_000_000)
          print("Done")
        }
        catch { }
      }

    func reset() {
        email = ""
        password = ""
    }
    
    func signInWithEmailPassword() async -> Bool {
        authenticationState = .authenticating
        do {
          try await Auth.auth().signIn(withEmail: self.email, password: self.password)
          return true
        }
        catch  {
          print("登入失敗:", error.localizedDescription)
          message = error.localizedDescription
          authenticationState = .unauthenticated
          return false
        }
    }


     func signUpWithEmailPassword() async -> Bool {
       authenticationState = .authenticating
       do  {
         try await Auth.auth().createUser(withEmail: email, password: password)
         message = "User created successfully! Please log in."
         return true
       }
       catch {
         print(error)
         message = error.localizedDescription
         authenticationState = .unauthenticated
         return false
       }
     }

     func signOut() {
       do {
         try Auth.auth().signOut()
       }
       catch {
         print(error)
         message = error.localizedDescription
       }
     }
    
    func signInWithGoogle() async -> Bool {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
          fatalError("No client ID found in Firebase configuration")
        }
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController else {
          print("There is no root view controller!")
          return false
        }

          do {
            let userAuthentication = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)

            let user = userAuthentication.user
            guard let idToken = user.idToken else { throw AuthenticationError.tokenError(message: "ID token missing") }
            let accessToken = user.accessToken

            let credential = GoogleAuthProvider.credential(withIDToken: idToken.tokenString,
                                                           accessToken: accessToken.tokenString)

            let result = try await Auth.auth().signIn(with: credential)
            let firebaseUser = result.user
            print("User \(firebaseUser.uid) signed in with email \(firebaseUser.email ?? "unknown")")
            return true
          }
          catch {
            print(error.localizedDescription)
            self.message = error.localizedDescription
            return false
          }
      }
    
    
     func deleteAccount() async -> Bool {
       do {
         try await Auth.auth().currentUser?.delete()
         return true
       }
       catch {
         message = error.localizedDescription
         return false
       }
     }
    
   
    
    func fetchUser() async {
        print("💻👤fetchUser called")
        do {
            let fetchedUser = try await APIService.shared.fetchUser()
            self.user = fetchedUser
        } catch {
            print("💻❌ 無法取得使用者資料：\(error)")
        }
    }


    
    func addCart(products: CartRequest) async {
        print("💻🛎️addCart called")
        do {
            _ = try await APIService.shared.submitCart(add: products)
            message = nil
        } catch {
            message = error.localizedDescription
            print("💻❌errorMessage:\(message ?? "")")
        }
    }

    func addOrder() async {
        print("💻🛎️addOrder called")
        guard !newOrderRequest.isEmpty else {
            message = "Please check the required fields."
            return
        }
        do {
            try await APIService.shared.submitOrder(order: newOrderRequest)
            newOrderRequest = .empty
            message = nil
        } catch {
            message = error.localizedDescription
        }
    }

    
    func updateCartItem(productId: String, quantity: Int) async {
        print("💻🛎️updateCartItem called")

        do {
            // 呼叫後端更新商品數量
            try await APIService.shared.updateCart(productId: productId, quantity: quantity)

            // 本地更新
            if let index = user?.cart.firstIndex(where: { $0.productId == productId }) {
                user?.cart[index].quantity = quantity
            }

            message = nil
        } catch {
            message = error.localizedDescription
            print("💻❌updateCartItem failed, errorMessage:\(message ?? "")")
        }
    }
    
    func updateOrder(order: Order) async {
        do {
            try await APIService.shared.updateOrder(orderId: order.id, order: newOrderRequest)
            newOrderRequest = .empty
            message = nil
        } catch {
            message = error.localizedDescription
            print("💻❌updateOrder failed, errorMessage:\(message ?? "")")
        }
    }

    func deleteCartItems(productIds: [String]) async {
        do {
            let request = DeleteCartRequest(productIds: productIds)
            try await APIService.shared.deleteCart(productIds: request)

            // Update the local cart (remove successfully deleted items).
            user?.cart.removeAll(where: { productIds.contains($0.id) })

            message = nil
        } catch {
            message = error.localizedDescription
        }
    }
    
    
    func deleteOrder(order: Order) async {
        do {
            try await APIService.shared.deleteOrder(orderId: order.id)
            user?.orders.removeAll(where: { $0.id == order.id })
            message = nil
        } catch {
            message = error.localizedDescription
        }
    }
    
    
    func addReview(orderId: String) async {
        let request = AddReviewRequest(
            orderId: orderId,
            comment: comment, //vm.commet
            rating: rating, //vm.rating
            images: selectedImages //vm.selectedImages
        )

        do {
            try await APIService.shared.submitReview(add: request)
            message = nil
            
            comment = ""
            rating = 0
            selectedImages = []
            
        } catch {
            message = error.localizedDescription
        }
    }

    
    func deleteReview(order: Order) async {
        do {
            try await APIService.shared.deleteReview(orderId: order.id)
            user?.orders.removeAll(where: { $0.id == order.id })
            message = nil
        } catch {
            message = error.localizedDescription
        }
    }
    
}




