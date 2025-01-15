import 'package:flutter/material.dart';

class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        body: Padding(
          padding: const EdgeInsets.only(top: 100),
          child: Column(
            children: [
              Center(
                child: Text(
                  "Welcome Mrs Noha.",
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge!
                      .copyWith(color: Colors.white),
                ),
              ),
              SizedBox(height: 24),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(30),
                          topRight: Radius.circular(30))),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Services",
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        SizedBox(
                          height: 8,
                        ),
                        Text(
                          "Recommendations for you",
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        SizedBox(height: 24),
                        Row(
                          children: [
                            Stack(
                              children: [
                                Stack(
                                  alignment: Alignment.bottomCenter,
                                  children: [
                                    Image.asset(
                                        "assets/images/overlay_orange.png"),
                                    Padding(
                                      padding: const EdgeInsets.only(
                                          bottom: 20, right: 40),
                                      child: Text(
                                        "Live Location",
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall!
                                            .copyWith(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                    )
                                  ],
                                ),
                                Padding(
                                  padding:
                                      const EdgeInsets.only(top: 16, left: 16),
                                  child: Stack(
                                    children: [
                                      Icon(
                                        Icons.pin_drop_outlined,
                                        color: Colors.white,
                                        size: 40,
                                      )
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(width: 8),
                            Stack(
                              children: [
                                Stack(
                                  alignment: Alignment.bottomCenter,
                                  children: [
                                    Image.asset(
                                        "assets/images/overlay_purple.png"),
                                    Padding(
                                      padding: const EdgeInsets.only(
                                          bottom: 20, right: 60),
                                      child: Text(
                                        "Calendar",
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall!
                                            .copyWith(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                    )
                                  ],
                                ),
                                Padding(
                                  padding:
                                      const EdgeInsets.only(top: 16, left: 16),
                                  child: Stack(
                                    children: [
                                      Icon(
                                        Icons.calendar_today_outlined,
                                        color: Colors.white,
                                        size: 40,
                                      )
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        SizedBox(
                          height: 60,
                        ),
                        Text("Today’s Schedule",
                            style: Theme.of(context).textTheme.titleLarge),
                        SizedBox(
                          height: 24,
                        ),
                        Stack(
                          children: [
                            Stack(
                              alignment: Alignment.topLeft,
                              children: [
                                Image.asset("assets/images/overlay_green.png"),
                                Padding(
                                  padding: const EdgeInsets.only(top: 20,left: 20),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Today’s Pills",
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall!
                                            .copyWith(color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16)
                                      ),
                                      SizedBox(height: 16),
                                      Text(
                                        "10:00 Am: Paracetamol (1 Pill)",
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall!
                                            .copyWith(color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12)
                                      ),
                                      Text(
                                        "10:00 Am: Paracetamol (1 Pill)",
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall!
                                            .copyWith(color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12)
                                      ),
                                      Text(
                                        "10:00 Am: Paracetamol (1 Pill)",
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall!
                                            .copyWith(color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12)
                                      ),
                                    ],
                                  ),
                                )
                              ],
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
