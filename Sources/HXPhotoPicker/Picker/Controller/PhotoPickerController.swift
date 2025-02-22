//
//  PhotoPickerController.swift
//  照片选择器-Swift
//
//  Created by Silence on 2020/11/9.
//  Copyright © 2020 Silence. All rights reserved.
//

import UIKit
import Photos

extension PhotoPickerController {
    public typealias FinishHandler = (PickerResult, PhotoPickerController) -> Void
    public typealias CancelHandler = (PhotoPickerController) -> Void
}

open class PhotoPickerController: UINavigationController {
    public weak var pickerDelegate: PhotoPickerControllerDelegate?
    
    public var finishHandler: FinishHandler?
    public var cancelHandler: CancelHandler?
    
    /// 相关配置
    public var config: PickerConfiguration
    
    /// 当前被选择的资源对应的 PhotoAsset 对象数组
    /// 外部预览时的资源数据
    public var selectedAssetArray: [PhotoAsset] = [] {
        didSet { setupSelectedArray() }
    }
    
    /// 是否选中了原图，配置不显示原图按钮时，内部也是根据此属性来判断是否获取原图数据
    public var isOriginal: Bool = false
    
    /// fetch Assets 时的选项配置
    public lazy var options: PHFetchOptions = .init()
    
    /// 完成/取消时自动 dismiss ,为false需要自己在代理回调里手动 dismiss
    public var autoDismiss: Bool = true
    
    /// 本地资源数组
    /// 创建本地资源的PhotoAsset然后赋值即可添加到照片列表，如需选中也要添加到selectedAssetArray中
    public var localAssetArray: [PhotoAsset] = []
    
    /// 相机拍摄存在本地的资源数组（通过相机拍摄的但是没有保存到系统相册）
    /// 可以通过 pickerControllerDidDismiss 得到上一次相机拍摄的资源，然后赋值即可显示上一次相机拍摄的资源
    public var localCameraAssetArray: [PhotoAsset] = []
    
    /// 刷新数据
    /// 可以在传入 selectedAssetArray 之后重新加载数据将重新设置的被选择的 PhotoAsset 选中
    /// - Parameter assetCollection: 切换显示其他资源集合
    public func reloadData(assetCollection: PhotoAssetCollection?) {
        pickerViewController?.changedAssetCollection(collection: assetCollection)
        reloadAlbumData()
    }
    
    /// 刷新相册数据，只对单独控制器展示的有效
    public func reloadAlbumData() {
        albumViewController?.tableView.reloadData()
    }
    
    /// 使用其他相机拍摄完之后调用此方法添加
    /// - Parameter photoAsset: 对应的 PhotoAsset 数据
    public func addedCameraPhotoAsset(_ photoAsset: PhotoAsset) {
        pickerViewController?.addedCameraPhotoAsset(photoAsset)
        previewViewController?.addedCameraPhotoAsset(photoAsset)
    }
    
    /// 删除当前预览的 Asset
    public func deleteCurrentPreviewPhotoAsset() {
        previewViewController?.deleteCurrentPhotoAsset()
    }
    
    /// 预览界面添加本地资源
    /// - Parameter photoAsset: 对应的 PhotoAsset 数据
    public func previewAddedCameraPhotoAsset(_ photoAsset: PhotoAsset) {
        previewViewController?.addedCameraPhotoAsset(photoAsset)
    }
    
    /// 获取预览界面当前显示的 image 视图
    /// - Returns: 对应的 UIImageView
    public func getCurrentPreviewImageView() -> UIImageView? {
        if let previewVC = previewViewController,
           let cell = previewVC.getCell(for: previewVC.currentPreviewIndex) {
            return cell.scrollContentView.imageView.imageView
        }
        return nil
    }
    
    /// 预览界面的数据
    public var previewAssets: [PhotoAsset] {
        if let assets = previewViewController?.previewAssets {
            return assets
        }
        return []
    }
    
    /// 预览界面当前显示的页数
    public var currentPreviewIndex: Int {
        if let index = previewViewController?.currentPreviewIndex {
            return index
        }
        return 0
    }
    
    /// 获取预览界面当前显示的 image 视图
    /// - Returns: 对应的 UIImageView
    public var currentPreviewImageView: UIImageView? {
        getCurrentPreviewImageView()
    }
    
    /// 相册列表控制器
    public var albumViewController: AlbumViewController? {
        getViewController(
            for: AlbumViewController.self
        ) as? AlbumViewController
    }
    /// 照片选择控制器
    public var pickerViewController: PhotoPickerViewController? {
        getViewController(
            for: PhotoPickerViewController.self
        ) as? PhotoPickerViewController
    }
    /// 照片预览控制器
    public var previewViewController: PhotoPreviewViewController? {
        getViewController(
            for: PhotoPreviewViewController.self
        ) as? PhotoPreviewViewController
    }
    
    /// 当前处于的外部预览
    public let isPreviewAsset: Bool
    
    /// 选择资源初始化
    /// - Parameter config: 相关配置
    public convenience init(
        picker config: PickerConfiguration,
        delegate: PhotoPickerControllerDelegate? = nil
    ) {
        self.init(
            config: config,
            delegate: delegate
        )
    }
    /// 选择资源初始化
    /// - Parameter config: 相关配置
    public init(
        config: PickerConfiguration,
        delegate: PhotoPickerControllerDelegate? = nil
    ) {
        var config = config
        PhotoManager.shared.appearanceStyle = config.appearanceStyle
        PhotoManager.shared.createLanguageBundle(languageType: config.languageType)
        self.config = config
        if config.selectMode == .multiple &&
            !config.allowSelectedTogether &&
            config.maximumSelectedVideoCount == 1 &&
            config.selectOptions.isPhoto && config.selectOptions.isVideo &&
            config.photoList.cell.isHiddenSingleVideoSelect {
            singleVideo = true
        }
        isPreviewAsset = false
        isExternalPickerPreview = false
        super.init(nibName: nil, bundle: nil)
        isOriginal = config.isSelectedOriginal
        autoDismiss = config.isAutoBack
        modalPresentationStyle = config.modalPresentationStyle
        pickerDelegate = delegate
        var photoVC: UIViewController
        if config.albumShowMode == .normal {
            photoVC = AlbumViewController(config: config.albumList)
        }else {
            photoVC = PhotoPickerViewController(config: config.photoList)
        }
        self.viewControllers = [photoVC]
    }
    
    /// 选择资源初始化
    /// - Parameter config: 相关配置
    public convenience init(
        config: PickerConfiguration,
        finish: FinishHandler? = nil,
        cancel: CancelHandler? = nil
    ) {
        self.init(config: config)
        self.finishHandler = finish
        self.cancelHandler = cancel
    }
    
    /// 外部预览资源初始化
    /// - Parameters:
    ///   - config: 相关配置
    ///   - currentIndex: 当前预览的下标
    ///   - modalPresentationStyle: 默认 custom 样式，框架自带动画效果
    public init(
        preview config: PickerConfiguration,
        previewAssets: [PhotoAsset],
        currentIndex: Int,
        modalPresentationStyle: UIModalPresentationStyle = .custom,
        delegate: PhotoPickerControllerDelegate? = nil
    ) {
        PhotoManager.shared.appearanceStyle = config.appearanceStyle
        PhotoManager.shared.createLanguageBundle(languageType: config.languageType)
        self.config = config
        isPreviewAsset = true
        isExternalPickerPreview = false
        super.init(nibName: nil, bundle: nil)
        isOriginal = config.isSelectedOriginal
        autoDismiss = config.isAutoBack
        pickerDelegate = delegate
        let vc = PhotoPreviewViewController(config: self.config.previewView)
        vc.isExternalPreview = true
        vc.previewAssets = previewAssets
        vc.currentPreviewIndex = currentIndex
        self.viewControllers = [vc]
        self.modalPresentationStyle = modalPresentationStyle
        if modalPresentationStyle == .custom {
            transitioningDelegate = self
            modalPresentationCapturesStatusBarAppearance = true
        }
    }
    
    /// 主动调用dismiss
    public func dismiss(_ animated: Bool, completion: (() -> Void)? = nil) {
        #if HXPICKER_ENABLE_EDITOR
        if presentedViewController is EditorViewController {
            presentingViewController?.dismiss(animated: animated, completion: completion)
            return
        }
        #endif
        dismiss(animated: animated, completion: completion)
    }
    
    let isExternalPickerPreview: Bool
    init(
        pickerPreview config: PickerConfiguration,
        previewAssets: [PhotoAsset],
        currentIndex: Int,
        modalPresentationStyle: UIModalPresentationStyle = .custom,
        delegate: PhotoPickerControllerDelegate? = nil
    ) {
        PhotoManager.shared.appearanceStyle = config.appearanceStyle
        PhotoManager.shared.createLanguageBundle(languageType: config.languageType)
        self.config = config
        isPreviewAsset = false
        isExternalPickerPreview = true
        super.init(nibName: nil, bundle: nil)
        isOriginal = config.isSelectedOriginal
        autoDismiss = config.isAutoBack
        pickerDelegate = delegate
        let vc = PhotoPreviewViewController(config: self.config.previewView)
        vc.previewAssets = previewAssets
        vc.currentPreviewIndex = currentIndex
        vc.isExternalPickerPreview = true
        self.viewControllers = [vc]
        self.modalPresentationStyle = modalPresentationStyle
        if modalPresentationStyle == .custom {
            transitioningDelegate = self
            modalPresentationCapturesStatusBarAppearance = true
        }
    }
    var disablesCustomDismiss = false
    
    /// 所有资源集合
    var assetCollectionsArray: [PhotoAssetCollection] = []
    var fetchAssetCollectionsCompletion: (([PhotoAssetCollection]) -> Void)?
    
    /// 相机胶卷资源集合
    var cameraAssetCollection: PhotoAssetCollection?
    var fetchCameraAssetCollectionCompletion: ((PhotoAssetCollection?) -> Void)?
    var canAddAsset: Bool = true
    private var isFirstAuthorization: Bool = false
    var selectOptions: PickerAssetOptions!
    var selectedPhotoAssetArray: [PhotoAsset] = []
    var selectedVideoAssetArray: [PhotoAsset] = []
    lazy var deniedView: DeniedAuthorizationView = {
        let deniedView = DeniedAuthorizationView.init(config: config.notAuthorized)
        deniedView.frame = view.bounds
        return deniedView
    }()
    var singleVideo: Bool = false
    lazy var assetCollectionsQueue: OperationQueue = {
        let assetCollectionsQueue = OperationQueue.init()
        assetCollectionsQueue.maxConcurrentOperationCount = 1
        return assetCollectionsQueue
    }()
    lazy var assetsQueue: OperationQueue = {
        let assetCollectionsQueue = OperationQueue()
        assetCollectionsQueue.maxConcurrentOperationCount = 1
        return assetCollectionsQueue
    }()
    lazy var requestAssetBytesQueue: OperationQueue = {
        let requestAssetBytesQueue = OperationQueue.init()
        requestAssetBytesQueue.maxConcurrentOperationCount = 1
        return requestAssetBytesQueue
    }()
    lazy var previewRequestAssetBytesQueue: OperationQueue = {
        let requestAssetBytesQueue = OperationQueue.init()
        requestAssetBytesQueue.maxConcurrentOperationCount = 1
        return requestAssetBytesQueue
    }()
    public override var modalPresentationStyle: UIModalPresentationStyle {
        didSet {
            if (isPreviewAsset || isExternalPickerPreview) && modalPresentationStyle == .custom {
                transitioningDelegate = self
                modalPresentationCapturesStatusBarAppearance = true
            }
        }
    }
    var interactiveTransition: PickerInteractiveTransition?
    
    var dismissInteractiveTransition: PickerControllerInteractiveTransition?
    
    #if HXPICKER_ENABLE_EDITOR
    lazy var editedPhotoAssetArray: [PhotoAsset] = []
    #endif
    
    var isDismissed: Bool = false
    var pickerTask: Any?
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        PhotoManager.shared.indicatorType = config.indicatorType
        PhotoManager.shared.loadNetworkVideoMode = config.previewView.loadNetworkVideoMode
        PhotoManager.shared.thumbnailLoadMode = .complete
        configColor()
        navigationBar.isTranslucent = config.navigationBarIsTranslucent
        selectOptions = config.selectOptions
        if !isPreviewAsset && !isExternalPickerPreview {
            setOptions()
            requestAuthorization()
            if modalPresentationStyle == .fullScreen &&
                config.albumShowMode == .popup &&
                config.allowCustomTransitionAnimation {
                modalPresentationCapturesStatusBarAppearance = true
                switch config.pickerPresentStyle {
                case .present(let rightSwipe):
                    transitioningDelegate = self
                    if let rightSwipe = rightSwipe {
                        dismissInteractiveTransition = .init(
                            panGestureRecognizerFor: self,
                            type: .dismiss,
                            triggerRange: rightSwipe.triggerRange
                        )
                    }
                case .push(let rightSwipe):
                    transitioningDelegate = self
                    if let rightSwipe = rightSwipe {
                        dismissInteractiveTransition = .init(
                            panGestureRecognizerFor: self,
                            type: .pop,
                            triggerRange: rightSwipe.triggerRange
                        )
                    }
                default:
                    break
                }
            }
        }else {
            if modalPresentationStyle == .custom && config.allowCustomTransitionAnimation {
                interactiveTransition = .init(panGestureRecognizerFor: self, type: .dismiss)
            }
        }
    }
    public override func present(
        _ viewControllerToPresent: UIViewController,
        animated flag: Bool,
        completion: (() -> Void)? = nil
    ) {
        if isFirstAuthorization &&
            viewControllerToPresent is UIImagePickerController {
            viewControllerToPresent.modalPresentationStyle = .fullScreen
            isFirstAuthorization = false
        }
        super.present(
            viewControllerToPresent,
            animated: flag,
            completion: completion
        )
    }
    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let status = AssetManager.authorizationStatus()
        if status.rawValue >= 1 && status.rawValue < 3 {
            deniedView.frame = view.bounds
        }
    }
    public override var preferredStatusBarStyle: UIStatusBarStyle {
        if PhotoManager.isDark {
            return .lightContent
        }
        return config.statusBarStyle
    }
    public override var prefersStatusBarHidden: Bool {
        if config.prefersStatusBarHidden {
            return config.prefersStatusBarHidden
        }else {
            if let prefersStatusBarHidden = topViewController?.prefersStatusBarHidden {
                return prefersStatusBarHidden
            }
            return false
        }
    }
    open override var shouldAutorotate: Bool {
        config.shouldAutorotate
    }
    open override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return config.supportedInterfaceOrientations
    }
    public override var preferredStatusBarUpdateAnimation: UIStatusBarAnimation {
        if let animation = topViewController?.preferredStatusBarUpdateAnimation {
            return animation
        }
        return .fade
    }
    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 13.0, *) {
            if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                configColor()
            }
        }
    }
    public override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if !isPreviewAsset && presentingViewController == nil && !isExternalPickerPreview {
            didDismiss()
        }
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    deinit {
        PhotoManager.shared.thumbnailLoadMode = .complete
        PhotoManager.shared.firstLoadAssets = false
        cancelFetchAssetsQueue()
        cancelAssetCollectionsQueue()
        cancelRequestAssetFileSize(isPreview: false)
        previewRequestAssetBytesQueue.cancelAllOperations()
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }
}

// MARK: Private function
extension PhotoPickerController {
    func configBackgroundColor() {
        view.backgroundColor = PhotoManager.isDark ?
            config.navigationViewBackgroudDarkColor :
            config.navigationViewBackgroundColor
    }
    private func setOptions() {
        if !selectOptions.mediaTypes.contains(.image) {
            options.predicate = NSPredicate(
                format: "mediaType == %ld",
                argumentArray: [PHAssetMediaType.video.rawValue]
            )
        }else if !selectOptions.mediaTypes.contains(.video) {
            options.predicate = NSPredicate(
                format: "mediaType == %ld",
                argumentArray: [PHAssetMediaType.image.rawValue]
            )
        }else {
            options.predicate = nil
        }
    }
    private func configColor() {
        if config.appearanceStyle == .normal {
            if #available(iOS 13.0, *) {
                overrideUserInterfaceStyle = .light
            }
        }
        
        if modalPresentationStyle != .custom {
            configBackgroundColor()
        }
        let isDark = PhotoManager.isDark
        let titleTextAttributes = [
            NSAttributedString.Key.foregroundColor:
                isDark ? config.navigationTitleDarkColor : config.navigationTitleColor
        ]
        navigationBar.titleTextAttributes = titleTextAttributes
        let tintColor = isDark ? config.navigationDarkTintColor : config.navigationTintColor
        navigationBar.tintColor = tintColor
        let barStyle = isDark ? config.navigationBarDarkStyle : config.navigationBarStyle
        navigationBar.barStyle = barStyle
        
        if !config.adaptiveBarAppearance {
            return
        }
        if #available(iOS 15.0, *) {
            let appearance = UINavigationBarAppearance()
            appearance.titleTextAttributes = titleTextAttributes
            switch barStyle {
            case .`default`:
                appearance.backgroundEffect = UIBlurEffect(style: .extraLight)
            default:
                appearance.backgroundEffect = UIBlurEffect(style: .dark)
            }
            navigationBar.standardAppearance = appearance
            navigationBar.scrollEdgeAppearance = appearance
        }
    }
    private func requestAuthorization() {
        if !config.allowLoadPhotoLibrary {
            fetchCameraAssetCollection()
            return
        }
        let status = AssetManager.authorizationStatus()
        if status.rawValue >= 3 {
            // 有权限
            fetchData(status: status)
        }else if status.rawValue >= 1 {
            // 无权限
            view.addSubview(deniedView)
        }else {
            // 用户还没做出选择，请求权限
            isFirstAuthorization = true
            AssetManager.requestAuthorization { (status) in
                self.fetchData(status: status)
                self.albumViewController?.updatePrompt()
                self.pickerViewController?.reloadAlbumData()
                self.pickerViewController?.updateBottomPromptView()
                PhotoManager.shared.registerPhotoChangeObserver()
            }
        }
    }
    private func setupSelectedArray() {
        if isPreviewAsset {
            for photoAsset in selectedAssetArray {
                photoAsset.isSelected = true
            }
            previewViewController?.previewAssets = selectedAssetArray
            return
        }
        if config.selectMode == .single {
            return
        }
        if !canAddAsset {
            canAddAsset = true
            return
        }
        let array = selectedAssetArray
        for photoAsset in array {
            if photoAsset.mediaType == .photo {
                selectedPhotoAssetArray.append(photoAsset)
                #if HXPICKER_ENABLE_EDITOR
                if let editedResult = photoAsset.editedResult {
                    photoAsset.initialEditedResult = editedResult
                }
                addedEditedPhotoAsset(photoAsset)
                #endif
            }else if photoAsset.mediaType == .video {
                if singleVideo {
                    if let index = selectedAssetArray.firstIndex(of: photoAsset) {
                        canAddAsset = false
                        selectedAssetArray.remove(at: index)
                    }
                }else {
                    selectedVideoAssetArray.append(photoAsset)
                }
                #if HXPICKER_ENABLE_EDITOR
                if let editedResult = photoAsset.editedResult {
                    photoAsset.initialEditedResult = editedResult
                }
                addedEditedPhotoAsset(photoAsset)
                #endif
            }
        }
    }
    private func getViewController(for viewControllerClass: UIViewController.Type) -> UIViewController? {
        for vc in viewControllers where vc.isMember(of: viewControllerClass) {
            return vc
        }
        return nil
    }
    private func didDismiss() {
        if #available(iOS 13.0, *) {
            if let task = pickerTask as? Task<(), Never> {
                task.cancel()
                pickerTask = nil
            }
        }
        #if HXPICKER_ENABLE_EDITOR
        removeAllEditedPhotoAsset()
        #endif
        var cameraAssetArray: [PhotoAsset] = []
        for photoAsset in localCameraAssetArray {
            if let cameraAsset = photoAsset.cameraAsset {
                cameraAssetArray.append(cameraAsset)
            }
        }
        PhotoManager.shared.saveCameraPreview()
        pickerDelegate?.pickerController(self, didDismissComplete: cameraAssetArray)
        if !isDismissed {
            cancelHandler?(self)
        }
    }
}

@available(iOS 13.0.0, *)
public extension PhotoPickerController {
    
    /// PhotoManager.shared.isConverHEICToPNG = true 内部自动将HEIC格式转换成PNG格式
    /// - Parameter compression: 压缩参数，不传则根据内部 isOriginal 判断是否压缩
    static func picker<T: PhotoAssetObject>(
        _ config: PickerConfiguration,
        delegate: PhotoPickerControllerDelegate? = nil,
        compression: PhotoAsset.Compression? = nil,
        fromVC: UIViewController? = nil
    ) async throws -> [T] {
        var config = config
        config.isAutoBack = false
        let vc = show(config, delegate: delegate, fromVC: fromVC)
        return try await vc.pickerObject(compression)
    }
    
    static func picker(
        _ config: PickerConfiguration,
        delegate: PhotoPickerControllerDelegate? = nil,
        fromVC: UIViewController? = nil
    ) async throws -> PickerResult {
        let vc = show(config, delegate: delegate, fromVC: fromVC)
        return try await vc.picker()
    }
    
    static func show(
        _ config: PickerConfiguration,
        delegate: PhotoPickerControllerDelegate? = nil,
        fromVC: UIViewController? = nil
    ) -> PhotoPickerController {
        let topVC: UIViewController?
        if let fromVC = fromVC {
            topVC = fromVC
        }else {
            topVC = UIViewController.topViewController
        }
        let pickerController = PhotoPickerController(picker: config, delegate: delegate)
        topVC?.present(pickerController, animated: true)
        return pickerController
    }
    
    func picker() async throws -> PickerResult {
        try await withCheckedThrowingContinuation { continuation in
            var isDimissed: Bool = false
            finishHandler = { result, _ in
                if isDimissed { return }
                isDimissed = true
                continuation.resume(with: .success(result))
            }
            cancelHandler = { _ in
                if isDimissed { return }
                isDimissed = true
                continuation.resume(with: .failure(PickerError.canceled))
            }
        }
    }
    
    /// PhotoManager.shared.isConverHEICToPNG = true 内部自动将HEIC格式转换成PNG格式
    /// - Parameter compression: 压缩参数，不传则根据内部 isOriginal 判断是否压缩
     func pickerObject<T: PhotoAssetObject>(_ compression: PhotoAsset.Compression? = nil) async throws -> [T] {
        try await withCheckedThrowingContinuation { continuation in
            finishHandler = { [weak self] result, controller in
                guard let self = self else { return }
                ProgressHUD.showLoading(addedTo: self.view)
                self.pickerTask = Task {
                    do {
                        let objects: [T] = try await result.objects(compression)
                        if !Task.isCancelled {
                            continuation.resume(with: .success(objects))
                        }else {
                            self.pickerTask = nil
                            continuation.resume(with: .failure(PickerError.canceled))
                            return
                        }
                    } catch {
                        continuation.resume(with: .failure(error))
                    }
                    self.pickerTask = nil
                    ProgressHUD.hide(forView: self.view)
                    controller.dismiss(true)
                }
            }
            cancelHandler = { controller in
                controller.dismiss(true)
                continuation.resume(with: .failure(PickerError.canceled))
            }
        }
    }
}
