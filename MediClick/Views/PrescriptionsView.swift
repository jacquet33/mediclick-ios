import SwiftUI
import SwiftData

struct PrescriptionsView: View {
    @Query(sort: \LocalPrescription.issuedAt, order: .reverse) private var prescriptions: [LocalPrescription]
    @State private var showNew = false
    @State private var searchText = ""
    
    var filtered: [LocalPrescription] {
        if searchText.isEmpty { return prescriptions }
        return prescriptions.filter {
            $0.diagnosis.localizedCaseInsensitiveContains(searchText) ||
            ($0.patient?.fullName ?? "").localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                MediBackground()
                
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 12) {
                        if prescriptions.isEmpty {
                            EmptyStateMedi(
                                icon: "cross.case.fill",
                                title: "Sin recetas",
                                subtitle: "Las recetas emitidas aparecerán acá",
                                actionTitle: "Emitir receta"
                            ) { showNew = true }
                            .padding(.top, 60)
                        } else {
                            ForEach(filtered) { rx in
                                NavigationLink {
                                    PrescriptionDetailView(prescription: rx)
                                } label: {
                                    PrescriptionCardPro(prescription: rx)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(20)
                }
                .searchable(text: $searchText, prompt: "Buscar receta o paciente")
            }
            .navigationTitle("Recetas")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showNew = true } label: {
                        ZStack {
                            Circle().fill(LinearGradient.mediHero).frame(width: 34, height: 34)
                            Image(systemName: "plus").font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
                        }
                        .shadow(color: .mediCyan.opacity(0.4), radius: 8, y: 3)
                    }
                }
            }
            .sheet(isPresented: $showNew) { NewPrescriptionView() }
        }
    }
}

struct PrescriptionCardPro: View {
    let prescription: LocalPrescription
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(LinearGradient.medi(MediStatus.gradient(for: prescription.status)))
                        .frame(width: 40, height: 40)
                    Image(systemName: "pills.fill")
                        .font(.system(size: 17))
                        .foregroundStyle(.white)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(prescription.items?.first?.medicationName ?? "Receta")
                        .font(.mediHeadline(15))
                        .foregroundStyle(Color.mediText)
                    Text(prescription.diagnosis)
                        .font(.caption)
                        .foregroundStyle(Color.mediTextSoft)
                        .lineLimit(1)
                }
                
                Spacer()
                
                MediBadge(MediStatus.label(for: prescription.status),
                          color: MediStatus.color(for: prescription.status))
            }
            
            if let item = prescription.items?.first {
                HStack(spacing: 6) {
                    Image(systemName: "clock.arrow.circlepath").font(.caption2)
                    Text("\(item.frequency)\(item.duration.map { " · \($0)" } ?? "")")
                        .font(.caption)
                }
                .foregroundStyle(Color.mediTextSoft)
            }
            
            Divider().overlay(Color.mediPrimary.opacity(0.1))
            
            HStack {
                HStack(spacing: 5) {
                    Image(systemName: "person.fill").font(.caption2)
                    Text(prescription.patient?.fullName ?? "")
                        .font(.caption)
                }
                .foregroundStyle(Color.mediTextSoft)
                Spacer()
                if let code = prescription.verificationCode {
                    Text(code)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Color.mediPrimary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.mediPrimary.opacity(0.08))
                        .clipShape(Capsule())
                }
            }
        }
        .mediElevated(padding: 16)
    }
}

struct PrescriptionDetailView: View {
    let prescription: LocalPrescription
    @State private var isLoadingPdf = false
    @State private var pdfURL: URL?
    @State private var showShareSheet = false
    @State private var pdfError: String?
    
    var body: some View {
        ZStack {
            MediBackground()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    // Header
                    VStack(spacing: 12) {
                        ZStack {
                            Circle().fill(LinearGradient.medi(MediStatus.gradient(for: prescription.status)))
                                .frame(width: 70, height: 70)
                            Image(systemName: "cross.case.fill")
                                .font(.system(size: 30))
                                .foregroundStyle(.white)
                        }
                        .shadow(color: MediStatus.color(for: prescription.status).opacity(0.4), radius: 12, y: 5)
                        
                        Text(prescription.patient?.fullName ?? "Paciente")
                            .font(.mediTitle(21))
                            .foregroundStyle(Color.mediText)
                        MediBadge(MediStatus.label(for: prescription.status),
                                  color: MediStatus.color(for: prescription.status))
                    }
                    .frame(maxWidth: .infinity)
                    .mediElevated(padding: 20)
                    
                    // Botones de acción: PDF + Compartir código
                    HStack(spacing: 12) {
                        Button {
                            Task { await downloadPdf() }
                        } label: {
                            HStack(spacing: 8) {
                                if isLoadingPdf {
                                    ProgressView().tint(.white)
                                } else {
                                    Image(systemName: "doc.text.fill")
                                }
                                Text("Ver PDF")
                            }
                            .font(.mediCaption(14))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(LinearGradient.medi([.mediCyan, .mediSky]))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .shadow(color: .mediCyan.opacity(0.3), radius: 8, y: 3)
                        }
                        .disabled(isLoadingPdf)
                        
                        Button {
                            Task { await downloadAndShare() }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "square.and.arrow.up")
                                Text("Compartir")
                            }
                            .font(.mediCaption(14))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(LinearGradient.medi([.mediPrimary, .mediDeep]))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .shadow(color: .mediPrimary.opacity(0.3), radius: 8, y: 3)
                        }
                    }
                    .mediElevated(padding: 14)
                    
                    if let pdfError {
                        if prescriptionServerId == nil {
                            // Receta local sin sincronizar — ofrecer sincronizar
                            Button {
                                Task { await retrySyncAndGeneratePdf() }
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                    Text("Sincronizar receta")
                                }
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Color.mediTeal)
                                .frame(maxWidth: .infinity)
                                .padding(12)
                                .background(Color.mediTealSoft)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.mediTeal.opacity(0.2), lineWidth: 0.5))
                            }
                        } else {
                            Text(pdfError)
                                .font(.caption)
                                .foregroundStyle(Color.mediDanger)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        MediSectionHeader(title: "Diagnóstico", icon: "stethoscope")
                        Text(prescription.diagnosis)
                            .font(.body)
                            .foregroundStyle(Color.mediText)
                        if let code = prescription.diagnosisCode {
                            MediBadge("CIE-10: \(code)", color: .mediPrimary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .mediElevated()
                    
                    VStack(alignment: .leading, spacing: 14) {
                        MediSectionHeader(title: "Medicamentos", icon: "pills.fill")
                        ForEach(prescription.items ?? [], id: \.id) { item in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(item.medicationName)
                                    .font(.mediHeadline(15))
                                    .foregroundStyle(Color.mediText)
                                HStack(spacing: 8) {
                                    MediBadge(item.dosage, color: .mediCyan)
                                    Text(item.frequency)
                                        .font(.caption)
                                        .foregroundStyle(Color.mediTextSoft)
                                }
                                if let duration = item.duration {
                                    Text("Duración: \(duration)")
                                        .font(.caption)
                                        .foregroundStyle(Color.mediTextMuted)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(Color.mediBgSoft.opacity(0.5))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                    .mediElevated()
                    
                    VStack(spacing: 12) {
                        MediSectionHeader(title: "Verificación", icon: "checkmark.seal.fill")
                        if let code = prescription.verificationCode {
                            Text(code)
                                .font(.system(size: 22, weight: .bold, design: .monospaced))
                                .foregroundStyle(LinearGradient.medi([.mediPrimary, .mediDeep]))
                                .padding(.vertical, 12)
                                .frame(maxWidth: .infinity)
                                .background(Color.mediBgSoft.opacity(0.6))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        MediInfoRow(icon: "calendar", label: "Emitida", value: prescription.issuedAt.formatted(date: .abbreviated, time: .omitted))
                        MediInfoRow(icon: "calendar.badge.exclamationmark", label: "Vence", value: prescription.expiresAt.formatted(date: .abbreviated, time: .omitted))
                    }
                    .mediElevated()
                }
                .padding(20)
            }
        }
        .navigationTitle("Receta")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showShareSheet) {
            if let pdfURL {
                ShareSheet(items: [pdfURL])
            }
        }
    }
    
    // MARK: - PDF Actions
    
    private var prescriptionServerId: String? {
        prescription.remoteId?.uuidString.lowercased()
    }
    
    private func downloadPdf() async {
        guard let serverId = prescriptionServerId else {
            await MainActor.run { pdfError = "Receta no sincronizada con el servidor" }
            return
        }
        isLoadingPdf = true
        pdfError = nil
        do {
            let data = try await APIClient.shared.download("/api/v1/prescriptions/\(serverId)/pdf")
            let url = savePdfToTemp(data)
            await MainActor.run {
                pdfURL = url
                isLoadingPdf = false
                if let url { UIApplication.shared.open(url) }
            }
        } catch {
            await MainActor.run {
                pdfError = "Error: \(error.localizedDescription)"
                isLoadingPdf = false
            }
        }
    }
    
    private func downloadAndShare() async {
        guard let serverId = prescriptionServerId else {
            await MainActor.run { pdfError = "Receta no sincronizada con el servidor" }
            return
        }
        isLoadingPdf = true
        pdfError = nil
        do {
            let data = try await APIClient.shared.download("/api/v1/prescriptions/\(serverId)/pdf")
            let url = savePdfToTemp(data)
            await MainActor.run {
                pdfURL = url
                isLoadingPdf = false
                if url != nil { showShareSheet = true }
            }
        } catch {
            await MainActor.run {
                pdfError = "Error: \(error.localizedDescription)"
                isLoadingPdf = false
            }
        }
    }
    
    private func savePdfToTemp(_ data: Data) -> URL? {
        let patientName = prescription.patient?.fullName.replacingOccurrences(of: " ", with: "_") ?? "receta"
        let fileName = "Receta_\(patientName)_\(Date.now.formatted(.dateTime.day().month().year())).pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        do {
            try data.write(to: url)
            return url
        } catch {
            return nil
        }
    }
    
    private func retrySyncAndGeneratePdf() async {
        isLoadingPdf = true
        pdfError = nil
        
        struct CreatePatientReq: Encodable {
            let firstName: String; let lastName: String
            let phone: String?; let email: String?; let dni: String?
        }
        struct CreatePatientResp: Decodable { let id: String }
        struct CreateRxRequest: Encodable {
            let patientId: String; let diagnosis: String
            let diagnosisCode: String?; let notes: String?
            let items: [CreateRxItem]
        }
        struct CreateRxItem: Encodable {
            let medicationName: String; let dosage: String?
            let frequency: String?; let duration: String?; let quantity: Int?
        }
        struct CreateRxResponse: Decodable {
            let id: String; let verificationCode: String?
            enum CodingKeys: String, CodingKey { case id; case verificationCode = "verification_code" }
        }
        
        guard let patient = prescription.patient else {
            await MainActor.run { pdfError = "Sin paciente asociado"; isLoadingPdf = false }
            return
        }
        
        do {
            // 1. Sincronizar paciente si no tiene remoteId
            var patientServerId = patient.remoteId?.uuidString
            if patientServerId == nil {
                let pReq = CreatePatientReq(
                    firstName: patient.firstName, lastName: patient.lastName,
                    phone: patient.phone, email: patient.email, dni: patient.dni
                )
                let pResp: CreatePatientResp = try await APIClient.shared.post("/api/v1/patients", body: pReq)
                await MainActor.run {
                    patient.remoteId = UUID(uuidString: pResp.id)
                    patient.syncStatus = .synced
                    try? patient.modelContext?.save()
                }
                patientServerId = pResp.id
            }
            
            guard let pid = patientServerId else {
                await MainActor.run { pdfError = "No se pudo sincronizar el paciente"; isLoadingPdf = false }
                return
            }
            
            // 2. Sincronizar receta
            let request = CreateRxRequest(
                patientId: pid,
                diagnosis: prescription.diagnosis,
                diagnosisCode: prescription.diagnosisCode,
                notes: nil,
                items: (prescription.items ?? []).map { item in
                    CreateRxItem(
                        medicationName: item.medicationName,
                        dosage: item.dosage,
                        frequency: item.frequency,
                        duration: item.duration,
                        quantity: nil
                    )
                }
            )
            
            let response: CreateRxResponse = try await APIClient.shared.post("/api/v1/prescriptions", body: request)
            
            await MainActor.run {
                prescription.remoteId = UUID(uuidString: response.id)
                if let code = response.verificationCode { prescription.verificationCode = code }
                prescription.syncStatus = .synced
                try? prescription.modelContext?.save()
            }
            
            // 3. Descargar PDF
            await downloadPdf()
        } catch {
            await MainActor.run {
                pdfError = "Error: \(error.localizedDescription)"
                isLoadingPdf = false
            }
        }
    }
}

// ShareSheet is defined in BatchDetailView.swift

// MARK: - Template Picker Sheet

struct TemplatePickerSheet: View {
    let templates: [NewPrescriptionView.RxTemplate]
    var onSelect: (NewPrescriptionView.RxTemplate) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                MediBackground()
                
                if templates.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 32))
                            .foregroundStyle(Color.mediTextMuted)
                        Text("No hay plantillas cargadas")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.mediTextSoft)
                        Text("Las plantillas se crean desde la configuración o se precargan con la migración.")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.mediTextMuted)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 8) {
                            ForEach(templates) { t in
                                Button {
                                    onSelect(t)
                                    dismiss()
                                } label: {
                                    HStack(spacing: 12) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(Color.mediTealSoft)
                                                .frame(width: 36, height: 36)
                                            Image(systemName: "doc.text")
                                                .font(.system(size: 15))
                                                .foregroundStyle(Color.mediTeal)
                                        }
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(t.name)
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundStyle(Color.mediText)
                                            if let cat = t.category {
                                                Text(cat)
                                                    .font(.system(size: 12))
                                                    .foregroundStyle(Color.mediTextMuted)
                                            }
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 11))
                                            .foregroundStyle(Color.mediTextMuted)
                                    }
                                    .padding(12)
                                    .background(Color.mediSurface)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.mediBorder, lineWidth: 0.5))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(20)
                    }
                }
            }
            .navigationTitle("Plantillas")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }.foregroundStyle(Color.mediTeal)
                }
            }
        }
    }
}

struct NewPrescriptionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \LocalPatient.lastName) private var patients: [LocalPatient]
    
    @State private var selectedPatient: LocalPatient?
    @State private var diagnosis = ""
    @State private var diagnosisCode = ""
    @State private var daysValid = 30
    
    // Medication items (multiple)
    @State private var medications: [MedItem] = [MedItem()]
    
    // Templates
    @State private var templates: [RxTemplate] = []
    @State private var showTemplates = false
    
    struct MedItem: Identifiable {
        let id = UUID()
        var name = ""
        var amount = ""
        var unit = "mg"
        var frequency = "Cada 8 horas"
        var duration = "7 días"
        var customFrequency = ""
        var customDuration = ""
    }
    
    struct RxTemplate: Decodable, Identifiable {
        let id: String
        let name: String
        let category: String?
        let diagnosis: String?
        let diagnosisCode: String?
        let items: [RxTemplateItem]?
        
        enum CodingKeys: String, CodingKey {
            case id, name, category, diagnosis, items
            case diagnosisCode = "diagnosis_code"
        }
    }
    struct RxTemplateItem: Decodable {
        let medicationName: String?
        let dosage: String?
        let frequency: String?
        let duration: String?
        let quantity: Int?
        
        enum CodingKeys: String, CodingKey {
            case dosage, frequency, duration, quantity
            case medicationName = "medication_name"
        }
    }
    
    static let units = ["mg", "g", "ml", "gotas", "comp.", "cáps.", "sobres", "ampollas", "puffs", "UI", "mcg", "cucharaditas"]
    static let frequencies = ["Cada 4 horas", "Cada 6 horas", "Cada 8 horas", "Cada 12 horas", "Cada 24 horas",
                              "1 vez al día", "2 veces al día", "3 veces al día",
                              "En ayunas", "Antes de dormir",
                              "Cada 48 horas", "1 vez por semana",
                              "Según necesidad", "Otro"]
    static let durations = ["3 días", "5 días", "7 días", "10 días", "14 días", "21 días",
                            "30 días", "60 días", "90 días", "Uso continuo", "Otro"]
    
    var body: some View {
        NavigationStack {
            ZStack {
                MediBackground()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        // Template selector
                        Button { loadTemplates() } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "doc.on.doc")
                                    .font(.system(size: 14))
                                Text("Usar plantilla")
                                    .font(.system(size: 14, weight: .medium))
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11))
                            }
                            .foregroundStyle(Color.mediTeal)
                            .padding(14)
                            .background(Color.mediTealSoft)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.mediTeal.opacity(0.2), lineWidth: 0.5))
                        }
                        
                        // Paciente
                        VStack(spacing: 12) {
                            MediSectionHeader(title: "Paciente", icon: "person.fill")
                            Menu {
                                ForEach(patients) { p in
                                    Button(p.fullName) { selectedPatient = p }
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "person.circle.fill")
                                        .foregroundStyle(Color.mediTeal)
                                    Text(selectedPatient?.fullName ?? "Seleccionar paciente")
                                        .foregroundStyle(selectedPatient == nil ? Color.mediTextMuted : Color.mediText)
                                    Spacer()
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 11))
                                        .foregroundStyle(Color.mediTextMuted)
                                }
                                .padding(14)
                                .background(Color.mediBgSoft)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.mediBorder, lineWidth: 0.5))
                            }
                        }
                        .mediElevated()
                        
                        // Diagnóstico
                        VStack(spacing: 12) {
                            MediSectionHeader(title: "Diagnóstico", icon: "stethoscope")
                            MediTextField(label: "Diagnóstico", icon: "text.alignleft", placeholder: "Ej: Faringitis aguda", text: $diagnosis)
                            MediTextField(label: "Código CIE-10", icon: "number", placeholder: "Ej: J02.9", text: $diagnosisCode)
                        }
                        .mediElevated()
                        
                        // Medicamentos
                        ForEach($medications) { $med in
                            VStack(spacing: 12) {
                                HStack {
                                    MediSectionHeader(title: "Medicamento", icon: "pills.fill")
                                    Spacer()
                                    if medications.count > 1 {
                                        Button {
                                            medications.removeAll { $0.id == med.id }
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.system(size: 18))
                                                .foregroundStyle(Color.mediDanger.opacity(0.6))
                                        }
                                    }
                                }
                                
                                MediTextField(label: "Nombre", icon: "pills", placeholder: "Ej: Amoxicilina", text: $med.name)
                                
                                // Dosis: cantidad + unidad
                                HStack(spacing: 8) {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("CANTIDAD")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundStyle(Color.mediTextMuted)
                                            .tracking(0.3)
                                        TextField("500", text: $med.amount)
                                            .font(.system(size: 15))
                                            .keyboardType(.decimalPad)
                                            .padding(14)
                                            .background(Color.mediBgSoft)
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.mediBorder, lineWidth: 0.5))
                                    }
                                    .frame(maxWidth: .infinity)
                                    
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("UNIDAD")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundStyle(Color.mediTextMuted)
                                            .tracking(0.3)
                                        Menu {
                                            ForEach(Self.units, id: \.self) { u in
                                                Button(u) { med.unit = u }
                                            }
                                        } label: {
                                            HStack {
                                                Text(med.unit)
                                                    .font(.system(size: 15))
                                                    .foregroundStyle(Color.mediText)
                                                Spacer()
                                                Image(systemName: "chevron.down")
                                                    .font(.system(size: 10))
                                                    .foregroundStyle(Color.mediTextMuted)
                                            }
                                            .padding(14)
                                            .background(Color.mediBgSoft)
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.mediBorder, lineWidth: 0.5))
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                                
                                // Frecuencia
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("FRECUENCIA")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(Color.mediTextMuted)
                                        .tracking(0.3)
                                    Menu {
                                        ForEach(Self.frequencies, id: \.self) { f in
                                            Button(f) { med.frequency = f }
                                        }
                                    } label: {
                                        HStack {
                                            Image(systemName: "clock")
                                                .font(.system(size: 14))
                                                .foregroundStyle(Color.mediTeal)
                                            Text(med.frequency)
                                                .font(.system(size: 15))
                                                .foregroundStyle(Color.mediText)
                                            Spacer()
                                            Image(systemName: "chevron.down")
                                                .font(.system(size: 10))
                                                .foregroundStyle(Color.mediTextMuted)
                                        }
                                        .padding(14)
                                        .background(Color.mediBgSoft)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.mediBorder, lineWidth: 0.5))
                                    }
                                }
                                if med.frequency == "Otro" {
                                    MediTextField(icon: "clock", placeholder: "Frecuencia personalizada", text: $med.customFrequency)
                                }
                                
                                // Duración
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("DURACIÓN")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(Color.mediTextMuted)
                                        .tracking(0.3)
                                    Menu {
                                        ForEach(Self.durations, id: \.self) { d in
                                            Button(d) { med.duration = d }
                                        }
                                    } label: {
                                        HStack {
                                            Image(systemName: "calendar")
                                                .font(.system(size: 14))
                                                .foregroundStyle(Color.mediTeal)
                                            Text(med.duration)
                                                .font(.system(size: 15))
                                                .foregroundStyle(Color.mediText)
                                            Spacer()
                                            Image(systemName: "chevron.down")
                                                .font(.system(size: 10))
                                                .foregroundStyle(Color.mediTextMuted)
                                        }
                                        .padding(14)
                                        .background(Color.mediBgSoft)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.mediBorder, lineWidth: 0.5))
                                    }
                                }
                                if med.duration == "Otro" {
                                    MediTextField(icon: "calendar", placeholder: "Duración personalizada", text: $med.customDuration)
                                }
                            }
                            .mediElevated()
                        }
                        
                        // Agregar otro medicamento
                        Button {
                            withAnimation { medications.append(MedItem()) }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 16))
                                Text("Agregar medicamento")
                                    .font(.system(size: 14, weight: .medium))
                            }
                            .foregroundStyle(Color.mediTeal)
                            .frame(maxWidth: .infinity)
                            .padding(12)
                            .background(Color.mediTealSoft)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        
                        // Validez
                        HStack {
                            Text("Validez: \(daysValid) días")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.mediText)
                            Spacer()
                            Stepper("", value: $daysValid, in: 1...365, step: 15)
                                .labelsHidden()
                        }
                        .padding(14)
                        .background(Color.mediSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.mediBorder, lineWidth: 0.5))
                        
                        Button { save() } label: {
                            Label("Emitir receta", systemImage: "doc.badge.plus")
                        }
                        .buttonStyle(MediButtonStyle())
                        .disabled(selectedPatient == nil || diagnosis.isEmpty || medications.first?.name.isEmpty != false)
                        .opacity(selectedPatient == nil || diagnosis.isEmpty || medications.first?.name.isEmpty != false ? 0.5 : 1)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Nueva receta")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }.foregroundStyle(Color.mediTeal)
                }
            }
            .sheet(isPresented: $showTemplates) {
                TemplatePickerSheet(templates: templates) { t in
                    applyTemplate(t)
                }
            }
        }
    }
    
    private func loadTemplates() {
        Task {
            do {
                let t: [RxTemplate] = try await APIClient.shared.get("/api/v1/prescription-templates")
                await MainActor.run {
                    templates = t
                    showTemplates = true
                }
            } catch {
                showTemplates = true // show empty
            }
        }
    }
    
    private func applyTemplate(_ t: RxTemplate) {
        diagnosis = t.diagnosis ?? ""
        diagnosisCode = t.diagnosisCode ?? ""
        if let items = t.items, !items.isEmpty {
            medications = items.map { item in
                var med = MedItem()
                med.name = item.medicationName ?? ""
                if let d = item.dosage { med.amount = d }
                if let f = item.frequency { med.frequency = f }
                if let dur = item.duration { med.duration = dur }
                return med
            }
        }
    }
    
    private func save() {
        guard let patient = selectedPatient else { return }
        let expiresAt = Calendar.current.date(byAdding: .day, value: daysValid, to: Date()) ?? Date()
        let rx = LocalPrescription(doctorId: UUID(), patient: patient, diagnosis: diagnosis, expiresAt: expiresAt)
        rx.diagnosisCode = diagnosisCode.isEmpty ? nil : diagnosisCode
        rx.verificationCode = "MC-" + String(UUID().uuidString.prefix(8)).uppercased()
        
        var localItems: [LocalPrescriptionItem] = []
        for med in medications where !med.name.isEmpty {
            let dosageStr = med.amount.isEmpty ? "" : "\(med.amount) \(med.unit)"
            let freqStr = med.frequency == "Otro" ? med.customFrequency : med.frequency
            let durStr = med.duration == "Otro" ? med.customDuration : med.duration
            let item = LocalPrescriptionItem(prescription: rx, medicationName: med.name, dosage: dosageStr, frequency: freqStr)
            item.duration = durStr.isEmpty ? nil : durStr
            modelContext.insert(item)
            localItems.append(item)
        }
        
        modelContext.insert(rx)
        try? modelContext.save()
        
        Task { await syncPrescriptionToServer(rx, items: localItems, patient: patient) }
        dismiss()
    }
    
    private func syncPrescriptionToServer(_ rx: LocalPrescription, items: [LocalPrescriptionItem], patient: LocalPatient) async {
        struct CreateRxRequest: Encodable {
            let patientId: String
            let diagnosis: String
            let diagnosisCode: String?
            let notes: String?
            let items: [CreateRxItem]
        }
        struct CreateRxItem: Encodable {
            let medicationName: String
            let dosage: String?
            let frequency: String?
            let duration: String?
            let quantity: Int?
        }
        struct CreateRxResponse: Decodable {
            let id: String
            let verificationCode: String?
            
            enum CodingKeys: String, CodingKey {
                case id
                case verificationCode = "verification_code"
            }
        }
        
        let patientServerId = patient.remoteId?.uuidString ?? patient.id.uuidString
        
        let request = CreateRxRequest(
            patientId: patientServerId,
            diagnosis: rx.diagnosis,
            diagnosisCode: rx.diagnosisCode,
            notes: nil,
            items: items.map { item in
                CreateRxItem(
                    medicationName: item.medicationName,
                    dosage: item.dosage,
                    frequency: item.frequency,
                    duration: item.duration,
                    quantity: nil
                )
            }
        )
        
        do {
            let response: CreateRxResponse = try await APIClient.shared.post("/api/v1/prescriptions", body: request)
            // Guardar el remoteId para que el PDF funcione
            await MainActor.run {
                rx.remoteId = UUID(uuidString: response.id)
                if let code = response.verificationCode {
                    rx.verificationCode = code
                }
                try? modelContext.save()
            }
            print("✅ Prescription synced: \(response.id)")
        } catch {
            print("❌ Prescription sync failed: \(error) — will retry later")
        }
    }
}
