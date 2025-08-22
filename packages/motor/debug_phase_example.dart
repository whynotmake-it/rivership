import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:motor/motor.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: DebugPhasePage(),
    );
  }
}

class DebugPhasePage extends StatefulWidget {
  @override
  State<DebugPhasePage> createState() => _DebugPhasePageState();
}

class _DebugPhasePageState extends State<DebugPhasePage> {
  int tapCount = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Debug Phase Auto-Loop')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            // Test 1: SinglePhaseMotionBuilder with trigger (like first example)
            Text('Test 1: SinglePhaseMotionBuilder WITH trigger', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            GestureDetector(
              onTap: () => setState(() => tapCount++),
              child: SinglePhaseMotionBuilder<double>(
                phases: [0.5, 0.6, 0.7, 0.8, 1.0],
                motion: const LinearMotion(duration: Duration(milliseconds: 500)),
                autoLoop: true,
                trigger: tapCount, // This might be causing the issue!
                onPhaseChanged: (phase) => print('Phase 1 changed to: $phase'),
                builder: (context, scale, phase, child) {
                  return Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Transform.scale(
                      scale: scale,
                      child: Center(
                        child: Text(
                          'Tap\n${scale.toStringAsFixed(2)}',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: 24),
            
            // Test 2: SinglePhaseMotionBuilder WITHOUT trigger
            Text('Test 2: SinglePhaseMotionBuilder WITHOUT trigger', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            SinglePhaseMotionBuilder<double>(
              phases: [0.5, 0.6, 0.7, 0.8, 1.0],
              motion: const LinearMotion(duration: Duration(milliseconds: 500)),
              autoLoop: true,
              // NO trigger here!
              onPhaseChanged: (phase) => print('Phase 2 changed to: $phase'),
              builder: (context, scale, phase, child) {
                return Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Transform.scale(
                    scale: scale,
                    child: Center(
                      child: Text(
                        'Auto\n${scale.toStringAsFixed(2)}',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                );
              },
            ),
            SizedBox(height: 24),
            
            // Test 3: ValuePhaseSequence WITHOUT trigger (like second example)  
            Text('Test 3: ValuePhaseSequence WITHOUT trigger', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            PhaseMotionBuilder<double, double>(
              sequence: ValuePhaseSequence<double>(
                values: [0.2, 1.0, 0.2, 1.0, 0.2],
                autoLoop: true,
              ),
              converter: const SingleMotionConverter(),
              motion: const LinearMotion(duration: Duration(milliseconds: 400)),
              onPhaseChanged: (phase) => print('Phase 3 changed to: $phase'),
              builder: (context, opacity, phase, child) {
                return Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(opacity),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      'Pulse\n${opacity.toStringAsFixed(2)}',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}