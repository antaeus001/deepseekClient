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
    @State private var slicedImages: [UIImage] = []
    @State private var showingSlicedImages = false
    
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
                // 移除 task 和背景，让 MessageContentView 自己处理代码块渲染
        }
        .background(colorScheme == .dark ? Color(.systemGray6) : .white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        .padding(.horizontal, 16)
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if showingSlicedImages {
                    // 显示切片后的图片
                    ScrollView {
                        VStack(spacing: 20) {
                            ForEach(slicedImages.indices, id: \.self) { index in
                                Image(uiImage: slicedImages[index])
                                    .resizable()
                                    .scaledToFit()
                                    .padding()
                                    .overlay(alignment: .topLeading) {
                                        Text("第\(index + 1)张")
                                            .foregroundColor(.white)
                                            .padding(6)
                                            .background(Color.black.opacity(0.6))
                                            .cornerRadius(6)
                                            .padding(8)
                                    }
                            }
                        }
                    }
                } else if let image = generatedImage {
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
            .navigationTitle(showingSlicedImages ? "图片切片" : "预览图片")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        if showingSlicedImages {
                            showingSlicedImages = false
                        } else {
                            dismiss()
                        }
                    }
                }
                
                if let image = generatedImage {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            if showingSlicedImages {
                                ForEach(slicedImages.indices, id: \.self) { index in
                                    Button(action: {
                                        saveImageToAlbum(slicedImages[index])
                                    }) {
                                        Label("保存第\(index + 1)张", systemImage: "square.and.arrow.down")
                                    }
                                }
                                Button(action: {
                                    slicedImages.forEach { saveImageToAlbum($0) }
                                }) {
                                    Label("保存全部", systemImage: "square.and.arrow.down.fill")
                                }
                            } else {
                                ShareLink(item: Image(uiImage: image), preview: SharePreview("分享图片"))
                                Button(action: {
                                    saveImageToAlbum(image)
                                }) {
                                    Label("保存到相册", systemImage: "square.and.arrow.down")
                                }
                                Button(action: {
                                    sliceImage(image)
                                }) {
                                    Label("切片(3:4)", systemImage: "rectangle.split.3x1")
                                }
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
            // 创建一个 UIHostingController 来托管 SwiftUI 视图
            let hostingController = UIHostingController(rootView: previewContent)
            
            // 添加到临时窗口以确保正确布局
            let window = UIWindow(frame: UIScreen.main.bounds)
            window.rootViewController = hostingController
            window.makeKeyAndVisible()
            
            let view = hostingController.view!
            
            // 设置视图大小
            let fittingSize = view.sizeThatFits(CGSize(
                width: UIScreen.main.bounds.width,
                height: UIView.layoutFittingCompressedSize.height
            ))
            view.frame = CGRect(origin: .zero, size: fittingSize)
            
            // 强制布局
            view.setNeedsLayout()
            view.layoutIfNeeded()
            
            // 创建图片上下文并渲染
            UIGraphicsBeginImageContextWithOptions(fittingSize, true, UIScreen.main.scale)
            defer { UIGraphicsEndImageContext() }
            
            // 填充白色背景
            UIColor.white.setFill()
            UIRectFill(CGRect(origin: .zero, size: fittingSize))
            
            // 渲染视图层级
            view.layer.render(in: UIGraphicsGetCurrentContext()!)
            
            // 获取生成的图片
            if let image = UIGraphicsGetImageFromCurrentImageContext() {
                print("图片生成成功")
                self.generatedImage = image
            } else {
                print("图片生成失败")
            }
            
            // 清理临时窗口
            window.isHidden = true
        }
    }
    
    private func sliceImage(_ image: UIImage) {
        Task {
            // 首先分割 markdown 内容
            let segments = splitMarkdownContent(markdownContent)
            var slicedImages: [UIImage] = []
            
            // 为每个分段生成图片
            for segment in segments {
                if let originalImage = await generateImageForSegment(segment) {
                    // 在这里创建 3:4 比例的图片
                    let targetWidth = originalImage.size.width
                    let targetHeight = max(targetWidth * (4.0/3.0), originalImage.size.height)
                    
                    UIGraphicsBeginImageContextWithOptions(CGSize(width: targetWidth, height: targetHeight), true, originalImage.scale)
                    
                    // 填充白色背景
                    UIColor.white.setFill()
                    UIRectFill(CGRect(origin: .zero, size: CGSize(width: targetWidth, height: targetHeight)))
                    
                    // 在顶部绘制原始图片
                    originalImage.draw(in: CGRect(x: 0, y: 0, width: originalImage.size.width, height: originalImage.size.height))
                    
                    if let finalImage = UIGraphicsGetImageFromCurrentImageContext() {
                        slicedImages.append(finalImage)
                    }
                    
                    UIGraphicsEndImageContext()
                }
            }
            
            await MainActor.run {
                self.slicedImages = slicedImages
                self.showingSlicedImages = true
            }
        }
    }
    
    private func splitMarkdownContent(_ content: String) -> [String] {
        // 按照段落或标题分割内容
        let segments = content.components(separatedBy: "\n\n")
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        
        var result: [String] = []
        var currentSegment = ""
        let targetRatio: CGFloat = 3.0 / 4.0
        let maxCharsPerSegment = 500 // 根据实际情况调整
        
        for segment in segments {
            let newSegment = currentSegment.isEmpty ? segment : currentSegment + "\n\n" + segment
            
            // 如果当前段落加上新段落超过限制，就开始新的分段
            if currentSegment.count + segment.count > maxCharsPerSegment {
                if !currentSegment.isEmpty {
                    result.append(currentSegment)
                }
                currentSegment = segment
            } else {
                currentSegment = newSegment
            }
        }
        
        // 添加最后一个分段
        if !currentSegment.isEmpty {
            result.append(currentSegment)
        }
        
        return result
    }
    
    private func generateImageForSegment(_ segment: String) async -> UIImage? {
        // 先创建内容视图
        let contentView = MessageContentView(content: segment)
        
        // 等待一小段时间让代码块渲染完成
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
        
        return await MainActor.run {
            // 创建该段落的预览内容
            let segmentContent = VStack(alignment: .leading, spacing: 16) {
                contentView
                    .padding(20)
                    .frame(maxWidth: UIScreen.main.bounds.width - 32)
                    .background(
                        Group {
                            if segment.contains("```") {
                                Color(uiColor: .systemGray6)
                                    .frame(minHeight: 200)
                            }
                        }
                    )
                    .frame(maxHeight: .infinity, alignment: .top)
            }
            .background(colorScheme == .dark ? Color(.systemGray6) : .white)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
            .padding(.horizontal, 16)
            
            // 渲染图片
            let renderer = ImageRenderer(content: segmentContent)
            renderer.scale = UIScreen.main.scale
            renderer.isOpaque = true
            renderer.proposedSize = ProposedViewSize(
                width: UIScreen.main.bounds.width,
                height: nil  // 让高度自适应内容
            )
            
            // 直接返回原始渲染图片
            return renderer.uiImage
        }
    }
    
    // 分析内容块的高度
    private func analyzeContentBlocks(_ image: UIImage) -> [CGFloat] {
        // 这里我们可以根据图片的内容特征来识别自然分段
        // 例如：通过分析图片的空白区域、文字块等
        
        let blockHeight: CGFloat = 100 * image.scale // 假设每个内容块的基础高度
        var blocks: [CGFloat] = []
        var remainingHeight = image.size.height
        
        while remainingHeight > 0 {
            let height = min(blockHeight, remainingHeight)
            blocks.append(height)
            remainingHeight -= height
        }
        
        return blocks
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