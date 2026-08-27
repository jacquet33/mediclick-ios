import SwiftUI

// MARK: - API Models

struct OrgMember: Decodable, Identifiable {
    let memberId: String
    let organizationId: String
    let doctorId: String?
    let staffId: String?
    let isOwner: Bool?
    let isActive: Bool?
    let department: String?
    let roomNumber: String?
    let roleId: String
    let roleCode: String
    let roleName: String
    let roleLevel: Int
    let roleCategory: String
    let isClinical: Bool?
    let roleIcon: String?
    let roleColor: String?
    let fullName: String
    let email: String?
    let phone: String?
    let specialty: String?
    let medicalLicense: String?
    
    var id: String { memberId }
    
    enum CodingKeys: String, CodingKey {
        case organizationId = "organization_id"
        case doctorId = "doctor_id"
        case staffId = "staff_id"
        case isOwner = "is_owner"
        case isActive = "is_active"
        case roleId = "role_id"
        case roleCode = "role_code"
        case roleName = "role_name"
        case roleLevel = "role_level"
        case roleCategory = "role_category"
        case isClinical = "is_clinical"
        case roleIcon = "role_icon"
        case roleColor = "role_color"
        case fullName = "full_name"
        case medicalLicense = "medical_license"
        case memberId = "member_id"
        case department, roomNumber = "room_number", email, phone, specialty
    }
}

struct RoleOption: Decodable, Identifiable {
    let id: String
    let code: String
    let name: String
    let description: String?
    let category: String
    let isClinical: Bool?
    let requiresLicense: Bool?
    let icon: String?
    let color: String?
    
    enum CodingKeys: String, CodingKey {
        case id, code, name, description, category, icon, color
        case isClinical = "is_clinical"
        case requiresLicense = "requires_license"
    }
}

// MARK: - Roles Management View

struct RolesManagementView: View {
    @Environment(AuthManager.self) private var auth
    @State private var members: [OrgMember] = []
    @State private var isLoading = true
    @State private var selectedMember: OrgMember?
    
    private var orgId: String { auth.activeOrganization?.id ?? "" }
    
    private var grouped: [(String, [OrgMember])] {
        let categories = ["directive", "leadership", "clinical", "administrative", "external"]
        let labels = ["Dirección", "Jefaturas", "Staff clínico", "Administrativo", "Externo"]
        
        return zip(categories, labels).compactMap { cat, label in
            let items = members.filter { $0.roleCategory == cat }
            return items.isEmpty ? nil : (label, items)
        }
    }
    
    var body: some View {
        ZStack {
            MediBackground()
            
            if isLoading {
                ProgressView().tint(.mediPrimary)
            } else if members.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "person.3")
                        .font(.system(size: 36))
                        .foregroundStyle(Color.mediTextMuted)
                    Text("Sin miembros registrados")
                        .font(.mediBody())
                        .foregroundStyle(Color.mediTextSoft)
                }
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        // Stats
                        HStack(spacing: 10) {
                            RoleStatPill(value: members.count, label: "Miembros", icon: "person.2.fill", color: .mediPrimary)
                            RoleStatPill(value: members.filter { $0.isClinical == true }.count, label: "Clínicos", icon: "stethoscope", color: .mediSuccess)
                            RoleStatPill(value: members.filter { $0.roleCategory == "administrative" }.count, label: "Admin", icon: "briefcase.fill", color: .mediWarning)
                        }
                        
                        ForEach(grouped, id: \.0) { label, items in
                            VStack(alignment: .leading, spacing: 10) {
                                MediSectionHeader(title: label, icon: categoryIcon(label))
                                
                                ForEach(items) { member in
                                    Button { selectedMember = member } label: {
                                        MemberRow(member: member)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .mediElevated()
                        }
                    }
                    .padding(20)
                }
            }
        }
        .navigationTitle("Equipo y roles")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedMember) { member in
            MemberDetailSheet(member: member, orgId: orgId) {
                Task { await load() }
            }
        }
        .task { await load() }
    }
    
    private func load() async {
        guard !orgId.isEmpty else { return }
        do {
            let m: [OrgMember] = try await APIClient.shared.get("/api/v1/organizations/\(orgId)/members")
            await MainActor.run { members = m; isLoading = false }
        } catch {
            await MainActor.run { isLoading = false }
        }
    }
    
    private func categoryIcon(_ label: String) -> String {
        switch label {
        case "Dirección": return "crown.fill"
        case "Jefaturas": return "star.fill"
        case "Staff clínico": return "stethoscope"
        case "Administrativo": return "briefcase.fill"
        default: return "person.fill"
        }
    }
}

// MARK: - Member Row

struct MemberRow: View {
    let member: OrgMember
    
    var body: some View {
        HStack(spacing: 12) {
            MediAvatar(name: member.fullName, size: 40)
            
            VStack(alignment: .leading, spacing: 3) {
                Text(member.fullName)
                    .font(.mediCaption(15))
                    .foregroundStyle(Color.mediText)
                
                HStack(spacing: 6) {
                    if let spec = member.specialty, !spec.isEmpty {
                        Text(spec)
                            .font(.caption)
                            .foregroundStyle(Color.mediTextSoft)
                    }
                    if let mp = member.medicalLicense, !mp.isEmpty {
                        Text("MP \(mp)")
                            .font(.caption)
                            .foregroundStyle(Color.mediTextMuted)
                    }
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                MediBadge(member.roleName, color: roleColor(member.roleCategory))
                if member.isOwner == true {
                    Text("Propietario")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Color.mediDeep)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    func roleColor(_ category: String) -> Color {
        switch category {
        case "directive": return .mediDeep
        case "leadership": return .mediSuccess
        case "clinical": return .mediCyan
        case "administrative": return .mediWarning
        default: return .mediTextMuted
        }
    }
}

// MARK: - Role Stat Pill

struct RoleStatPill: View {
    let value: Int
    let label: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(color)
            Text("\(value)")
                .font(.mediNumber(18))
                .foregroundStyle(Color.mediText)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color.mediTextSoft)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(color.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(color.opacity(0.12), lineWidth: 1))
    }
}

// MARK: - Member Detail / Change Role Sheet

struct MemberDetailSheet: View {
    let member: OrgMember
    let orgId: String
    var onChanged: (() -> Void)?
    
    @Environment(\.dismiss) private var dismiss
    @State private var roles: [RoleOption] = []
    @State private var selectedRoleCode: String
    @State private var isSaving = false
    @State private var isLoading = true
    
    init(member: OrgMember, orgId: String, onChanged: (() -> Void)? = nil) {
        self.member = member
        self.orgId = orgId
        self.onChanged = onChanged
        _selectedRoleCode = State(initialValue: member.roleCode)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                MediBackground()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        // Profile header
                        VStack(spacing: 12) {
                            MediAvatar(name: member.fullName, size: 64)
                            
                            Text(member.fullName)
                                .font(.mediTitle(20))
                                .foregroundStyle(Color.mediText)
                            
                            if let spec = member.specialty, !spec.isEmpty {
                                Text(spec)
                                    .font(.subheadline)
                                    .foregroundStyle(Color.mediTextSoft)
                            }
                            
                            HStack(spacing: 16) {
                                if let email = member.email {
                                    Label(email, systemImage: "envelope")
                                        .font(.caption)
                                        .foregroundStyle(Color.mediTextMuted)
                                }
                                if let mp = member.medicalLicense {
                                    Label("MP \(mp)", systemImage: "doc.text")
                                        .font(.caption)
                                        .foregroundStyle(Color.mediTextMuted)
                                }
                            }
                            
                            MediBadge(member.roleName, color: .mediPrimary)
                        }
                        .frame(maxWidth: .infinity)
                        .mediElevated(padding: 20)
                        
                        // Role selector
                        if isLoading {
                            ProgressView().tint(.mediPrimary).padding()
                        } else {
                            VStack(alignment: .leading, spacing: 12) {
                                MediSectionHeader(title: "Cambiar rol", icon: "arrow.triangle.2.circlepath")
                                
                                ForEach(roles) { role in
                                    let isSelected = role.code == selectedRoleCode
                                    Button {
                                        withAnimation(.easeInOut(duration: 0.15)) {
                                            selectedRoleCode = role.code
                                        }
                                    } label: {
                                        HStack(spacing: 12) {
                                            Image(systemName: role.icon ?? "person.fill")
                                                .font(.system(size: 16))
                                                .foregroundStyle(isSelected ? .white : Color.mediTextSoft)
                                                .frame(width: 36, height: 36)
                                                .background(
                                                    isSelected
                                                    ? AnyShapeStyle(LinearGradient.medi([.mediCyan, .mediPrimary]))
                                                    : AnyShapeStyle(Color.mediBgSoft)
                                                )
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                            
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(role.name)
                                                    .font(.mediCaption(14))
                                                    .foregroundStyle(isSelected ? Color.mediPrimary : Color.mediText)
                                                if let desc = role.description {
                                                    Text(desc)
                                                        .font(.caption2)
                                                        .foregroundStyle(Color.mediTextMuted)
                                                        .lineLimit(2)
                                                }
                                            }
                                            
                                            Spacer()
                                            
                                            if isSelected {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundStyle(Color.mediPrimary)
                                            }
                                        }
                                        .padding(10)
                                        .background(isSelected ? Color.mediCyan.opacity(0.06) : Color.clear)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(isSelected ? Color.mediCyan.opacity(0.3) : Color.clear, lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .mediElevated()
                        }
                        
                        if selectedRoleCode != member.roleCode {
                            Button {
                                Task { await changeRole() }
                            } label: {
                                if isSaving {
                                    ProgressView().tint(.white)
                                } else {
                                    Label("Guardar cambio de rol", systemImage: "checkmark.circle.fill")
                                }
                            }
                            .buttonStyle(MediButtonStyle())
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                    .padding(20)
                }
                .animation(.easeInOut(duration: 0.2), value: selectedRoleCode)
            }
            .navigationTitle("Miembro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                        .foregroundStyle(Color.mediPrimary)
                }
            }
            .task { await loadRoles() }
        }
    }
    
    private func loadRoles() async {
        do {
            let r: [RoleOption] = try await APIClient.shared.get("/api/v1/roles")
            await MainActor.run { roles = r; isLoading = false }
        } catch {
            await MainActor.run { isLoading = false }
        }
    }
    
    private func changeRole() async {
        isSaving = true
        do {
            struct RoleBody: Encodable { let roleCode: String }
            let _: OrgMember = try await APIClient.shared.put(
                "/api/v1/organizations/\(orgId)/members/\(member.id)/role",
                body: RoleBody(roleCode: selectedRoleCode)
            )
            await MainActor.run {
                onChanged?()
                dismiss()
            }
        } catch {
            await MainActor.run { isSaving = false }
        }
    }
}
