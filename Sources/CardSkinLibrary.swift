import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct CardSkin: Identifiable {
    let id: String
    let name: String
    let finish: String
    let fileName: String

    static let presets: [CardSkin] = [
        .init(id: "amex-black", name: "American Express Black", finish: "Centurion · negro", fileName: "amex-black.png"),
        .init(id: "amex-platinum", name: "American Express Platinum", finish: "Platinum · plata", fileName: "amex-platinum.png"),
        .init(id: "amex-gold", name: "American Express Gold", finish: "Gold · oro", fileName: "amex-gold.png"),
        .init(id: "jp-morgan-palladium", name: "J.P. Morgan Palladium", finish: "Palladium · metal cepillado", fileName: "jp-morgan-palladium.png")
    ]

    func artworkURL() -> URL? {
        let roots = [
            Bundle.main.resourceURL?.appendingPathComponent("skins"),
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent("assets/skins/premium")
        ].compactMap { $0 }
        return roots.map { $0.appendingPathComponent(fileName) }
            .first { FileManager.default.fileExists(atPath: $0.path) }
    }
}

struct SkinLibraryPreview: View {
    let onOpen: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Tus diseños").font(.title3.bold())
                    Text("Carátulas sin números añadidos ni chip")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Abrir biblioteca", action: onOpen).buttonStyle(.bordered)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 250, maximum: 250))], alignment: .leading, spacing: 20) {
                ForEach(CardSkin.presets) { skin in
                    VStack(alignment: .leading, spacing: 8) {
                        if let url = skin.artworkURL(), let image = NSImage(contentsOf: url) {
                            Image(nsImage: image).resizable().scaledToFill()
                                .frame(width: 250, height: 158)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        Text(skin.name).font(.system(size: 13, weight: .semibold))
                        Text(skin.finish).font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: 250, alignment: .leading)
                }
            }
        }
        .padding(20)
    }
}

struct SkinLibraryPresentation: Identifiable {
    let cardID: String?
    let deviceID: String?
    var id: String { "\(deviceID ?? "none")|\(cardID ?? "library")" }
}

struct SkinLibraryView: View {
    @ObservedObject var vm: AppViewModel
    let presentation: SkinLibraryPresentation
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCardID: String

    init(vm: AppViewModel, presentation: SkinLibraryPresentation) {
        self.vm = vm
        self.presentation = presentation
        _selectedCardID = State(initialValue: presentation.cardID ?? "")
    }

    private var eligibleCards: [CardItem] {
        guard vm.device?.udid == presentation.deviceID else { return [] }
        return vm.currentVerifiedCards
    }

    private var canAssign: Bool {
        !vm.isFlashing && eligibleCards.contains { $0.id == selectedCardID }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Biblioteca de diseños").font(.title2.bold())
                    Text("Tus carátulas, listas para personalizar Wallet.")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Cerrar") { dismiss() }.keyboardShortcut(.cancelAction)
            }

            LazyVGrid(columns: [GridItem(.fixed(236)), GridItem(.fixed(236))], spacing: 20) {
                ForEach(CardSkin.presets) { skin in
                    SkinPresetTile(skin: skin, canAssign: canAssign) { url in
                        guard canAssign else { return }
                        vm.setCardImage(for: selectedCardID, url: url)
                        dismiss()
                    }
                }
            }

            Divider()

            if eligibleCards.isEmpty {
                Label("Conecta tu iPhone y pulsa Scan Cards para elegir la tarjeta que quieres personalizar.", systemImage: "iphone")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Picker("Tarjeta de Wallet", selection: $selectedCardID) {
                    Text("Elige una tarjeta").tag("")
                    ForEach(eligibleCards) { card in
                        Text("\(card.displayName ?? "Tarjeta") · \(card.id.prefix(8))…").tag(card.id)
                    }
                }
                Text("Después, pulsa Flash Skins para aplicarlo al iPhone.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            HStack {
                Button("Elegir otra imagen…") { chooseImage() }.disabled(!canAssign)
                Spacer()
            }
        }
        .padding(24)
        .frame(width: 540)
    }

    private func chooseImage() {
        guard canAssign else { return }
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url, canAssign {
            vm.setCardImage(for: selectedCardID, url: url)
            dismiss()
        }
    }
}

private struct SkinPresetTile: View {
    let skin: CardSkin
    let canAssign: Bool
    let onSelect: (URL) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            artwork
                .frame(width: 236, height: 149)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .accessibilityLabel("Vista previa de \(skin.name)")
            Text(skin.name).font(.system(size: 13, weight: .semibold)).lineLimit(1)
            Text(skin.finish).font(.caption).foregroundStyle(.secondary)
            Text("Sin números añadidos · sin chip").font(.caption)
                .foregroundStyle(.secondary)
            Button("Usar este diseño") {
                if let url = skin.artworkURL() { onSelect(url) }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canAssign || skin.artworkURL() == nil)
            .accessibilityLabel("Usar \(skin.name)")
        }
        .frame(width: 236, alignment: .leading)
    }

    @ViewBuilder private var artwork: some View {
        if let url = skin.artworkURL(), let image = NSImage(contentsOf: url) {
            Image(nsImage: image).resizable().scaledToFill()
        } else {
            ZStack {
                Color(NSColor.controlBackgroundColor)
                Label("Diseño no disponible", systemImage: "photo")
            }
        }
    }
}
