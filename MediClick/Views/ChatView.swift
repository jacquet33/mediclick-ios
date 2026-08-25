import SwiftUI
import SwiftData

struct ChatListView: View {
    @Query(sort: \LocalConversation.lastMessageAt, order: .reverse) private var conversations: [LocalConversation]
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(conversations) { conv in
                    NavigationLink {
                        ChatView(conversation: conv)
                    } label: {
                        ChatRow(conversation: conv)
                    }
                }
            }
            .navigationTitle("Mensajes")
            .overlay {
                if conversations.isEmpty {
                    ContentUnavailableView {
                        Label("Sin mensajes", systemImage: "message")
                    } description: {
                        Text("Los chats con pacientes aparecerán acá")
                    }
                }
            }
        }
    }
}

struct ChatRow: View {
    let conversation: LocalConversation
    
    var body: some View {
        HStack(spacing: 12) {
            if conversation.doctorUnreadCount > 0 {
                Circle()
                    .fill(.blue)
                    .frame(width: 8, height: 8)
            } else {
                Spacer().frame(width: 8)
            }
            
            PatientAvatar(name: conversation.patient?.fullName ?? "?", size: 44)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(conversation.patient?.fullName ?? "Paciente")
                    .font(.body.weight(.medium))
                Text(conversation.lastMessageText ?? "")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            if let date = conversation.lastMessageAt {
                Text(date, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Chat Conversation

struct ChatView: View {
    let conversation: LocalConversation
    @Environment(\.modelContext) private var modelContext
    @State private var messageText = ""
    @State private var messages: [LocalMessage] = []
    
    var body: some View {
        VStack(spacing: 0) {
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(conversation.messages?.sorted(by: { $0.createdAt < $1.createdAt }) ?? []) { msg in
                            MessageBubble(message: msg)
                                .id(msg.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: conversation.messages?.count) {
                    if let last = conversation.messages?.sorted(by: { $0.createdAt < $1.createdAt }).last {
                        withAnimation {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            // Input bar
            HStack(spacing: 12) {
                TextField("Escribir mensaje...", text: $messageText, axis: .vertical)
                    .lineLimit(1...4)
                    .padding(10)
                    .background(.gray.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                
                Button {
                    sendMessage()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.blue)
                }
                .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(.bar)
        }
        .navigationTitle(conversation.patient?.fullName ?? "Chat")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func sendMessage() {
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        let msg = LocalMessage(
            conversation: conversation,
            senderType: "doctor",
            senderId: UUID(),
            content: text
        )
        modelContext.insert(msg)
        
        conversation.lastMessageText = text
        conversation.lastMessageAt = Date()
        
        try? modelContext.save()
        messageText = ""
    }
}

struct MessageBubble: View {
    let message: LocalMessage
    
    var isDoctor: Bool { message.senderType == "doctor" }
    
    var body: some View {
        HStack {
            if isDoctor { Spacer(minLength: 60) }
            
            VStack(alignment: isDoctor ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(.body)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(isDoctor ? .blue : Color(.systemGray5))
                    .foregroundStyle(isDoctor ? .white : .primary)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                
                Text(message.createdAt, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            
            if !isDoctor { Spacer(minLength: 60) }
        }
    }
}
