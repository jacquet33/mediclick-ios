import SwiftUI

struct LoginView: View {
    @Environment(AuthManager.self) private var auth
    @State private var email = ""
    @State private var password = ""
    @State private var showRegister = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    Spacer().frame(height: 60)
                    
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
                    
                    // Form
                    VStack(spacing: 16) {
                        TextField("Email", text: $email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .padding()
                            .background(.gray.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        
                        SecureField("Contraseña", text: $password)
                            .textContentType(.password)
                            .padding()
                            .background(.gray.opacity(0.1))
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
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                            } else {
                                Text("Iniciar sesión")
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
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
                }
                .padding(.horizontal, 24)
            }
            .sheet(isPresented: $showRegister) {
                RegisterView()
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
                    Button("Crear cuenta") {
                        // TODO: Call register API
                        dismiss()
                    }
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
