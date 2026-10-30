import Flutter
import UIKit
import Tapjoy

class ChannelManager: NSObject, FlutterStreamHandler {

    static let shared = ChannelManager()
    private var eventChannel: FlutterEventChannel?
    private var events: FlutterEventSink? = nil
    private var methodChannels: [String: FlutterMethodChannel] = [:]

    func registerMethodChannel(forRegistrar registrar: FlutterPluginRegistrar, name: String) -> FlutterMethodChannel {
        let channel = FlutterMethodChannel(name: name, binaryMessenger: registrar.messenger())
        methodChannels[name] = channel
        return channel
    }

    func getMethodChannel(name: String) -> FlutterMethodChannel? {
        return methodChannels[name]
    }

    func setEventChannel(_ eventChannel: FlutterEventChannel) {
        self.eventChannel = eventChannel
        self.eventChannel?.setStreamHandler(self)
    }

    func clear() {
        self.methodChannels = [:]
    }

    func sendEvent(_ type: String, _ value: Any?) {
        if let events = events {
            events(["type": type as Any, "value": value as Any])
        }
    }

    func sendError(_ code: Int, _ type: String, _ details: String) {
        let error = FlutterError(code: String(code), message: type, details: details)
        if let events = events {
            events(error)
        }
    }

    func invokeChannelMethod(_ channelName: String, _ methodName: String, arguments: Any?) {
        guard let methodChannel = getMethodChannel(name: channelName) else { return }
        DispatchQueue.main.async {
          methodChannel.invokeMethod(methodName, arguments: arguments)
        }
    }

    func onListen(withArguments arguments: Any?, eventSink: @escaping FlutterEventSink) -> FlutterError? {
        self.events = eventSink
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.events = nil
        return nil
    }
}
