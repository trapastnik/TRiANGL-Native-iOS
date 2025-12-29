import SwiftUI

struct ContentView: View {
    @State private var showScanner = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                Spacer()

                // App Icon
                Image(systemName: "cube.transparent")
                    .imageScale(.large)
                    .foregroundStyle(.tint)
                    .font(.system(size: 80))

                // App Name
                VStack(spacing: 8) {
                    Text("TRiANGL")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("3D Corner Illusion App")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text("LiDAR-powered AR Scanner")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Description
                VStack(alignment: .leading, spacing: 12) {
                    FeatureRow(icon: "camera.fill", text: "Сканируйте угол комнаты с помощью LiDAR")
                    FeatureRow(icon: "cube.fill", text: "Создавайте 3D оптические иллюзии")
                    FeatureRow(icon: "doc.fill", text: "Генерируйте PDF для печати")
                }
                .padding(.horizontal, 30)

                Spacer()

                // Start Button
                Button(action: {
                    showScanner = true
                }) {
                    HStack {
                        Image(systemName: "arkit")
                            .font(.title2)
                        Text("Начать сканирование")
                            .font(.headline)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.blue)
                    )
                }
                .padding(.bottom, 50)
            }
            .navigationTitle("")
            .navigationBarHidden(true)
            .fullScreenCover(isPresented: $showScanner) {
                ScannerView()
            }
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 30)

            Text(text)
                .font(.body)
                .foregroundColor(.primary)

            Spacer()
        }
    }
}

#Preview {
    ContentView()
}
