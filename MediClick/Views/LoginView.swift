import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @Environment(AuthManager.self) private var auth
    @State private var email = ""
    @State private var password = ""
    @State private var showRegister = false
    @State private var animateLogo = false
    
    var body: some View {
        ZStack {
            MediBackground()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 26) {
                    Spacer().frame(height: 50)
                    
                    // Logo
                    VStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(Color.mediTeal)
                                .frame(width: 80, height: 80)
                            Image(systemName: "cross.case.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(.white)
                        }
                            .scaleEffect(animateLogo ? 1 : 0.85)
                            .opacity(animateLogo ? 1 : 0)
                            .animation(.easeOut(duration: 0.5), value: animateLogo)
                        
                        Text("mediclick")
                            .font(.system(size: 28, weight: .medium))
                            .foregroundStyle(Color.mediText)
                        
                        Text("Gestión médica integral")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.mediTextMuted)
                    }
                    .onAppear { animateLogo = true }
                    
                    // OAuth
                    VStack(spacing: 12) {
                        SignInWithAppleButton(.signIn) { request in
                            request.requestedScopes = [.fullName, .email]
                        } onCompletion: { result in
                            Task { await handleAppleSignIn(result) }
                        }
                        .signInWithAppleButtonStyle(.black)
                        .frame(height: 52)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
                        
                        Button {
                            Task { await auth.loginWithGoogle() }
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "g.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(LinearGradient.medi([.mediSky, .mediPrimary]))
                                Text("Continuar con Google")
                                    .fontWeight(.semibold)
                                    .foregroundStyle(Color.mediText)
                            }
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(LinearGradient.mediBorder, lineWidth: 1)
                            )
                            .shadow(color: .mediPrimary.opacity(0.12), radius: 12, y: 4)
                        }
                    }
                    
                    // Divider
                    HStack(spacing: 12) {
                        Rectangle()
                            .fill(LinearGradient.medi([.clear, .mediPrimary.opacity(0.25)]))
                            .frame(height: 1)
                        Text("o con email")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Color.mediTextSoft)
                        Rectangle()
                            .fill(LinearGradient.medi([.mediPrimary.opacity(0.25), .clear]))
                            .frame(height: 1)
                    }
                    
                    // Form
                    VStack(spacing: 14) {
                        MediTextField(icon: "envelope.fill", placeholder: "Email", text: $email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                        
                        MediTextField(icon: "lock.fill", placeholder: "Contraseña", text: $password, isSecure: true)
                            .textContentType(.password)
                        
                        if let error = auth.errorMessage {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.circle.fill")
                                Text(error).font(.caption)
                            }
                            .foregroundStyle(Color.mediDanger)
                            .padding(10)
                            .frame(maxWidth: .infinity)
                            .background(Color.mediDanger.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        
                        Button {
                            Task { await auth.login(email: email, password: password) }
                        } label: {
                            if auth.isLoading {
                                ProgressView().tint(.white)
                            } else {
                                HStack(spacing: 8) {
                                    Image(systemName: "stethoscope")
                                    Text("Iniciar sesión")
                                }
                            }
                        }
                        .buttonStyle(MediButtonStyle())
                        .disabled(email.isEmpty || password.isEmpty || auth.isLoading)
                        .opacity(email.isEmpty || password.isEmpty ? 0.6 : 1)
                    }
                    
                    Button {
                        showRegister = true
                    } label: {
                        Text("¿No tenés cuenta? ")
                            .foregroundStyle(Color.mediTextSoft)
                        + Text("Registrate")
                            .foregroundStyle(Color.mediPrimary)
                            .fontWeight(.semibold)
                    }
                    .font(.subheadline)
                    
                    Spacer().frame(height: 30)
                }
                .padding(.horizontal, 24)
            }
        }
        .sheet(isPresented: $showRegister) { RegisterView() }
    }
    
    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) async {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let identityTokenData = credential.identityToken,
                  let identityToken = String(data: identityTokenData, encoding: .utf8),
                  let authCodeData = credential.authorizationCode,
                  let authCode = String(data: authCodeData, encoding: .utf8)
            else { return }
            await auth.loginWithApple(identityToken: identityToken, authorizationCode: authCode,
                                       fullName: credential.fullName, email: credential.email)
        case .failure(let error):
            await MainActor.run { auth.errorMessage = "Error: \(error.localizedDescription)" }
        }
    }
}

struct RegisterView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var medicalLicense = ""
    @State private var specialty = "Clínica médica"
    
    var body: some View {
        NavigationStack {
            ZStack {
                MediBackground()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        VStack(spacing: 14) {
                            MediSectionHeader(title: "Datos personales", icon: "person.fill")
                            MediTextField(icon: "person", placeholder: "Nombre", text: $firstName)
                            MediTextField(icon: "person", placeholder: "Apellido", text: $lastName)
                            MediTextField(icon: "envelope.fill", placeholder: "Email", text: $email)
                                .keyboardType(.emailAddress).autocapitalization(.none)
                            MediTextField(icon: "lock.fill", placeholder: "Contraseña", text: $password, isSecure: true)
                        }
                        .mediElevated(padding: 18)
                        
                        VStack(spacing: 14) {
                            MediSectionHeader(title: "Datos profesionales", icon: "cross.case.fill")
                            MediTextField(icon: "creditcard.fill", placeholder: "Matrícula", text: $medicalLicense)
                            MediTextField(icon: "stethoscope", placeholder: "Especialidad", text: $specialty)
                        }
                        .mediElevated(padding: 18)
                        
                        Button {
                            dismiss()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Crear cuenta")
                            }
                        }
                        .buttonStyle(MediButtonStyle())
                        .disabled(firstName.isEmpty || email.isEmpty || medicalLicense.isEmpty)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Registro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }.foregroundStyle(Color.mediPrimary)
                }
            }
        }
    }
}
