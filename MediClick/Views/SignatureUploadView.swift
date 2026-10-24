import SwiftUI
import PhotosUI

/// View for uploading / managing the doctor's digital signature image.
/// The signature gets embedded in every prescription PDF.
struct SignatureUploadView: View {
    @Environment(AuthManager.self) private var auth
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var signatureImage: UIImage?
    @State private var isUploading = false
    @State private var isDeleting = false
    @State private var showDeleteConfirm = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var hasSignature = false

    var body: some View {
        NavigationStack {
            ZStack {
                MediBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        headerSection
                        previewSection
                        actionsSection
                        tipsSection
                        statusSection
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Firma Digital")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                        .foregroundStyle(Color.mediPrimary)
                }
            }
            .onChange(of: selectedPhoto) {
                Task {
                    if let data = try? await selectedPhoto?.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data) {
                        signatureImage = resizeIfNeeded(uiImage, maxWidth: 800)
                        errorMessage = nil
                        successMessage = nil
                    }
                }
            }
            .confirmationDialog("¿Eliminar firma?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("Eliminar", role: .destructive) {
                    Task { await deleteSignature() }
                }
                Button("Cancelar", role: .cancel) {}
            } message: {
                Text("Tu firma se eliminará de las futuras recetas.")
            }
            .task { await checkSignatureStatus() }
        }
    }

    // MARK: - Body Sections

    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "signature")
                .font(.system(size: 40))
                .foregroundStyle(Color.mediPrimary)

            Text("Firma Digital")
                .font(.mediTitle(22))
                .foregroundStyle(Color.mediText)

            Text("Tu firma se incluirá automáticamente en cada receta médica que generes.")
                .font(.subheadline)
                .foregroundStyle(Color.mediTextSoft)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(.top, 8)
    }

    private var previewSection: some View {
        VStack(spacing: 12) {
            MediSectionHeader(title: "Vista previa", icon: "eye.fill")
            ZStack {
                previewBackground
                previewContent
            }
        }
        .mediElevated()
    }

    private var previewBackground: some View {
        let dashedStroke = StrokeStyle(lineWidth: 1, dash: [6, 4])
        let borderColor: Color = Color.mediPrimary.opacity(0.3)
        return RoundedRectangle(cornerRadius: 16)
            .fill(Color.white)
            .frame(height: 160)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(style: dashedStroke)
                    .foregroundStyle(borderColor)
            )
    }

    @ViewBuilder
    private var previewContent: some View {
        if let signatureImage {
            Image(uiImage: signatureImage)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 140)
                .padding(10)
        } else if hasSignature {
            VStack(spacing: 6) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(Color.mediSuccess)
                Text("Firma guardada")
                    .font(.mediCaption(14))
                    .foregroundStyle(Color.mediSuccess)
            }
        } else {
            VStack(spacing: 6) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 28))
                    .foregroundStyle(Color.mediTextSoft.opacity(0.5))
                Text("Sin firma cargada")
                    .font(.mediCaption(14))
                    .foregroundStyle(Color.mediTextSoft)
            }
        }
    }

    private var actionsSection: some View {
        VStack(spacing: 12) {
            pickerButton
            if signatureImage != nil {
                uploadButton
            }
            if hasSignature {
                deleteButton
            }
        }
        .padding(.horizontal, 4)
    }

    private var pickerButton: some View {
        let title = (hasSignature || signatureImage != nil)
            ? "Cambiar firma"
            : "Seleccionar imagen de firma"
        return PhotosPicker(selection: $selectedPhoto, matching: .images) {
            Label(title, systemImage: "photo.on.rectangle")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(MediButtonStyle(colors: [.mediPrimary, .mediCyan]))
        .disabled(isUploading)
    }

    private var uploadButton: some View {
        Button {
            Task { await uploadSignature() }
        } label: {
            uploadButtonLabel
        }
        .buttonStyle(MediButtonStyle(colors: [Color(hex: "879DFF"), Color(hex: "6B7FE6")]))
        .disabled(isUploading)
    }

    @ViewBuilder
    private var uploadButtonLabel: some View {
        if isUploading {
            ProgressView()
                .tint(.white)
                .frame(maxWidth: .infinity)
        } else {
            Label("Guardar firma", systemImage: "arrow.up.circle.fill")
                .frame(maxWidth: .infinity)
        }
    }

    private var deleteButton: some View {
        Button {
            showDeleteConfirm = true
        } label: {
            Label("Eliminar firma", systemImage: "trash")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(MediButtonStyle(colors: [.mediDanger, Color(red: 0.85, green: 0.25, blue: 0.30)]))
        .disabled(isUploading || isDeleting)
    }

    private var tipsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            MediSectionHeader(title: "Recomendaciones", icon: "lightbulb.fill")
            tipRow("Firmá sobre un papel blanco y fotografiá solo la firma")
            tipRow("Usá fondo blanco o transparente para mejor resultado")
            tipRow("La imagen no debe superar 500KB")
            tipRow("Formatos aceptados: PNG, JPEG")
        }
        .mediElevated()
    }

    @ViewBuilder
    private var statusSection: some View {
        if let errorMessage {
            statusBanner(message: errorMessage, icon: "exclamationmark.triangle.fill", color: .mediDanger)
        }
        if let successMessage {
            statusBanner(message: successMessage, icon: "checkmark.circle.fill", color: .mediSuccess)
        }
    }

    private func statusBanner(message: String, icon: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(message)
                .font(.mediCaption(13))
                .foregroundStyle(color)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Helpers

    @ViewBuilder
    private func tipRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 12))
                .foregroundStyle(Color.mediPrimary)
                .padding(.top, 2)
            Text(text)
                .font(.mediCaption(13))
                .foregroundStyle(Color.mediTextSoft)
        }
    }

    private func resizeIfNeeded(_ image: UIImage, maxWidth: CGFloat) -> UIImage {
        guard image.size.width > maxWidth else { return image }
        let scale = maxWidth / image.size.width
        let newSize = CGSize(width: maxWidth, height: image.size.height * scale)
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resized = UIGraphicsGetImageFromCurrentImageContext() ?? image
        UIGraphicsEndImageContext()
        return resized
    }

    // MARK: - API

    private func checkSignatureStatus() async {
        struct ProfileResponse: Decodable { let hasSignature: Bool }
        do {
            let profile: ProfileResponse = try await APIClient.shared.get("/api/v1/profile")
            await MainActor.run { hasSignature = profile.hasSignature }
        } catch {
            print("Could not check signature status: \(error)")
        }
    }

    private func uploadSignature() async {
        guard let image = signatureImage else { return }

        guard let pngData = image.pngData() else {
            errorMessage = "No se pudo procesar la imagen"
            return
        }

        if pngData.count > 500 * 1024 {
            guard let jpegData = image.jpegData(compressionQuality: 0.7) else {
                errorMessage = "La imagen es demasiado grande"
                return
            }
            if jpegData.count > 500 * 1024 {
                errorMessage = "La imagen supera 500KB incluso comprimida. Usá una imagen más chica."
                return
            }
            await doUpload(data: jpegData, mimeType: "image/jpeg")
        } else {
            await doUpload(data: pngData, mimeType: "image/png")
        }
    }

    private func doUpload(data: Data, mimeType: String) async {
        isUploading = true
        errorMessage = nil
        successMessage = nil

        let base64 = "data:\(mimeType);base64,\(data.base64EncodedString())"

        struct UploadBody: Encodable { let image: String }
        struct UploadResponse: Decodable { let ok: Bool; let sizeKb: Int }

        do {
            let result: UploadResponse = try await APIClient.shared.put(
                "/api/v1/profile/signature",
                body: UploadBody(image: base64)
            )
            await MainActor.run {
                isUploading = false
                if result.ok {
                    hasSignature = true
                    successMessage = "Firma guardada correctamente (\(result.sizeKb)KB)"
                }
            }
        } catch {
            await MainActor.run {
                isUploading = false
                errorMessage = "Error al subir la firma: \(error.localizedDescription)"
            }
        }
    }

    private func deleteSignature() async {
        isDeleting = true
        errorMessage = nil
        successMessage = nil

        struct OkResponse: Decodable { let ok: Bool }
        do {
            let _: OkResponse = try await APIClient.shared.delete("/api/v1/profile/signature")
            await MainActor.run {
                isDeleting = false
                hasSignature = false
                signatureImage = nil
                selectedPhoto = nil
                successMessage = "Firma eliminada"
            }
        } catch {
            await MainActor.run {
                isDeleting = false
                errorMessage = "Error al eliminar: \(error.localizedDescription)"
            }
        }
    }
}
