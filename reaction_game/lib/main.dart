import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:audioplayers/audioplayers.dart';

void main() {
  runApp(const ReactionTimerApp());
}

class ReactionTimerApp extends StatelessWidget {
  const ReactionTimerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Reaction Timer Game',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const ReactionGamePage(),
    );
  }
}

class ReactionGamePage extends StatefulWidget {
  const ReactionGamePage({super.key});

  @override
  State<ReactionGamePage> createState() => _ReactionGamePageState();
}

class _ReactionGamePageState extends State<ReactionGamePage> {
  String gameState = "Shake to Start";
  DateTime? startTime;
  int? reactionTime;
  List<int> scores = [];

  StreamSubscription? _accelSub;
  StreamSubscription? _gyroSub;
  final player = AudioPlayer();

  double gyroThreshold = 3.0;
  bool allowShake = true;

  @override
  void initState() {
    super.initState();
    loadScores();
    startSensorDetection();
  }

  @override
  void dispose() {
    _accelSub?.cancel();
    _gyroSub?.cancel();
    super.dispose();
  }

  void startSensorDetection() {
    _gyroSub = gyroscopeEvents.listen((event) {
      if ((event.x.abs() + event.y.abs() + event.z.abs()) > gyroThreshold) {
        allowShake = false;
      } else {
        allowShake = true;
      }
    });

    _accelSub = accelerometerEvents.listen((event) {
      double gForce =
          sqrt(event.x * event.x + event.y * event.y + event.z * event.z) /
          9.81;
      if (gForce > 2.7 && gameState == "Shake to Start" && allowShake) {
        onShake();
      }
    });
  }

  void onShake() {
    setState(() {
      reactionTime = null;
      gameState = "Get Ready";
    });
    vibrate();
    startGame();
  }

  Future<void> startGame() async {
    for (int i = 3; i > 0; i--) {
      setState(() {
        gameState = "Get Ready ($i)";
      });
      await Future.delayed(const Duration(seconds: 1));
    }

    final randomDelay = Duration(seconds: Random().nextInt(4) + 2);
    await Future.delayed(randomDelay);

    setState(() {
      gameState = "Tap Now!";
      startTime = DateTime.now();
    });
    playStartSound();
  }

  void handleTap() {
    if (gameState == "Tap Now!" && startTime != null) {
      final rt = DateTime.now().difference(startTime!).inMilliseconds;
      setState(() {
        reactionTime = rt;
        gameState = "Result";
      });
      saveScore(rt);
      vibrate();
      playTapSound();
    }
  }

  Future<void> saveScore(int score) async {
    final prefs = await SharedPreferences.getInstance();
    scores.add(score);
    scores.sort();
    if (scores.length > 5) {
      scores = scores.sublist(0, 5);
    }
    await prefs.setStringList(
      'scores',
      scores.map((s) => s.toString()).toList(),
    );
    setState(() {});
  }

  Future<void> loadScores() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('scores') ?? [];
    scores = saved.map(int.parse).toList();
    setState(() {});
  }

  void playStartSound() async {
    await player.play(AssetSource('start.mp3'));
  }

  void playTapSound() async {
    await player.play(AssetSource('tap.mp3'));
  }

  void vibrate() {
    HapticFeedback.mediumImpact();
  }

  void shareScore() {
    if (reactionTime != null) {
      Share.share("Mijn reaction time: ${reactionTime}ms! 🚀");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: gameState == "Tap Now!" ? Colors.red : Colors.white,
      appBar: AppBar(
        title: const Text("Reaction Timer Game"),
        actions: [
          if (reactionTime != null)
            IconButton(icon: const Icon(Icons.share), onPressed: shareScore),
        ],
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: handleTap,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                gameState,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              if (reactionTime != null)
                Text(
                  "Reaction Time: ${reactionTime}ms",
                  style: const TextStyle(fontSize: 24),
                ),
              if (scores.isNotEmpty) ...[
                const SizedBox(height: 20),
                const Text("Leaderboard:", style: TextStyle(fontSize: 22)),
                for (int i = 0; i < scores.length; i++)
                  Text(
                    "#${i + 1}: ${scores[i]} ms",
                    style: const TextStyle(fontSize: 18),
                  ),
              ],
              if (gameState == "Result")
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        gameState = "Shake to Start";
                      });
                    },
                    child: const Text("Opnieuw spelen"),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
