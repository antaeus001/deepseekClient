import SwiftUI
import Photos

struct ImagePreviewView: View {
    let markdownContent: String
    @Environment(\.dismiss) private var dismiss
    @State private var generatedImage: UIImage?
    @Environment(\.colorScheme) private var colorScheme
    @State private var showingSaveSuccess = false
    @State private var showingSaveError = false
    @State private var showToast = false  // 添加 Toast 状态
    
    // 创建一个独立的视图来处理 markdown 内容
    private let contentView: MessageContentView
    
    init(markdownContent: String) {
        print("ImagePreviewView 初始化，内容长度：\(markdownContent.count)")  // 添加日志
        self.markdownContent = markdownContent
        self.contentView = MessageContentView(content: markdownContent)
    }
    
    // 添加一个视图构建器来创建预览内容
    @ViewBuilder
    private var previewContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            contentView
                .padding(20)
                .frame(maxWidth: UIScreen.main.bounds.width - 32)
        }
        .background(colorScheme == .dark ? Color(.systemGray6) : .white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        .padding(.horizontal, 16)
    }
    
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
                    ScrollView {
                        previewContent
                            .onAppear {
                                Task {
                                    await generateImage()
                                }
                            }
                    }
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
                
                if let image = generatedImage {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            ShareLink(item: Image(uiImage: image), preview: SharePreview("分享图片"))
                            Button(action: {
                                saveImageToAlbum(image)
                            }) {
                                Label("保存到相册", systemImage: "square.and.arrow.down")
                            }
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
            }
            // 添加一个隐藏的 MessageContentView 来预热 Markdown 渲染器
            .background(
                MessageContentView(content: "预热 Markdown 渲染器")
                    .frame(width: 0, height: 0)
                    .hidden()
            )
            .alert("保存成功", isPresented: $showingSaveSuccess) {
                Button("确定", role: .cancel) { }
            }
            .alert("保存失败", isPresented: $showingSaveError) {
                Button("确定", role: .cancel) { }
            } message: {
                Text("请在设置中允许应用访问相册")
            }
            .overlay(alignment: .bottom) {
                // Toast 提示
                if showToast {
                    ToastView(message: "图片已保存到相册")
                        .transition(.move(edge: .bottom))
                        .animation(.spring(), value: showToast)
                }
            }
        }
    }
    
    private func saveImageToAlbum(_ image: UIImage) {
        let status = PHPhotoLibrary.authorizationStatus()
        
        switch status {
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization { status in
                DispatchQueue.main.async {
                    if status == .authorized {
                        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                        // 显示 Toast
                        withAnimation {
                            showToast = true
                        }
                        // 3秒后隐藏
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            withAnimation {
                                showToast = false
                            }
                        }
                    } else {
                        showingSaveError = true
                    }
                }
            }
        case .authorized:
            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
            // 显示 Toast
            withAnimation {
                showToast = true
            }
            // 3秒后隐藏
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation {
                    showToast = false
                }
            }
        default:
            showingSaveError = true
        }
    }
    
    private func generateImage() async {
        await MainActor.run {
            let renderer = ImageRenderer(content: previewContent)
            renderer.scale = UIScreen.main.scale
            renderer.isOpaque = true
            renderer.proposedSize = ProposedViewSize(width: UIScreen.main.bounds.width, height: nil)
            
            if let image = renderer.uiImage {
                print("图片生成成功")
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
}

// 添加用于视图大小的 PreferenceKey
private struct ViewSizeKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

// 添加 Toast 视图组件
struct ToastView: View {
    let message: String
    
    var body: some View {
        Text(message)
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.black.opacity(0.8))
            .cornerRadius(20)
            .padding(.bottom, 40)
    }
} 