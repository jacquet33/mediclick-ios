import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @Environment(AuthManager.self) private var auth
    @State private var email = ""
    @State private var password = ""
    @State private var showRegister = false
    @State private var showLicensePrompt = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    Spacer().frame(height: 50)
                    
                    // Logo
                    VStack(spacing: 8) {
                        Image(systemName: "cross.circle.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(.blue)
                        Text("MediClick")
                            .font(.largeTitle.bold())
                        Text("Gestión médica integral")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    // ─── OAuth Buttons ───────────────────────
                    VStack(spacing: 12) {
                        
                        // Sign in with Apple
                        SignInWithAppleButton(.signIn) { request in
                            request.requestedScopes = [.fullName, .email]
                        } onCompletion: { result in
                            Task { await handleAppleSignIn(result) }
                        }
                        .signInWithAppleButtonStyle(.black)
                        .frame(height: 52)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        
                        // Sign in with Google
                        Button {
                            Task { await handleGoogleSignIn() }
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "g.circle.fill")
                                    .font(.title2)
                                Text("Continuar con Google")
                                    .fontWeight(.medium)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(.white)
                            .foregroundStyle(.black)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(.gray.opacity(0.3), lineWidth: 1)
                            )
                        }
                    }
                    .padding(.horizontal, 4)
                    
                    // Divider
                    HStack {
                        Rectangle().frame(height: 0.5).foregroundStyle(.gray.opacity(0.3))
                        Text("o con email")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Rectangle().frame(height: 0.5).foregroundStyle(.gray.opacity(0.3))
                    }
                    
                    // ─── Email/Password ──────────────────────
                    VStack(spacing: 14) {
                        TextField("Email", text: $email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .padding()
                            .background(.gray.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        
                        SecureField("Contraseña", text: $password)
                            .textContentType(.password)
                            .padding()
                            .background(.gray.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        
                        if let error = auth.errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                        
                        Button {
                            Task { await auth.login(email: email, password: password) }
                        } label: {
                            if auth.isLoading {
                                ProgressView()
                                    .frame(maxWidth: .infinity, minHeight: 50)
                            } else {
                                Text("Iniciar sesión")
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity, minHeight: 50)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .disabled(email.isEmpty || password.isEmpty || auth.isLoading)
                    }
                    .padding(.horizontal, 4)
                    
                    Button("¿No tenés cuenta? Registrate") {
                        showRegister = true
                    }
                    .font(.subheadline)
                    
                    Spacer().frame(height: 20)
                }
                .padding(.horizontal, 24)
            }
            .sheet(isPresented: $showRegister) {
                RegisterView()
            }
            .sheet(isPresented: $showLicensePrompt) {
                LicensePromptView()
            }
        }
    }
    
    // ─── Apple Sign-In Handler ──────────────────────────────
    
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
            
            if auth.needsLicense {
                showLicensePrompt = true
            }
            
        case .failure(let error):
            await MainActor.run {
                auth.errorMessage = "Error con Apple Sign-In: \(error.localizedDescription)"
            }
        }
    }
    
    // ─── Google Sign-In Handler ─────────────────────────────
    
    private func handleGoogleSignIn() async {
        // Google Sign-In se maneja con el SDK de Google
        // Por ahora placeholder - necesita GoogleSignIn-iOS package
        await auth.loginWithGoogle()
    }
}

// ─── License Prompt (para usuarios OAuth nuevos) ────────────

struct LicensePromptView: View {
    @Environment(AuthManager.self) private var auth
    @Environment(\.dismiss) private var dismiss
    @State private var medicalLicense = ""
    @State private var specialty = "Clínica médica"
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "stethoscope")
                    .font(.system(size: 48))
                    .foregroundStyle(.blue)
                
                Text("Completá tu perfil médico")
                    .font(.title2.bold())
                
                Text("Para usar MediClick necesitamos verificar tu matrícula profesional.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                
                VStack(spacing: 14) {
                    TextField("Matrícula (ej: MN 12345)", text: $medicalLicense)
                        .padding()
                        .background(.gray.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    TextField("Especialidad", text: $specialty)
                        .padding()
                        .background(.gray.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                Button {
                    Task {
                        await auth.updateLicense(license: medicalLicense, specialty: specialty)
                        dismiss()
                    }
                } label: {
                    Text("Guardar")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity, minHeight: 50)
                }
                .buttonStyle(.borderedProminent)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .disabled(medicalLicense.isEmpty)
                
                Button("Completar después") { dismiss() }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(24)
        }
    }
}

// ─── Register View ──────────────────────────────────────────

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
                    TextField("Matrícula", text: $medicalLicense)
                    TextField("Especialidad", text: $specialty)
                }
                Section {
                    Button("Crear cuenta") { dismiss() }
                        .frame(maxWidth: .infinity)
                        .disabled(firstName.isEmpty || lastName.isEmpty || email.isEmpty || password.isEmpty || medicalLicense.isEmpty)
                }
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
