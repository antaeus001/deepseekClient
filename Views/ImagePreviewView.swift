import SwiftUI

struct ImagePreviewView: View {
    let markdownContent: String
    @Environment(\.dismiss) private var dismiss
    @State private var generatedImage: UIImage?
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        NavigationStack {
            Group {
                if let image = generatedImage {
                    ScrollView {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .padding()
                    }
                } else {
                    ProgressView()
                        .scaleEffect(1.5)
                }
            }
            .navigationTitle("预览图片")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                }
                
                if generatedImage != nil {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        ShareLink(item: Image(uiImage: generatedImage!), preview: SharePreview("分享图片"))
                    }
                }
            }
            .onAppear {
                generateImage()
            }
        }
    }
    
    private func generateImage() {
        print("准备生成图片，markdown内容：\n\(markdownContent)")
        
        let contentView = VStack(alignment: .leading, spacing: 16) {
            Text(markdownContent)
                .font(.system(size: 16))
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)
                .padding(20)
                .frame(maxWidth: UIScreen.main.bounds.width - 32)
        }
        .background(colorScheme == .dark ? Color(.systemGray6) : .white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        .padding(.horizontal, 16)
        
        let renderer = ImageRenderer(content: contentView)
        
        // 设置渲染参数
        renderer.scale = UIScreen.main.scale
        renderer.isOpaque = true
        renderer.proposedSize = ProposedViewSize(width: UIScreen.main.bounds.width, height: nil)
        
        if let image = renderer.uiImage {
            print("图片生成成功")
            // 添加额外的白色背景
            UIGraphicsBeginImageContextWithOptions(image.size, true, image.scale)
            UIColor.white.setFill()
            UIRectFill(CGRect(origin: .zero, size: image.size))
            image.draw(at: .zero)
            let finalImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            
            self.generatedImage = finalImage
        } else {
            print("图片生成失败")
        }
    }
} 