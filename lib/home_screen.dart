import 'dart:convert';
import 'package:amanak/home/calendar_tab.dart';
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

  HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    // sendData(context);
  }

  @override
  Widget build(BuildContext context) {
    var provider = Provider.of<MyProvider>(context);
    return Scaffold(
      bottomNavigationBar: BottomNavigationBar(
        items: [
          BottomNavigationBarItem(icon: (provider.selectedIndexHome ==0 )?SvgPicture.asset('assets/svg/HomeSelected.svg'):SvgPicture.asset('assets/svg/Home.svg'), label: ""),
          BottomNavigationBarItem(
              icon: (provider.selectedIndexHome == 1 )?SvgPicture.asset('assets/svg/calendarSelected.svg'):SvgPicture.asset('assets/svg/Calendaric.svg'), label: ""),
          BottomNavigationBarItem(
              icon: (provider.selectedIndexHome == 2 )?SvgPicture.asset('assets/svg/MessageSelected.svg'):SvgPicture.asset('assets/svg/Message.svg'), label: ""),
          BottomNavigationBarItem(
              icon: (provider.selectedIndexHome == 3 )?SvgPicture.asset('assets/svg/ProfileSelected.svg'):SvgPicture.asset('assets/svg/Profile.svg'), label: ""),
        ],
        currentIndex:
            (provider.selectedIndexHome == 2 || provider.selectedIndexHome == 1 ||provider.selectedIndexHome == 3 )
                ? provider.selectedIndexHome
                : selectedIndex,
        onTap: (value) {
          setState(() {
            selectedIndex = value;
            provider.selectedIndexHome = value;
          });
        },
      ),
      // body:provider.selectedIndexHome == 2? currentTabs[provider.selectedIndexHome] : currentTabs[selectedIndex],
      body: (provider.selectedIndexHome == 2 || provider.selectedIndexHome == 1 || provider.selectedIndexHome == 3)
          ? currentTabs[provider.selectedIndexHome]
          : currentTabs[selectedIndex],
    );
  }
}

List<Widget> currentTabs = [
  HomeTab(),
  CalendarTab(),
  MessagingTab(),
  ProfileTab(),
];

// Future<void> sendData(BuildContext context) async {
//   final url = 'https://b9ba-35-201-232-178.ngrok-free.app/predict/'; // Your API URL
//
//   final Map<String, dynamic> data = {
//     "features": [
//       [0.1538, -0.9254, -1.0239, -0.008, -0.006, 0.004],
//       [0.1418, -0.9274, -1.0199, -0.0119999999999999, -0.002, 0.004],
//       [0.1338, -0.9294, -1.0159, -0.008, -0.002, 0.004],
//       [0.1238, -0.9334, -1.0119, -0.01, -0.004, 0.004],
//       [0.1138, -0.9374, -1.0079, -0.0099999999999999, -0.004, 0.004],
//       [0.1075, -0.9394, -1.0039, -0.0063, -0.002, 0.004],
//       [0.1015, -0.9394, -1.0019, -0.0059999999999999, 0.0, 0.002],
//       [0.0935, -0.9414, -0.9959, -0.008, -0.002, 0.006],
//       [0.0875, -0.9454, -0.9919, -0.006, -0.004, 0.004],
//       [0.0815, -0.9474, -0.9899, -0.0059999999999999, -0.002, 0.002],
//       [0.0755, -0.9474, -0.9839, -0.006, 0.0, 0.006],
//       [0.0695, -0.9494, -0.9799, -0.0059999999999999, -0.002, 0.004],
//       [0.0675, -0.9514, -0.9779, -0.002, -0.002, 0.002],
//       [0.0635, -0.9534, -0.9719, -0.004, -0.002, 0.006],
//       [0.0575, -0.9534, -0.9699, -0.0059999999999999, 0.0, 0.002],
//       [0.0535, -0.9514, -0.9659, -0.004, 0.002, 0.004],
//       [0.0495, -0.9514, -0.9619, -0.0039999999999999, 0.0, 0.004],
//       [0.0455, -0.9494, -0.9559, -0.004, 0.002, 0.006],
//       [0.0415, -0.9474, -0.9519, -0.0039999999999999, 0.002, 0.004],
//       [0.0375, -0.9454, -0.9479, -0.004, 0.002, 0.004],
//       [0.0335, -0.9434, -0.9399, -0.0039999999999999, 0.002, 0.008],
//       [0.0295, -0.9394, -0.9339, -0.004, 0.004, 0.006],
//       [0.0255, -0.9214, -0.9279, -0.004, 0.018, 0.006],
//       [
//         0.0235,
//         -0.9093,
//         -0.9219,
//         -0.0019999999999999,
//         0.0121,
//         0.0059999999999998
//       ],
//       [0.0195, -0.8933, -0.9179, -0.004, 0.016, 0.004],
//       [0.0135, -0.8813, -0.9119, -0.006, 0.012, 0.006],
//       [0.0075, -0.8693, -0.9099, -0.006, 0.012, 0.002],
//       [0.0015, -0.8553, -0.9018, -0.006, 0.014, 0.0080999999999999],
//       [-0.0005, -0.8433, -0.8998, -0.002, 0.0119999999999999, 0.002],
//       [-0.0065, -0.8313, -0.8978, -0.006, 0.012, 0.002],
//       [-0.0125, -0.8213, -0.8958, -0.006, 0.01, 0.002],
//       [-0.0185, -0.8093, -0.8938, -0.0059999999999999, 0.012, 0.002],
//       [-0.0245, -0.7953, -0.8938, -0.006, 0.014, 0.0],
//       [-0.0305, -0.7813, -0.8918, -0.0059999999999999, 0.014, 0.002],
//       [-0.0345, -0.7653, -0.8918, -0.004, 0.016, 0.0],
//       [-0.0405, -0.7493, -0.8918, -0.0059999999999999, 0.016, 0.0],
//       [-0.0485, -0.735, -0.8938, -0.008, 0.0142999999999999, -0.002],
//       [-0.0545, -0.717, -0.8938, -0.0059999999999999, 0.018, 0.0],
//       [-0.0625, -0.699, -0.8958, -0.008, 0.018, -0.002],
//       [-0.0685, -0.681, -0.8978, -0.006, 0.0179999999999999, -0.002],
//       [-0.0725, -0.663, -0.8978, -0.0039999999999999, 0.018, 0.0],
//       [-0.0825, -0.647, -0.8978, -0.01, 0.016, 0.0],
//       [-0.0905, -0.637, -0.8978, -0.0079999999999999, 0.01, 0.0],
//       [-0.0945, -0.621, -0.8978, -0.004, 0.016, 0.0],
//       [-0.1005, -0.607, -0.8998, -0.006, 0.014, -0.002],
//       [-0.1065, -0.591, -0.9018, -0.0059999999999999, 0.016, -0.002],
//       [-0.1105, -0.577, -0.9038, -0.004, 0.014, -0.002],
//       [-0.1145, -0.563, -0.9038, -0.004, 0.014, 0.0],
//       [
//         -0.1205,
//         -0.549,
//         -0.9058,
//         -0.0059999999999999,
//         0.0139999999999999,
//         -0.002
//       ],
//       [-0.1245, -0.535, -0.9078, -0.004, 0.014, -0.002],
//       [-0.1265, -0.521, -0.9119, -0.002, 0.014, -0.0040999999999999],
//       [-0.1306, -0.5089, -0.9159, -0.0040999999999999, 0.0121, -0.004],
//       [-0.1346, -0.4949, -0.9199, -0.004, 0.014, -0.004],
//       [-0.1406, -0.4849, -0.9239, -0.006, 0.01, -0.004],
//       [-0.1426, -0.4749, -0.9299, -0.002, 0.01, -0.0059999999999998],
//       [-0.1466, -0.4629, -0.9339, -0.004, 0.012, -0.004],
//       [-0.1466, -0.4549, -0.9379, 0.0, 0.0079999999999999, -0.004],
//       [-0.1506, -0.4469, -0.9419, -0.004, 0.008, -0.004],
//       [-0.1566, -0.4369, -0.9439, -0.0059999999999999, 0.01, -0.002],
//       [-0.1606, -0.4289, -0.9459, -0.004, 0.008, -0.002],
//       [-0.1646, -0.4209, -0.9479, -0.004, 0.008, -0.002],
//       [-0.1666, -0.4149, -0.9499, -0.002, 0.006, -0.002],
//       [-0.1726, -0.4109, -0.9499, -0.006, 0.004, 0.0],
//       [-0.1766, -0.4049, -0.9519, -0.004, 0.006, -0.002],
//       [-0.1806, -0.3969, -0.9519, -0.004, 0.008, 0.0],
//       [-0.1806, -0.3909, -0.9539, 0.0, 0.0059999999999999, -0.002],
//       [-0.1826, -0.3849, -0.9539, -0.002, 0.006, 0.0],
//       [-0.1846, -0.3769, -0.9559, -0.0019999999999999, 0.008, -0.002],
//       [-0.1846, -0.3709, -0.9579, 0.0, 0.006, -0.002],
//       [-0.1846, -0.3649, -0.9599, 0.0, 0.006, -0.002],
//       [-0.1846, -0.3569, -0.9619, 0.0, 0.008, -0.002],
//       [-0.1826, -0.3469, -0.9659, 0.0019999999999999, 0.01, -0.004],
//       [-0.1826, -0.3389, -0.9659, 0.0, 0.008, 0.0],
//       [-0.1826, -0.3289, -0.9679, 0.0, 0.0099999999999999, -0.002],
//       [-0.1826, -0.3209, -0.9699, 0.0, 0.008, -0.002],
//       [-0.1826, -0.3089, -0.9739, 0.0, 0.012, -0.004],
//       [-0.1806, -0.2989, -0.9739, 0.002, 0.01, 0.0],
//       [-0.1806, -0.2889, -0.9779, 0.0, 0.01, -0.004],
//       [-0.1826, -0.2789, -0.9779, -0.002, 0.01, 0.0],
//       [-0.1826, -0.2669, -0.9799, 0.0, 0.0119999999999999, -0.002],
//       [-0.1746, -0.2508, -0.9819, 0.008, 0.0161, -0.002],
//       [-0.1706, -0.2348, -0.9799, 0.004, 0.016, 0.002],
//       [-0.1646, -0.2208, -0.9799, 0.006, 0.014, 0.0],
//       [-0.1586, -0.2088, -0.9799, 0.006, 0.0119999999999999, 0.0],
//       [-0.1566, -0.1968, -0.9779, 0.002, 0.012, 0.002],
//       [-0.1546, -0.1848, -0.9779, 0.002, 0.012, 0.0],
//       [-0.1506, -0.1748, -0.9779, 0.0039999999999999, 0.0099999999999999, 0.0],
//       [-0.1486, -0.1668, -0.9779, 0.002, 0.008, 0.0],
//       [-0.1466, -0.1568, -0.9779, 0.002, 0.01, 0.0],
//       [-0.1406, -0.1488, -0.9799, 0.006, 0.008, -0.002],
//       [-0.1406, -0.1408, -0.9719, 0.0, 0.0079999999999999, 0.008],
//       [-0.1386, -0.1328, -0.9679, 0.002, 0.008, 0.004],
//       [-0.1346, -0.1248, -0.9619, 0.004, 0.008, 0.006],
//       [-0.1326, -0.1168, -0.9579, 0.002, 0.0079999999999999, 0.004],
//       [-0.1285, -0.1108, -0.9539, 0.0040999999999999, 0.006, 0.004],
//       [-0.1225, -0.1028, -0.9519, 0.006, 0.0079999999999999, 0.002],
//       [-0.1225, -0.0948, -0.9499, 0.0, 0.008, 0.002],
//       [-0.1205, -0.0888, -0.9479, 0.002, 0.0059999999999999, 0.002],
//       [-0.1205, -0.0828, -0.9499, 0.0, 0.006, -0.002],
//       [-0.1165, -0.0768, -0.9459, 0.0039999999999999, 0.006, 0.004]
//     ]
//   };
//
//   try {
//     final response = await http.post(
//       Uri.parse(url),
//       headers: {'Content-Type': 'application/json'},
//       body: jsonEncode(data),
//     ); // Set timeout to 10 seconds;
//
//     if (response.statusCode == 200) {
//       final responseData = jsonDecode(response.body);
//       if (responseData['predicted_class'] == 'falling') {
//         // Show the alert dialog
//         _showAlertDialog(context);
//       }
//     } else {
//       print('Failed to send data: ${response.statusCode}');
//     }
//   } catch (e) {
//     print('Error: $e');
//   }
// }

// void _showAlertDialog(BuildContext context) {
//   SimpleAlertDialog.show(
//     context,
//     assetImagepath: AnimatedImage.error,
//     buttonsColor: Colors.red,
//     title: AlertTitleText('Fall Detected !',
//         style: Theme.of(context).textTheme.titleLarge),
//     content: AlertContentText('Are You Okay ?',
//         style: Theme.of(context).textTheme.titleSmall),
//     onConfirmButtonPressed: (ctx) {
//       Navigator.pop(ctx);
//     },
//   );
// }
