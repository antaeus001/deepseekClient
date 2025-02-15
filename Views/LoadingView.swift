import SwiftUI

struct LoadingView: View {
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(Color.gray.opacity(0.5))
                .frame(width: 6, height: 6)
                .offset(y: isAnimating ? -4 : 0)
            Circle()
                .fill(Color.gray.opacity(0.5))
                .frame(width: 6, height: 6)
                .offset(y: isAnimating ? -4 : 0)
                .animation(.easeInOut(duration: 0.3).delay(0.15), value: isAnimating)
            Circle()
                .fill(Color.gray.opacity(0.5))
                .frame(width: 6, height: 6)
                .offset(y: isAnimating ? -4 : 0)
                .animation(.easeInOut(duration: 0.3).delay(0.3), value: isAnimating)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.3).repeatForever()) {
                isAnimating = true
            }
        }
    }
} 