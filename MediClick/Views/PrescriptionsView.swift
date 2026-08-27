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
                        Text(pdfError)
                            .font(.caption)
                            .foregroundStyle(Color.mediDanger)
                            .frame(maxWidth: .infinity)
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
    
    private func downloadPdf() async {
        isLoadingPdf = true
        pdfError = nil
        do {
            let data = try await APIClient.shared.download("/api/v1/prescriptions/\(prescription.remoteId?.uuidString ?? prescription.id.uuidString)/pdf")
            let url = savePdfToTemp(data)
            await MainActor.run {
                pdfURL = url
                isLoadingPdf = false
                if let url { UIApplication.shared.open(url) }
            }
        } catch {
            await MainActor.run {
                pdfError = "No se pudo generar el PDF"
                isLoadingPdf = false
            }
        }
    }
    
    private func downloadAndShare() async {
        isLoadingPdf = true
        pdfError = nil
        do {
            let data = try await APIClient.shared.download("/api/v1/prescriptions/\(prescription.remoteId?.uuidString ?? prescription.id.uuidString)/pdf")
            let url = savePdfToTemp(data)
            await MainActor.run {
                pdfURL = url
                isLoadingPdf = false
                if url != nil { showShareSheet = true }
            }
        } catch {
            await MainActor.run {
                pdfError = "No se pudo generar el PDF"
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
}

// ShareSheet is defined in BatchDetailView.swift

struct NewPrescriptionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \LocalPatient.lastName) private var patients: [LocalPatient]
    
    @State private var selectedPatient: LocalPatient?
    @State private var diagnosis = ""
    @State private var diagnosisCode = ""
    @State private var medicationName = ""
    @State private var dosage = ""
    @State private var frequency = ""
    @State private var duration = ""
    @State private var daysValid = 30
    
    var body: some View {
        NavigationStack {
            ZStack {
                MediBackground()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        VStack(spacing: 14) {
                            MediSectionHeader(title: "Paciente", icon: "person.fill")
                            Menu {
                                ForEach(patients) { p in
                                    Button(p.fullName) { selectedPatient = p }
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "person.circle.fill").foregroundStyle(Color.mediPrimary)
                                    Text(selectedPatient?.fullName ?? "Seleccionar paciente")
                                        .foregroundStyle(selectedPatient == nil ? Color.mediTextMuted : Color.mediText)
                                    Spacer()
                                    Image(systemName: "chevron.down").font(.caption).foregroundStyle(Color.mediPrimary)
                                }
                                .padding(16)
                                .background(Color.white.opacity(0.7))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.mediPrimary.opacity(0.15), lineWidth: 1))
                            }
                        }
                        .mediElevated(padding: 18)
                        
                        VStack(spacing: 14) {
                            MediSectionHeader(title: "Diagnóstico", icon: "stethoscope")
                            MediTextField(icon: "text.alignleft", placeholder: "Diagnóstico", text: $diagnosis)
                            MediTextField(icon: "number", placeholder: "Código CIE-10", text: $diagnosisCode)
                        }
                        .mediElevated(padding: 18)
                        
                        VStack(spacing: 14) {
                            MediSectionHeader(title: "Medicamento", icon: "pills.fill")
                            MediTextField(icon: "pills", placeholder: "Nombre del medicamento", text: $medicationName)
                            MediTextField(icon: "scalemass", placeholder: "Dosis (ej: 10mg)", text: $dosage)
                            MediTextField(icon: "clock", placeholder: "Frecuencia", text: $frequency)
                            MediTextField(icon: "calendar", placeholder: "Duración (ej: 30 días)", text: $duration)
                            
                            HStack {
                                Text("Validez: \(daysValid) días")
                                    .font(.subheadline)
                                    .foregroundStyle(Color.mediText)
                                Spacer()
                                Stepper("", value: $daysValid, in: 1...365, step: 15)
                                    .labelsHidden()
                                    .tint(Color.mediPrimary)
                            }
                            .padding(.horizontal, 4)
                        }
                        .mediElevated(padding: 18)
                        
                        Button { save() } label: {
                            Label("Emitir receta", systemImage: "doc.badge.plus")
                        }
                        .buttonStyle(MediButtonStyle())
                        .disabled(selectedPatient == nil || diagnosis.isEmpty || medicationName.isEmpty)
                        .opacity(selectedPatient == nil || diagnosis.isEmpty || medicationName.isEmpty ? 0.6 : 1)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Nueva receta")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }.foregroundStyle(Color.mediPrimary)
                }
            }
        }
    }
    
    private func save() {
        guard let patient = selectedPatient else { return }
        let expiresAt = Calendar.current.date(byAdding: .day, value: daysValid, to: Date()) ?? Date()
        let rx = LocalPrescription(doctorId: UUID(), patient: patient, diagnosis: diagnosis, expiresAt: expiresAt)
        rx.diagnosisCode = diagnosisCode.isEmpty ? nil : diagnosisCode
        rx.verificationCode = "MC-" + String(UUID().uuidString.prefix(8)).uppercased()
        
        let item = LocalPrescriptionItem(prescription: rx, medicationName: medicationName, dosage: dosage, frequency: frequency)
        item.duration = duration.isEmpty ? nil : duration
        
        modelContext.insert(rx)
        modelContext.insert(item)
        try? modelContext.save()
        dismiss()
    }
}
