import SwiftUI

// =========================================================================
// MARK: - Launch Screen
// =========================================================================
// Shown briefly on app launch before ContentView appears.
// Matches app's dark studio theme — #0c0c0c bg + SinAudio logo.
// Fades out once the app is ready.
// =========================================================================

struct LaunchScreenView: View {
    var body: some View {
        ZStack {
            // Match app background exactly
            Color(hex: "#0c0c0c")
                .ignoresSafeArea()

            // Subtle gradient — matches ContentView depth effect
            LinearGradient(
                colors: [
                    Color.white.opacity(0.06),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 16) {
                // SinAudio logo — same asset used in ContentView header
                Image("SinAudioLogo")
                    .resizable()
                    .renderingMode(.template)
                    .foregroundColor(.white.opacity(0.90))
                    .scaledToFit()
                    .frame(height: 48)

                // App name in Digital Dismay font matching console branding
                Text("CTRLR")
                    .font(.custom("Digital Dismay", size: 13))
                    .foregroundColor(Color(hex: "#a89f94"))
                    .kerning(4)
            }
        }
    }
}
