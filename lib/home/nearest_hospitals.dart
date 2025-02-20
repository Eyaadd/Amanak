import 'package:flutter/material.dart';

class NearestHospitals extends StatelessWidget {
  const NearestHospitals({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
