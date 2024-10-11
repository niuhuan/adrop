import Flutter
import Photos
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
    
    static let albumName = "ADrop"

  func createDirectoryIfNotExists(path: String) {
    if !FileManager.default.fileExists(atPath: path) {
      do {
        try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)
      } catch {
        print("Error creating directory: \(error)")
      }
    }
  }
    
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
      let controller = self.window.rootViewController as! FlutterViewController
      let appSupDir = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true)[0]
      let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
      createDirectoryIfNotExists(path: appSupDir)
      createDirectoryIfNotExists(path: documentsPath)
      let channel = FlutterMethodChannel.init(name: "cross", binaryMessenger: controller as! FlutterBinaryMessenger)
      channel.setMethodCallHandler { (call, result) in
          Thread {
              if call.method == "root" {
                  result(appSupDir)
              }
              else if call.method == "documentDirectory" {
                  result(documentsPath)
              }
              else if call.method == "saveImageToGallery"{
                  if let args = call.arguments as? String{
                      // load image
                      var uiImage :UIImage
                      do {
                          let fileURL: URL = URL(fileURLWithPath: args)
                          let imageData = try Data(contentsOf: fileURL)
                          if let image = UIImage(data: imageData) {
                              uiImage = image
                          } else{
                              result(FlutterError(code: "", message: "Error loading image ", details: ""))
                              return
                          }
                      } catch {
                          result(FlutterError(code: "", message: "Error loading image : \(error)", details: ""))
                          return
                      }
                      //
                      var collOpt :PHAssetCollection?
                      PHPhotoLibrary.shared().performChanges({
                          collOpt = self.fetchAssetCollectionForAlbum(albumName: AppDelegate.albumName)
                          if nil == collOpt {
                              collOpt = self.createAssetCollectionForAlbum(albumName: AppDelegate.albumName)
                          }
                          if (collOpt == nil) {
                              result(FlutterError(code: "", message: "Error collOpt", details: ""))
                              return
                          }
                          if let albumChangeRequest = PHAssetCollectionChangeRequest(for: collOpt!) {
                                   let creationRequest = PHAssetChangeRequest.creationRequestForAsset(from: uiImage)
                                   let placeholder = creationRequest.placeholderForCreatedAsset
                                   let fastEnumeration = NSArray(object: placeholder!)
                                   albumChangeRequest.addAssets(fastEnumeration)
                                   result("OK")
                          } else {
                              result(FlutterError(code: "", message: "no request", details: ""))
                          }
                      }, completionHandler: { success, error in
                          if !success {
                              result(FlutterError(code: "", message: "Error PHAssetCollection : \(String(describing: error))", details: ""))
                          }
                      })
                  }else{
                      result(FlutterError(code: "", message: "params error", details: ""))
                  }
              }
              else if call.method == "saveVideoToGallery"{
                  if let args = call.arguments as? String{
                      
                      
                      PHPhotoLibrary.requestAuthorization { status in
                          // Return if unauthorized
                          guard status == .authorized else {
                              result(FlutterError(code: "", message: "Error saving video: unauthorized access", details: ""))
                              return
                          }
                      }
                      
                      
                      //
                      var collOpt :PHAssetCollection?
                      PHPhotoLibrary.shared().performChanges({
                          collOpt = self.fetchAssetCollectionForAlbum(albumName: AppDelegate.albumName)
                          if nil == collOpt {
                              collOpt = self.createAssetCollectionForAlbum(albumName: AppDelegate.albumName)
                          }
                          if (collOpt == nil) {
                              result(FlutterError(code: "", message: "Error collOpt", details: ""))
                              return
                          }
                          if let albumChangeRequest = PHAssetCollectionChangeRequest(for: collOpt!) {
                                  if let assetChangeRequest = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: NSURL(fileURLWithPath: args) as URL) {
                                      let placeholder = assetChangeRequest.placeholderForCreatedAsset
                                      let _ = albumChangeRequest.addAssets(NSArray(object: placeholder!))
                                      result("OK")
                                  } else {
                                      result(FlutterError(code: "", message: "no load video", details: ""))
                                  }
                          } else {
                              result(FlutterError(code: "", message: "no request", details: ""))
                          }
                      }, completionHandler: { success, error in
                          if !success {
                              result(FlutterError(code: "", message: "Error PHAssetCollection : \(String(describing: error))", details: ""))
                          }
                      })
                    
                  }else{
                      result(FlutterError(code: "", message: "params error", details: ""))
                  }
              }
              else if call.method == "getKeepScreenOn" {
                  result(application.isIdleTimerDisabled)
              }
              else if call.method == "setKeepScreenOn" {
                  if let args = call.arguments as? Bool {
                      DispatchQueue.main.async { () -> Void in
                          application.isIdleTimerDisabled = args
                      }
                  }
                  result(nil)
              }
              else{
                  result(FlutterMethodNotImplemented)
              }
          }.start()
      }

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
    
    
    // 辅助函数，用于获取相册
    func fetchAssetCollectionForAlbum(albumName: String) -> PHAssetCollection? {
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "title = %@", albumName)
        let collection = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: fetchOptions)
        return collection.firstObject
    }
    
    func createAssetCollectionForAlbum(albumName: String) -> PHAssetCollection? {
        let createAlbumRequest = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: albumName)
        let albumPlaceholder = createAlbumRequest.placeholderForCreatedAssetCollection
        let collectionFetchResult = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [albumPlaceholder.localIdentifier], options: nil)
        return collectionFetchResult.firstObject
    }
    
    enum ADropError: Error {
        case loadMedia
    }

}
