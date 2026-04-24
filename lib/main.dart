import 'package:flutter/material.dart';
import 'package:crypto/crypto.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:shake/shake.dart';
import 'package:flutter_windowmanager_plus/flutter_windowmanager_plus.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  final prefs = await SharedPreferences.getInstance();
  final hasPin = prefs.getString('pin') != null;
  runApp(DeadSwitchApp(showPin: hasPin));
}

class DeadSwitchApp extends StatelessWidget {
  final bool showPin;
  const DeadSwitchApp({super.key, required this.showPin});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DeadSwitch',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0A0A0A),
        colorScheme: const ColorScheme.dark(primary: Color(0xFFFF3B3B)),
      ),
      home: showPin
          ? PinScreen(
              isSetup: false,
              onSuccess: (context) => Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const OnboardingScreen()),
              ),
            )
          : const OnboardingScreen(),
    );
  }
}

// ─── MODELS ───────────────────────────────────────────────────
class VaultItem {
  final String id;
  final String type;
  final String name;
  final String? content;
  final String? filePath;
  final DateTime addedAt;
  VaultItem({
    required this.id,
    required this.type,
    required this.name,
    this.content,
    this.filePath,
    required this.addedAt,
  });
}

class TrustedContact {
  final String name;
  final String email;
  final String relation;
  TrustedContact({
    required this.name,
    required this.email,
    required this.relation,
  });
}

// ─── ONBOARDING ───────────────────────────────────────────────
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _currentPage = 0;
  final List<Map<String, dynamic>> _pages = [
    {
      'icon': Icons.shield,
      'title': 'Welcome to DeadSwitch',
      'desc': 'Your personal safety switch. If something happens to you, DeadSwitch protects your data and alerts the people you trust.',
    },
    {
      'icon': Icons.timer,
      'title': 'How it works',
      'desc': 'Set a timer and check in every day. If you miss a check-in, DeadSwitch automatically triggers your chosen actions.',
    },
    {
      'icon': Icons.lock,
      'title': 'You are in control',
      'desc': 'Choose what happens when triggered — wipe files, alert contacts, or lock your vault. Your rules, your safety.',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemCount: _pages.length,
                itemBuilder: (context, i) {
                  final page = _pages[i];
                  return Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(page['icon'] as IconData, size: 100, color: const Color(0xFFFF3B3B)),
                        const SizedBox(height: 40),
                        Text(page['title'] as String,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                        const SizedBox(height: 20),
                        Text(page['desc'] as String,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 16, color: Colors.grey, height: 1.6)),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _pages.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentPage == i ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _currentPage == i ? const Color(0xFFFF3B3B) : Colors.grey,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: () {
                    if (_currentPage < _pages.length - 1) {
                      _controller.nextPage(
                          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                    } else {
                      Navigator.pushReplacement(
                          context, MaterialPageRoute(builder: (_) => const HomeScreen()));
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF3B3B),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(
                    _currentPage < _pages.length - 1 ? 'NEXT' : 'GET STARTED',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1, color: Colors.white),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ─── HOME SCREEN ──────────────────────────────────────────────
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Duration _remaining = const Duration(hours: 24);
  Timer? _timer;
  bool _isActive = true;
  int _selectedHours = 24;
  List<TrustedContact> _contacts = [];
  List<VaultItem> _vaultItems = [];
  ShakeDetector? _shakeDetector;
  List<String> _activityLog = [];
  DateTime? _lastActiveTime;
  Timer? _lockTimer;


  @override
void initState() {
  super.initState();
  _startTimer();
  _shakeDetector = ShakeDetector.autoStart(
    onPhoneShake: (ShakeEvent event) {
      _checkIn();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
          content: Text('✅ Checked in by shake!',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      );
    },
  );
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    await FlutterWindowManagerPlus.addFlags(FlutterWindowManagerPlus.FLAG_SECURE);
    _startLockTimer();
  });
}

  void _startTimer() {
  _timer?.cancel();
  _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
    setState(() {
      if (_remaining.inSeconds > 0) {
        _remaining -= const Duration(seconds: 1);
        // Warning at 30 minutes remaining
        if (_remaining.inMinutes == 30 && _remaining.inSeconds % 60 == 0) {
          _showGraceWarning();
        }
      } else {
        if (!_graceTriggered) {
          _graceTriggered = true;
          _startGracePeriod();
        }
      }
    });
  });
}

bool _graceTriggered = false;
Timer? _graceTimer;

void _showGraceWarning() {
  if (!mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      backgroundColor: Colors.orange,
      duration: const Duration(seconds: 10),
      content: const Row(
        children: [
          Icon(Icons.warning, color: Colors.white),
          SizedBox(width: 8),
          Text('30 minutes left! Check in now.',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
      action: SnackBarAction(
        label: 'CHECK IN',
        textColor: Colors.white,
        onPressed: _checkIn,
      ),
    ),
  );
}

void _startGracePeriod() {
  setState(() {
    _remaining = const Duration(minutes: 30);
    _isActive = false;
  });
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      backgroundColor: Colors.red,
      duration: const Duration(seconds: 10),
      content: const Row(
        children: [
          Icon(Icons.warning_rounded, color: Colors.white),
          SizedBox(width: 8),
          Expanded(
            child: Text('FINAL WARNING! 30 minutes to check in or DeadSwitch triggers!',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      action: SnackBarAction(
        label: 'CHECK IN',
        textColor: Colors.white,
        onPressed: _checkIn,
      ),
    ),
  );
  _graceTimer = Timer(const Duration(minutes: 30), () {
    _triggerNow();
  });
}
void _startLockTimer() {
  _lockTimer?.cancel();
  _lastActiveTime = DateTime.now();
  _lockTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
    if (_lastActiveTime != null) {
      final diff = DateTime.now().difference(_lastActiveTime!);
      if (diff.inMinutes >= 1) {
        timer.cancel();
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (_) => PinScreen(
                isSetup: false,
                onSuccess: (ctx) => Navigator.pushReplacement(
                  ctx,
                  MaterialPageRoute(builder: (_) => const HomeScreen()),
                ),
              ),
            ),
            (route) => false,
          );
        }
      }
    }
  });
}

void _addLog(String message) {
  setState(() {
    _activityLog.insert(0,
        '${DateTime.now().toString().substring(0, 16)} — $message');
    if (_activityLog.length > 50) _activityLog.removeLast();
  });
}

Future<String> _getLocation() async {
  try {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return 'Location not available';
    }
    final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
    final lat = position.latitude;
    final lng = position.longitude;
    return 'https://www.google.com/maps?q=$lat,$lng';
  } catch (e) {
    return 'Location not available';
  }
}
  void _checkIn() {
  _graceTimer?.cancel();
  _graceTriggered = false;
  setState(() {
    _remaining = Duration(hours: _selectedHours);
    _isActive = true;
  });
  _addLog('✅ Checked in successfully');
}

void _triggerNow() async {
  setState(() {
    _isActive = false;
    _remaining = Duration.zero;
    _timer?.cancel();
  });
  _addLog('🚨 DeadSwitch triggered!');
  await _uploadVaultAndAlert();
}

  Future<void> _uploadVaultAndAlert() async {
  try {
    List<String> downloadLinks = [];
    String vaultSummary = '';

    for (final item in _vaultItems) {
      if (item.type == 'note') {
        vaultSummary += '📝 NOTE — ${item.name}:\n${item.content}\n\n';
      } else if (item.filePath != null) {
        try {
          final file = File(item.filePath!);
          final bytes = await file.readAsBytes();
          final base64File = base64Encode(bytes);
          
          final cloudName = 'YOUR_CLOUDINARY_API_KEY';
          final apiKey = 'YOUR_CLOUDINARY_API_KEY';
          final apiSecret = 'YOUR_CLOUDINARY_API_KEY';
          final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
          
          final response = await http.post(
            Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/auto/upload'),
            body: {
              'file': 'data:application/octet-stream;base64,$base64File',
              'api_key': apiKey,
              'timestamp': timestamp.toString(),
              'signature': _generateSignature(timestamp, apiSecret),
            },
          );

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            final url = data['secure_url'];
            downloadLinks.add('${item.name}: $url');
            if (item.type == 'photo') {
              vaultSummary += '📸 PHOTO — ${item.name}\n';
            } else {
              vaultSummary += '📄 DOCUMENT — ${item.name}\n';
            }
          }
        } catch (e) {
          debugPrint('Upload error: $e');
          if (item.type == 'photo') {
            vaultSummary += '📸 PHOTO — ${item.name} (upload failed)\n';
          } else {
            vaultSummary += '📄 DOCUMENT — ${item.name} (upload failed)\n';
          }
        }
      }
    }
     final location = await _getLocation();
     final prefs = await SharedPreferences.getInstance();
     final personalMessage = prefs.getString('personal_message') ?? '';
   final aiMessage = personalMessage.isNotEmpty
    ? 'URGENT: This person has not checked in to DeadSwitch. Please check on them immediately.\n\nLast known location: $location\n\nPersonal message:\n$personalMessage'
    : 'URGENT: This person has not checked in to DeadSwitch. Please check on them immediately.\n\nLast known location: $location';
    final secureLink = downloadLinks.isEmpty 
        ? 'No files to download.' 
        : downloadLinks.join('\n');
    
    final fullMessage = vaultSummary.isEmpty 
        ? 'No items in vault.' 
        : vaultSummary;

 await _sendEmergencyEmails(secureLink, aiMessage, vaultSummary);

    // Delete all files from vault folder
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final vaultDir = Directory('${appDir.path}/vault');
      if (await vaultDir.exists()) {
        await vaultDir.delete(recursive: true);
      }
    } catch (e) {
      debugPrint('Vault wipe error: $e');
    }

    setState(() => _vaultItems.clear());

  } catch (e) {
    debugPrint('Trigger error: $e');
  }
}

String _generateSignature(int timestamp, String apiSecret) {
  final stringToSign = 'timestamp=$timestamp$apiSecret';
  final bytes = utf8.encode(stringToSign);
  final digest = sha1.convert(bytes);
  return digest.toString();
}

  Future<void> _sendEmergencyEmails(String secureLink, String aiMessage, String vaultSummary) async {
  const serviceId = 'YOUR_KEY';
  const templateId = 'YOUR_KEY';
  const publicKey = 'YOUR_KEY';
  const privateKey = 'YOUR_KEY';
  for (final contact in _contacts) {
    try {
      final response = await http.post(
        Uri.parse('https://api.emailjs.com/api/v1.0/email/send'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'service_id': serviceId,
          'template_id': templateId,
          'user_id': publicKey,
          'accessToken': privateKey,
          'template_params': {
            'to_name': contact.name,
            'to_email': contact.email,
            'secure_link': secureLink,
            'emergency_message': aiMessage,
            'trigger_time': DateTime.now().toString(),
            'vault_summary': vaultSummary,
          }
        }),
      );
      debugPrint('Email response status: ${response.statusCode}');
      debugPrint('Email response body: ${response.body}');
    } catch (e) {
      debugPrint('Email error: ${e.toString()}');
    }
  }
}

  void _updateTimer(int hours) {
    setState(() {
      _selectedHours = hours;
      _remaining = Duration(hours: hours);
      _isActive = true;
    });
    _startTimer();
  }

  String _formatDuration(Duration d) {
    String hours = d.inHours.toString().padLeft(2, '0');
    String minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
    String seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  @override
void dispose() {
  _timer?.cancel();
  _graceTimer?.cancel();
  _shakeDetector?.stopListening();
  _lockTimer?.cancel();
  super.dispose();
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        elevation: 0,
        actions: [
         IconButton(
  icon: const Icon(Icons.history, color: Colors.grey),
  onPressed: () => Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) =>
              ActivityLogScreen(logs: _activityLog))),
), 
                  IconButton(
            icon: const Icon(Icons.lock, color: Colors.grey),
            onPressed: () async {
              final result = await Navigator.push(context,
                  MaterialPageRoute(builder: (_) => VaultScreen(items: _vaultItems)));
              if (result != null) setState(() => _vaultItems = result as List<VaultItem>);
            },
          ),
          IconButton(
            icon: const Icon(Icons.people, color: Colors.grey),
            onPressed: () async {
              final result = await Navigator.push(context,
                  MaterialPageRoute(builder: (_) => ContactsScreen(contacts: _contacts)));
              if (result != null) setState(() => _contacts = result as List<TrustedContact>);
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.grey),
            onPressed: () async {
              final result = await Navigator.push(context,
                  MaterialPageRoute(builder: (_) => SettingsScreen(selectedHours: _selectedHours)));
              if (result != null) _updateTimer(result as int);
            },
          ),
        ],
      ),
      body: GestureDetector(
      onTap: () => _lastActiveTime = DateTime.now(),
      onPanDown: (_) => _lastActiveTime = DateTime.now(),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              const Icon(Icons.shield, color: Color(0xFFFF3B3B), size: 64),
              const SizedBox(height: 16),
              const Text('DeadSwitch',
                  style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 2)),
              const Text('Your data. Protected. Always.',
                  style: TextStyle(fontSize: 14, color: Colors.grey, letterSpacing: 1)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  border: Border.all(color: _isActive ? const Color(0xFFFF3B3B) : Colors.grey, width: 2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    Text(_isActive ? 'TIME REMAINING' : 'TRIGGERED',
                        style: TextStyle(fontSize: 12, color: _isActive ? const Color(0xFFFF3B3B) : Colors.grey, letterSpacing: 2)),
                    const SizedBox(height: 12),
                    Text(_isActive ? _formatDuration(_remaining) : '00:00:00',
                        style: const TextStyle(fontSize: 52, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 8),
                    Text('Timer set to $_selectedHours hours',
                        style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_contacts.isNotEmpty) _infoChip(Icons.people, '${_contacts.length} contacts'),
                  if (_contacts.isNotEmpty && _vaultItems.isNotEmpty) const SizedBox(width: 8),
                  if (_vaultItems.isNotEmpty) _infoChip(Icons.lock, '${_vaultItems.length} vault items'),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: _isActive ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _isActive ? Colors.green : Colors.red),
                ),
                child: Text(_isActive ? '● ACTIVE' : '● TRIGGERED',
                    style: TextStyle(color: _isActive ? Colors.green : Colors.red, fontWeight: FontWeight.bold, letterSpacing: 2)),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => PanicScreen(onConfirm: _triggerNow, contacts: _contacts, vaultItems: _vaultItems),
                )),
                child: Container(
                  width: double.infinity,
                  height: 56,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFFF3B3B), width: 1.5),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Color(0xFFFF3B3B), size: 20),
                      SizedBox(width: 8),
                      Text('PANIC — TRIGGER NOW',
                          style: TextStyle(color: Color(0xFFFF3B3B), fontWeight: FontWeight.bold, letterSpacing: 1, fontSize: 14)),
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: _checkIn,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF3B3B),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('CHECK IN — I\'M SAFE',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1, color: Colors.white)),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
       ),
      ),
    ),
  );
}

  Widget _infoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFFFF3B3B)),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }
}

// ─── PANIC SCREEN ─────────────────────────────────────────────
class PanicScreen extends StatefulWidget {
  final VoidCallback onConfirm;
  final List<TrustedContact> contacts;
  final List<VaultItem> vaultItems;
  const PanicScreen({super.key, required this.onConfirm, required this.contacts, required this.vaultItems});
  @override
  State<PanicScreen> createState() => _PanicScreenState();
}

class _PanicScreenState extends State<PanicScreen> with SingleTickerProviderStateMixin {
  bool _holding = false;
  double _progress = 0.0;
  Timer? _holdTimer;
  bool _triggered = false;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
  }

  void _startHold() {
    if (_triggered) return;
    setState(() => _holding = true);
    HapticFeedback.heavyImpact();
    int ticks = 0;
    _holdTimer = Timer.periodic(const Duration(milliseconds: 30), (t) {
      ticks++;
      setState(() => _progress = ticks / 100);
      if (ticks >= 100) {
        t.cancel();
        _trigger();
      }
    });
  }

  void _stopHold() {
    if (_triggered) return;
    _holdTimer?.cancel();
    setState(() { _holding = false; _progress = 0.0; });
  }

  void _trigger() {
    HapticFeedback.vibrate();
    setState(() => _triggered = true);
    widget.onConfirm();
    Future.delayed(const Duration(seconds: 2), () { if (mounted) Navigator.pop(context); });
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        elevation: 0,
        leading: _triggered ? null : IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(_triggered ? 'TRIGGERED' : 'PANIC MODE',
            style: TextStyle(
                color: _triggered ? const Color(0xFFFF3B3B) : Colors.white,
                fontWeight: FontWeight.bold,
                letterSpacing: 2)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _triggered ? _buildTriggered() : _buildHoldButton(),
        ),
      ),
    );
  }

  Widget _buildTriggered() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Spacer(),
        const Icon(Icons.warning_rounded, color: Color(0xFFFF3B3B), size: 80),
        const SizedBox(height: 24),
        const Text('DEADSWITCH TRIGGERED',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFFFF3B3B), fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2)),
        const SizedBox(height: 16),
        const Text('Uploading vault to secure cloud...\nContacts will be alerted.\nVault will be wiped.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 16, height: 1.6)),
        const SizedBox(height: 40),
        const CircularProgressIndicator(color: Color(0xFFFF3B3B)),
        const Spacer(),
        if (widget.contacts.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Alerting:', style: TextStyle(color: Colors.grey, fontSize: 12, letterSpacing: 1)),
                const SizedBox(height: 8),
                ...widget.contacts.map((c) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green, size: 16),
                      const SizedBox(width: 8),
                      Text(c.name, style: const TextStyle(color: Colors.white)),
                      const SizedBox(width: 4),
                      Text('(${c.email})', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                )),
              ],
            ),
          ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildHoldButton() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Spacer(),
        const Icon(Icons.warning_amber_rounded, color: Color(0xFFFF3B3B), size: 48),
        const SizedBox(height: 16),
        const Text('EMERGENCY TRIGGER',
            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 1)),
        const SizedBox(height: 12),
        const Text('Hold the button below for 3 seconds\nto immediately trigger DeadSwitch',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 15, height: 1.5)),
        if (widget.contacts.isEmpty)
          Container(
            margin: const EdgeInsets.only(top: 16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.withOpacity(0.4)),
            ),
            child: const Text('⚠ No trusted contacts added yet',
                style: TextStyle(color: Colors.orange, fontSize: 13)),
          ),
        const Spacer(),
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 200,
              height: 200,
              child: CircularProgressIndicator(
                value: _progress,
                strokeWidth: 6,
                backgroundColor: const Color(0xFF1A1A1A),
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF3B3B)),
              ),
            ),
            GestureDetector(
              onTapDown: (_) => _startHold(),
              onTapUp: (_) => _stopHold(),
              onTapCancel: _stopHold,
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _holding
                          ? const Color(0xFFFF3B3B)
                          : Color.lerp(const Color(0xFF2A0A0A), const Color(0xFF3A1010), _pulseController.value)!,
                      border: Border.all(color: const Color(0xFFFF3B3B), width: 2),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.warning_rounded,
                            color: _holding ? Colors.white : const Color(0xFFFF3B3B), size: 40),
                        const SizedBox(height: 8),
                        Text(_holding ? 'HOLD...' : 'HOLD',
                            style: TextStyle(
                                color: _holding ? Colors.white : const Color(0xFFFF3B3B),
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                letterSpacing: 2)),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        const Spacer(),
        const Text('This action cannot be undone.\nAll vault items will be sent and wiped.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 13, height: 1.5)),
        const SizedBox(height: 32),
      ],
    );
  }
}

// ─── VAULT SCREEN ─────────────────────────────────────────────
class VaultScreen extends StatefulWidget {
  final List<VaultItem> items;
  const VaultScreen({super.key, required this.items});
  @override
  State<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends State<VaultScreen> {
  late List<VaultItem> _items;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.items);
  }

  void _addNote() {
    final titleController = TextEditingController();
    final contentController = TextEditingController();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Add Secret Note',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(controller: titleController, style: const TextStyle(color: Colors.white), decoration: _inputDecoration('Note title')),
            const SizedBox(height: 12),
            TextField(controller: contentController, style: const TextStyle(color: Colors.white), maxLines: 4, decoration: _inputDecoration('Write your note here...')),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () {
                  if (titleController.text.isNotEmpty) {
                    setState(() {
                      _items.add(VaultItem(
                          id: DateTime.now().toString(),
                          type: 'note',
                          name: titleController.text,
                          content: contentController.text,
                          addedAt: DateTime.now()));
                    });
                    Navigator.pop(context);
                  }
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF3B3B),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                child: const Text('SAVE NOTE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addPhoto() async {
  final XFile? photo = await _imagePicker.pickImage(source: ImageSource.gallery);
  if (photo != null) {
    try {
      // Get app's private directory
      final appDir = await getApplicationDocumentsDirectory();
      final vaultDir = Directory('${appDir.path}/vault');
      if (!await vaultDir.exists()) {
        await vaultDir.create(recursive: true);
      }

      // Move file to vault (copy then delete original)
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${photo.name}';
      final newPath = '${vaultDir.path}/$fileName';
      final originalFile = File(photo.path);
      await originalFile.copy(newPath);
      await originalFile.delete(); // Remove from gallery

      setState(() {
        _items.add(VaultItem(
            id: DateTime.now().toString(),
            type: 'photo',
            name: photo.name,
            filePath: newPath,
            addedAt: DateTime.now()));
      });
    } catch (e) {
      debugPrint('Photo move error: $e');
    }
  }
}

 Future<void> _addDocument() async {
  FilePickerResult? result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['pdf', 'doc', 'docx', 'txt'],
  );
  if (result != null && result.files.isNotEmpty && result.files.first.path != null) {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final vaultDir = Directory('${appDir.path}/vault');
      if (!await vaultDir.exists()) {
        await vaultDir.create(recursive: true);
      }

      final file = result.files.first;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
      final newPath = '${vaultDir.path}/$fileName';
      final originalFile = File(file.path!);
      await originalFile.copy(newPath);
      await originalFile.delete();

      setState(() {
        _items.add(VaultItem(
            id: DateTime.now().toString(),
            type: 'document',
            name: file.name,
            filePath: newPath,
            addedAt: DateTime.now()));
      });
    } catch (e) {
      debugPrint('Document move error: $e');
    }
  }
}

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.grey),
      filled: true,
      fillColor: const Color(0xFF0A0A0A),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.withOpacity(0.3))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.withOpacity(0.3))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFFF3B3B))),
    );
  }

  IconData _getIcon(String type) {
    switch (type) {
      case 'photo': return Icons.image;
      case 'document': return Icons.description;
      default: return Icons.note;
    }
  }

  Color _getColor(String type) {
    switch (type) {
      case 'photo': return Colors.blue;
      case 'document': return Colors.orange;
      default: return const Color(0xFFFF3B3B);
    }
  }

  String _getTypeLabel(String type) {
    switch (type) {
      case 'photo': return 'PHOTO';
      case 'document': return 'DOCUMENT';
      default: return 'NOTE';
    }
  }

  Widget _addButton(IconData icon, String label, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              Icon(icon, color: const Color(0xFFFF3B3B), size: 24),
              const SizedBox(height: 4),
              Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        elevation: 0,
        title: const Text('Secure Vault', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context, _items),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _addButton(Icons.note_add, 'Note', _addNote),
                const SizedBox(width: 8),
                _addButton(Icons.add_photo_alternate, 'Photo', _addPhoto),
                const SizedBox(width: 8),
                _addButton(Icons.upload_file, 'Document', _addDocument),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFF3B3B).withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFF3B3B).withOpacity(0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Color(0xFFFF3B3B), size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'When triggered, all items upload to secure cloud. A download link is sent to your contacts. Vault is then wiped.',
                    style: TextStyle(color: Colors.grey, fontSize: 12, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _items.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.lock_outline, size: 80, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('Vault is empty', style: TextStyle(color: Colors.grey, fontSize: 18)),
                        SizedBox(height: 8),
                        Text('Add notes, photos or documents\nyou want protected',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey, fontSize: 14)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _items.length,
                    itemBuilder: (context, i) {
                      final item = _items[i];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A1A),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.withOpacity(0.2)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: _getColor(item.type).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: item.type == 'photo' && item.filePath != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.file(File(item.filePath!), fit: BoxFit.cover))
                                  : Icon(_getIcon(item.type), color: _getColor(item.type), size: 24),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.name,
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: _getColor(item.type).withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(_getTypeLabel(item.type),
                                            style: TextStyle(color: _getColor(item.type), fontSize: 10, fontWeight: FontWeight.bold)),
                                      ),
                                      const SizedBox(width: 8),
                                      Text('${item.addedAt.day}/${item.addedAt.month}/${item.addedAt.year}',
                                          style: const TextStyle(color: Colors.grey, fontSize: 11)),
                                    ],
                                  ),
                                  if (item.content != null && item.content!.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(item.content!,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                    ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.grey),
                              onPressed: () => setState(() => _items.removeAt(i)),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── CONTACTS SCREEN ──────────────────────────────────────────
class ContactsScreen extends StatefulWidget {
  final List<TrustedContact> contacts;
  const ContactsScreen({super.key, required this.contacts});
  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  late List<TrustedContact> _contacts;
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _relationController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _contacts = List.from(widget.contacts);
  }

  void _addContact() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Add Trusted Contact',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            _buildField(_nameController, 'Full name', Icons.person),
            const SizedBox(height: 16),
            _buildField(_emailController, 'Email address', Icons.email),
            const SizedBox(height: 16),
            _buildField(_relationController, 'Relation (e.g. sister, lawyer)', Icons.people),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () {
                  if (_nameController.text.isNotEmpty && _emailController.text.isNotEmpty) {
                    setState(() {
                      _contacts.add(TrustedContact(
                          name: _nameController.text,
                          email: _emailController.text,
                          relation: _relationController.text));
                    });
                    _nameController.clear();
                    _emailController.clear();
                    _relationController.clear();
                    Navigator.pop(context);
                  }
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF3B3B),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                child: const Text('ADD CONTACT',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(TextEditingController controller, String hint, IconData icon) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.grey),
        prefixIcon: Icon(icon, color: const Color(0xFFFF3B3B), size: 20),
        filled: true,
        fillColor: const Color(0xFF0A0A0A),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.withOpacity(0.3))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.withOpacity(0.3))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFFF3B3B))),
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        elevation: 0,
        title: const Text('Trusted Contacts', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context, _contacts),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Color(0xFFFF3B3B)),
            onPressed: _addContact,
          ),
        ],
      ),
      body: _contacts.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.people_outline, size: 80, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('No trusted contacts yet', style: TextStyle(color: Colors.grey, fontSize: 18)),
                  const SizedBox(height: 8),
                  const Text('Add people who will be alerted\nif your switch triggers',
                      textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 14)),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: _addContact,
                    icon: const Icon(Icons.add, color: Colors.white),
                    label: const Text('Add first contact', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF3B3B),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _contacts.length,
              itemBuilder: (context, i) {
                final c = _contacts[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF3B3B).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Center(
                          child: Text(_getInitials(c.name),
                              style: const TextStyle(color: Color(0xFFFF3B3B), fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(c.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                            Text(c.email, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                            if (c.relation.isNotEmpty)
                              Text(c.relation, style: const TextStyle(color: Color(0xFFFF3B3B), fontSize: 12)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.grey),
                        onPressed: () => setState(() => _contacts.removeAt(i)),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

// ─── SETTINGS SCREEN ──────────────────────────────────────────
class SettingsScreen extends StatefulWidget {
  final int selectedHours;
  const SettingsScreen({super.key, required this.selectedHours});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late int _selectedHours;
  bool _notificationsEnabled = true;
  bool _biometricEnabled = false;
  final List<int> _timerOptions = [6, 12, 24, 48, 72];
  final _messageController = TextEditingController();
  final _fakePinController = TextEditingController();
  String _personalMessage = '';
  @override
void initState() {
  super.initState();
  _selectedHours = widget.selectedHours;
  _loadMessage();
}

Future<void> _loadMessage() async {
  final prefs = await SharedPreferences.getInstance();
  setState(() {
    _personalMessage = prefs.getString('personal_message') ?? '';
    _messageController.text = _personalMessage;
    _fakePinController.text = prefs.getString('fake_pin') ?? '';
  });
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        elevation: 0,
        title: const Text('Settings', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('personal_message', _messageController.text);
  await prefs.setString('fake_pin', _fakePinController.text);
  Navigator.pop(context, _selectedHours);
},
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('CHECK-IN TIMER',
                style: TextStyle(color: Color(0xFFFF3B3B), fontSize: 12, letterSpacing: 2, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            const Text('How often must you check in?', style: TextStyle(color: Colors.grey, fontSize: 14)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _timerOptions.map((hours) {
                final isSelected = _selectedHours == hours;
                return GestureDetector(
                  onTap: () => setState(() => _selectedHours = hours),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFFF3B3B) : const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isSelected ? const Color(0xFFFF3B3B) : Colors.grey.withOpacity(0.3)),
                    ),
                    child: Text('${hours}h',
                        style: TextStyle(color: isSelected ? Colors.white : Colors.grey, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 40),
            const Divider(color: Color(0xFF1A1A1A)),
            const SizedBox(height: 24),
            const Text('SECURITY',
                style: TextStyle(color: Color(0xFFFF3B3B), fontSize: 12, letterSpacing: 2, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildToggle(
                icon: Icons.notifications,
                title: 'Check-in reminders',
                subtitle: 'Get notified before timer runs out',
                value: _notificationsEnabled,
                onChanged: (v) => setState(() => _notificationsEnabled = v)),
            const SizedBox(height: 16),
            _buildToggle(
                icon: Icons.fingerprint,
                title: 'Biometric lock',
                subtitle: 'Require fingerprint to open app',
                value: _biometricEnabled,
                onChanged: (v) => setState(() => _biometricEnabled = v)),
            
            const SizedBox(height: 24),
            const Divider(color: Color(0xFF1A1A1A)),
            const SizedBox(height: 24),
            const Text('PERSONAL MESSAGE',
                style: TextStyle(
                    color: Color(0xFFFF3B3B),
                    fontSize: 12,
                    letterSpacing: 2,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
              'This message will be sent to your contacts when triggered.',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _messageController,
              style: const TextStyle(color: Colors.white),
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'If you are reading this, something happened to me...',
                hintStyle: const TextStyle(color: Colors.grey),
                filled: true,
                fillColor: const Color(0xFF1A1A1A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFFF3B3B)),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Divider(color: Color(0xFF1A1A1A)),
            const SizedBox(height: 24),
            const Text('DECOY PIN',
                style: TextStyle(
                    color: Color(0xFFFF3B3B),
                    fontSize: 12,
                    letterSpacing: 2,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
              'If someone forces you to open the app, use this PIN. They will see an empty app.',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _fakePinController,
              style: const TextStyle(color: Colors.white),
              keyboardType: TextInputType.number,
              maxLength: 4,
              obscureText: true,
              decoration: InputDecoration(
                hintText: 'Set decoy PIN (4 digits)',
                hintStyle: const TextStyle(color: Colors.grey),
                filled: true,
                fillColor: const Color(0xFF1A1A1A),
                counterStyle: const TextStyle(color: Colors.grey),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFFF3B3B)),
                ),
              ),
            ),
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, _selectedHours),
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF3B3B),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                child: const Text('SAVE SETTINGS',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggle({required IconData icon, required String title, required String subtitle, required bool value, required ValueChanged<bool> onChanged}) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: const Color(0xFFFF3B3B), size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500)),
              Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
        ),
        Switch(value: value, onChanged: onChanged, activeColor: const Color(0xFFFF3B3B)),
      ],
    );
  }
}

// ─── PIN SCREEN ───────────────────────────────────────────────
class PinScreen extends StatefulWidget {
  final bool isSetup;
  final Function(BuildContext) onSuccess;
  const PinScreen({super.key, required this.isSetup, required this.onSuccess});
  @override
  State<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen> {
  String _pin = '';
  String _confirmPin = '';
  bool _confirming = false;
  String _error = '';
  int _failedAttempts = 0;

  void _onNumber(String n) async {
    if (_pin.length >= 4) return;
    setState(() => _pin += n);
    if (_pin.length == 4) {
      final prefs = await SharedPreferences.getInstance();
      if (widget.isSetup) {
        if (!_confirming) {
          setState(() {
            _confirming = true;
            _confirmPin = _pin;
            _pin = '';
          });
        } else {
          if (_pin == _confirmPin) {
            await prefs.setString('pin', _pin);
            widget.onSuccess(context);
          } else {
            setState(() {
              _pin = '';
              _confirmPin = '';
              _confirming = false;
              _error = 'PINs do not match. Try again.';
            });
          }
        }
      } else {
        final saved = prefs.getString('pin');
        final fakePin = prefs.getString('fake_pin') ?? '';
        if (_pin == saved) {
          widget.onSuccess(context);
        } else if (fakePin.isNotEmpty && _pin == fakePin) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const DecoyScreen()),
          );
        } else {
          _failedAttempts++;
          if (_failedAttempts >= 5) {
            setState(() {
              _error = 'Too many attempts! Triggering DeadSwitch...';
            });
            await Future.delayed(const Duration(seconds: 2));
            await prefs.remove('pin');
            widget.onSuccess(context);
          } else {
            setState(() {
              _pin = '';
              _error = 'Wrong PIN. ${5 - _failedAttempts} attempts remaining.';
            });
          }
        }
      }
    }
  }

  void _onDelete() {
    if (_pin.isNotEmpty) {
      setState(() => _pin = _pin.substring(0, _pin.length - 1));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.shield, color: Color(0xFFFF3B3B), size: 60),
              const SizedBox(height: 24),
              Text(
                widget.isSetup
                    ? (_confirming ? 'Confirm your PIN' : 'Create a PIN')
                    : 'Enter your PIN',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (_error.isNotEmpty)
                Text(_error,
                    style: const TextStyle(
                        color: Color(0xFFFF3B3B), fontSize: 14)),
              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  4,
                  (i) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i < _pin.length
                          ? const Color(0xFFFF3B3B)
                          : const Color(0xFF1A1A1A),
                      border: Border.all(color: const Color(0xFFFF3B3B)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 60),
              ...[
                ['1', '2', '3'],
                ['4', '5', '6'],
                ['7', '8', '9'],
                ['', '0', '⌫']
              ].map(
                (row) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: row
                        .map(
                          (key) => GestureDetector(
                            onTap: () => key == '⌫'
                                ? _onDelete()
                                : key.isNotEmpty
                                    ? _onNumber(key)
                                    : null,
                            child: Container(
                              width: 72,
                              height: 72,
                              margin: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: key.isEmpty
                                    ? Colors.transparent
                                    : const Color(0xFF1A1A1A),
                                border: key.isEmpty
                                    ? null
                                    : Border.all(
                                        color: Colors.grey.withOpacity(0.3)),
                              ),
                              child: Center(
                                child: Text(
                                  key,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
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
class ActivityLogScreen extends StatelessWidget {
  final List<String> logs;
  const ActivityLogScreen({super.key, required this.logs});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        elevation: 0,
        title: const Text('Activity Log',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: logs.isEmpty
          ? const Center(
              child: Text('No activity yet',
                  style: TextStyle(color: Colors.grey, fontSize: 16)))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: logs.length,
              itemBuilder: (context, i) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(logs[i],
                    style:
                        const TextStyle(color: Colors.grey, fontSize: 13)),
              ),
            ),
    );
  }
}
// ─── DECOY SCREEN ─────────────────────────────────────────────
class DecoyScreen extends StatelessWidget {
  const DecoyScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.shield, color: Colors.grey, size: 60),
              SizedBox(height: 16),
              Text('DeadSwitch',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text('No data found.',
                  style: TextStyle(color: Colors.grey, fontSize: 16)),
            ],
          ),
        ),
      ),
    );
  }
}