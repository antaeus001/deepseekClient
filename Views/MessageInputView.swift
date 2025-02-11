import SwiftUI

struct MessageInputView: View {
    @Binding var text: String
    @State private var isEditing = false
    @State private var isSending = false
    let onSend: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            TextField("输入消息...", text: $text, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .frame(minHeight: 36)
                .lineLimit(1...5)
                .disabled(isSending)
            
            Button(action: {
                isSending = true
                onSend()
                isSending = false
            }) {
                Image(systemName: "paperplane.fill")
                    .foregroundColor(text.isEmpty || isSending ? .gray : .blue)
                    .font(.system(size: 20))
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(Color.blue.opacity(0.1))
                    )
            }
            .disabled(text.isEmpty || isSending)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 1),
            alignment: .top
        )
    }
}

// 预览
struct MessageInputView_Previews: PreviewProvider {
    static var previews: some View {
        MessageInputView(text: .constant(""), onSend: {})
            .previewLayout(.sizeThatFits)
    }
} 