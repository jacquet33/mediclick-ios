import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @Environment(AuthManager.self) private var auth
    @State private var email = ""
    @State private var password = ""
    @State private var showRegister = false
    
    var body: some View {
        ZStack {
            Color.mediBackground.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 28) {
                    Spacer().frame(height: 40)
                    
                    // Logo
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.mediPrimary)
                                .frame(width: 90, height: 90)
                            Image(systemName: "stethoscope")
                                .font(.system(size: 40))
                                .foregroundStyle(.white)
                        }
                        Text("MediClick")
                            .font(.largeTitle.bold())
                            .foregroundStyle(Color.mediPrimaryDark)
                        Text("Gestión médica integral")
                            .font(.subheadline)
                            .foregroundStyle(Color.mediTextSecondary)
                    }
                    
                    // OAuth buttons
                    VStack(spacing: 12) {
                        SignInWithAppleButton(.signIn) { request in
                            request.requestedScopes = [.fullName, .email]
                        } onCompletion: { result in
                            Task { await handleAppleSignIn(result) }
                        }
                        .signInWithAppleButtonStyle(.black)
                        .frame(height: 52)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        
                        Button {
                            Task { await auth.loginWithGoogle() }
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "g.circle.fill")
                                    .font(.title2)
                                Text("Continuar con Google")
                                    .fontWeight(.medium)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Color.white)
                            .foregroundStyle(Color.mediTextPrimary)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
                        }
                    }
                    .padding(.horizontal, 4)
                    
                    // Divider
                    HStack {
                        Rectangle().frame(height: 0.5).foregroundStyle(Color.mediPrimary.opacity(0.2))
                        Text("o con email")
                            .font(.caption)
                            .foregroundStyle(Color.mediTextSecondary)
                        Rectangle().frame(height: 0.5).foregroundStyle(Color.mediPrimary.opacity(0.2))
                    }
                    
                    // Email/Password
                    VStack(spacing: 14) {
                        MediTextField(icon: "envelope.fill", placeholder: "Email", text: $email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                        
                        MediTextField(icon: "lock.fill", placeholder: "Contraseña", text: $password, isSecure: true)
                            .textContentType(.password)
                        
                        if let error = auth.errorMessage {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(Color.mediDanger)
                                Text(error)
                                    .font(.caption)
                                    .foregroundStyle(Color.mediDanger)
                            }
                        }
                        
                        Button {
                            Task { await auth.login(email: email, password: password) }
                        } label: {
                            if auth.isLoading {
                                ProgressView().tint(.white)
                            } else {
                                HStack {
                                    Image(systemName: "stethoscope")
                                    Text("Iniciar sesión")
                                }
                            }
                        }
                        .buttonStyle(MediButtonStyle())
                        .disabled(email.isEmpty || password.isEmpty || auth.isLoading)
                    }
                    .padding(.horizontal, 4)
                    
                    Button("¿No tenés cuenta? Registrate") {
                        showRegister = true
                    }
                    .font(.subheadline)
                    .foregroundStyle(Color.mediPrimary)
                }
                .padding(.horizontal, 24)
            }
        }
        .sheet(isPresented: $showRegister) {
            RegisterView()
        }
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
            await auth.loginWithApple(
                identityToken: identityToken,
                authorizationCode: authCode,
                fullName: credential.fullName,
                email: credential.email
            )
        case .failure(let error):
            await MainActor.run {
                auth.errorMessage = "Error con Apple Sign-In: \(error.localizedDescription)"
            }
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
                Color.mediBackground.ignoresSafeArea()
                Form {
                    Section("Datos personales") {
                        TextField("Nombre", text: $firstName)
                        TextField("Apellido", text: $lastName)
                        TextField("Email", text: $email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                        SecureField("Contraseña", text: $password)
                    }
                    Section("Datos profesionales") {
                        HStack {
                            Image(systemName: "cross.case.fill").foregroundStyle(Color.mediPrimary)
                            TextField("Matrícula", text: $medicalLicense)
                        }
                        HStack {
                            Image(systemName: "stethoscope").foregroundStyle(Color.mediPrimary)
                            TextField("Especialidad", text: $specialty)
                        }
                    }
                    Section {
                        Button("Crear cuenta") { dismiss() }
                            .frame(maxWidth: .infinity)
                            .foregroundStyle(Color.mediPrimary)
                            .disabled(firstName.isEmpty || email.isEmpty || medicalLicense.isEmpty)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Registro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
        }
    }
}
