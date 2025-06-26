import 'dart:convert';
import 'package:amanak/home/calendar_tab.dart';
import 'package:amanak/home/fall_detection_tab.dart';
import 'package:amanak/live_tracking.dart';
import 'package:amanak/nearest_hospitals.dart';
import 'package:amanak/home/profile_tab.dart';
import 'package:amanak/home/messaging_tab.dart';
import 'package:amanak/provider/my_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:simple_alert_dialog/simple_alert_dialog.dart';
import 'gaurdian_location.dart';
import 'home/home_tab.dart';

class HomeScreen extends StatefulWidget {
  static const String routeName = "HomeScreen";

  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    var provider = Provider.of<MyProvider>(context);
    return Scaffold(
      bottomNavigationBar: Theme(
        data: Theme.of(context).copyWith(
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: BottomNavigationBar(
          items: [
            BottomNavigationBarItem(
              icon: (provider.selectedIndexHome == 0)
                ? SvgPicture.asset('assets/svg/HomeSelected.svg')
                : SvgPicture.asset('assets/svg/Home.svg'),
              label: "Home",
            ),
            BottomNavigationBarItem(
              icon: (provider.selectedIndexHome == 1)
                ? SvgPicture.asset('assets/svg/calendarSelected.svg')
                : SvgPicture.asset('assets/svg/Calendaric.svg'),
              label: "Calendar",
            ),
            BottomNavigationBarItem(
              icon: (provider.selectedIndexHome == 2)
                ? SvgPicture.asset('assets/svg/MessageSelected.svg')
                : SvgPicture.asset('assets/svg/Message.svg'),
              label: "Messages",
            ),
            BottomNavigationBarItem(
              icon: (provider.selectedIndexHome == 3)
                ? SvgPicture.asset('assets/svg/sensorsSelected.svg')
                : SvgPicture.asset('assets/svg/sensors.svg'),
              label: "Fall Detection",
            ),
            BottomNavigationBarItem(
              icon: (provider.selectedIndexHome == 4)
                ? SvgPicture.asset('assets/svg/ProfileSelected.svg')
                : SvgPicture.asset('assets/svg/Profile.svg'),
              label: "Profile",
            ),
          ],
          currentIndex: provider.selectedIndexHome,
          onTap: (value) => provider.selectedIndexHome = value,
          type: BottomNavigationBarType.fixed,
          showSelectedLabels: true,
          showUnselectedLabels: true,
          selectedItemColor: Theme.of(context).primaryColor,
          unselectedItemColor: Colors.grey,
        ),
      ),
      body: IndexedStack(
        index: provider.selectedIndexHome,
        children: currentTabs,
      ),
    );
  }
}

List<Widget> currentTabs = [
  HomeTab(),
  CalendarTab(),
  MessagingTab(),
  FallDetectionTab(),
  ProfileTab(),
];
