import SwiftUI

/// About/Info view.
struct AboutView: View {
    var body: some View {
        VStack(spacing: 20) {
            // App Icon
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 64))
                .foregroundStyle(.blue)

            // App Name & Version
            VStack(spacing: 4) {
                Text(Constants.appName)
                    .font(.title)
                    .fontWeight(.bold)

                Text("Version \(Constants.version)")
                    .foregroundStyle(.secondary)
            }

            // Description
            Text("Synchronisiert Platzhalter-Termine zwischen mehreren Kalendern.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            Spacer()

            // Copyright
            Text("© 2025 Appschmiede")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    AboutView()
}
