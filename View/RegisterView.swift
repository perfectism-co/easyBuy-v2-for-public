//
//  RegisterView.swift
//  
//
//  
//
import SwiftUI


struct RegisterView: View {
    @StateObject var vm: AuthViewModel
    @EnvironmentObject var vmLogin: LoginSharedViewModel
    

    var body: some View {
        
        VStack(spacing: 20) {
            
            EmailField(text: $vm.email)
    
            PasswordField(password: $vm.password)

            Text("By tapping Done, you agree to the privacy policy and terms of service.")
                .font(.footnote)
                .foregroundColor(Color.gray)
                .frame(height: 50)
            
            PrimaryFilledButton(title: "Register") {
                Task { await vm.signUpWithEmailPassword() }
            }
            .padding(.top, 20)
            
            Spacer()
            
            HStack {
                Text("Already have an account?")
                    .foregroundColor(Color.gray)
                
                Button("Login") {
                    withAnimation {
                        vmLogin.register = false
                    }
                    vm.email = ""
                    vm.password = ""
                    vm.message = nil
                }
                .foregroundColor(Color.white)
            }
            
//            if let err = vm.message {
//                Text(err).foregroundColor(.red)
//            }
        }
        .padding()
        .navigationBarHidden(true)
    }
}



#Preview {
   
   RegisterView(vm: AuthViewModel())
    .environmentObject(AuthViewModel.preview())
    .environmentObject(ShippingViewModel())
    .environmentObject(CouponViewModel())
    .environmentObject(ProductViewModel())
    .environmentObject(LoginSharedViewModel())
    
}
