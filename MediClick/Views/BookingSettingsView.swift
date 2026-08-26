import SwiftUI

struct BookingSettingsView: View {
    @Environment(AuthManager.self) private var auth
    @Environment(\.dismiss) private var dismiss
    
    @State private var isEnabled = false
    @State private var publicSlug = ""
    @State private var bookingMode = "open"
    
    // Seña
    @State private var requiresDeposit = false
    @State private var consultationFee = ""
    @State private var depositAmount = ""
    @State private var paymentMethods = "both"
    @State private var bankName = ""
    @State private var bankHolder = ""
    @State private var bankCbu = ""
    @State private var bankAlias = ""
    @State private var paymentDeadline = 120
    
    // No-show
    @State private var chargeOnNoShow = false
    @State private var noShowFee = ""
    @State private var keepsDeposit = true
    
    // Cancelación
    @State private var minHoursCancel = 24
    @State private var refundOnCancel = true
    
    // Restricciones
    @State private var maxDaysAdvance = 60
    @State private var minHoursAdvance = 2
    @State private var allowNewPatients = true
    @State private var requiresInsurance = false
    
    // Mensajes
    @State private var welcomeMessage = ""
    @State private var instructions = ""
    
    @State private var isSaving = false
    @State private var showCopied = false
    
    private var publicURL: String {
        "\(APIConfig.baseURL)/reservar/\(publicSlug)"
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                MediBackground()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        
                        // ─── Activar ───
                        VStack(spacing: 14) {
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(LinearGradient.medi(isEnabled ? [.mediSuccess, .mediCyan] : [.mediTextMuted, .mediTextMuted]))
                                        .frame(width: 46, height: 46)
                                    Image(systemName: "link")
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundStyle(.white)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Reservas online")
                                        .font(.mediHeadline(15))
                                        .foregroundStyle(Color.mediText)
                                    Text(isEnabled ? "Activo · los pacientes pueden reservar" : "Desactivado")
                                        .font(.caption)
                                        .foregroundStyle(isEnabled ? Color.mediSuccess : Color.mediTextSoft)
                                }
                                Spacer()
                                Toggle("", isOn: $isEnabled).labelsHidden().tint(Color.mediSuccess)
                            }
                            
                            if isEnabled {
                                Divider().overlay(Color.mediPrimary.opacity(0.1))
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("TU ENLACE PÚBLICO")
                                        .font(.system(size: 10, weight: .bold))
                                        .tracking(0.5)
                                        .foregroundStyle(Color.mediTextSoft)
                                    
                                    HStack {
                                        Text(publicURL)
                                            .font(.system(size: 12, design: .monospaced))
                                            .foregroundStyle(Color.mediPrimary)
                                            .lineLimit(2)
                                        Spacer()
                                        Button {
                                            UIPasteboard.general.string = publicURL
                                            withAnimation { showCopied = true }
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                                withAnimation { showCopied = false }
                                            }
                                        } label: {
                                            Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundStyle(showCopied ? Color.mediSuccess : Color.mediPrimary)
                                        }
                                    }
                                    .padding(12)
                                    .background(Color.mediBgSoft.opacity(0.6))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    
                                    Text("Pegá este link en tu bio de Instagram o WhatsApp")
                                        .font(.caption2)
                                        .foregroundStyle(Color.mediTextMuted)
                                    
                                    MediTextField(icon: "at", placeholder: "Personalizar enlace", text: $publicSlug)
                                        .autocapitalization(.none)
                                }
                            }
                        }
                        .mediElevated(padding: 18)
                        
                        if isEnabled {
                            // ─── Modalidad ───
                            VStack(alignment: .leading, spacing: 14) {
                                MediSectionHeader(title: "¿Cómo reservan?", icon: "person.badge.clock.fill")
                                
                                ModeOption(
                                    id: "open", selected: $bookingMode,
                                    icon: "bolt.fill", title: "Reserva libre",
                                    subtitle: "El turno queda confirmado al instante",
                                    colors: [.mediSuccess, .mediCyan]
                                )
                                ModeOption(
                                    id: "approval", selected: $bookingMode,
                                    icon: "checkmark.shield.fill", title: "Con aprobación",
                                    subtitle: "Vos aprobás cada solicitud",
                                    colors: [.mediWarning, Color(red: 0.95, green: 0.55, blue: 0.10)]
                                )
                                ModeOption(
                                    id: "deposit", selected: $bookingMode,
                                    icon: "dollarsign.circle.fill", title: "Con seña",
                                    subtitle: "Debe pagar para confirmar",
                                    colors: [.mediCyan, .mediPrimary]
                                )
                                ModeOption(
                                    id: "deposit_approval", selected: $bookingMode,
                                    icon: "lock.shield.fill", title: "Seña + aprobación",
                                    subtitle: "Paga y además vos confirmás",
                                    colors: [.mediPrimary, .mediDeep]
                                )
                            }
                            .mediElevated(padding: 18)
                            .onChange(of: bookingMode) {
                                requiresDeposit = bookingMode.contains("deposit")
                            }
                            
                            // ─── Seña ───
                            if requiresDeposit {
                                VStack(alignment: .leading, spacing: 14) {
                                    MediSectionHeader(title: "Seña", icon: "dollarsign.circle.fill")
                                    
                                    MediTextField(icon: "banknote", placeholder: "Valor de la consulta", text: $consultationFee)
                                        .keyboardType(.numberPad)
                                    MediTextField(icon: "dollarsign", placeholder: "Monto de la seña", text: $depositAmount)
                                        .keyboardType(.numberPad)
                                    
                                    Text("MÉTODOS DE PAGO")
                                        .font(.system(size: 10, weight: .bold))
                                        .tracking(0.5)
                                        .foregroundStyle(Color.mediTextSoft)
                                    
                                    Picker("", selection: $paymentMethods) {
                                        Text("Ambos").tag("both")
                                        Text("Transferencia").tag("transfer")
                                        Text("Efectivo").tag("cash")
                                    }
                                    .pickerStyle(.segmented)
                                    
                                    if paymentMethods != "cash" {
                                        Divider().overlay(Color.mediPrimary.opacity(0.1))
                                        Text("DATOS BANCARIOS")
                                            .font(.system(size: 10, weight: .bold))
                                            .tracking(0.5)
                                            .foregroundStyle(Color.mediTextSoft)
                                        MediTextField(icon: "building.columns", placeholder: "Banco", text: $bankName)
                                        MediTextField(icon: "person.text.rectangle", placeholder: "Titular de la cuenta", text: $bankHolder)
                                        MediTextField(icon: "number", placeholder: "CBU", text: $bankCbu)
                                            .keyboardType(.numberPad)
                                        MediTextField(icon: "at", placeholder: "Alias", text: $bankAlias)
                                            .autocapitalization(.none)
                                    }
                                    
                                    HStack {
                                        Text("Tiempo para pagar")
                                            .font(.subheadline)
                                            .foregroundStyle(Color.mediText)
                                        Spacer()
                                        Text("\(paymentDeadline) min")
                                            .font(.mediHeadline(15))
                                            .foregroundStyle(Color.mediPrimary)
                                        Stepper("", value: $paymentDeadline, in: 15...1440, step: 15)
                                            .labelsHidden().tint(Color.mediPrimary)
                                    }
                                }
                                .mediElevated(padding: 18)
                            }
                            
                            // ─── No-show ───
                            VStack(alignment: .leading, spacing: 14) {
                                MediSectionHeader(title: "Si el paciente no viene", icon: "person.fill.xmark")
                                
                                if requiresDeposit {
                                    Toggle(isOn: $keepsDeposit) {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Me quedo con la seña")
                                                .font(.mediCaption(15))
                                                .foregroundStyle(Color.mediText)
                                            Text("No se devuelve si no asiste")
                                                .font(.caption)
                                                .foregroundStyle(Color.mediTextSoft)
                                        }
                                    }
                                    .tint(Color.mediWarning)
                                }
                                
                                Toggle(isOn: $chargeOnNoShow) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Cobrar multa adicional")
                                            .font(.mediCaption(15))
                                            .foregroundStyle(Color.mediText)
                                        Text("Cargo extra por inasistencia")
                                            .font(.caption)
                                            .foregroundStyle(Color.mediTextSoft)
                                    }
                                }
                                .tint(Color.mediDanger)
                                
                                if chargeOnNoShow {
                                    MediTextField(icon: "dollarsign", placeholder: "Monto de la multa", text: $noShowFee)
                                        .keyboardType(.numberPad)
                                }
                            }
                            .mediElevated(padding: 18)
                            
                            // ─── Cancelación ───
                            VStack(alignment: .leading, spacing: 14) {
                                MediSectionHeader(title: "Cancelación", icon: "calendar.badge.minus")
                                
                                HStack {
                                    Text("Cancelar sin cargo hasta")
                                        .font(.subheadline)
                                        .foregroundStyle(Color.mediText)
                                    Spacer()
                                    Text("\(minHoursCancel)h antes")
                                        .font(.mediHeadline(15))
                                        .foregroundStyle(Color.mediPrimary)
                                    Stepper("", value: $minHoursCancel, in: 1...168, step: 1)
                                        .labelsHidden().tint(Color.mediPrimary)
                                }
                                
                                if requiresDeposit {
                                    Toggle(isOn: $refundOnCancel) {
                                        Text("Devolver seña si cancela a tiempo")
                                            .font(.subheadline)
                                            .foregroundStyle(Color.mediText)
                                    }
                                    .tint(Color.mediSuccess)
                                }
                            }
                            .mediElevated(padding: 18)
                            
                            // ─── Restricciones ───
                            VStack(alignment: .leading, spacing: 14) {
                                MediSectionHeader(title: "Restricciones", icon: "slider.horizontal.3")
                                
                                HStack {
                                    Text("Reservar hasta")
                                        .font(.subheadline).foregroundStyle(Color.mediText)
                                    Spacer()
                                    Text("\(maxDaysAdvance) días")
                                        .font(.mediHeadline(15)).foregroundStyle(Color.mediPrimary)
                                    Stepper("", value: $maxDaysAdvance, in: 1...365, step: 5)
                                        .labelsHidden().tint(Color.mediPrimary)
                                }
                                
                                HStack {
                                    Text("Anticipación mínima")
                                        .font(.subheadline).foregroundStyle(Color.mediText)
                                    Spacer()
                                    Text("\(minHoursAdvance)h")
                                        .font(.mediHeadline(15)).foregroundStyle(Color.mediPrimary)
                                    Stepper("", value: $minHoursAdvance, in: 0...72, step: 1)
                                        .labelsHidden().tint(Color.mediPrimary)
                                }
                                
                                Toggle(isOn: $allowNewPatients) {
                                    Text("Aceptar pacientes nuevos")
                                        .font(.subheadline).foregroundStyle(Color.mediText)
                                }
                                .tint(Color.mediCyan)
                                
                                Toggle(isOn: $requiresInsurance) {
                                    Text("Requiere obra social")
                                        .font(.subheadline).foregroundStyle(Color.mediText)
                                }
                                .tint(Color.mediCyan)
                            }
                            .mediElevated(padding: 18)
                            
                            // ─── Mensajes ───
                            VStack(alignment: .leading, spacing: 14) {
                                MediSectionHeader(title: "Mensajes al paciente", icon: "text.bubble.fill")
                                MediTextField(icon: "hand.wave", placeholder: "Mensaje de bienvenida", text: $welcomeMessage)
                                MediTextField(icon: "info.circle", placeholder: "Instrucciones (qué traer, etc.)", text: $instructions)
                            }
                            .mediElevated(padding: 18)
                        }
                        
                        Button {
                            Task { await save() }
                        } label: {
                            if isSaving {
                                ProgressView().tint(.white)
                            } else {
                                Label("Guardar configuración", systemImage: "checkmark.circle.fill")
                            }
                        }
                        .buttonStyle(MediButtonStyle())
                        .disabled(isSaving)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Reservas online")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }.foregroundStyle(Color.mediPrimary)
                }
            }
            .task { await load() }
        }
    }
    
    // MARK: - API
    
    private func load() async {
        guard let token = KeychainHelper.load(key: "access_token"),
              let orgId = auth.activeOrganization?.id else { return }
        
        var req = URLRequest(url: URL(string: "\(APIConfig.baseURL)/api/v1/booking/settings")!)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue(orgId, forHTTPHeaderField: "x-organization-id")
        req.setValue(auth.doctorId, forHTTPHeaderField: "x-doctor-id")
        
        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            guard let j = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
            
            await MainActor.run {
                isEnabled = j["is_enabled"] as? Bool ?? false
                publicSlug = j["public_slug"] as? String ?? ""
                bookingMode = j["booking_mode"] as? String ?? "open"
                requiresDeposit = j["requires_deposit"] as? Bool ?? false
                consultationFee = numString(j["consultation_fee"])
                depositAmount = numString(j["deposit_amount"])
                paymentMethods = j["payment_methods"] as? String ?? "both"
                bankName = j["bank_name"] as? String ?? ""
                bankHolder = j["bank_account_holder"] as? String ?? ""
                bankCbu = j["bank_cbu"] as? String ?? ""
                bankAlias = j["bank_alias"] as? String ?? ""
                paymentDeadline = j["payment_deadline_minutes"] as? Int ?? 120
                chargeOnNoShow = j["charge_on_no_show"] as? Bool ?? false
                noShowFee = numString(j["no_show_fee"])
                keepsDeposit = j["keeps_deposit_on_no_show"] as? Bool ?? true
                minHoursCancel = j["min_hours_before_cancel"] as? Int ?? 24
                refundOnCancel = j["refund_on_early_cancel"] as? Bool ?? true
                maxDaysAdvance = j["max_days_in_advance"] as? Int ?? 60
                minHoursAdvance = j["min_hours_in_advance"] as? Int ?? 2
                allowNewPatients = j["allow_new_patients"] as? Bool ?? true
                requiresInsurance = j["requires_insurance_info"] as? Bool ?? false
                welcomeMessage = j["welcome_message"] as? String ?? ""
                instructions = j["instructions"] as? String ?? ""
            }
        } catch { }
    }
    
    private func save() async {
        guard let token = KeychainHelper.load(key: "access_token"),
              let orgId = auth.activeOrganization?.id else { return }
        
        await MainActor.run { isSaving = true }
        
        var body: [String: Any] = [
            "isEnabled": isEnabled,
            "publicSlug": publicSlug,
            "bookingMode": bookingMode,
            "requiresDeposit": requiresDeposit,
            "paymentMethods": paymentMethods,
            "paymentDeadlineMinutes": paymentDeadline,
            "chargeOnNoShow": chargeOnNoShow,
            "keepsDepositOnNoShow": keepsDeposit,
            "minHoursBeforeCancel": minHoursCancel,
            "refundOnEarlyCancel": refundOnCancel,
            "maxDaysInAdvance": maxDaysAdvance,
            "minHoursInAdvance": minHoursAdvance,
            "allowNewPatients": allowNewPatients,
            "requiresInsuranceInfo": requiresInsurance,
            "welcomeMessage": welcomeMessage,
            "instructions": instructions,
            "bankName": bankName,
            "bankAccountHolder": bankHolder,
            "bankCbu": bankCbu,
            "bankAlias": bankAlias,
        ]
        if let fee = Double(consultationFee) { body["consultationFee"] = fee }
        if let dep = Double(depositAmount) { body["depositAmount"] = dep }
        if let ns = Double(noShowFee) { body["noShowFee"] = ns }
        
        var req = URLRequest(url: URL(string: "\(APIConfig.baseURL)/api/v1/booking/settings")!)
        req.httpMethod = "PUT"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue(orgId, forHTTPHeaderField: "x-organization-id")
        req.setValue(auth.doctorId, forHTTPHeaderField: "x-doctor-id")
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        do {
            _ = try await URLSession.shared.data(for: req)
            await MainActor.run { isSaving = false; dismiss() }
        } catch {
            await MainActor.run { isSaving = false }
        }
    }
    
    private func numString(_ v: Any?) -> String {
        if let d = v as? Double { return String(format: "%.0f", d) }
        if let s = v as? String, let d = Double(s) { return String(format: "%.0f", d) }
        if let i = v as? Int { return "\(i)" }
        return ""
    }
}

// MARK: - Mode Option

struct ModeOption: View {
    let id: String
    @Binding var selected: String
    let icon: String
    let title: String
    let subtitle: String
    let colors: [Color]
    
    var isSelected: Bool { selected == id }
    
    var body: some View {
        Button { withAnimation(.spring(response: 0.3)) { selected = id } } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isSelected ? LinearGradient.medi(colors)
                                         : LinearGradient.medi([.mediTextMuted.opacity(0.15), .mediTextMuted.opacity(0.08)]))
                        .frame(width: 40, height: 40)
                    Image(systemName: icon)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(isSelected ? .white : Color.mediTextMuted)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.mediHeadline(15))
                        .foregroundStyle(Color.mediText)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(Color.mediTextSoft)
                }
                
                Spacer()
                
                ZStack {
                    Circle()
                        .stroke(isSelected ? colors.first! : Color.mediTextMuted.opacity(0.3), lineWidth: 2)
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Circle().fill(LinearGradient.medi(colors)).frame(width: 13, height: 13)
                    }
                }
            }
            .padding(12)
            .background(isSelected ? colors.first!.opacity(0.06) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}
