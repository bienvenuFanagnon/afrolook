import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';

class TJOfferwallDiscoverViewWidget extends StatefulWidget {
  const TJOfferwallDiscoverViewWidget({super.key, this.creationParams = const {} });
  final Map<String, dynamic> creationParams;
  @override
  State<TJOfferwallDiscoverViewWidget> createState() => _TJOfferwallDiscoverViewWidget();
}

class _TJOfferwallDiscoverViewWidget extends State<TJOfferwallDiscoverViewWidget> {
  
  @override
  Widget build(BuildContext context) {
    const String viewType = 'tapjoy_offerwall_discover';
      Map<String, dynamic> creationParams = widget.creationParams;
    switch(defaultTargetPlatform) {
      case TargetPlatform.android:
        return PlatformViewLink(
          viewType: viewType,
          surfaceFactory: (context, controller) {
            return AndroidViewSurface(
              controller: controller as AndroidViewController,
              gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                Factory<HorizontalDragGestureRecognizer>(
                  () => HorizontalDragGestureRecognizer(),
                ),
                Factory<TapGestureRecognizer>(() => TapGestureRecognizer()),
              },
              hitTestBehavior: PlatformViewHitTestBehavior.opaque,
            );
          },
          onCreatePlatformView: (params) {
            return PlatformViewsService.initSurfaceAndroidView(
              id: params.id,
              viewType: viewType,
              layoutDirection: TextDirection.ltr,
              creationParams: creationParams,
              creationParamsCodec: const StandardMessageCodec(),
              onFocus: () {
                params.onFocusChanged(true);
              },
            )
            ..addOnPlatformViewCreatedListener(params.onPlatformViewCreated)
            ..create();
          },
        );
      case TargetPlatform.iOS:
        return UiKitView(
          viewType: viewType,
          layoutDirection: TextDirection.ltr,
          gestureRecognizers: <Factory<OneSequenceGestureRecognizer>> {
            Factory<HorizontalDragGestureRecognizer>(
              () => HorizontalDragGestureRecognizer(),
            ),
            Factory<TapGestureRecognizer>(() => TapGestureRecognizer()),
          },
          creationParams: creationParams,
          creationParamsCodec: const StandardMessageCodec(),
        );

      default:
          throw UnsupportedError('Unsupported platform view');
    }
  }
}