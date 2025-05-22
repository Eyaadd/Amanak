import 'package:flutter/material.dart';

class NearestHospitals extends StatelessWidget {
  static const routeName = "NearestHospitals";
  const NearestHospitals({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        centerTitle: true,
        title: Text("Nearest Hospitals"),
      ),
      body: Expanded(
          child: Image.asset(
        "assets/images/nearesthospitals.jpg",
        width: double.infinity,
            fit: BoxFit.cover,
      )),
    );
  }
}
