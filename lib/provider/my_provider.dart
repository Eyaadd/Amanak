import 'package:flutter/cupertino.dart';

class ChangeTab extends ChangeNotifier{

  int selectedIndexHome = 0;

  changeIndex(){
    selectedIndexHome = 2;
    notifyListeners();
  }

}