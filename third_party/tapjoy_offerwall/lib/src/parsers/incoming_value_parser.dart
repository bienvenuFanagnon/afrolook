/// To parse values to be passed to Flutter from the native side via [MethodChannel]
class IncomingValueParser {

  /// Maps [tags] to the Set of tags.
  /// ```
  /// { 'userId': String }
  /// ```
  static Set<String> getUserSegment(List<dynamic>? tags) {
    if(tags == null){
      return <String>{};
    }
    return tags.map((item) => item as String).toSet();
  }
}