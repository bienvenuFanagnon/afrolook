import Flutter
import UIKit
import Tapjoy

class TapjoyOfferwallDiscover: NSObject{
    private let channelName = "tapjoy_offerwall_discover"
    var owdView: TapjoyOfferwallDiscoverNativeView?
    static let shared = TapjoyOfferwallDiscover()

    func registerChannel(with registrar: FlutterPluginRegistrar) {
         let channel = ChannelManager.shared.registerMethodChannel(forRegistrar: registrar,
                                                                        name: channelName)
        channel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
            self?.handleMethodCall(call: call, result: result)
        }
    }

    private func handleMethodCall(call: FlutterMethodCall, result: @escaping FlutterResult) {
            switch call.method {
            case "requestOWDContent":
                if let args = call.arguments as? [String: Any?] {
                    requestOWDContent(args, result: result)
                }
            case "clearOWDContent":
                    clearOWDContent(result: result)
            default:
                result(FlutterMethodNotImplemented)
            }
    }

    func requestOWDContent(_ args: [String: Any?], result: @escaping FlutterResult) {

        guard let placementName = args["placementName"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENT",
                                message: "Missing placementName",
                                details: nil))
            return
        }
        requestContent(placementName)
        result(nil)
    }

    func clearOWDContent(result: @escaping FlutterResult) {
        self.owdView?.clearContent()
        result(nil)
    }

    @objc func requestContent(_ placementName: String) {
        self.owdView = TapjoyOfferwallDiscoverNativeView()
        self.owdView?.delegate = self
        self.owdView?.requestContent(placementName)
    }

    private func sendEvent(_ eventName: String, _ message: String) {
        ChannelManager.shared.sendEvent(eventName, message)
    }

    private func sendError(_ eventName: String,  _ error: Error?) {
        let errorCode = (error as NSError?)?.code ?? -1
        ChannelManager.shared.sendError(errorCode, eventName, error?.localizedDescription ?? "Unknown Error")
    }
}

extension TapjoyOfferwallDiscover: TJOfferwallDiscoverDelegate {

    func requestDidSucceed(for view: TJOfferwallDiscoverView) {
        sendEvent("requestDidSucceedForView", "Request succeeded for view.")
    }

    func requestDidFail(for view: TJOfferwallDiscoverView, error: Error?) {
        sendError("requestDidFailForView", error)
    }

    func contentIsReady(for view: TJOfferwallDiscoverView) {
        sendEvent("contentIsReadyForView", "Content is ready for view.")
    }

    func contentError(for view: TJOfferwallDiscoverView, error: Error?) {
        sendError("contentErrorForView", error)
    }
}

