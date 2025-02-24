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
        VStack(alignment: .leading, spacing: 0) {
            contentView
                .padding(.horizontal, 50)
                .padding(.vertical, 80)
                .frame(maxWidth: UIScreen.main.bounds.width)
                .environment(\.colorScheme, .light)  // 强制使用浅色模式
        }
        .background(.white)  // 统一使用白色背景
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
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
                                Button(action: {
                                    saveImageToAlbum(image)
                                }) {
                                    Label("保存到相册", systemImage: "square.and.arrow.down")
                                }
                                Button(action: {
                                    sliceImage(image)
                                }) {
                                    Label("小红书切片", systemImage: "rectangle.split.3x1")
                                }
                                ShareLink(item: Image(uiImage: image), preview: SharePreview("分享图片")) {
                                    Label("分享", systemImage: "square.and.arrow.up")
                                }
                            }
                        } label: {
                            Image(systemName: "square.and.arrow.down")
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
            
            // 先设置一个临时的大小来获取实际内容高度
            view.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIView.layoutFittingExpandedSize.height)
            view.setNeedsLayout()
            view.layoutIfNeeded()
            
            // 获取实际内容大小
            let fittingSize = view.systemLayoutSizeFitting(
                CGSize(width: UIScreen.main.bounds.width, height: UIView.layoutFittingExpandedSize.height),
                withHorizontalFittingPriority: .required,
                verticalFittingPriority: .fittingSizeLevel
            )
            
            // 在上下都添加额外空间来确保圆角完全显示
            let padding: CGFloat = 50
            let finalSize = CGSize(
                width: fittingSize.width,
                height: fittingSize.height + padding * 2
            )
            
            // 设置视图frame，居中显示内容
            view.frame = CGRect(
                origin: CGPoint(x: 0, y: padding),
                size: fittingSize
            )
            
            // 强制布局
            view.setNeedsLayout()
            view.layoutIfNeeded()
            
            // 创建图片上下文并渲染
            UIGraphicsBeginImageContextWithOptions(finalSize, true, UIScreen.main.scale)
            defer { UIGraphicsEndImageContext() }
            
            // 填充白色背景
            UIColor.white.setFill()
            UIRectFill(CGRect(origin: .zero, size: finalSize))
            
            // 确保视图背景是白色
            view.backgroundColor = .white
            
            // 渲染视图层级
            view.layer.render(in: UIGraphicsGetCurrentContext()!)
            
            // 添加水印
            let watermark = "AI Client APP"
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12, weight: .regular),
                .foregroundColor: UIColor.gray.withAlphaComponent(0.6)
            ]
            let watermarkSize = watermark.size(withAttributes: attributes)
            
            // 在底部居中绘制水印
            let watermarkPoint = CGPoint(
                x: (finalSize.width - watermarkSize.width) / 2,
                y: finalSize.height - watermarkSize.height - 16 // 距离底部 16 点
            )
            watermark.draw(at: watermarkPoint, withAttributes: attributes)
            
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
            
            // 使用原始图片的宽度
            let targetWidth = image.size.width
            
            // 为每个分段生成图片
            for (index, segment) in segments.enumerated() {
                if let originalImage = await generateImageForSegment(segment, index: index, total: segments.count) {
                    slicedImages.append(originalImage)
                }
            }
            
            await MainActor.run {
                self.slicedImages = slicedImages
                self.showingSlicedImages = true
            }
        }
    }
    
    private func splitMarkdownContent(_ content: String) -> [String] {
        // 调试：打印原始内容和处理后的内容
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        print("\n原始内容长度: \(content.count)")
        print("处理后内容长度: \(trimmedContent.count)")
        
        // 将内容按行分割，保留空行
        let lines = content.components(separatedBy: .newlines)
        var segments: [String] = []
        var currentSegment: [String] = []
        var inCodeBlock = false
        var inMathBlock = false
        var inTable = false
        
        func shouldStartNewSegment(_ line: String) -> Bool {
            let segmentContent = currentSegment.joined(separator: "\n")
            let contentLength = segmentContent.count
            
            print("\n当前段落信息：")
            print("原始长度：\(contentLength)")
            print("行数：\(currentSegment.count)")
            print("内容预览：\(segmentContent.prefix(50))...")
            
            return contentLength > 400
        }
        
        func finalizeCurrentSegment() {
            if !currentSegment.isEmpty {
                let segment = currentSegment.joined(separator: "\n")
                if !segment.isEmpty {
                    print("\n添加新段落:")
                    print("长度：\(segment.count)")
                    print("行数：\(currentSegment.count)")
                    print("内容：\n\(segment)")
                    segments.append(segment)
                }
                currentSegment.removeAll()
            }
        }
        
        // 处理每一行
        for (index, line) in lines.enumerated() {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // 添加当前行到段落
            currentSegment.append(line)
            
            // 处理代码块
            if trimmedLine.hasPrefix("```") {
                if inCodeBlock {
                    inCodeBlock = false
                    finalizeCurrentSegment()
                } else {
                    inCodeBlock = true
                }
                continue
            }
            
            // 处理数学公式块
            if trimmedLine.hasPrefix("$$") {
                if inMathBlock {
                    inMathBlock = false
                    finalizeCurrentSegment()
                } else {
                    inMathBlock = true
                }
                continue
            }
            
            // 处理表格
            if trimmedLine.contains("|") && trimmedLine.contains("-") {
                if !inTable {
                    inTable = true
                }
            } else if inTable && trimmedLine.isEmpty {
                inTable = false
                finalizeCurrentSegment()
            }
            
            // 检查是否需要开始新段落
            if !inCodeBlock && !inMathBlock && !inTable {
                if shouldStartNewSegment(line) {
                    finalizeCurrentSegment()
                }
            }
            
            // 处理最后一行
            if index == lines.count - 1 {
                if !currentSegment.isEmpty {
                    finalizeCurrentSegment()
                }
            }
        }
        
        // 打印最终分段信息
        print("\n最终分段结果:")
        print("总分段数量: \(segments.count)")
        print("原始内容总长度: \(content.count)")
        print("分段后总长度: \(segments.map { $0.count }.reduce(0, +))")
        segments.enumerated().forEach { index, segment in
            print("\n第\(index + 1)段:")
            print("长度: \(segment.count)")
            print("行数: \(segment.components(separatedBy: .newlines).count)")
            print("完整内容：\n\(segment)")
            print("---")
        }
        
        return segments
    }
    
    private func generateImageForSegment(_ segment: String, index: Int, total: Int) async -> UIImage? {
        return await MainActor.run {
            // 创建该段落的预览内容
            let segmentContent = VStack(alignment: .leading, spacing: 16) {
                MessageContentView(content: segment)
                    .padding(.horizontal, 50)
                    .padding(.vertical, 40)
                    .frame(maxWidth: UIScreen.main.bounds.width)
                    .environment(\.colorScheme, .light)  // 强制使用浅色模式
            }
            .background(.white)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
            
            // 创建一个 UIHostingController 来托管 SwiftUI 视图
            let hostingController = UIHostingController(rootView: segmentContent)
            
            // 添加到临时窗口以确保正确布局
            let window = UIWindow(frame: UIScreen.main.bounds)
            window.rootViewController = hostingController
            window.makeKeyAndVisible()
            
            let view = hostingController.view!
            
            // 先设置一个临时的大小来获取实际内容高度
            view.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIView.layoutFittingExpandedSize.height)
            view.setNeedsLayout()
            view.layoutIfNeeded()
            
            // 获取实际内容大小
            let fittingSize = view.systemLayoutSizeFitting(
                CGSize(width: UIScreen.main.bounds.width, height: UIView.layoutFittingExpandedSize.height),
                withHorizontalFittingPriority: .required,
                verticalFittingPriority: .fittingSizeLevel
            )
            
            // 计算目标高度，确保不超过 4:3 比例
            let targetWidth = fittingSize.width
            let targetHeight = max(
                fittingSize.height + 60, // 确保有足够的空间显示内容
                targetWidth * (4.0/3.0)  // 保持最小 3:4 比例
            )
            
            let finalSize = CGSize(
                width: targetWidth,
                height: targetHeight
            )
            
            // 设置视图frame，居中显示内容
            view.frame = CGRect(
                origin: CGPoint(x: 0, y: (targetHeight - fittingSize.height) / 2), // 垂直居中
                size: fittingSize
            )
            
            // 强制布局
            view.setNeedsLayout()
            view.layoutIfNeeded()
            
            // 创建图片上下文并渲染
            UIGraphicsBeginImageContextWithOptions(finalSize, true, UIScreen.main.scale)
            defer { UIGraphicsEndImageContext() }
            
            // 填充白色背景
            UIColor.white.setFill()
            UIRectFill(CGRect(origin: .zero, size: finalSize))
            
            // 确保视图背景是白色
            view.backgroundColor = .white
            
            // 渲染视图层级
            view.layer.render(in: UIGraphicsGetCurrentContext()!)
            
            // 添加水印
            let watermark = "AI Client APP"
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12, weight: .regular),
                .foregroundColor: UIColor.gray.withAlphaComponent(0.6)
            ]
            let watermarkSize = watermark.size(withAttributes: attributes)
            
            // 在底部居中绘制水印
            let watermarkPoint = CGPoint(
                x: (finalSize.width - watermarkSize.width) / 2,
                y: finalSize.height - watermarkSize.height - 16 // 距离底部 16 点
            )
            watermark.draw(at: watermarkPoint, withAttributes: attributes)
            
            // 添加序号水印
            let pageNumber = "\(index + 1)/\(total)"
            let pageAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 14, weight: .medium),
                .foregroundColor: UIColor.gray.withAlphaComponent(0.8)
            ]
            let pageSize = pageNumber.size(withAttributes: pageAttributes)
            
            // 在右下角绘制序号
            let pagePoint = CGPoint(
                x: finalSize.width - pageSize.width - 20,
                y: finalSize.height - pageSize.height - 16
            )
            pageNumber.draw(at: pagePoint, withAttributes: pageAttributes)
            
            // 获取生成的图片
            let image = UIGraphicsGetImageFromCurrentImageContext()
            
            // 清理临时窗口
            window.isHidden = true
            
            return image
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