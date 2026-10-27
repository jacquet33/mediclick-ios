import SwiftUI
import PhotosUI
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
                        
                        (Text("TuConsultorio").foregroundStyle(Color.mediText)
                         + Text("Online").foregroundStyle(Color.mediTeal))
                            .font(.system(size: 28, weight: .medium))
                        
                        Text("by Rispy · Gestión médica integral")
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
    @Environment(AuthManager.self) private var auth
    @State private var r = AuthManager.RegistroMedico(prefijo: "Dr.", nombre: "", apellido: "", dni: "", email: "", celular: "",
                                                       password: "", tipoMatricula: "MP", provincia: "Entre Ríos", matricula: "",
                                                       especialidad: "Clínica médica", fotoDni: nil, fotoCredencial: nil)
    @State private var refeps: AuthManager.RefepsCheck?
    @State private var consultando = false
    @State private var itemDni: PhotosPickerItem?
    @State private var itemCred: PhotosPickerItem?
    @State private var error: String?
    @State private var paso = 1

    static let provincias = ["Buenos Aires", "Ciudad de Buenos Aires", "Catamarca", "Chaco", "Chubut", "Córdoba", "Corrientes", "Entre Ríos",
                             "Formosa", "Jujuy", "La Pampa", "La Rioja", "Mendoza", "Misiones", "Neuquén", "Río Negro", "Salta", "San Juan",
                             "San Luis", "Santa Cruz", "Santa Fe", "Santiago del Estero", "Tierra del Fuego", "Tucumán"]

    private var paso1OK: Bool {
        !r.nombre.trimmingCharacters(in: .whitespaces).isEmpty && !r.apellido.trimmingCharacters(in: .whitespaces).isEmpty
            && r.dni.filter(\.isNumber).count >= 7 && r.fotoDni != nil
    }
    private var paso2OK: Bool { !r.matricula.isEmpty && (r.tipoMatricula == "MN" || !r.provincia.isEmpty) }
    private var paso3OK: Bool { r.email.contains("@") && r.password.count >= 8 }

    var body: some View {
        NavigationStack {
            ZStack {
                MediBackground()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        HStack(spacing: 6) {
                            ForEach(1...3, id: \.self) { i in
                                Capsule().fill(i <= paso ? Color.mediPrimary : Color.mediTextSoft.opacity(0.25)).frame(height: 5)
                            }
                        }
                        Text(paso == 1 ? "Información básica" : paso == 2 ? "Datos profesionales" : "Tu cuenta")
                            .font(.title3.weight(.semibold)).foregroundStyle(Color.mediText).frame(maxWidth: .infinity, alignment: .leading)

                        if paso == 1 { pasoBasico }
                        if paso == 2 { pasoProfesional }
                        if paso == 3 { pasoCuenta }

                        if let error {
                            Text(error).font(.footnote).foregroundStyle(.red).frame(maxWidth: .infinity, alignment: .leading)
                        }

                        HStack(spacing: 12) {
                            if paso > 1 {
                                Button("Atrás") { paso -= 1; error = nil }
                                    .buttonStyle(MediButtonStyle()).opacity(0.85)
                            }
                            Button {
                                Task { await siguiente() }
                            } label: {
                                if auth.isLoading { ProgressView().tint(.white) } else { Text(paso == 3 ? "Crear cuenta" : "Siguiente") }
                            }
                            .buttonStyle(MediButtonStyle())
                            .disabled(!(paso == 1 ? paso1OK : paso == 2 ? paso2OK : paso3OK) || auth.isLoading)
                            .opacity((paso == 1 ? paso1OK : paso == 2 ? paso2OK : paso3OK) ? 1 : 0.6)
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Alta de médico")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }.foregroundStyle(Color.mediPrimary)
                }
            }
            .onChange(of: itemDni) { _, it in Task { r.fotoDni = await jpeg(it) } }
            .onChange(of: itemCred) { _, it in Task { r.fotoCredencial = await jpeg(it) } }
        }
    }

    private var pasoBasico: some View {
        VStack(spacing: 14) {
            Picker("Prefijo", selection: $r.prefijo) {
                Text("Dr.").tag("Dr."); Text("Dra.").tag("Dra.")
            }.pickerStyle(.segmented)
            MediTextField(icon: "person", placeholder: "Nombre(s)", text: $r.nombre)
            MediTextField(icon: "person", placeholder: "Apellido(s)", text: $r.apellido)
            MediTextField(icon: "person.text.rectangle", placeholder: "N° de DNI", text: $r.dni)
                .keyboardType(.numberPad)
                .onChange(of: r.dni) { _, v in
                    refeps = nil
                    let d = v.filter(\.isNumber)
                    guard d.count >= 7 else { return }
                    Task {
                        try? await Task.sleep(for: .milliseconds(700))
                        guard d == r.dni.filter(\.isNumber) else { return }
                        consultando = true
                        refeps = await auth.consultarRefeps(dni: d)
                        consultando = false
                    }
                }
            if consultando {
                Text("Consultando REFEPS…").font(.footnote).foregroundStyle(Color.mediTextSoft).frame(maxWidth: .infinity, alignment: .leading)
            } else if let c = refeps, c.consultado {
                Text(c.encontrado && c.esMedico
                     ? (c.matriculaVigente ? "✓ Encontramos tu matrícula de médico en REFEPS (SISA)." : "Figurás en REFEPS pero sin matrícula vigente. Revisalo.")
                     : "No hemos encontrado su DNI en el registro de REFEPS de SISA. Revise si es correcto.")
                    .font(.footnote)
                    .foregroundStyle(c.encontrado && c.esMedico && c.matriculaVigente ? Color.green : Color.orange)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            PhotosPicker(selection: $itemDni, matching: .images) {
                fotoBox(titulo: "Foto del documento *", data: r.fotoDni)
            }
            Text("Subí una foto de tu DNI. Nos permite reforzar la seguridad y evitar la suspensión de tu cuenta.")
                .font(.footnote).foregroundStyle(Color.mediTextSoft).frame(maxWidth: .infinity, alignment: .leading)
        }
        .mediElevated(padding: 18)
    }

    private var pasoProfesional: some View {
        VStack(spacing: 14) {
            Picker("Matrícula", selection: $r.tipoMatricula) {
                Text("Provincial (M.P.)").tag("MP"); Text("Nacional (M.N.)").tag("MN")
            }.pickerStyle(.segmented)
            if r.tipoMatricula == "MP" {
                Picker("Provincia", selection: $r.provincia) {
                    ForEach(Self.provincias, id: \.self) { Text($0).tag($0) }
                }
                .tint(Color.mediPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            MediTextField(icon: "creditcard.fill", placeholder: "N° de matrícula", text: $r.matricula)
            MediTextField(icon: "stethoscope", placeholder: "Especialidad", text: $r.especialidad)
            PhotosPicker(selection: $itemCred, matching: .images) {
                fotoBox(titulo: "Foto de la credencial o título (opcional)", data: r.fotoCredencial)
            }
            Text("Verificamos que tu matrícula esté vigente en REFEPS para que puedas emitir recetas electrónicas.")
                .font(.footnote).foregroundStyle(Color.mediTextSoft).frame(maxWidth: .infinity, alignment: .leading)
        }
        .mediElevated(padding: 18)
    }

    private var pasoCuenta: some View {
        VStack(spacing: 14) {
            MediTextField(icon: "envelope.fill", placeholder: "Email", text: $r.email)
                .keyboardType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled()
            MediTextField(icon: "phone.fill", placeholder: "Celular (sin 0 ni 15)", text: $r.celular)
                .keyboardType(.phonePad)
            MediTextField(icon: "lock.fill", placeholder: "Contraseña (mín. 8)", text: $r.password, isSecure: true)
        }
        .mediElevated(padding: 18)
    }

    private func fotoBox(titulo: String, data: Data?) -> some View {
        VStack(spacing: 8) {
            if let data, let img = UIImage(data: data) {
                Image(uiImage: img).resizable().scaledToFill().frame(height: 140).clipped().clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                Image(systemName: "photo.badge.plus").font(.title2).foregroundStyle(Color.mediPrimary)
                    .frame(maxWidth: .infinity, minHeight: 110)
            }
            Text(data == nil ? titulo : "Cambiar foto").font(.footnote.weight(.medium)).foregroundStyle(Color.mediText)
        }
        .frame(maxWidth: .infinity)
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 14).strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6])).foregroundStyle(Color.mediTextSoft.opacity(0.5)))
    }

    private func jpeg(_ item: PhotosPickerItem?) async -> Data? {
        guard let item, let data = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: data) else { return nil }
        let lado: CGFloat = 1400
        let escala = min(1, lado / max(img.size.width, img.size.height))
        let tam = CGSize(width: img.size.width * escala, height: img.size.height * escala)
        let r = UIGraphicsImageRenderer(size: tam).image { _ in img.draw(in: CGRect(origin: .zero, size: tam)) }
        return r.jpegData(compressionQuality: 0.8)
    }

    private func siguiente() async {
        error = nil
        if paso < 3 { paso += 1; return }
        if let e = await auth.registrarMedico(r) {
            error = e
            if auth.isAuthenticated { try? await Task.sleep(for: .seconds(3)); dismiss() }
        } else {
            dismiss()
        }
    }
}
