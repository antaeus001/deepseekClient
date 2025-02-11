import SwiftUI

struct MessageInputView: View {
    @Binding var text: String
    let onSend: () -> Void
    
    var body: some View {
        HStack {
            TextField("输入消息...", text: $text)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)
            
            Button(action: {
                guard !text.isEmpty else { return }
                onSend()
            }) {
                Image(systemName: "paperplane.fill")
                    .foregroundColor(.blue)
            }
            .padding(.trailing)
        }
        .padding(.vertical, 8)
        .background(Color.gray.opacity(0.1))
    }
} 