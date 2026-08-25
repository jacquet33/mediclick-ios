import SwiftUI
import SwiftData

struct PatientsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \LocalPatient.lastName) private var patients: [LocalPatient]
    @State private var searchText = ""
    @State private var showNewPatient = false
    
    var filteredPatients: [LocalPatient] {
        if searchText.isEmpty { return patients }
        return patients.filter {
            $0.fullName.localizedCaseInsensitiveContains(searchText) ||
            ($0.dni ?? "").contains(searchText)
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.mediBackground.ignoresSafeArea()
                
                List {
                    ForEach(filteredPatients) { patient in
                        NavigationLink {
                            PatientDetailView(patient: patient)
                        } label: {
                            HStack(spacing: 12) {
                                MediAvatar(name: patient.fullName, size: 44)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(patient.fullName)
                                        .font(.body.weight(.medium))
                                        .foregroundStyle(Color.mediTextPrimary)
                                    HStack(spacing: 4) {
                                        Image(systemName: "heart.text.clipboard")
                                            .font(.caption2)
                                        Text(patient.chronicConditions.joined(separator: " · "))
                                            .lineLimit(1)
                                    }
                                    .font(.caption)
                                    .foregroundStyle(Color.mediTextSecondary)
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .trailing, spacing: 2) {
                                    if let age = patient.age {
                                        Text("\(age) años")
                                            .font(.subheadline.weight(.medium))
                                            .foregroundStyle(Color.mediPrimary)
                                    }
                                    Text(patient.insuranceProvider ?? "")
                                        .font(.caption2)
                                        .foregroundStyle(Color.mediTextMuted)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .searchable(text: $searchText, prompt: "Buscar por nombre o DNI")
            }
            .navigationTitle("Pacientes")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showNewPatient = true } label: {
                        Image(systemName: "person.badge.plus")
                            .foregroundStyle(Color.mediPrimary)
                    }
                }
            }
            .overlay {
                if patients.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "person.2.badge.gearshape")
                            .font(.system(size: 50))
                            .foregroundStyle(Color.mediPrimary.opacity(0.4))
                        Text("Sin pacientes")
                            .font(.title3.weight(.medium))
                            .foregroundStyle(Color.mediTextPrimary)
                        Text("Agregá tu primer paciente")
                            .font(.subheadline)
                            .foregroundStyle(Color.mediTextSecondary)
                        Button("Agregar paciente") { showNewPatient = true }
                            .buttonStyle(MediButtonStyle())
                            .frame(width: 200)
                    }
                }
            }
            .sheet(isPresented: $showNewPatient) {
                NewPatientView()
            }
        }
    }
}

struct PatientDetailView: View {
    let patient: LocalPatient
    
    var body: some View {
        ZStack {
            Color.mediBackground.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 16) {
                    // Header
                    VStack(spacing: 12) {
                        MediAvatar(name: patient.fullName, size: 70)
                        Text(patient.fullName)
                            .font(.title2.bold())
                            .foregroundStyle(Color.mediTextPrimary)
                        if let age = patient.age {
                            Text("\(age) años · DNI \(patient.dni ?? "—")")
                                .font(.subheadline)
                                .foregroundStyle(Color.mediTextSecondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(color: Color.mediPrimary.opacity(0.06), radius: 8, y: 2)
                    
                    // Contact
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Contacto", systemImage: "phone.circle.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.mediPrimary)
                        MediInfoRow(icon: "phone.fill", label: "Teléfono", value: patient.phone ?? "—")
                        MediInfoRow(icon: "envelope.fill", label: "Email", value: patient.email ?? "—")
                        MediInfoRow(icon: "cross.case.fill", label: "Obra social", value: patient.insuranceProvider ?? "—")
                    }
                    .mediCard()
                    
                    // Allergies
                    if !patient.allergies.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Alergias", systemImage: "exclamationmark.triangle.fill")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.mediDanger)
                            FlowLayout(items: patient.allergies) { allergy in
                                MediBadge(allergy, color: .mediDanger, bgColor: .mediDangerLight)
                            }
                        }
                        .mediCard()
                    }
                    
                    // Chronic conditions
                    if !patient.chronicConditions.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Condiciones crónicas", systemImage: "heart.text.clipboard")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.mediPrimary)
                            FlowLayout(items: patient.chronicConditions) { cond in
                                MediBadge(cond, color: .mediPrimary, bgColor: Color.mediPrimary.opacity(0.12))
                            }
                        }
                        .mediCard()
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Ficha")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct MediInfoRow: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(Color.mediPrimary)
                .frame(width: 20)
            Text(label)
                .font(.subheadline)
                .foregroundStyle(Color.mediTextSecondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.mediTextPrimary)
        }
    }
}

struct NewPatientView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var dni = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var dateOfBirth = Date()
    @State private var insuranceProvider = ""
    @State private var insuranceNumber = ""
    @State private var allergiesText = ""
    @State private var conditionsText = ""
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.mediBackground.ignoresSafeArea()
                Form {
                    Section {
                        Label("Datos personales", systemImage: "person.fill")
                            .foregroundStyle(Color.mediPrimary)
                    }
                    Section {
                        TextField("Nombre *", text: $firstName)
                        TextField("Apellido *", text: $lastName)
                        TextField("DNI", text: $dni).keyboardType(.numberPad)
                        TextField("Teléfono", text: $phone).keyboardType(.phonePad)
                        TextField("Email", text: $email).keyboardType(.emailAddress).autocapitalization(.none)
                        DatePicker("Nacimiento", selection: $dateOfBirth, displayedComponents: .date)
                    }
                    Section {
                        Label("Obra social", systemImage: "cross.case.fill")
                            .foregroundStyle(Color.mediPrimary)
                    }
                    Section {
                        TextField("Obra social / Prepaga", text: $insuranceProvider)
                        TextField("Nro. de afiliado", text: $insuranceNumber)
                    }
                    Section {
                        Label("Datos clínicos", systemImage: "heart.text.clipboard")
                            .foregroundStyle(Color.mediPrimary)
                    }
                    Section {
                        TextField("Alergias (separar con coma)", text: $allergiesText)
                        TextField("Condiciones crónicas (separar con coma)", text: $conditionsText)
                    }
                    Section {
                        Button { save() } label: {
                            HStack {
                                Image(systemName: "person.badge.plus")
                                Text("Guardar paciente")
                            }
                            .frame(maxWidth: .infinity)
                            .foregroundStyle(Color.mediPrimary)
                        }
                        .disabled(firstName.isEmpty || lastName.isEmpty)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Nuevo paciente")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
        }
    }
    
    private func save() {
        let patient = LocalPatient(doctorId: UUID(), firstName: firstName, lastName: lastName)
        patient.dni = dni.isEmpty ? nil : dni
        patient.phone = phone.isEmpty ? nil : phone
        patient.email = email.isEmpty ? nil : email
        patient.dateOfBirth = dateOfBirth
        patient.insuranceProvider = insuranceProvider.isEmpty ? nil : insuranceProvider
        patient.insuranceNumber = insuranceNumber.isEmpty ? nil : insuranceNumber
        patient.allergies = allergiesText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        patient.chronicConditions = conditionsText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        patient.syncStatus = .pendingUpload
        modelContext.insert(patient)
        try? modelContext.save()
        dismiss()
    }
}

struct FlowLayout<T: Hashable, Content: View>: View {
    let items: [T]
    let content: (T) -> Content
    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], alignment: .leading, spacing: 6) {
            ForEach(items, id: \.self) { item in content(item) }
        }
    }
}
