import 'package:amanak/chatbot.dart';
import 'package:amanak/gaurdian_location.dart';
import 'package:amanak/home/messaging_tab.dart';
import 'package:amanak/nearest_hospitals.dart';
import 'package:amanak/widgets/overlay_button.dart';
import 'package:amanak/widgets/pillsearchfield.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../live_tracking.dart';
import '../provider/my_provider.dart';

class HomeTab extends StatelessWidget {
  HomeTab({super.key});

  static int selectedHomeIndex = 0;
  final _searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    var provider = Provider.of<MyProvider>(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return SafeArea(
      child: Scaffold(
        body: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(screenWidth * 0.05),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        SvgPicture.asset("assets/svg/handshake.svg", height: screenHeight * 0.06),
                        SizedBox(width: screenWidth * 0.02),
                        Text(
                          "Amanak",
                          style: Theme.of(context).textTheme.titleMedium!.copyWith(
                            color: Colors.black,
                            fontSize: screenWidth * 0.05,
                          ),
                        ),
                      ],
                    ),
                    SvgPicture.asset("assets/svg/notification.svg", height: screenHeight * 0.035),
                  ],
                ),
                SizedBox(height: screenHeight * 0.025),
                // Search Field
                PillSearchField(controller: _searchController),
                SizedBox(height: screenHeight * 0.02),
                // Overlay Buttons Row
                Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              OverlayButton(
                                assetName: "location",
                                onTap: () => Navigator.pushNamed(context, LiveTracking.routeName),
                              ),
                              SizedBox(height:screenHeight * 0.025),
                              Text(
                                "Live \nLocation",
                                style: Theme.of(context).textTheme.titleSmall!.copyWith(
                                  color: Color(0xFFA1A8B0),
                                  fontSize: screenWidth * 0.032,
                                ),
                                textAlign: TextAlign.center,
                              ),
                          
                            ],
                          ),
                        ),
                        SizedBox(width: screenWidth * 0.04),
                        Expanded(
                          child: Column(
                            children: [
                              OverlayButton(
                                assetName: "calendar",
                                onTap: () => provider.changeCalendarIndex(),
                              ),
                              SizedBox(height:screenHeight * 0.025),
                              Text(
                                "Calendar\n",
                                style: Theme.of(context).textTheme.titleSmall!.copyWith(
                                  color: Color(0xFFA1A8B0),
                                  fontSize: screenWidth * 0.032,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: screenWidth * 0.04),
                        Expanded(
                          child: Column(
                            children: [
                              OverlayButton(
                                assetName: "hospital",
                                onTap: () => Navigator.pushNamed(context, NearestHospitals.routeName),
                              ),
                              SizedBox(height:screenHeight * 0.025),
                              Text(
                                "Nearest \nHospitals",
                                style: Theme.of(context).textTheme.titleSmall!.copyWith(
                                  color: Color(0xFFA1A8B0),
                                  fontSize: screenWidth * 0.032,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: screenHeight * 0.025),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              OverlayButton(
                                assetName: "messages",
                                onTap: () {
                                  provider.changeMessageIndex();
                                }
                              ),
                              SizedBox(height:screenHeight * 0.025),
                              Text(
                                "Messages",
                                style: Theme.of(context).textTheme.titleSmall!.copyWith(
                                  color: Color(0xFFA1A8B0),
                                  fontSize: screenWidth * 0.032,
                                ),
                                textAlign: TextAlign.center,
                              ),
                          
                            ],
                          ),
                        ),
                        SizedBox(width: screenWidth * 0.04),
                        Expanded(
                          child: Column(
                            children: [
                              OverlayButton(
                                assetName: "pills",
                                onTap: () => provider.changeCalendarIndex(),
                              ),
                              SizedBox(height:screenHeight * 0.025),
                              Text(
                                "Pills",
                                style: Theme.of(context).textTheme.titleSmall!.copyWith(
                                  color: Color(0xFFA1A8B0),
                                  fontSize: screenWidth * 0.032,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: screenWidth * 0.04),
                        Expanded(
                          child: Column(
                            children: [
                              OverlayButton(
                                assetName: "chatbot",
                                onTap: () => Navigator.pushNamed(context, ChatBot.routeName),
                              ),
                              SizedBox(height:screenHeight * 0.025),
                              Text(
                                "Chatbot",
                                style: Theme.of(context).textTheme.titleSmall!.copyWith(
                                  color: Color(0xFFA1A8B0),
                                  fontSize: screenWidth * 0.032,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: screenHeight * 0.05),
                // Pill Reminder Title
                Text(
                  "Pill Reminder",
                  style: Theme.of(context).textTheme.titleMedium!.copyWith(
                    color: Colors.black,
                    fontSize: screenWidth * 0.045,
                  ),
                ),
                SizedBox(height: screenHeight * 0.03),
                Row(
                  children: [
                    Expanded(child: SvgPicture.asset("assets/svg/pillreminder.svg")),
                  ],
                ),
                SizedBox(height: screenHeight * 0.02,),
                Row(
                  children: [
                    Expanded(child: SvgPicture.asset("assets/svg/pillreminder2.svg")),
                  ],
                ),

              ],
            ),
          ),
        ),
      ),
    );
  }
}
