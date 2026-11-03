import SwiftUI

struct TunerView: View {
    @Environment(TunerModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase
    @State private var showingSettings = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if let message = model.errorMessage {
                    ErrorBanner(message: message)
                }

                NoteDisplay(reading: model.reading, isActive: model.isSignalPresent)

                CentsGauge(cents: model.reading?.cents, isActive: model.isSignalPresent)
                    .frame(height: 170)
                    .padding(.horizontal)

                StatusLine(reading: model.reading, isActive: model.isSignalPresent, isListening: model.isListening)

                Spacer(minLength: 0)

                StringSelector()
            }
            .padding()
            .navigationTitle(model.tuning.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    TuningMenu()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Label("Settings", systemImage: "slider.horizontal.3")
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
                    .presentationDetents([.medium])
            }
        }
        .task {
            await model.start()
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                Task { await model.start() }
            case .background:
                model.stop()
            default:
                break
            }
        }
    }
}

// MARK: - Note

private struct NoteDisplay: View {
    let reading: TunerModel.Reading?
    let isActive: Bool

    var body: some View {
        let color = noteColor
        VStack(spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(reading?.target.name ?? "–")
                    .font(.system(size: 120, weight: .bold, design: .rounded))
                Text(reading.map { "\($0.target.octave)" } ?? "")
                    .font(.system(size: 36, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(color)
            .contentTransition(.numericText())
            .animation(.snappy, value: reading?.target)
        }
        .opacity(isActive || reading == nil ? 1 : 0.4)
        .animation(.easeOut(duration: 0.3), value: isActive)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(reading.map { "Target note \($0.target.fullName)" } ?? "No note detected")
    }

    private var noteColor: Color {
        guard let reading, isActive else { return .primary }
        return reading.isInTune ? .green : .primary
    }
}

// MARK: - Status

private struct StatusLine: View {
    let reading: TunerModel.Reading?
    let isActive: Bool
    let isListening: Bool

    var body: some View {
        VStack(spacing: 6) {
            Text(headline)
                .font(.title3.weight(.semibold))
                .foregroundStyle(headlineColor)
            if let reading {
                Text(String(format: "%.1f Hz  ·  target %.1f Hz", reading.frequency, reading.targetFrequency))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .frame(minHeight: 50)
    }

    private var headline: String {
        guard isListening else { return "Microphone off" }
        guard let reading, isActive else { return "Play a string" }
        if reading.isInTune { return "In tune" }
        let cents = Int(reading.cents.rounded())
        return cents > 0 ? "\(cents)¢ sharp — tune down" : "\(-cents)¢ flat — tune up"
    }

    private var headlineColor: Color {
        guard let reading, isActive else { return .secondary }
        if reading.isInTune { return .green }
        return abs(reading.cents) < 15 ? .orange : .red
    }
}

// MARK: - Strings

private struct StringSelector: View {
    @Environment(TunerModel.self) private var model

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                ForEach(Array(model.tuning.strings.enumerated()), id: \.offset) { index, note in
                    StringButton(
                        note: note,
                        number: model.tuning.strings.count - index,
                        isLocked: isLocked(note),
                        isDetected: isDetected(note)
                    ) {
                        model.toggleString(note)
                    }
                }
            }
            Text(modeDescription)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func isLocked(_ note: Note) -> Bool {
        if case .string(let locked) = model.mode { return locked == note }
        return false
    }

    private func isDetected(_ note: Note) -> Bool {
        guard model.isSignalPresent, let reading = model.reading else { return false }
        return reading.target == note
    }

    private var modeDescription: String {
        switch model.mode {
        case .auto: return "Auto-detecting string · tap a string to lock it"
        case .string(let note): return "Locked to \(note.fullName) · tap again to unlock"
        case .chromatic: return "Chromatic mode"
        }
    }
}

private struct StringButton: View {
    let note: Note
    let number: Int
    let isLocked: Bool
    let isDetected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(note.name)
                    .font(.title3.weight(.bold))
                Text("\(note.octave)")
                    .font(.caption2)
                    .opacity(0.7)
            }
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(background, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(isDetected ? Color.accentColor : .clear, lineWidth: 2)
            }
            .foregroundStyle(isLocked ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.15), value: isDetected)
        .accessibilityLabel("String \(number), \(note.fullName)")
        .accessibilityAddTraits(isLocked ? .isSelected : [])
    }

    private var background: Color {
        isLocked ? .accentColor : Color(.secondarySystemBackground)
    }
}

// MARK: - Toolbar

private struct TuningMenu: View {
    @Environment(TunerModel.self) private var model

    var body: some View {
        Menu {
            ForEach(Tuning.all) { tuning in
                Button {
                    model.tuning = tuning
                    if model.mode == .chromatic { model.mode = .auto }
                } label: {
                    if tuning == model.tuning && model.mode != .chromatic {
                        Label(tuning.name, systemImage: "checkmark")
                    } else {
                        Text(tuning.name)
                    }
                }
            }
            Divider()
            Button {
                model.mode = model.mode == .chromatic ? .auto : .chromatic
            } label: {
                if model.mode == .chromatic {
                    Label("Chromatic", systemImage: "checkmark")
                } else {
                    Text("Chromatic")
                }
            }
        } label: {
            Label("Tuning", systemImage: "guitars")
        }
    }
}

private struct ErrorBanner: View {
    let message: String

    var body: some View {
        VStack(spacing: 8) {
            Label(message, systemImage: "mic.slash")
                .font(.subheadline)
                .multilineTextAlignment(.leading)
            if let url = URL(string: UIApplication.openSettingsURLString) {
                Link("Open Settings", destination: url)
                    .font(.subheadline.weight(.semibold))
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.red.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    TunerView()
        .environment(TunerModel())
}
