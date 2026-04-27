import SwiftUI
#if os(watchOS)
import WatchKit
#endif

struct WorkoutNotesView: View {
    @EnvironmentObject private var manager: WatchWorkoutManager
    @State private var isDictating = false

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "mic.fill")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.purple)

            Text("How did it feel?")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)

            Text("Log your thoughts or skip")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button(action: startDictation) {
                HStack(spacing: 6) {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Dictate")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(Color.purple)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(isDictating)

            Button(action: { manager.skipWorkoutNotes() }) {
                Text("Skip")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 6)
        .navigationTitle("Feelings")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func startDictation() {
        isDictating = true
        #if os(watchOS)
        WKExtension.shared().visibleInterfaceController?.presentTextInputController(
            withSuggestions: ["Felt strong", "Legs were heavy", "Good session", "Tough but done", "Need more rest"],
            allowedInputMode: .allowEmoji
        ) { results in
            DispatchQueue.main.async {
                isDictating = false
                if let result = results?.first as? String, !result.isEmpty {
                    manager.submitWorkoutNotes(result)
                }
                // If cancelled (nil/empty), stay on this screen so user can retry or skip
            }
        }
        #else
        isDictating = false
        #endif
    }
}
