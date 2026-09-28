import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';

// SwiftUI's `Spring.value(target: 1, initialVelocity: v, time: t)`, sampled
// on macOS 26 with Xcode 26.
const _times = [0.05, 0.1, 0.2, 0.3, 0.5, 1.0, 2.0];
const _swiftUI = <String, List<(double, List<double>)>>{
  'Spring()': [
    (
      0.0,
      [
        0.131311455,
        0.357739556,
        0.715415689,
        0.890033939,
        0.986399069,
        0.999952689,
        1.000000000,
      ]
    ),
    (
      5.0,
      [
        0.264683478,
        0.500044328,
        0.796418281,
        0.924615105,
        0.991067675,
        0.999970126,
        1.000000000,
      ]
    ),
    (
      -3.0,
      [
        0.051288242,
        0.272356693,
        0.666814134,
        0.869285240,
        0.983597904,
        0.999942227,
        1.000000000,
      ]
    ),
  ],
  'smooth': [
    (
      0.0,
      [
        0.131311455,
        0.357739556,
        0.715415689,
        0.890033939,
        0.986399069,
        0.999952689,
        1.000000000,
      ]
    ),
    (
      5.0,
      [
        0.264683478,
        0.500044328,
        0.796418281,
        0.924615105,
        0.991067675,
        0.999970126,
        1.000000000,
      ]
    ),
    (
      -3.0,
      [
        0.051288242,
        0.272356693,
        0.666814134,
        0.869285240,
        0.983597904,
        0.999942227,
        1.000000000,
      ]
    ),
  ],
  'snappy': [
    (
      0.0,
      [
        0.138210353,
        0.388102446,
        0.786369170,
        0.956446594,
        1.006019961,
        0.999966082,
        0.999999999,
      ]
    ),
    (
      5.0,
      [
        0.282102531,
        0.547648721,
        0.872862894,
        0.984495546,
        1.005413684,
        0.999971811,
        0.999999999,
      ]
    ),
    (
      -3.0,
      [
        0.051875046,
        0.292374681,
        0.734472936,
        0.939617222,
        1.006383727,
        0.999962644,
        0.999999999,
      ]
    ),
  ],
  'bouncy': [
    (
      0.0,
      [
        0.145715014,
        0.423302123,
        0.873710896,
        1.033930362,
        1.014498422,
        1.000071597,
        1.000000003,
      ]
    ),
    (
      5.0,
      [
        0.301402882,
        0.604019800,
        0.967236896,
        1.051218877,
        1.007819113,
        1.000108301,
        0.999999993,
      ]
    ),
    (
      -3.0,
      [
        0.052302293,
        0.314871517,
        0.817595295,
        1.023557253,
        1.018506007,
        1.000049575,
        1.000000009,
      ]
    ),
  ],
  'interactive(0.15,0.15)': [
    (
      0.0,
      [
        0.681165993,
        0.979974982,
        1.001484021,
        0.999966082,
        1.000000029,
        1.000000000,
        1.000000000,
      ]
    ),
    (
      5.0,
      [
        0.715270092,
        0.985157485,
        1.001309067,
        0.999967801,
        1.000000025,
        1.000000000,
        1.000000000,
      ]
    ),
    (
      -3.0,
      [
        0.660703534,
        0.976865480,
        1.001588993,
        0.999965051,
        1.000000032,
        1.000000000,
        1.000000000,
      ]
    ),
  ],
  'smooth(extraBounce:0.2)': [
    (
      0.0,
      [
        0.140641428,
        0.399251268,
        0.813403338,
        0.980893462,
        1.010450575,
        0.999932103,
        1.000000000,
      ]
    ),
    (
      5.0,
      [
        0.288315231,
        0.565367394,
        0.902027103,
        1.005930773,
        1.007893017,
        0.999959255,
        1.000000001,
      ]
    ),
    (
      -3.0,
      [
        0.052037147,
        0.299581592,
        0.760229079,
        0.965871075,
        1.011985109,
        0.999915811,
        1.000000000,
      ]
    ),
  ],
  'snappy(extraBounce:0.1)': [
    (
      0.0,
      [
        0.143142149,
        0.410971610,
        0.842441248,
        1.006675887,
        1.013394131,
        0.999953595,
        1.000000010,
      ]
    ),
    (
      5.0,
      [
        0.294745580,
        0.584130658,
        0.933395211,
        1.028158854,
        1.008805502,
        0.999997139,
        1.000000007,
      ]
    ),
    (
      -3.0,
      [
        0.052180091,
        0.307076181,
        0.787868871,
        0.993786106,
        1.016147308,
        0.999927469,
        1.000000012,
      ]
    ),
  ],
  'bouncy(extraBounce:0.2)': [
    (
      0.0,
      [
        0.156781542,
        0.479612147,
        1.026971950,
        1.161460828,
        0.989822129,
        1.001281480,
        1.000002949,
      ]
    ),
    (
      5.0,
      [
        0.330503698,
        0.696734531,
        1.134466558,
        1.152884978,
        0.975014149,
        1.000428951,
        1.000003307,
      ]
    ),
    (
      -3.0,
      [
        0.052548248,
        0.349338717,
        0.962475186,
        1.166606339,
        0.998706917,
        1.001792997,
        1.000002734,
      ]
    ),
  ],
  'bouncy(extraBounce:-0.5)': [
    (
      0.0,
      [
        0.120999593,
        0.315683409,
        0.622707749,
        0.797729428,
        0.942382605,
        0.997510076,
        0.999995350,
      ]
    ),
    (
      5.0,
      [
        0.239249898,
        0.435708916,
        0.696462304,
        0.837864143,
        0.953844528,
        0.998005431,
        0.999996275,
      ]
    ),
    (
      -3.0,
      [
        0.050049410,
        0.243668105,
        0.578455016,
        0.773648599,
        0.935505451,
        0.997212864,
        0.999994795,
      ]
    ),
  ],
  'smooth(extraBounce:-0.3)': [
    (
      0.0,
      [
        0.114430257,
        0.290825711,
        0.570395351,
        0.742605813,
        0.907764486,
        0.992911329,
        0.999958131,
      ]
    ),
    (
      5.0,
      [
        0.223439398,
        0.398566910,
        0.639854204,
        0.784412399,
        0.922751267,
        0.994063126,
        0.999964934,
      ]
    ),
    (
      -3.0,
      [
        0.049024772,
        0.226180992,
        0.528720039,
        0.717521861,
        0.898772418,
        0.992220251,
        0.999954049,
      ]
    ),
  ],
};
const _swiftUIStiffnessDamping = <String, (double, double)>{
  'Spring()': (157.91367, 25.132741),
  'smooth': (157.91367, 25.132741),
  'snappy': (157.91367, 21.36283),
  'bouncy': (157.91367, 17.592919),
  'interactive(0.15,0.15)': (1754.596338, 71.209433),
  'smooth(extraBounce:0.2)': (157.91367, 20.106193),
  'snappy(extraBounce:0.1)': (157.91367, 18.849556),
  'bouncy(extraBounce:0.2)': (157.91367, 12.566371),
  'bouncy(extraBounce:-0.5)': (335.56655, 31.415927),
  'smooth(extraBounce:-0.3)': (486.631923, 35.903916),
};

/// Motor's counterparts of each SwiftUI spring.
final _motor = <String, List<CupertinoMotion>>{
  'Spring()': [
    const CupertinoMotion(),
    const Motion.cupertino() as CupertinoMotion,
  ],
  'smooth': [
    const CupertinoMotion.smooth(),
    const Motion.smoothSpring() as CupertinoMotion,
  ],
  'snappy': [
    const CupertinoMotion.snappy(),
    const Motion.snappySpring() as CupertinoMotion,
  ],
  'bouncy': [
    const CupertinoMotion.bouncy(),
    const Motion.bouncySpring() as CupertinoMotion,
  ],
  'interactive(0.15,0.15)': [
    const CupertinoMotion.interactive(),
    const Motion.interactiveSpring() as CupertinoMotion,
  ],
  'smooth(extraBounce:0.2)': [const CupertinoMotion.smooth(extraBounce: 0.2)],
  'snappy(extraBounce:0.1)': [const CupertinoMotion.snappy(extraBounce: 0.1)],
  'bouncy(extraBounce:0.2)': [
    const CupertinoMotion.bouncy(extraBounce: 0.2),
    const Motion.bouncySpring(extraBounce: 0.2) as CupertinoMotion,
  ],
  'bouncy(extraBounce:-0.5)': [const CupertinoMotion.bouncy(extraBounce: -0.5)],
  'smooth(extraBounce:-0.3)': [const CupertinoMotion.smooth(extraBounce: -0.3)],
};

void main() {
  group('Cupertino presets match SwiftUI', () {
    for (final MapEntry(key: name, value: motions) in _motor.entries) {
      test(name, () {
        final (stiffness, damping) = _swiftUIStiffnessDamping[name]!;
        for (final motion in motions) {
          final description = motion.description;
          expect(description.mass, 1);
          expect(description.damping, closeTo(damping, 1e-5));
          // SwiftUI reports a stiffness its own curve doesn't use for
          // negative bounce; the curves below still match.
          if (motion.bounce >= 0) {
            expect(description.stiffness, closeTo(stiffness, 1e-5));
          }
          final raw = SpringMotion(description, snapToEnd: false);
          for (final (velocity, values) in _swiftUI[name]!) {
            final simulation = raw.createSimulation(velocity: velocity);
            for (var i = 0; i < _times.length; i++) {
              expect(
                simulation.x(_times[i]),
                closeTo(values[i], 1e-8),
                reason: '$motion at ${_times[i]} s, velocity $velocity',
              );
            }
          }
        }
      });
    }

    test('the default and interactive springs', () {
      const duration = Duration(milliseconds: 500);
      expect(const CupertinoMotion().duration, duration);
      expect(const CupertinoMotion(), const CupertinoMotion.smooth());
      expect(const CupertinoMotion.interactive().bounce, closeTo(0.15, 1e-12));
    });
  });

  group('bounce', () {
    test('1 is undamped', () {
      final description = const CupertinoMotion(bounce: 1).description;
      expect(description.damping, 0);
      expect(const CupertinoMotion(bounce: 1).settlingDuration(), isNull);
    });

    test('above 1 asserts', () {
      expect(
        () => const CupertinoMotion.bouncy(extraBounce: 0.8).description,
        throwsAssertionError,
      );
    });
  });
}
