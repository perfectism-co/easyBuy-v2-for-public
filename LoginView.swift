//
//  LoginView.swift
//  
//
//  
//

import SwiftUI

// ViewModel：集中管理狀態
class LoginSharedViewModel: ObservableObject {
    @Published var isShowingEmailSignUp: Bool = false
    @Published var register: Bool = false
}

struct LoginView: View {
    @StateObject var vm: AuthViewModel
    @EnvironmentObject var vmLogin: LoginSharedViewModel
    
    var body: some View {
       
            VStack(spacing: 20) {
                if vmLogin.isShowingEmailSignUp {
                    EmailField(text: $vm.email)
                    PasswordField(password: $vm.password)
                    
                    PrimaryFilledButton(title: "Login") {
                        Task { await vm.signInWithEmailPassword() }
                    }
                    
                    Spacer()
                    
                    Button{
                        vmLogin.isShowingEmailSignUp.toggle()
                    } label: {
                        Text("Sing in with other method")
                            .foregroundColor(.white)
                    }
                    
                    HStack {
                        Text("Don't have an account?")
                            .foregroundColor(Color.gray)
                        
                        Button("Register") {
                            withAnimation {
                                vmLogin.register = true
                            }
                            vm.email = ""
                            vm.password = ""
                            vm.message = nil
                        }
                        .foregroundColor(Color.white)
                    }
                } else {
                    Text("Sign in / Sign up")
                        .font(.headline)
                        .foregroundStyle(.white)
                   
                    Button {
                        vmLogin.isShowingEmailSignUp.toggle()
                    }label:{
                        Text("Continue with Email")
                            .fontWeight(.bold)
                         .padding(.vertical, 8)
                         .frame(maxWidth: .infinity)
                         .background(alignment: .leading) {
                             Image(systemName: "envelope.fill")
                             .resizable()
                             .scaledToFit()
                             .frame(width: 18, height: 18)
                         }
                     }
                     .buttonStyle(.borderedProminent)
                     .tint(Color.accentColor)
                    
                    Button {
                        Task { await vm.signInWithGoogle() }
                    }label:{
                        Text("Continue with Google")
                            .fontWeight(.bold)
                         .padding(.vertical, 8)
                         .frame(maxWidth: .infinity)
                         .background(alignment: .leading) {
                           Image("google")
                             .resizable()
                             .scaledToFit()
                             .frame(width: 16, height: 16)
                         }
                     }
                     .buttonStyle(.borderedProminent)
                     .tint(Color(hue: 0.694, saturation: 0.87, brightness: 0.393))
                }
                
//                if let err = vm.message {
//                    Text(err).foregroundColor(.red)
//                }
            }
            .padding()
            .navigationBarHidden(true)
    }
}


#Preview {
    ZStack {
        Color.black.opacity(0.7)
        LoginView(vm: AuthViewModel())
          .environmentObject(AuthViewModel.preview())
          .environmentObject(ShippingViewModel())
          .environmentObject(CouponViewModel())
          .environmentObject(ProductViewModel())
          .environmentObject(LoginSharedViewModel())
    }
}



