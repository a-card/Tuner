import SwiftUI

struct SettingsView: View {
    @Environment(TunerModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var model = model

        NavigationStack {
            Form {
                Section {
                    Stepper(value: $model.a4, in: 420...460, step: 1) {
                        HStack {
                            Text("A4 reference")
                            Spacer()
                            Text("\(Int(model.a4)) Hz")
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    }
                    if model.a4 != 440 {
                        Button("Reset to 440 Hz") { model.a4 = 440 }
                    }
                } footer: {
                    Text("Concert pitch is 440 Hz. Change this to match a piano or recording tuned differently.")
                }

                Section("Tuning") {
                    Picker("Tuning", selection: $model.tuning) {
                        ForEach(Tuning.all) { tuning in
                            Text(tuning.name).tag(tuning)
                        }
                    }
                    Toggle("Chromatic mode", isOn: Binding(
                        get: { model.mode == .chromatic },
                        set: { model.mode = $0 ? .chromatic : .auto }
                    ))
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
