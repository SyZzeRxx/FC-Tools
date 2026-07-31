import SwiftUI

struct SplashView: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [.black, Color(red: 0.08, green: 0.12, blue: 0.18)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            VStack(spacing: 18) {
                Image(systemName: "sportscourt.fill")
                    .font(.system(size: 68, weight: .bold))
                    .foregroundStyle(.green)
                Text("FC Tools").font(.largeTitle.bold()).foregroundStyle(.white)
                ProgressView().tint(.white)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("FC Tools is loading")
    }
}

