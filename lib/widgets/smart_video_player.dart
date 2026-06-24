export 'smart_video_player_stub.dart'
    if (dart.library.html) 'smart_video_player_web.dart'
    if (dart.library.io) 'smart_video_player_native.dart';
