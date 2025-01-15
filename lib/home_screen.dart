import 'package:amanak/home/calendar_tab.dart';
import 'package:amanak/home/live_tracking.dart';
import 'package:amanak/home/nearest_hospitals.dart';
import 'package:flutter/material.dart';

import 'home/home_tab.dart';

class HomeScreen extends StatefulWidget {
  static const String routeName = "HomeScreen";
   HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int selectedIndex = 0;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: BottomNavigationBar(items: [
        BottomNavigationBarItem(icon: Icon(Icons.home_outlined) , label: ""),
        BottomNavigationBarItem(icon: Icon(Icons.calendar_month_outlined) , label: ""),
        BottomNavigationBarItem(icon: Icon(Icons.pin_drop_outlined) , label: ""),
        BottomNavigationBarItem(icon: Icon(Icons.local_hospital_outlined) , label: ""),
      ],
      currentIndex: selectedIndex,
      onTap: (value) {
        setState(() {
          selectedIndex = value;
        });
      },),
      body: currentTabs[selectedIndex],
    );
  }
}



List<Widget>currentTabs = [
  HomeTab(),
  CalendarTab(),
  LiveTracking(),
  NearestHospitals()
];
