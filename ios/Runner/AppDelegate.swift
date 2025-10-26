import Flutter
import UIKit
import CoreBluetooth

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var blePeripheralManager: BlePeripheralManager?
  
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    
    let controller = window?.rootViewController as! FlutterViewController
    let channel = FlutterMethodChannel(name: "bluecard.ble.peripheral", binaryMessenger: controller.binaryMessenger)
    
    blePeripheralManager = BlePeripheralManager()
    
    channel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
      guard let self = self else { return }
      
      switch call.method {
      case "startAdvertising":
        if let args = call.arguments as? [String: Any],
           let serviceUuid = args["serviceUuid"] as? String,
           let deviceName = args["deviceName"] as? String {
          self.blePeripheralManager?.startAdvertising(serviceUuid: serviceUuid, deviceName: deviceName) { success in
            result(success)
          }
        } else {
          result(FlutterError(code: "INVALID_ARGS", message: "Missing serviceUuid or deviceName", details: nil))
        }
        
      case "stopAdvertising":
        self.blePeripheralManager?.stopAdvertising { success in
          result(success)
        }
        
      case "isPeripheralSupported":
        result(self.blePeripheralManager?.isPeripheralSupported() ?? false)
        
      case "setupGattServer":
        if let args = call.arguments as? [String: Any],
           let serviceUuid = args["serviceUuid"] as? String,
           let characteristicUuid = args["characteristicUuid"] as? String {
          self.blePeripheralManager?.setupPeripheralManager(serviceUuid: serviceUuid, characteristicUuid: characteristicUuid) { success in
            result(success)
          }
        } else {
          result(FlutterError(code: "INVALID_ARGS", message: "Missing UUIDs", details: nil))
        }
        
      case "sendData":
        if let args = call.arguments as? [String: Any],
           let data = args["data"] as? String {
          self.blePeripheralManager?.sendData(data: data) { success in
            result(success)
          }
        } else {
          result(FlutterError(code: "INVALID_ARGS", message: "Missing data", details: nil))
        }
        
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
