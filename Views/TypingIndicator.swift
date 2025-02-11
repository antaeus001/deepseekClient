import SwiftUI

struct TypingIndicator: View {
    @State private var showDot1 = false
    @State private var showDot2 = false
    @State private var showDot3 = false
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(Color.purple.opacity(0.5))
                .frame(width: 6, height: 6)
                .scaleEffect(showDot1 ? 1 : 0.5)
                .opacity(showDot1 ? 1 : 0.5)
            
            Circle()
                .fill(Color.purple.opacity(0.5))
                .frame(width: 6, height: 6)
                .scaleEffect(showDot2 ? 1 : 0.5)
                .opacity(showDot2 ? 1 : 0.5)
            
            Circle()
                .fill(Color.purple.opacity(0.5))
                .frame(width: 6, height: 6)
                .scaleEffect(showDot3 ? 1 : 0.5)
                .opacity(showDot3 ? 1 : 0.5)
        }
        .onAppear {
            animate()
        }
    }
    
    private func animate() {
        let animation = Animation.easeInOut(duration: 0.4).repeatForever(autoreverses: true)
        
        withAnimation(animation.delay(0.0)) {
            showDot1 = true
        }
        
        withAnimation(animation.delay(0.2)) {
            showDot2 = true
        }
        
        withAnimation(animation.delay(0.4)) {
            showDot3 = true
        }
    }
} 