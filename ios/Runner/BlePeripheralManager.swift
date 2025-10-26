import Foundation
import CoreBluetooth

class BlePeripheralManager: NSObject {
    private var peripheralManager: CBPeripheralManager?
    private var gameService: CBMutableService?
    private var gameCharacteristic: CBMutableCharacteristic?
    private var connectedCentrals: Set<CBCentral> = []
    
    private var isAdvertising = false
    private var serviceUUID: CBUUID?
    private var characteristicUUID: CBUUID?
    
    override init() {
        super.init()
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
    }
    
    func isPeripheralSupported() -> Bool {
        return CBPeripheralManager.authorizationStatus() != .denied &&
               peripheralManager?.state == .poweredOn
    }
    
    func startAdvertising(serviceUuid: String, deviceName: String, completion: @escaping (Bool) -> Void) {
        guard let peripheralManager = peripheralManager,
              peripheralManager.state == .poweredOn else {
            print("❌ Peripheral manager not ready")
            completion(false)
            return
        }
        
        if isAdvertising {
            print("⚠️ Already advertising")
            completion(true)
            return
        }
        
        guard let serviceUUID = CBUUID(string: serviceUuid) else {
            print("❌ Invalid service UUID")
            completion(false)
            return
        }
        
        self.serviceUUID = serviceUUID
        
        let advertisementData: [String: Any] = [
            CBAdvertisementDataServiceUUIDsKey: [serviceUUID],
            CBAdvertisementDataLocalNameKey: deviceName
        ]
        
        peripheralManager.startAdvertising(advertisementData)
        
        // We'll get the result in the delegate callback
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            completion(self.isAdvertising)
        }
    }
    
    func stopAdvertising(completion: @escaping (Bool) -> Void) {
        guard let peripheralManager = peripheralManager else {
            completion(false)
            return
        }
        
        if isAdvertising {
            peripheralManager.stopAdvertising()
            isAdvertising = false
            print("🛑 Stopped advertising")
        }
        
        completion(true)
    }
    
    func setupPeripheralManager(serviceUuid: String, characteristicUuid: String, completion: @escaping (Bool) -> Void) {
        guard let peripheralManager = peripheralManager,
              peripheralManager.state == .poweredOn else {
            print("❌ Peripheral manager not ready for GATT setup")
            completion(false)
            return
        }
        
        guard let serviceUUID = CBUUID(string: serviceUuid),
              let characteristicUUID = CBUUID(string: characteristicUuid) else {
            print("❌ Invalid UUIDs")
            completion(false)
            return
        }
        
        self.serviceUUID = serviceUUID
        self.characteristicUUID = characteristicUUID
        
        // Create characteristic for game communication
        gameCharacteristic = CBMutableCharacteristic(
            type: characteristicUUID,
            properties: [.read, .write, .notify],
            value: nil,
            permissions: [.readable, .writeable]
        )
        
        // Create service
        gameService = CBMutableService(type: serviceUUID, primary: true)
        gameService?.characteristics = [gameCharacteristic!]
        
        // Add service to peripheral manager
        peripheralManager.add(gameService!)
        
        print("🔧 Setting up GATT server with service: \(serviceUuid)")
        
        // We'll get confirmation in the delegate
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            completion(self.gameService != nil)
        }
    }
    
    func sendData(data: String, completion: @escaping (Bool) -> Void) {
        guard let gameCharacteristic = gameCharacteristic,
              let peripheralManager = peripheralManager else {
            print("❌ No characteristic available for sending data")
            completion(false)
            return
        }
        
        let dataToSend = data.data(using: .utf8) ?? Data()
        
        if connectedCentrals.isEmpty {
            print("⚠️ No connected centrals to send data to")
            completion(false)
            return
        }
        
        var successCount = 0
        
        for central in connectedCentrals {
            let success = peripheralManager.updateValue(
                dataToSend,
                for: gameCharacteristic,
                onSubscribedCentrals: [central]
            )
            
            if success {
                successCount += 1
            }
        }
        
        let allSuccess = successCount == connectedCentrals.count
        print("📤 Sent data to \(successCount)/\(connectedCentrals.count) centrals")
        completion(allSuccess)
    }
}

// MARK: - CBPeripheralManagerDelegate
extension BlePeripheralManager: CBPeripheralManagerDelegate {
    
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        switch peripheral.state {
        case .poweredOn:
            print("✅ Bluetooth is powered on and ready")
        case .poweredOff:
            print("❌ Bluetooth is powered off")
        case .resetting:
            print("🔄 Bluetooth is resetting")
        case .unauthorized:
            print("❌ Bluetooth access unauthorized")
        case .unsupported:
            print("❌ Bluetooth LE not supported")
        case .unknown:
            print("❓ Bluetooth state unknown")
        @unknown default:
            print("❓ Unknown Bluetooth state")
        }
    }
    
    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        if let error = error {
            print("❌ Failed to start advertising: \(error.localizedDescription)")
            isAdvertising = false
        } else {
            print("✅ Successfully started BLE advertising")
            isAdvertising = true
        }
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        if let error = error {
            print("❌ Failed to add service: \(error.localizedDescription)")
        } else {
            print("✅ Successfully added GATT service: \(service.uuid)")
        }
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        print("✅ Central subscribed to characteristic: \(central.identifier)")
        connectedCentrals.insert(central)
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        print("❌ Central unsubscribed from characteristic: \(central.identifier)")
        connectedCentrals.remove(central)
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        if request.characteristic.uuid == gameCharacteristic?.uuid {
            // Provide current data
            request.value = gameCharacteristic?.value
            peripheral.respond(to: request, withResult: .success)
            print("📖 Handled read request from central: \(request.central.identifier)")
        } else {
            peripheral.respond(to: request, withResult: .attributeNotFound)
        }
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        for request in requests {
            if request.characteristic.uuid == gameCharacteristic?.uuid {
                // Update characteristic with new data
                gameCharacteristic?.value = request.value
                
                if let data = request.value,
                   let message = String(data: data, encoding: .utf8) {
                    print("📨 Received data from central \(request.central.identifier): \(message)")
                    // Here you could notify Flutter about received data
                }
                
                peripheral.respond(to: request, withResult: .success)
            } else {
                peripheral.respond(to: request, withResult: .attributeNotFound)
            }
        }
    }
}