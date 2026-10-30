import Flutter
import UIKit
import Tapjoy

class TapjoyOfferwallDiscoverNativeView: TJOfferwallDiscoverView {

    func requestContent(_ placement: String) {
        request(placement)
    }

    func clearContent() {
        clear()
    }
}