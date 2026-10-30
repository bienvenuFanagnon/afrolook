enum TJSegment {
  nonPayer, payer, vip, unknown;

  int getValue(){
    switch(this){
      case nonPayer:
        return 0;
      case payer:
        return 1;
      case vip:
        return 2;
      case unknown:
        return -1;
    }
  }

  static TJSegment valueOf(int value){
        switch (value) {
            case 0:
                return nonPayer;
            case 1:
                return payer;
            case 2:
                return vip;
            default:
                return unknown;
        }
  }
}