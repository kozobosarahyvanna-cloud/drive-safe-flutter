import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:vibration/vibration.dart';

// ═══════════════════════════════════════════════════════════════
//  WEEK 1 — data class, null safety, fun, List<T>, when
// ═══════════════════════════════════════════════════════════════
class DrivingEvent {
  final String type;
  final double intensity;
  final DateTime time;
  final String description;

  const DrivingEvent({
    required this.type,
    required this.intensity,
    required this.time,
    required this.description,
  });

  @override
  String toString() => 'DrivingEvent(type: $type, intensity: $intensity)';

  DrivingEvent copyWith({String? type, double? intensity}) {
    return DrivingEvent(
      type:        type        ?? this.type,
      intensity:   intensity   ?? this.intensity,
      time:        time,
      description: description,
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  WEEK 2 — abstract class, interface, inheritance, sealed class
// ═══════════════════════════════════════════════════════════════
abstract class Scorable {
  double computeScore();
  String getRating();
}

abstract class Reportable {
  String generateReport();
}

abstract class DriveAnalyzer implements Scorable {
  final List<DrivingEvent> events;
  DriveAnalyzer(this.events);

  int countByType(String type) =>
      events.where((e) => e.type == type).length;

  double get avgIntensity => events.isEmpty
      ? 0.0
      : events.map((e) => e.intensity).reduce((a, b) => a + b) / events.length;
}

class SafetyAnalyzer extends DriveAnalyzer implements Reportable {
  SafetyAnalyzer(super.events);

  @override
  double computeScore() {
    if (events.isEmpty) return 100.0;
    final penalty = (countByType('BRAKE') * 5) +
        (countByType('ACCEL') * 4) +
        (countByType('TURN') * 3) +
        (countByType('SKID') * 8);
    return (100 - penalty).clamp(0, 100).toDouble();
  }

  @override
  String getRating() {
    final s = computeScore();
    if (s >= 90) return 'EXPERT DRIVER';
    if (s >= 75) return 'SAFE DRIVER';
    if (s >= 60) return 'AVERAGE';
    if (s >= 40) return 'RISKY';
    return 'DANGEROUS';
  }

  @override
  String generateReport() {
    return 'Hard Brakes: ${countByType('BRAKE')}\n'
        'Hard Accels: ${countByType('ACCEL')}\n'
        'Sharp Turns: ${countByType('TURN')}\n'
        'Skids: ${countByType('SKID')}\n'
        'Score: ${computeScore().toStringAsFixed(0)}/100\n'
        'Rating: ${getRating()}';
  }
}

// ═══════════════════════════════════════════════════════════════
//  WEEK 3 — Generics
// ═══════════════════════════════════════════════════════════════
class Box<T> {
  T? _value;
  void set(T val) => _value = val;
  T? get() => _value;
}

double? maxOf(List<double> list) {
  if (list.isEmpty) return null;
  return list.reduce((a, b) => a > b ? a : b);
}

// Sealed class
sealed class DriveState {}
class DriveIdle    extends DriveState {}
class DriveActive  extends DriveState {
  final DateTime startTime;
  DriveActive(this.startTime);
}
class DriveFinished extends DriveState {
  final List<DrivingEvent> events;
  final double score;
  DriveFinished(this.events, this.score);
}

// ═══════════════════════════════════════════════════════════════
//  THEME
// ═══════════════════════════════════════════════════════════════
const kBg       = Color(0xFF080810);
const kSurface  = Color(0xFF0F0F1C);
const kCard     = Color(0xFF13131F);
const kRed      = Color(0xFFE8001C);
const kRedGlow  = Color(0xFFFF1E3A);
const kAmber    = Color(0xFFFFB300);
const kGreen    = Color(0xFF00E676);
const kText     = Color(0xFFEEEEF5);
const kTextMid  = Color(0xFF8888AA);
const kTextDim  = Color(0xFF3A3A55);
const kBorder   = Color(0xFF1E1E30);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MobileAds.instance.initialize();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const DriveSafeApp());
}

class DriveSafeApp extends StatelessWidget {
  const DriveSafeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DriveSafe',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: kBg,
        colorScheme: const ColorScheme.dark(
          primary: kRed,
          secondary: kAmber,
          surface: kSurface,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  HOME SCREEN
// ═══════════════════════════════════════════════════════════════
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin {

  DriveState _driveState = DriveIdle();

  final Box<double> _accelBox = Box();
  final Box<double> _gyroBox  = Box();

  StreamSubscription<AccelerometerEvent>? _accelSub;
  StreamSubscription<GyroscopeEvent>?     _gyroSub;

  final List<DrivingEvent> _events     = [];
  final List<FlSpot>       _accelSpots = [];
  final List<FlSpot>       _gyroSpots  = [];

  int    _dataPoints     = 0;
  double _accelMag       = 0.0;
  double _gyroMag        = 0.0;
  int    _elapsedSeconds = 0;
  Timer? _timer;

  late AnimationController _pulseCtrl;
  late AnimationController _fadeCtrl;
  late Animation<double>   _pulseAnim;
  late Animation<double>   _fadeAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _pulseAnim = Tween<double>(begin: 0.97, end: 1.03)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut));
  }

  String? _detectEvent(double accel, double gyro) {
    if (accel > 15) return 'BRAKE';
    if (accel > 12) return 'ACCEL';
    if (gyro  >  3.0) return 'SKID';
    if (gyro  >  2.0) return 'TURN';
    return null;
  }

  String _eventLabel(String type) {
    switch (type) {
      case 'BRAKE': return 'Hard Brake';
      case 'ACCEL': return 'Hard Acceleration';
      case 'SKID':  return 'Skid Detected';
      case 'TURN':  return 'Sharp Turn';
      default:      return 'Event';
    }
  }

  Color _eventColor(String type) {
    switch (type) {
      case 'BRAKE': return kRed;
      case 'ACCEL': return kAmber;
      case 'SKID':  return const Color(0xFFFF0055);
      case 'TURN':  return const Color(0xFF00B8FF);
      default:      return kTextMid;
    }
  }

  IconData _eventIcon(String type) {
    switch (type) {
      case 'BRAKE': return Icons.warning_rounded;
      case 'ACCEL': return Icons.speed;
      case 'SKID':  return Icons.rotate_right;
      case 'TURN':  return Icons.turn_right;
      default:      return Icons.circle;
    }
  }

  void _startDrive() {
    setState(() {
      _driveState = DriveActive(DateTime.now());
      _events.clear();
      _accelSpots.clear();
      _gyroSpots.clear();
      _dataPoints    = 0;
      _elapsedSeconds = 0;
    });

    _accelSub = accelerometerEventStream().listen((event) {
      final mag = (sqrt(event.x * event.x +
              event.y * event.y +
              event.z * event.z) - 9.8).abs();
      setState(() {
        _accelMag = mag.clamp(0, 30);
        _accelBox.set(_accelMag);
        _accelSpots.add(FlSpot(_dataPoints.toDouble(), _accelMag));
        if (_accelSpots.length > 60) _accelSpots.removeAt(0);
      });
      final type = _detectEvent(mag, _gyroMag);
      if (type == 'BRAKE' || type == 'ACCEL') _addEvent(type!, mag);
    });

    _gyroSub = gyroscopeEventStream().listen((event) {
      final mag = sqrt(event.x * event.x +
          event.y * event.y +
          event.z * event.z);
      setState(() {
        _gyroMag = mag.clamp(0, 10);
        _gyroBox.set(_gyroMag);
        _dataPoints++;
        _gyroSpots.add(FlSpot(_dataPoints.toDouble(), _gyroMag));
        if (_gyroSpots.length > 60) _gyroSpots.removeAt(0);
      });
      final type = _detectEvent(_accelMag, mag);
      if (type == 'SKID' || type == 'TURN') _addEvent(type!, mag);
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _elapsedSeconds++);
    });
  }

  void _addEvent(String type, double intensity) {
    final last = _events.isEmpty ? null : _events.last;
    if (last == null ||
        DateTime.now().difference(last.time).inSeconds > 2) {
      setState(() {
        _events.add(DrivingEvent(
          type:        type,
          intensity:   intensity,
          time:        DateTime.now(),
          description: _eventLabel(type),
        ));
      });
      // Vibration selon gravité (Week 3 — scope functions)
      switch (type) {
        case 'SKID':
          Vibration.vibrate(pattern: [0, 200, 100, 200, 100, 200]);
        case 'BRAKE':
          Vibration.vibrate(pattern: [0, 400, 100, 400]);
        case 'ACCEL':
          Vibration.vibrate(duration: 300);
        case 'TURN':
          Vibration.vibrate(duration: 150);
      }
    }
  }


  void _stopDrive() {
    _accelSub?.cancel();
    _gyroSub?.cancel();
    _timer?.cancel();

    final analyzer = SafetyAnalyzer(_events);
    final score    = analyzer.computeScore();

    setState(() => _driveState = DriveFinished(List.from(_events), score));

    Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (_, a, b) => ResultScreen(
          events:  List.from(_events),
          score:   score,
          elapsed: _elapsedSeconds,
        ),
        transitionsBuilder: (_, a, b, child) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end:   Offset.zero,
          ).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
          child: child,
        ),
      ),
    );
  }

  String _formatTime(int s) {
    final m   = (s ~/ 60).toString().padLeft(2, '0');
    final sec = (s % 60).toString().padLeft(2, '0');
    return '$m:$sec';
  }

  Color get _scoreColor {
    final score = SafetyAnalyzer(_events).computeScore();
    if (score >= 80) return kGreen;
    if (score >= 60) return kAmber;
    return kRed;
  }

  @override
  void dispose() {
    _accelSub?.cancel();
    _gyroSub?.cancel();
    _timer?.cancel();
    _pulseCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isActive = _driveState is DriveActive;
    final score    = SafetyAnalyzer(_events).computeScore();

    return Scaffold(
      backgroundColor: kBg,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SafeArea(
          child: Column(
            children: [

              // ── TOP BAR ──────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('DRIVESAFE',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: kText,
                              letterSpacing: 4,
                            )),
                        const Text('DRIVE ANALYSIS SYSTEM',
                            style: TextStyle(
                              fontSize: 10,
                              color: kTextMid,
                              letterSpacing: 2,
                            )),
                      ],
                    ),
                    if (isActive)
                      _LiveBadge(time: _formatTime(_elapsedSeconds)),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── MAIN CONTENT ─────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [

                      // ── SCORE RING ──────────────────────
                      _ScoreRing(
                        score:  score,
                        color:  _scoreColor,
                        rating: SafetyAnalyzer(_events).getRating(),
                        isActive: isActive,
                      ),

                      const SizedBox(height: 20),

                      // ── SENSORS ─────────────────────────
                      Row(children: [
                        Expanded(child: _SensorTile(
                          label:    'ACCELEROMETER',
                          value:    _accelMag.toStringAsFixed(1),
                          unit:     'm/s²',
                          progress: _accelMag / 30,
                          color:    kRed,
                        )),
                        const SizedBox(width: 12),
                        Expanded(child: _SensorTile(
                          label:    'GYROSCOPE',
                          value:    _gyroMag.toStringAsFixed(2),
                          unit:     'rad/s',
                          progress: _gyroMag / 10,
                          color:    const Color(0xFF00B8FF),
                        )),
                      ]),

                      const SizedBox(height: 16),

                      // ── CHARTS ──────────────────────────
                      if (isActive && _accelSpots.length > 3) ...[
                        _ChartCard(
                          label:  'ACCELERATION',
                          spots:  _accelSpots,
                          color:  kRed,
                          maxY:   30,
                        ),
                        const SizedBox(height: 12),
                        _ChartCard(
                          label:  'ROTATION',
                          spots:  _gyroSpots,
                          color:  const Color(0xFF00B8FF),
                          maxY:   10,
                        ),
                        const SizedBox(height: 16),
                      ],

                      // ── EVENTS ──────────────────────────
                      if (_events.isNotEmpty) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('EVENTS',
                                style: TextStyle(
                                  color: kTextMid,
                                  fontSize: 11,
                                  letterSpacing: 2,
                                  fontWeight: FontWeight.w700,
                                )),
                            Text('${_events.length} DETECTED',
                                style: TextStyle(
                                  color: _events.length > 5
                                      ? kRed
                                      : kTextMid,
                                  fontSize: 11,
                                  letterSpacing: 1,
                                )),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ..._events.reversed.take(4).map((e) =>
                            _EventTile(
                              event:      e,
                              color:      _eventColor(e.type),
                              icon:       _eventIcon(e.type),
                              label:      _eventLabel(e.type),
                            )),
                        const SizedBox(height: 16),
                      ],

                      // ── CTA BUTTON ──────────────────────
                      ScaleTransition(
                        scale: isActive
                            ? _pulseAnim
                            : const AlwaysStoppedAnimation(1.0),
                        child: _CTAButton(
                          isActive: isActive,
                          onTap:    isActive ? _stopDrive : _startDrive,
                        ),
                      ),

                      const SizedBox(height: 20),

                      if (!isActive)
                        const Text(
                          'PLACE YOUR DEVICE ON THE DASHBOARD\nTO BEGIN MONITORING',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: kTextDim,
                            fontSize: 11,
                            letterSpacing: 1.5,
                            height: 1.8,
                          ),
                        ),

                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  COMPONENTS
// ─────────────────────────────────────────────────────────────

class _LiveBadge extends StatefulWidget {
  final String time;
  const _LiveBadge({required this.time});
  @override
  State<_LiveBadge> createState() => _LiveBadgeState();
}

class _LiveBadgeState extends State<_LiveBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: kRed.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: kRed.withOpacity(0.4)),
      ),
      child: Row(children: [
        FadeTransition(
          opacity: _anim,
          child: Container(
            width: 6, height: 6,
            decoration: const BoxDecoration(
              color: kRed, shape: BoxShape.circle),
          ),
        ),
        const SizedBox(width: 8),
        Text('LIVE  ${widget.time}',
            style: const TextStyle(
              color: kRed,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            )),
      ]),
    );
  }
}

class _ScoreRing extends StatelessWidget {
  final double score;
  final Color  color;
  final String rating;
  final bool   isActive;

  const _ScoreRing({
    required this.score,
    required this.color,
    required this.rating,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kBorder),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 40,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Column(children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 180, height: 180,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: score / 100),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOutCubic,
                builder: (_, val, __) => CircularProgressIndicator(
                  value:           val,
                  strokeWidth:     10,
                  backgroundColor: kBorder,
                  valueColor:      AlwaysStoppedAnimation<Color>(color),
                  strokeCap:       StrokeCap.round,
                ),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: score),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeOutCubic,
                  builder: (_, val, __) => Text(
                    val.toStringAsFixed(0),
                    style: TextStyle(
                      fontSize: 56,
                      fontWeight: FontWeight.w900,
                      color: color,
                      height: 1,
                    ),
                  ),
                ),
                const Text('/ 100',
                    style: TextStyle(
                      color: kTextMid,
                      fontSize: 13,
                      letterSpacing: 1,
                    )),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Text(
            rating,
            style: TextStyle(
              color:       color,
              fontSize:    13,
              fontWeight:  FontWeight.w700,
              letterSpacing: 2,
            ),
          ),
        ),
      ]),
    );
  }
}

class _SensorTile extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final double progress;
  final Color  color;

  const _SensorTile({
    required this.label,
    required this.value,
    required this.unit,
    required this.progress,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                color: kTextMid, fontSize: 9, letterSpacing: 1.5)),
          const SizedBox(height: 8),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: TextStyle(
                    color: color,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
                TextSpan(
                  text: ' $unit',
                  style: const TextStyle(
                    color: kTextMid,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress.clamp(0.0, 1.0)),
              duration: const Duration(milliseconds: 200),
              builder: (_, val, __) => LinearProgressIndicator(
                value:           val,
                backgroundColor: kBorder,
                valueColor:      AlwaysStoppedAnimation<Color>(color),
                minHeight:       3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  final String      label;
  final List<FlSpot> spots;
  final Color       color;
  final double      maxY;

  const _ChartCard({
    required this.label,
    required this.spots,
    required this.color,
    required this.maxY,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                color: kTextMid, fontSize: 10, letterSpacing: 2)),
          const SizedBox(height: 12),
          SizedBox(
            height: 100,
            child: LineChart(LineChartData(
              minY: 0,
              maxY: maxY,
              backgroundColor: Colors.transparent,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (_) =>
                    FlLine(color: kBorder, strokeWidth: 1),
              ),
              titlesData: const FlTitlesData(show: false),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots:    spots,
                  isCurved: true,
                  curveSmoothness: 0.3,
                  color:    color,
                  barWidth: 2,
                  dotData:  const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show:  true,
                    color: color.withOpacity(0.08),
                  ),
                ),
              ],
            )),
          ),
        ],
      ),
    );
  }
}

class _EventTile extends StatelessWidget {
  final DrivingEvent event;
  final Color        color;
  final IconData     icon;
  final String       label;

  const _EventTile({
    required this.event,
    required this.color,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  )),
              Text('Intensity: ${event.intensity.toStringAsFixed(1)}',
                  style: const TextStyle(
                    color: kTextMid, fontSize: 11)),
            ],
          ),
        ),
        Container(
          width: 4, height: 36,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ]),
    );
  }
}

class _CTAButton extends StatelessWidget {
  final bool     isActive;
  final VoidCallback onTap;

  const _CTAButton({required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color:        isActive ? const Color(0xFF1A0005) : kRed,
          borderRadius: BorderRadius.circular(16),
          border:       Border.all(
            color: isActive ? kRed.withOpacity(0.5) : kRed,
          ),
          boxShadow: [
            BoxShadow(
              color:       kRed.withOpacity(isActive ? 0.15 : 0.35),
              blurRadius:  24,
              spreadRadius: 0,
              offset:      const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Text(
            isActive ? 'STOP ANALYSIS' : 'START ANALYSIS',
            style: TextStyle(
              color:       isActive ? kRed : Colors.white,
              fontSize:    15,
              fontWeight:  FontWeight.w800,
              letterSpacing: 3,
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  RESULT SCREEN
// ═══════════════════════════════════════════════════════════════
class ResultScreen extends StatefulWidget {
  final List<DrivingEvent> events;
  final double score;
  final int    elapsed;

  const ResultScreen({
    super.key,
    required this.events,
    required this.score,
    required this.elapsed,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen>
    with SingleTickerProviderStateMixin {
  bool _reportUnlocked = false;
  late AnimationController _animCtrl;
  late Animation<double>   _scoreAnim;
  RewardedAd? _rewardedAd;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _scoreAnim = Tween<double>(begin: 0, end: widget.score).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _animCtrl.forward();
    _loadAd();
  }

  void _loadAd() {
    RewardedAd.load(
      adUnitId: 'ca-app-pub-3940256099942544/5354046379',
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          setState(() => _rewardedAd = ad);
        },
        onAdFailedToLoad: (error) {
          debugPrint('RewardedAd failed: $error');
        },
      ),
    );
  }
  

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Color get _scoreColor {
    if (widget.score >= 80) return kGreen;
    if (widget.score >= 60) return kAmber;
    return kRed;
  }

 void _watchAd() {
    if (_rewardedAd != null) {
      _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _loadAd();
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          ad.dispose();
          _loadAd();
        },
      );
      _rewardedAd!.show(
        onUserEarnedReward: (_, reward) {
          setState(() => _reportUnlocked = true);
        },
      );
      _rewardedAd = null;
    } else {
      // Ad pas encore chargée — simulation
      showDialog(
        context: context,
        builder: (_) => Dialog(
          backgroundColor: kCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: kBorder),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('AD LOADING...',
                    style: TextStyle(
                      color: kTextMid, fontSize: 10, letterSpacing: 3)),
                const SizedBox(height: 16),
                const CircularProgressIndicator(color: kRed),
                const SizedBox(height: 16),
                const Text('Please wait for the ad to load.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: kTextMid, fontSize: 13)),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => _reportUnlocked = true);
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: kRed,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text('SKIP',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2,
                        )),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }


  String _formatTime(int s) {
    final m   = (s ~/ 60).toString().padLeft(2, '0');
    final sec = (s % 60).toString().padLeft(2, '0');
    return '$m:$sec';
  }

  @override
  Widget build(BuildContext context) {
    final analyzer     = SafetyAnalyzer(widget.events);
    final maxIntensity = maxOf(widget.events.map((e) => e.intensity).toList()) ?? 0.0;

    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: kText, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('TRIP REPORT',
            style: TextStyle(
              color: kText,
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: 3,
            )),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [

            // ── SCORE ──────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: kCard,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: kBorder),
                boxShadow: [
                  BoxShadow(
                    color:       _scoreColor.withOpacity(0.1),
                    blurRadius:  40,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Column(children: [
                AnimatedBuilder(
                  animation: _scoreAnim,
                  builder: (_, __) => Text(
                    _scoreAnim.value.toStringAsFixed(0),
                    style: TextStyle(
                      fontSize:   80,
                      fontWeight: FontWeight.w900,
                      color:      _scoreColor,
                      height:     1,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                const Text('SAFETY SCORE',
                    style: TextStyle(
                      color: kTextMid, fontSize: 11, letterSpacing: 3)),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 8),
                  decoration: BoxDecoration(
                    color: _scoreColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: _scoreColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    analyzer.getRating(),
                    style: TextStyle(
                      color:       _scoreColor,
                      fontSize:    13,
                      fontWeight:  FontWeight.w800,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _StatItem(label: 'DURATION',
                        value: _formatTime(widget.elapsed)),
                    _Divider(),
                    _StatItem(label: 'EVENTS',
                        value: '${widget.events.length}'),
                    _Divider(),
                    _StatItem(label: 'MAX G',
                        value: maxIntensity.toStringAsFixed(1)),
                  ],
                ),
              ]),
            ),

            const SizedBox(height: 16),

            // ── EVENT BREAKDOWN ────────────────────────────
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: kCard,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: kBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('EVENT BREAKDOWN',
                      style: TextStyle(
                        color: kTextMid, fontSize: 10, letterSpacing: 2)),
                  const SizedBox(height: 16),
                  _BreakdownRow('Hard Brakes',
                      analyzer.countByType('BRAKE'), kRed),
                  _BreakdownRow('Hard Accelerations',
                      analyzer.countByType('ACCEL'), kAmber),
                  _BreakdownRow('Sharp Turns',
                      analyzer.countByType('TURN'),
                      const Color(0xFF00B8FF)),
                  _BreakdownRow('Skids',
                      analyzer.countByType('SKID'),
                      const Color(0xFFFF0055)),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── FULL REPORT ────────────────────────────────
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: kCard,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _reportUnlocked
                      ? kGreen.withOpacity(0.3)
                      : kBorder,
                ),
              ),
              child: Column(children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('FULL REPORT',
                        style: TextStyle(
                          color: kTextMid,
                          fontSize: 10,
                          letterSpacing: 2,
                        )),
                    if (_reportUnlocked)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: kGreen.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                              color: kGreen.withOpacity(0.4)),
                        ),
                        child: const Text('UNLOCKED',
                            style: TextStyle(
                              color: kGreen,
                              fontSize: 9,
                              letterSpacing: 1.5,
                              fontWeight: FontWeight.w700,
                            )),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_reportUnlocked) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: kBorder),
                    ),
                    child: Text(
                      analyzer.generateReport(),
                      style: const TextStyle(
                        color:       kTextMid,
                        fontSize:    13,
                        fontFamily:  'monospace',
                        height:      1.8,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ] else ...[
                  const Icon(Icons.lock_outline,
                      color: kTextDim, size: 40),
                  const SizedBox(height: 12),
                  const Text('Full report is locked',
                      style: TextStyle(color: kTextMid, fontSize: 13)),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: _watchAd,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: kRed,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color:      kRed.withOpacity(0.3),
                            blurRadius: 16,
                            offset:     const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Text('WATCH AD TO UNLOCK',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color:       Colors.white,
                            fontWeight:  FontWeight.w800,
                            letterSpacing: 2.5,
                            fontSize:    13,
                          )),
                    ),
                  ),
                ],
              ]),
            ),

            const SizedBox(height: 16),

            // ── NEW TRIP ───────────────────────────────────
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: kCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: kBorder),
                ),
                child: const Text('NEW TRIP',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color:       kText,
                      fontSize:    13,
                      fontWeight:  FontWeight.w800,
                      letterSpacing: 3,
                    )),
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(value,
          style: const TextStyle(
            color: kText, fontSize: 20, fontWeight: FontWeight.w800)),
      const SizedBox(height: 2),
      Text(label,
          style: const TextStyle(
            color: kTextMid, fontSize: 9, letterSpacing: 1.5)),
    ]);
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 30, color: kBorder);
  }
}

class _BreakdownRow extends StatelessWidget {
  final String label;
  final int    count;
  final Color  color;
  const _BreakdownRow(this.label, this.count, this.color);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [
            Container(
              width: 3, height: 16,
              color: color,
              margin: const EdgeInsets.only(right: 12),
            ),
            Text(label,
                style: const TextStyle(color: kTextMid, fontSize: 13)),
          ]),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text('$count',
                style: TextStyle(
                  color:      color,
                  fontWeight: FontWeight.w800,
                  fontSize:   14,
                )),
          ),
        ],
      ),
    );
  }
}

