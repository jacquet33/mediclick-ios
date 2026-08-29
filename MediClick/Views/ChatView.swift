import SwiftUI
import SwiftData

struct ChatListView: View {
    @Query(sort: \LocalConversation.lastMessageAt, order: .reverse) private var conversations: [LocalConversation]
    @Query(sort: \LocalPatient.lastName) private var patients: [LocalPatient]
    @Environment(\.modelContext) private var modelContext
    @State private var showNewChat = false
    
    var body: some View {
            ZStack {
                MediBackground()

                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 12) {
                        if conversations.isEmpty {
                            EmptyStateMedi(
                                icon: "message.badge.filled.fill",
                                title: "Sin mensajes",
                                subtitle: "Los chats con pacientes aparecerán acá",
                                actionTitle: patients.isEmpty ? nil : "Iniciar chat"
                            ) { showNewChat = true }
                            .padding(.top, 60)
                        } else {
                            ForEach(conversations) { conv in
                                NavigationLink {
                                    ChatView(conversation: conv)
                                } label: {
                                    ChatRowPro(conversation: conv)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Mensajes")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showNewChat = true } label: {
                        ZStack {
                            Circle().fill(LinearGradient.mediHero).frame(width: 34, height: 34)
                            Image(systemName: "square.and.pencil").font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                        }
                        .shadow(color: .mediCyan.opacity(0.4), radius: 8, y: 3)
                    }
                }
            }
            .sheet(isPresented: $showNewChat) {
                NewChatView()
            }
    }
}

struct ChatRowPro: View {
    let conversation: LocalConversation
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack(alignment: .topTrailing) {
                MediAvatar(name: conversation.patient?.fullName ?? "?", size: 50)
                if conversation.doctorUnreadCount > 0 {
                    ZStack {
                        Circle().fill(Color.mediDanger).frame(width: 18, height: 18)
                        Text("\(conversation.doctorUnreadCount)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .offset(x: 3, y: -3)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(conversation.patient?.fullName ?? "Paciente")
                    .font(.mediHeadline(15))
                    .foregroundStyle(Color.mediText)
                Text(conversation.lastMessageText ?? "Sin mensajes")
                    .font(.caption)
                    .foregroundStyle(Color.mediTextSoft)
                    .lineLimit(1)
            }
            
            Spacer()
            
            if let date = conversation.lastMessageAt {
                Text(date, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(Color.mediTextMuted)
            }
        }
        .mediElevated(padding: 14)
    }
}

struct ChatView: View {
    let conversation: LocalConversation
    @Environment(\.modelContext) private var modelContext
    @State private var messageText = ""
    
    var sortedMessages: [LocalMessage] {
        (conversation.messages ?? []).sorted { $0.createdAt < $1.createdAt }
    }
    
    var body: some View {
        ZStack {
            MediBackground()
            
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 10) {
                            ForEach(sortedMessages) { msg in
                                MessageBubblePro(message: msg).id(msg.id)
                            }
                        }
                        .padding(20)
                    }
                    .onChange(of: sortedMessages.count) {
                        if let last = sortedMessages.last {
                            withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                        }
                    }
                }
                
                // Input bar
                HStack(spacing: 12) {
                    TextField("Escribir mensaje...", text: $messageText, axis: .vertical)
                        .lineLimit(1...4)
                        .padding(14)
                        .background(Color.white.opacity(0.8))
                        .clipShape(RoundedRectangle(cornerRadius: 22))
                        .overlay(
                            RoundedRectangle(cornerRadius: 22)
                                .stroke(LinearGradient.mediBorder, lineWidth: 1)
                        )
                    
                    Button { sendMessage() } label: {
                        ZStack {
                            Circle()
                                .fill(messageText.trimmingCharacters(in: .whitespaces).isEmpty
                                      ? LinearGradient.medi([.mediTextMuted, .mediTextMuted])
                                      : LinearGradient.mediHero)
                                .frame(width: 44, height: 44)
                            Image(systemName: "arrow.up")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        .shadow(color: .mediCyan.opacity(0.3), radius: 8, y: 3)
                    }
                    .disabled(messageText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
            }
        }
        .navigationTitle(conversation.patient?.fullName ?? "Chat")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func sendMessage() {
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        messageText = ""
        
        Task {
            struct SendMsgReq: Encodable { let content: String }
            struct SendMsgResp: Decodable { let id: String; let content: String }
            
            let convId = conversation.remoteId?.uuidString ?? conversation.id.uuidString
            
            do {
                let resp: SendMsgResp = try await APIClient.shared.post(
                    "/api/v1/conversations/\(convId)/messages", body: SendMsgReq(content: text)
                )
                
                await MainActor.run {
                    let msg = LocalMessage(conversation: conversation, senderType: "doctor", senderId: UUID(), content: text)
                    msg.remoteId = UUID(uuidString: resp.id)
                    msg.syncStatus = .synced
                    modelContext.insert(msg)
                    conversation.lastMessageText = text
                    conversation.lastMessageAt = Date()
                    try? modelContext.save()
                }
            } catch {
                // Guardar local como fallback
                await MainActor.run {
                    let msg = LocalMessage(conversation: conversation, senderType: "doctor", senderId: UUID(), content: text)
                    msg.syncStatus = .pendingUpload
                    modelContext.insert(msg)
                    conversation.lastMessageText = text
                    conversation.lastMessageAt = Date()
                    try? modelContext.save()
                }
                print("❌ Message send failed: \(error)")
            }
        }
    }
}

struct MessageBubblePro: View {
    let message: LocalMessage
    var isDoctor: Bool { message.senderType == "doctor" }
    
    var body: some View {
        HStack {
            if isDoctor { Spacer(minLength: 60) }
            
            VStack(alignment: isDoctor ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(.subheadline)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)
                    .background(
                        ZStack {
                            if isDoctor {
                                LinearGradient.mediHero
                                LinearGradient.mediShine
                            } else {
                                Color.white
                            }
                        }
                    )
                    .foregroundStyle(isDoctor ? .white : Color.mediText)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(isDoctor ? .white.opacity(0.2) : Color.mediPrimary.opacity(0.12), lineWidth: 1)
                    )
                    .shadow(color: isDoctor ? .mediCyan.opacity(0.25) : .mediPrimary.opacity(0.06), radius: 8, y: 3)
                
                Text(message.createdAt, style: .time)
                    .font(.system(size: 10))
                    .foregroundStyle(Color.mediTextMuted)
            }
            
            if !isDoctor { Spacer(minLength: 60) }
        }
    }
}

struct NewChatView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \LocalPatient.lastName) private var patients: [LocalPatient]
    @State private var searchText = ""
    
    var filtered: [LocalPatient] {
        if searchText.isEmpty { return patients }
        return patients.filter { $0.fullName.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                MediBackground()
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 10) {
                        ForEach(filtered) { patient in
                            Button {
                                createConversation(with: patient)
                            } label: {
                                HStack(spacing: 12) {
                                    MediAvatar(name: patient.fullName, size: 46)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(patient.fullName)
                                            .font(.mediCaption(15))
                                            .foregroundStyle(Color.mediText)
                                        Text(patient.phone ?? "")
                                            .font(.caption)
                                            .foregroundStyle(Color.mediTextSoft)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(Color.mediPrimary)
                                }
                                .mediElevated(padding: 14)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(20)
                }
                .searchable(text: $searchText, prompt: "Buscar paciente")
            }
            .navigationTitle("Nuevo chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }.foregroundStyle(Color.mediPrimary)
                }
            }
        }
    }
    
    private func createConversation(with patient: LocalPatient) {
        let conv = LocalConversation(doctorId: UUID(), patient: patient)
        modelContext.insert(conv)
        try? modelContext.save()
        dismiss()
    }
}
