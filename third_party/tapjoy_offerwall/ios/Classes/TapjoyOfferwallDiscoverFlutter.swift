import Flutter
import UIKit
import Tapjoy

class TapjoyOfferwallDiscoverViewFactory: NSObject, FlutterPlatformViewFactory {
    
    private var messenger: FlutterBinaryMessenger

    init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
        super.init()
    }

    func create(withFrame frame: CGRect, viewIdentifier viewId: Int64,
    arguments args: Any?) -> FlutterPlatformView {
        return TapjoyOfferwallDiscoverFlutterView(frame: frame,
        viewId: viewId,
        messenger: messenger,
        args: args)
    }
}

class TapjoyOfferwallDiscoverFlutterView: NSObject, FlutterPlatformView, TJOfferwallDiscoverDelegate {

    private var _view: UIView

    init(frame: CGRect, viewId: Int64, messenger: FlutterBinaryMessenger, args: Any?) {
        _view = UIView(frame: frame)
        super.init()
        loadContent()
    }

    func view() -> UIView {
        return _view
    }

    func loadContent() {
        guard let owdView = TapjoyOfferwallDiscover.shared.owdView else { return }
        owdView.translatesAutoresizingMaskIntoConstraints = false
        _view.addSubview(owdView)
        NSLayoutConstraint.activate([
                owdView.leadingAnchor.constraint(equalTo: _view.leadingAnchor),
                owdView.trailingAnchor.constraint(equalTo: _view.trailingAnchor),
                owdView.topAnchor.constraint(equalTo: _view.topAnchor),
                owdView.bottomAnchor.constraint(equalTo: _view.bottomAnchor)
        ])
    }
}
