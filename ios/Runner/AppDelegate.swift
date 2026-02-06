import UIKit
import Flutter

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    // TODO: 注册自定义插件 - 需要在Xcode中将LivePhotoPlugin.swift添加到项目
    // if let registrar = self.registrar(forPlugin: "LivePhotoPlugin") {
    //   LivePhotoPlugin.register(with: registrar)
    // }
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
