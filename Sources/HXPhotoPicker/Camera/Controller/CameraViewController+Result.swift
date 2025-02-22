//
//  CameraViewController+Result.swift
//  CameraViewController+Result
//
//  Created by Slience on 2021/10/19.
//

import UIKit
import CoreLocation
import Photos

#if targetEnvironment(macCatalyst)
@available(macCatalyst 14.0, *)
#endif
extension CameraViewController: CameraResultViewControllerDelegate {
    func cameraResultViewController(
        didDone cameraResultViewController: CameraResultViewController
    ) {
        let vc = cameraResultViewController
        switch vc.type {
        case .photo:
            if let image = vc.image {
                didFinish(withImage: image)
            }
        case .video:
            if let videoURL = vc.videoURL {
                didFinish(withVideo: videoURL)
            }
        }
    }
    func didFinish(withImage image: UIImage) {
        var location: CLLocation?
        #if HXPICKER_ENABLE_CAMERA_LOCATION
        location = currentLocation
        #endif
        let result = CameraController.Result.image(image)
        if config.isSaveSystemAlbum {
            navigationController?.view.hx.show()
            AssetManager.saveSystemAlbum(type: .image(image), location: location) {
                self.navigationController?.view.hx.hide()
                switch $0 {
                case .success(let phAsset):
                    self.didFinish(result, phAsset: phAsset, location: location)
                case .failure:
                    ProgressHUD.showWarning(
                        addedTo: self.navigationController?.view,
                        text: "保存失败".localized,
                        animated: true,
                        delayHide: 1.5
                    )
                }
            }
            return
        }
        didFinish(result, location: location)
    }
    func didFinish(withVideo videoURL: URL) {
        var location: CLLocation?
        #if HXPICKER_ENABLE_CAMERA_LOCATION
        location = currentLocation
        #endif
        let result = CameraController.Result.video(videoURL)
        if config.isSaveSystemAlbum {
            navigationController?.view.hx.show()
            AssetManager.saveSystemAlbum(type: .videoURL(videoURL), location: location) {
                self.navigationController?.view.hx.hide()
                switch $0 {
                case .success(let phAsset):
                    self.didFinish(result, phAsset: phAsset, location: location)
                case .failure:
                    ProgressHUD.showWarning(
                        addedTo: self.navigationController?.view,
                        text: "保存失败".localized,
                        animated: true,
                        delayHide: 1.5
                    )
                }
            }
            return
        }
        didFinish(result, location: location)
    }
    
    func didFinish(_ result: CameraController.Result, phAsset: PHAsset? = nil, location: CLLocation?) {
        delegate?.cameraViewController(
            self,
            didFinishWithResult: result,
            location: location
        )
        if let phAsset = phAsset {
            delegate?.cameraViewController(
                self,
                didFinishWithResult: result,
                phAsset: phAsset,
                location: location
            )
        }
        if autoDismiss {
            dismiss(animated: true, completion: nil)
        }
    }
    
    func saveCameraImage(_ image: UIImage) {
        let previewSize = previewView.size
        DispatchQueue.global().async {
            let thumbImage = image.scaleToFillSize(size: previewSize)
            PhotoManager.shared.cameraPreviewImage = thumbImage
        }
    }
    func saveCameraVideo(_ videoURL: URL) {
        PhotoTools.getVideoThumbnailImage(
            url: videoURL,
            atTime: 0.1
        ) { _, image, _ in
            if let image = image {
                PhotoManager.shared.cameraPreviewImage = image
            }
        }
    }
}
