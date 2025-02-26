import SwiftUI
import Photos

struct ImagePreviewView: View {
    let markdownContent: String
    let userContent: String?
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
    
    init(markdownContent: String, userContent: String? = nil) {
        print("ImagePreviewView 初始化，内容长度：\(markdownContent.count)")  // 添加日志
        self.markdownContent = markdownContent
        self.userContent = userContent
        self.contentView = MessageContentView(content: markdownContent)
    }
    
    // 修改预览内容视图构建器
    @ViewBuilder
    private var previewContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 添加用户问题标题
            if let userContent = userContent {
                VStack(alignment: .leading, spacing: 8) {
                    Text("问题")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.gray)
                    
                    Text(userContent)
                        .font(.system(size: 15))
                        .foregroundColor(.black)
                        .lineLimit(2)
                }
                .padding(.horizontal, 50)
                .padding(.vertical, 20)
                .padding(.bottom, 10)
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(Color.gray.opacity(0.2)),
                    alignment: .bottom
                )
            }
            
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
            // 首先处理内容，将推理过程移到前面
            let segments = splitMarkdownContent(markdownContent)
            let hasReasoningProcess = segments.first?.contains("推理过程") ?? false
            
            // 创建一个 UIHostingController 来托管 SwiftUI 视图
            let hostingController = UIHostingController(rootView: 
                VStack(alignment: .leading, spacing: 0) {
                    // 添加用户问题标题
                    if let userContent = userContent {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("问题")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.gray)
                            
                            Text(userContent)
                                .font(.system(size: 15))
                                .foregroundColor(.black)
                                .lineLimit(2)
                        }
                        .padding(.horizontal, 50)
                        .padding(.vertical, 20)
                        .padding(.bottom, 10)
                        .overlay(
                            Rectangle()
                                .frame(height: 1)
                                .foregroundColor(Color.gray.opacity(0.2)),
                            alignment: .bottom
                        )
                    }
                    
                    ForEach(segments.indices, id: \.self) { index in
                        let isReasoningSection = index == 0 && hasReasoningProcess
                        
                        VStack(alignment: .leading, spacing: 0) {
                            if isReasoningSection {
                                // 推理过程部分的样式
                                VStack(alignment: .leading, spacing: 12) {
                                    // 标题部分
                                    if segments[index].hasPrefix("推理过程：") {
                                        HStack {
                                            Image(systemName: "brain")
                                                .foregroundColor(.blue)
                                            Text("推理过程")
                                                .font(.system(size: 16, weight: .medium))
                                                .foregroundColor(.blue)
                                        }
                                        .padding(.bottom, 4)
                                        
                                        // 去掉开头部分的内容
                                        let contentWithoutPrefix = String(segments[index].dropFirst("推理过程：".count))
                                        MessageContentView(content: contentWithoutPrefix)
                                    } else {
                                        // 内容部分
                                        MessageContentView(content: segments[index])
                                    }
                                }
                                .padding(.horizontal, 50)
                                .padding(.vertical, 40)
                                .overlay(
                                    // 左侧装饰条
                                    Rectangle()
                                        .fill(Color.blue.opacity(0.6))
                                        .frame(width: 4)
                                        .padding(.vertical, 20),
                                    alignment: .leading
                                )
                            } else {
                                // 主要内容部分的样式
                                MessageContentView(content: segments[index])
                                    .padding(.horizontal, 50)
                                    .padding(.vertical, 40)
                            }
                        }
                        .padding(.bottom, isReasoningSection ? 20 : 0)
                    }
                }
                .padding(.vertical, 40)
                .frame(maxWidth: UIScreen.main.bounds.width)
                .background(.white)
                .environment(\.colorScheme, .light)
            )
            
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
            let segments = splitMarkdownContent(markdownContent)
            var slicedImages: [UIImage] = []
            var currentIndex = 0
            
            // 计算目标尺寸 - 固定 3:4 比例
            let targetWidth = UIScreen.main.bounds.width
            let targetHeight = targetWidth * 4/3 // 3:4 比例
            let targetSize = CGSize(width: targetWidth, height: targetHeight)
            
            for (index, segment) in segments.enumerated() {
                let isReasoningSection = index == 0 && (segment.hasPrefix("推理过程：") || segment.hasPrefix("思考过程："))
                
                // 如果内容较长，进行动态分段
                if segment.count > 200 {
                    let subSegments = await dynamicSplitContent(
                        segment,
                        targetSize: targetSize,
                        isReasoning: isReasoningSection
                    )
                    
                    for subSegment in subSegments {
                        if let slicedImage = await generateImageForSegment(
                            subSegment,
                            index: currentIndex,
                            total: segments.count,
                            targetSize: targetSize,
                            isReasoning: isReasoningSection
                        ) {
                            slicedImages.append(slicedImage)
                            currentIndex += 1
                        }
                    }
                } else {
                    if let slicedImage = await generateImageForSegment(
                        segment,
                        index: currentIndex,
                        total: segments.count,
                        targetSize: targetSize,
                        isReasoning: isReasoningSection
                    ) {
                        slicedImages.append(slicedImage)
                        currentIndex += 1
                    }
                }
            }
            
            await MainActor.run {
                self.slicedImages = slicedImages
                self.showingSlicedImages = true
            }
        }
    }
    
    private func dynamicSplitContent(_ content: String, targetSize: CGSize, isReasoning: Bool) async -> [String] {
        var segments: [String] = []
        let lines = content.components(separatedBy: .newlines)
        var currentSegment: [String] = []
        var isFirst = true
        var index = 0
        
        while index < lines.count {
            let line = lines[index]
            currentSegment.append(line)
            let currentContent = currentSegment.joined(separator: "\n")
            
            // 检查当前内容生成的图片高度
            let fittingHeight = await calculateContentHeight(
                currentContent, 
                width: targetSize.width, 
                isReasoning: isReasoning,
                isFirstSegment: isFirst
            )
            
            if fittingHeight > targetSize.height * 0.85 {
                if currentSegment.count > 1 {
                    // 回退一行
                    currentSegment.removeLast()
                    index -= 1 // 回退索引，下一次循环会重新处理这一行
                    
                    // 保存当前段落
                    let segment = currentSegment.joined(separator: "\n")
                    if !segment.isEmpty {
                        segments.append(segment)
                        isFirst = false
                    }
                    
                    // 开始新的段落
                    currentSegment = []
                } else {
                    // 如果只有一行，需要强制分段
                    // 先保存当前行
                    segments.append(line)
                    isFirst = false
                    currentSegment = []
                    
                    // 继续处理下一行
                    index += 1
                }
            } else {
                // 内容未超出，继续添加下一行
                index += 1
                
                // 如果是最后一行或者已经处理完所有行，保存当前段落
                if index >= lines.count {
                    let segment = currentSegment.joined(separator: "\n")
                    if !segment.isEmpty {
                        segments.append(segment)
                    }
                }
            }
        }
        
        // 确保没有遗漏的内容
        if !currentSegment.isEmpty {
            let finalSegment = currentSegment.joined(separator: "\n")
            if !finalSegment.isEmpty && !segments.contains(finalSegment) {
                segments.append(finalSegment)
            }
        }
        
        // 打印日志以便调试
        print("原始内容行数: \(lines.count)")
        print("分割后段落数: \(segments.count)")
        for (i, segment) in segments.enumerated() {
            print("段落 \(i + 1) 行数: \(segment.components(separatedBy: .newlines).count)")
        }
        
        return segments
    }
    
    // 添加一个辅助函数来计算内容高度
    private func calculateContentHeight(_ content: String, width: CGFloat, isReasoning: Bool, isFirstSegment: Bool = false) async -> CGFloat {
        return await MainActor.run {
            let contentView = VStack(alignment: .leading, spacing: 16) {
                // 添加问题部分（仅在第一个分段）
                if isFirstSegment, let userContent = userContent {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("问题")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.gray)
                        
                        Text(userContent)
                            .font(.system(size: 15))
                            .foregroundColor(.black)
                            .lineLimit(2)
                    }
                    .padding(.horizontal, 50)
                    .padding(.vertical, 20)
                    .padding(.bottom, 10)
                    .overlay(
                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(Color.gray.opacity(0.2)),
                        alignment: .bottom
                    )
                }
                
                if isReasoning {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "brain")
                                .foregroundColor(.blue)
                            Text("推理过程")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.blue)
                        }
                        .padding(.bottom, 4)
                        
                        MessageContentView(content: content)
                    }
                    .padding(.horizontal, 50)
                    .padding(.vertical, 40)
                    .overlay(
                        Rectangle()
                            .fill(Color.blue.opacity(0.6))
                            .frame(width: 4)
                            .padding(.vertical, 20),
                        alignment: .leading
                    )
                } else {
                    MessageContentView(content: content)
                        .padding(.horizontal, 50)
                        .padding(.vertical, 40)
                }
            }
            .frame(width: width)
            
            let controller = UIHostingController(rootView: contentView)
            let view = controller.view!
            
            // 设置宽度并获取适合的高度
            view.frame = CGRect(origin: .zero, size: CGSize(width: width, height: UIView.layoutFittingExpandedSize.height))
            view.setNeedsLayout()
            view.layoutIfNeeded()
            
            let fittingSize = view.systemLayoutSizeFitting(
                CGSize(width: width, height: UIView.layoutFittingExpandedSize.height),
                withHorizontalFittingPriority: .required,
                verticalFittingPriority: .fittingSizeLevel
            )
            
            return fittingSize.height
        }
    }
    
    private func generateTestImage(_ content: String, targetSize: CGSize, isReasoning: Bool) async -> UIImage? {
        return await MainActor.run {
            let contentView = VStack(alignment: .leading, spacing: 16) {
                if isReasoning {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "brain")
                                .foregroundColor(.blue)
                            Text("推理过程")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.blue)
                        }
                        .padding(.bottom, 4)
                        
                        MessageContentView(content: content)
                    }
                    .padding(.horizontal, 50)
                    .padding(.vertical, 40)
                    .overlay(
                        Rectangle()
                            .fill(Color.blue.opacity(0.6))
                            .frame(width: 4)
                            .padding(.vertical, 20),
                        alignment: .leading
                    )
                } else {
                    MessageContentView(content: content)
                        .padding(.horizontal, 50)
                        .padding(.vertical, 40)
                }
            }
            .frame(width: targetSize.width)
            .background(.white)
            
            let controller = UIHostingController(rootView: contentView)
            let view = controller.view!
            
            // 设置初始大小
            view.frame = CGRect(origin: .zero, size: CGSize(width: targetSize.width, height: UIView.layoutFittingExpandedSize.height))
            view.setNeedsLayout()
            view.layoutIfNeeded()
            
            // 获取实际大小
            let fittingSize = view.systemLayoutSizeFitting(
                CGSize(width: targetSize.width, height: UIView.layoutFittingExpandedSize.height),
                withHorizontalFittingPriority: .required,
                verticalFittingPriority: .fittingSizeLevel
            )
            
            // 创建图片上下文
            UIGraphicsBeginImageContextWithOptions(fittingSize, true, UIScreen.main.scale)
            defer { UIGraphicsEndImageContext() }
            
            view.frame = CGRect(origin: .zero, size: fittingSize)
            view.backgroundColor = .white
            view.layer.render(in: UIGraphicsGetCurrentContext()!)
            
            return UIGraphicsGetImageFromCurrentImageContext()
        }
    }
    
    private func generateImageForSegment(_ segment: String, index: Int, total: Int, targetSize: CGSize, isReasoning: Bool = false) async -> UIImage? {
        return await MainActor.run {
            // 创建该段落的预览内容
            let segmentContent = VStack(alignment: .leading, spacing: 16) {
                // 只在第一个分段显示用户问题
                if index == 0, let userContent = userContent {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("问题")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.gray)
                        
                        Text(userContent)
                            .font(.system(size: 15))
                            .foregroundColor(.black)
                            .lineLimit(2)
                    }
                    .padding(.horizontal, 50)
                    .padding(.vertical, 20)
                    .padding(.bottom, 10)
                    .overlay(
                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(Color.gray.opacity(0.2)),
                        alignment: .bottom
                    )
                }
                
                if isReasoning {
                    // 推理过程部分的样式
                    VStack(alignment: .leading, spacing: 12) {
                        // 标题部分
                        if segment.hasPrefix("推理过程：") {
                            HStack {
                                Image(systemName: "brain")
                                    .foregroundColor(.blue)
                                Text("推理过程")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.blue)
                            }
                            .padding(.bottom, 4)
                            
                            // 去掉开头部分的内容
                            let contentWithoutPrefix = String(segment.dropFirst("推理过程：".count))
                            MessageContentView(content: contentWithoutPrefix)
                        } else {
                            // 内容部分
                            MessageContentView(content: segment)
                        }
                    }
                    .padding(.horizontal, 50)
                    .padding(.vertical, 40)
                    .overlay(
                        // 左侧装饰条
                        Rectangle()
                            .fill(Color.blue.opacity(0.6))
                            .frame(width: 4)
                            .padding(.vertical, 20),
                        alignment: .leading
                    )
                } else {
                    // 普通内容的样式
                    MessageContentView(content: segment)
                        .padding(.horizontal, 50)
                        .padding(.vertical, 40)
                }
            }
            .frame(width: targetSize.width)
            .background(.white)
            .environment(\.colorScheme, .light)
            
            // 创建一个 UIHostingController 来托管 SwiftUI 视图
            let hostingController = UIHostingController(rootView: segmentContent)
            
            // 添加到临时窗口以确保正确布局
            let window = UIWindow(frame: UIScreen.main.bounds)
            window.rootViewController = hostingController
            window.makeKeyAndVisible()
            
            let view = hostingController.view!
            
            // 先设置一个临时的大小来获取实际内容高度
            view.frame = CGRect(x: 0, y: 0, width: targetSize.width, height: UIView.layoutFittingExpandedSize.height)
            view.setNeedsLayout()
            view.layoutIfNeeded()
            
            // 获取实际内容大小
            let fittingSize = view.systemLayoutSizeFitting(
                CGSize(width: targetSize.width, height: UIView.layoutFittingExpandedSize.height),
                withHorizontalFittingPriority: .required,
                verticalFittingPriority: .fittingSizeLevel
            )
            
            // 设置最终尺寸为目标尺寸
            view.frame = CGRect(origin: .zero, size: targetSize)
            view.backgroundColor = .white
            
            // 强制布局
            view.setNeedsLayout()
            view.layoutIfNeeded()
            
            // 创建图片上下文并渲染
            UIGraphicsBeginImageContextWithOptions(targetSize, true, UIScreen.main.scale)
            defer { UIGraphicsEndImageContext() }
            
            // 填充白色背景
            UIColor.white.setFill()
            UIRectFill(CGRect(origin: .zero, size: targetSize))
            
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
                x: (targetSize.width - watermarkSize.width) / 2,
                y: targetSize.height - watermarkSize.height - 16
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
                x: targetSize.width - pageSize.width - 20,
                y: targetSize.height - pageSize.height - 16
            )
            pageNumber.draw(at: pagePoint, withAttributes: pageAttributes)
            
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
    
    private func splitMarkdownContent(_ content: String) -> [String] {
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        print("\n原始内容长度: \(content.count)")
        print("处理后内容长度: \(trimmedContent.count)")
        
        // 将内容按行分割
        let lines = content.components(separatedBy: .newlines)
        var mainSegments: [String] = []
        var reasoningSegment: [String] = []
        var currentSegment: [String] = []
        
        // 首先找到推理过程部分
        var reasoningStartIndex: Int = -1
        for (index, line) in lines.enumerated() {
            if line.contains("推理过程") || line.contains("思考过程") {
                reasoningStartIndex = index
                break
            }
        }
        
        if reasoningStartIndex != -1 {
            // 将推理过程部分提取出来
            let reasoningLines = Array(lines[reasoningStartIndex...])
            // 将剩余部分作为主要内容
            let mainLines = Array(lines[..<reasoningStartIndex])
            
            // 处理推理过程部分
            reasoningSegment = [reasoningLines.joined(separator: "\n")]
            
            // 处理主要内容部分
            mainSegments = [mainLines.joined(separator: "\n")]
        } else {
            // 如果没有找到推理过程，则整体作为一个段落
            mainSegments = [lines.joined(separator: "\n")]
        }
        
        // 合并推理部分和主要内容（推理部分在前）
        var finalSegments = reasoningSegment
        finalSegments.append(contentsOf: mainSegments)
        
        print("\n最终分段结果:")
        print("推理部分段数: \(reasoningSegment.count)")
        print("主要内容段数: \(mainSegments.count)")
        print("总分段数量: \(finalSegments.count)")
        
        return finalSegments
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