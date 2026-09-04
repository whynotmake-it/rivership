import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:heroine/heroine.dart';

/// Standalone test for OverHeroine clipping during hero flights.
///
/// Two pages, each with a fixed top bar (OverHeroine, keepDir=bottom) and a
/// Heroine card. When pushing to the next page the flying hero should be
/// clipped so it never appears to "pop out" from behind the top bar.
void main() {
  runApp(
    CupertinoApp(
      theme: const CupertinoThemeData(brightness: Brightness.light),
      home: const HomePage(),
      navigatorObservers: [HeroineController()],
    ),
  );
}

// ---------------------------------------------------------------------------
// Home Page
// ---------------------------------------------------------------------------

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return OverHeroineScope(
      child: CupertinoPageScaffold(
        child: Column(
          children: [
            // ---- Fixed top bar (occludes from above) ----
            OverHeroine(
              keepDir: KeepDir.bottom,
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 8,
                  bottom: 12,
                ),
                decoration: const BoxDecoration(
                  color: CupertinoColors.systemBackground,
                  border: Border(
                    bottom: BorderSide(
                      color: CupertinoColors.systemGrey4,
                      width: 0.5,
                    ),
                  ),
                ),
                child: const Row(
                  children: [
                    SizedBox(width: 16),
                    Text(
                      'Home',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ---- Scrollable content ----
            Expanded(
              child: Stack(children: [
                ListView.builder(
                  padding: const EdgeInsets.all(24),
                  itemCount: 20,
                  itemBuilder: (context, index) {
                    // Put the Heroine at index 5 so it's initially below the
                    // fold and the user can scroll it behind the top bar.
                    if (index == 5) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              CupertinoPageRoute(
                                builder: (_) => const DetailPage(),
                              ),
                            );
                          },
                          child: Heroine(
                            tag: 'card',
                            flightShuttleBuilder: const ClippingShuttleBuilder(
                              inner: FadeShuttleBuilder(),
                            ),
                            continuouslyTrackTarget: true,
                            child: Container(
                              width: double.infinity,
                              height: 200,
                              decoration: BoxDecoration(
                                color: CupertinoColors.systemBlue
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: CupertinoColors.systemBlue
                                      .withValues(alpha: 0.4),
                                  width: 1.5,
                                ),
                              ),
                              child: const Center(
                                child: Text(
                                  'Tap me',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                    color: CupertinoColors.systemBlue,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Container(
                        height: 80,
                        decoration: BoxDecoration(
                          color: CupertinoColors.systemGrey6,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            'Item #$index',
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                Positioned.fill(
                    child: Align(
                  alignment: Alignment.bottomCenter,
                  child: OverHeroine(
                      keepDir: KeepDir.right,
                      child: Container(
                        height: 200,
                        width: 100,
                        color: CupertinoColors.systemGrey6.withOpacity(0.5),
                      )),
                )),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Detail Page
// ---------------------------------------------------------------------------

class DetailPage extends StatelessWidget {
  const DetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    return OverHeroineScope(
      child: CupertinoPageScaffold(
        child: Column(
          children: [
            // ---- Fixed top bar (same occlusion) ----
            OverHeroine(
              keepDir: KeepDir.bottom,
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 8,
                  bottom: 12,
                ),
                decoration: const BoxDecoration(
                  color: CupertinoColors.systemBackground,
                  border: Border(
                    bottom: BorderSide(
                      color: CupertinoColors.systemGrey4,
                      width: 0.5,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 16),
                    GestureDetector(
                      onTap: () => Navigator.maybeOf(context)?.pop(),
                      child: const Icon(
                        CupertinoIcons.back,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Detail',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ---- Scrollable content ----
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(24),
                itemCount: 12,
                itemBuilder: (context, index) {
                  if (index == 3) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Heroine(
                        tag: 'card',
                        flightShuttleBuilder: const ClippingShuttleBuilder(
                          inner: FadeShuttleBuilder(),
                        ),
                        continuouslyTrackTarget: true,
                        child: Container(
                          width: double.infinity,
                          height: 300,
                          decoration: BoxDecoration(
                            color: CupertinoColors.systemBlue
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: CupertinoColors.systemBlue
                                  .withValues(alpha: 0.4),
                              width: 1.5,
                            ),
                          ),
                          child: const Center(
                            child: Text(
                              'Detail Page',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: CupertinoColors.systemBlue,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Container(
                      height: 80,
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemGrey6,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          'Detail item #$index',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
