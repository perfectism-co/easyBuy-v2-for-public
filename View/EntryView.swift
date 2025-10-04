//
//  EntryView.swift
//  easyBuy
//
// 
//

import SwiftUI
import GoogleSignInSwift


struct EntryView: View {
    @EnvironmentObject var vm: AuthViewModel
    @EnvironmentObject var vmLogin: LoginSharedViewModel
    @Namespace private var animationNamespace // 為避免動畫衝突
    @State private var isShowAlert = false
    
    var body: some View {
        ZStack {
            VideoBackgroundView()
                .edgesIgnoringSafeArea(.all)
            
            Rectangle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [.black.opacity(0.18),.black.opacity(0.6), .black.opacity(1)]),
                        startPoint: .top,
                        endPoint: .bottom
                   )
                )
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                Spacer()
                Image("FASHION")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 48)
                    .padding(.bottom, 32)
                ZStack {
                    if !vmLogin.register {
                        LoginView(vm: vm)
                            .transition(.move(edge: .leading).combined(with: .opacity))
                            
                    } else {
                        RegisterView(vm: vm)
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                }
                .frame(height: 340, alignment: .top)
                .animation(.easeInOut(duration: 0.3), value: vmLogin.register)

                Spacer()
            }
            if vm.isLoading {
                ZStack {
                    Color.black.opacity(0.3).ignoresSafeArea()
                    ProgressView("Loading...")
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                }
                .transition(.opacity)
                .zIndex(99)
            }
        }
        .alert(isPresented: $isShowAlert) {
            Alert(
                title: Text(""),
                message: Text(vm.message ?? ""),
                dismissButton: .default(Text("OK"), action: {
                    isShowAlert = false
                    vm.message = nil
                })
            )
        }
        .onChange(of: vm.message) { newValue in
            isShowAlert = newValue != nil
        }
    }
}

#Preview {
    EntryView()
        .environmentObject(AuthViewModel.preview())
        .environmentObject(ShippingViewModel())
        .environmentObject(CouponViewModel())
        .environmentObject(ProductViewModel())
        .environmentObject(LoginSharedViewModel())
    
}


struct Preview_Previews : PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.opacity(0.3).ignoresSafeArea()
            VStack(spacing: 20) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
                Text("Loading...")
                    .foregroundColor(.white)
            }
        }
        .zIndex(99)
    }
}
