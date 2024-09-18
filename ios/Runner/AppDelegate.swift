import Flutter
import Photos
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {

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
                      do {
                          let fileURL: URL = URL(fileURLWithPath: args)
                          let imageData = try Data(contentsOf: fileURL)
                          if let uiImage = UIImage(data: imageData) {
                              UIImageWriteToSavedPhotosAlbum(uiImage, nil, nil, nil)
                              result("OK")
                          }else{
                              result(FlutterError(code: "", message: "Error loading image ", details: ""))
                          }
                      } catch {
                              result(FlutterError(code: "", message: "Error loading image : \(error)", details: ""))
                      }
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

                          PHPhotoLibrary.shared().performChanges({
                              PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: NSURL(fileURLWithPath: args) as URL)
                          }) { success, error in
                              if success {
                                  result("OK")
                              } else {
                                  result(FlutterError(code: "", message: "saving error", details: "Error saving video: \(String(describing: error))"))
                              }
                          }
                      }
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
}
