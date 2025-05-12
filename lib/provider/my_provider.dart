import 'package:flutter/cupertino.dart';

class MyProvider extends ChangeNotifier {
  int selectedIndexHome = 0;

  changeLiveTrackingIndex() {
    selectedIndexHome = 2;
    notifyListeners();
  }

  changeCalendarIndex() {
    selectedIndexHome = 1;
    notifyListeners();
  }

  String userID = "";
  String userEmail = "";
  String userName = "";
  String chosedRole = "";

  setUserModel(String userId, String userName1, String userEmail1) {
    userID = userId;
    userName = userName1;
    userEmail = userEmail1;
    notifyListeners();
  }

  setRole(String role) {
    chosedRole = role;
    notifyListeners();
  }
}
