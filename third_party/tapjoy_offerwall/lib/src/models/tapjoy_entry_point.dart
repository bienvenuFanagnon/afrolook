enum TJEntryPoint {

    /// Other unspecified entry point.
    entryPointUnknown(null),

    /// Other unspecified entry point.
    entryPointOther("other"),

    /// Main menu of the app.
    entryPointMainMenu("main_menu"),

    /// Heads-up display (HUD) in the app.
    entryPointHUD("hud"),

    /// Exit the app.
    entryPointExit("exit"),

    /// Failing a game level.
    entryPointFail("fail"),

    /// Completing a game level.
    entryPointComplete("complete"),

    /// Inbox.
    entryPointInbox("inbox"),

    /// App initialization with a message to earn.
    entryPointInit("initialisation"),

    /// In-app currency store.
    entryPointStore("store");

    final String? value;

    const TJEntryPoint(this.value);

    static TJEntryPoint fromOrdinal(int ordinal) {
        return TJEntryPoint.values[ordinal];
    }
    
    static TJEntryPoint fromString(String value) {
      switch (value){
          case "other":
              return entryPointOther;
          case "main_menu":
              return entryPointMainMenu;
          case "hud":
              return entryPointHUD;
          case "exit":
              return entryPointExit;
          case "fail":
              return entryPointFail;
          case "complete":
              return entryPointComplete;
          case "inbox":
              return entryPointInbox;
          case "initialisation":
              return entryPointInit;
          case "store":
              return entryPointStore;
          default:
              return entryPointUnknown;
      }
    }

}