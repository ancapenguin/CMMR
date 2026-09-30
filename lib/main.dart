import 'package:flutter/material.dart';

void main() => runApp(const CmmrApp());

class CmmrApp extends StatelessWidget {
  const CmmrApp({super.key});

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF18212F);
    const mint = Color(0xFF69E3BE);

    return MaterialApp(
      title: 'CMMR',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: mint,
          brightness: Brightness.dark,
          surface: const Color(0xFF202B3A),
        ),
        scaffoldBackgroundColor: ink,
        useMaterial3: true,
      ),
      home: const CmmrHomePage(),
    );
  }
}

class CmmrHomePage extends StatefulWidget {
  const CmmrHomePage({super.key});

  @override
  State<CmmrHomePage> createState() => _CmmrHomePageState();
}

class _CmmrHomePageState extends State<CmmrHomePage> {
  int _checks = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CMMR'),
        centerTitle: false,
        backgroundColor: Colors.transparent,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.phone_android_rounded, size: 44, color: Color(0xFF69E3BE)),
                const SizedBox(height: 20),
                Text(
                  'Mobil geliştirme alanı hazır.',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Bu ilk Flutter ekranı Android için derleniyor. Butona dokunarak uygulama etkileşimini deneyebilirsin.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.white70,
                        height: 1.5,
                      ),
                ),
                const SizedBox(height: 28),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_outline, color: Color(0xFF69E3BE)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _checks == 0
                                ? 'APK derleme denemesi hazır'
                                : 'Etkileşim çalışıyor · $_checks',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () => setState(() => _checks++),
                  icon: const Icon(Icons.touch_app_rounded),
                  label: const Text('Etkileşimi dene'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
