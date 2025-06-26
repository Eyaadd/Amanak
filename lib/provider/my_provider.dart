import 'package:flutter/cupertino.dart';

class MyProvider extends ChangeNotifier {
  int _selectedIndexHome = 0;
  
  int get selectedIndexHome => _selectedIndexHome;
  
  set selectedIndexHome(int value) {
    if (_selectedIndexHome != value) {
      _selectedIndexHome = value;
      notifyListeners();
    }
  }

  void changeProfileIndex() {
    selectedIndexHome = 4;
  }

  void changeCalendarIndex() {
    selectedIndexHome = 1;
  }

  void changeMessageIndex() {
    selectedIndexHome = 2;
  }

  void changeFallDetectionIndex() {
    selectedIndexHome = 3;
  }

  String userID = "";
  String userEmail = "";
  String userName = "";
  String chosedRole = "";

  void setUserModel(String userId, String userName1, String userEmail1) {
    userID = userId;
    userName = userName1;
    userEmail = userEmail1;
    notifyListeners();
  }

  void setRole(String role) {
    chosedRole = role;
    notifyListeners();
  }
}
