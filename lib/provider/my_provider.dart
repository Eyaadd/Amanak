import 'package:flutter/cupertino.dart';

class ChangeTab extends ChangeNotifier{

  int selectedIndexHome = 0;

  changeLiveTrackingIndex(){
    selectedIndexHome = 2;
    notifyListeners();
  }

  changeCalendarIndex(){
    selectedIndexHome = 1;
    notifyListeners();
  }

}