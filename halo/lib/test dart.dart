import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'halo_api.dart';
import 'dart:async';
import 'dart:math';

// Note: You might need to adjust this file path if your halo_api.dart is in a different location.

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HALO',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const AccountSelectionScreen(),
    );
  }
}

/// ------------------ ACCOUNT SELECTION ------------------
class AccountSelectionScreen extends StatelessWidget {
  const AccountSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Choose Account")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              },
              icon: const Icon(Icons.lock),
              label: const Text("Parent Account"),
              style: ElevatedButton.styleFrom(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 40, vertical: 15)),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const ChildDashboard()),
                );
              },
              icon: const Icon(Icons.child_care),
              label: const Text("Child Account"),
              style: ElevatedButton.styleFrom(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 40, vertical: 15)),
            ),
          ],
        ),
      ),
    );
  }
}

/// ------------------ LOGIN SCREEN (PARENT) ------------------
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _secureStorage = const FlutterSecureStorage();
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _saveDefaultCredentials();
  }

  Future<void> _saveDefaultCredentials() async {
    await _secureStorage.write(key: 'username', value: 'parent@example.com');
    await _secureStorage.write(key: 'password', value: '123456');
    await _secureStorage.write(key: 'parent_uid', value: 'parent1');
  }

  Future<void> _login() async {
    final savedUsername = await _secureStorage.read(key: 'username');
    final savedPassword = await _secureStorage.read(key: 'password');
    final parentId = await _secureStorage.read(key: 'parent_uid');

    if (_usernameController.text == savedUsername &&
        _passwordController.text == savedPassword) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (context) => ParentDashboard(parentUid: parentId!)),
      );
    } else {
      setState(() {
        _errorMessage = "Invalid username or password";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Parent Login")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: "Username",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: "Password",
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _login,
              child: const Text("Login"),
              style: ElevatedButton.styleFrom(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 50, vertical: 15)),
            ),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(_errorMessage!,
                    style: const TextStyle(color: Colors.red)),
              ),
          ],
        ),
      ),
    );
  }
}

/// ------------------ PARENT DASHBOARD ------------------
class ParentDashboard extends StatefulWidget {
  final String parentUid;
  const ParentDashboard({super.key, required this.parentUid});

  @override
  _ParentDashboardState createState() => _ParentDashboardState();
}

class _ParentDashboardState extends State<ParentDashboard> {
  int _selectedIndex = 0;
  List<dynamic> _alerts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAlerts();
  }

  Future<void> _loadAlerts() async {
    try {
      final data = await HaloApi.getAlerts(widget.parentUid);
      setState(() {
        _alerts = data;
        _loading = false;
      });
    } catch (e) {
      print("Error fetching alerts: $e");
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _markAsRead(String id) async {
    try {
      await HaloApi.markAlertRead(id);
      setState(() {
        _alerts = _alerts.map((alert) {
          if (alert['id'] == id) {
            alert['acknowledged'] = true;
          }
          return alert;
        }).toList();
      });
    } catch (e) {
      print("Error marking alert as read: $e");
    }
  }

  void _onTabSelected(int index) {
    setState(() => _selectedIndex = index);
  }

  void _logout() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const AccountSelectionScreen()),
    );
  }

  Widget _buildCurrentTab() {
    switch (_selectedIndex) {
      case 0:
        return _buildOverviewTab();
      case 1:
        return _buildAlertsTab();
      case 2:
        return _buildLocationTab();
      default:
        return const Center(child: Text("Coming soon..."));
    }
  }

  Widget _buildOverviewTab() {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                const Text("📊 General Analytics",
                    style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Text("Total Alerts: ${_alerts.length}"),
                Text(
                    "Unread Alerts: ${_alerts.where((a) => a['acknowledged'] == false).length}"),
              ],
            ),
          ),
        )
      ],
    );
  }

  Widget _buildAlertsTab() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_alerts.isEmpty) return const Center(child: Text("No alerts 🎉"));

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: _alerts.length,
      itemBuilder: (context, index) {
        final alert = _alerts[index];
        final isAcknowledged = alert["acknowledged"] ?? false;
        return Card(
          elevation: 2,
          color: isAcknowledged ? Colors.grey[200] : Colors.white,
          child: ExpansionTile(
            leading: Icon(
              Icons.warning,
              color: isAcknowledged ? Colors.grey : Colors.red,
            ),
            title: Text(alert["type"] ?? "Alert"),
            subtitle: Text("From: ${alert["from"] ?? alert["child_uid"]}"),
            children: [
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Text(alert["text"] ?? ""),
              ),
              if (!isAcknowledged)
                TextButton.icon(
                  onPressed: () => _markAsRead(alert["id"]),
                  icon: const Icon(Icons.done, color: Colors.green),
                  label: const Text("Mark as Acknowledged"),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLocationTab() {
    return const Center(
        child: LocationDisplay(childUid: 'child1')); // Hardcoded childId for demo
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Parent Dashboard"),
        actions: [
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
          )
        ],
      ),
      body: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => _onTabSelected(0),
                  child: Text("Overview",
                      style: TextStyle(
                          color: _selectedIndex == 0
                              ? Colors.blue
                              : Colors.black)),
                ),
              ),
              Expanded(
                child: TextButton(
                  onPressed: () => _onTabSelected(1),
                  child: Text("Alerts",
                      style: TextStyle(
                          color: _selectedIndex == 1
                              ? Colors.blue
                              : Colors.black)),
                ),
              ),
              Expanded(
                child: TextButton(
                  onPressed: () => _onTabSelected(2),
                  child: Text("Location",
                      style: TextStyle(
                          color: _selectedIndex == 2
                              ? Colors.blue
                              : Colors.black)),
                ),
              ),
            ],
          ),
          const Divider(height: 1),
          Expanded(child: _buildCurrentTab()),
        ],
      ),
    );
  }
}

/// ------------------ CHILD DASHBOARD ------------------
class ChildDashboard extends StatefulWidget {
  const ChildDashboard({super.key});

  @override
  _ChildDashboardState createState() => _ChildDashboardState();
}

class _ChildDashboardState extends State<ChildDashboard> {
  String? _tip;
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadTip();
  }

  void _loadTip() async {
    final tips = [
      "Always tell a parent if you see something suspicious!",
      "Never share your password with anyone.",
      "Don't click on links from strangers.",
      "Be kind to others online.",
      "If you feel unsafe, use the SOS button!"
    ];
    setState(() => _tip = tips[Random().nextInt(tips.length)]);
  }

  void _sendReport() async {
    if (_controller.text.isEmpty) return;
    try {
      await HaloApi.reportText(_controller.text, childId: "child1");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Report sent successfully!")),
      );
      _controller.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to send report")),
      );
    }
  }

  void _sendSos() async {
    try {
      await HaloApi.sendSos(childId: "child1");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("SOS alert sent to your parent!")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to send SOS alert")),
      );
    }
  }

  void _logout() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const AccountSelectionScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Child Dashboard"),
        actions: [
          IconButton(onPressed: _logout, icon: const Icon(Icons.logout))
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text("💡 Daily Tip",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Text(
                      _tip ?? "Loading tip...",
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: "Type a message to report",
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.report),
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: _sendReport,
              icon: const Icon(Icons.send),
              label: const Text("Send Report"),
              style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15)),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _sendSos,
              icon: const Icon(Icons.emergency, color: Colors.white),
              label: const Text("Send SOS Alert",
                  style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
            ),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: () {
                // Navigate to a new screen for other features
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ChildFeaturesScreen()));
              },
              icon: const Icon(Icons.more_horiz),
              label: const Text("More Features"),
            )
          ],
        ),
      ),
    );
  }
}

/// ------------------ NEW FEATURES FOR CHILD ------------------
class ChildFeaturesScreen extends StatefulWidget {
  const ChildFeaturesScreen({super.key});

  @override
  _ChildFeaturesScreenState createState() => _ChildFeaturesScreenState();
}

class _ChildFeaturesScreenState extends State<ChildFeaturesScreen> {
  List<dynamic> _flashcards = [];
  bool _loadingFlashcards = true;

  @override
  void initState() {
    super.initState();
    _loadFlashcards();
  }

  Future<void> _loadFlashcards() async {
    try {
      final cards = await HaloApi.getFlashcards();
      setState(() {
        _flashcards = cards;
        _loadingFlashcards = false;
      });
    } catch (e) {
      print("Error loading flashcards: $e");
      setState(() => _loadingFlashcards = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Child Features")),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Flashcards Section
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text("🧠 Safety Flashcards",
                      style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  _loadingFlashcards
                      ? const Center(child: CircularProgressIndicator())
                      : (_flashcards.isEmpty
                      ? const Text("No flashcards available.")
                      : Column(
                    children: _flashcards
                        .map((card) => FlashcardTile(card: card))
                        .toList(),
                  )),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Journaling Section
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const JournalingScreen(childUid: 'child1'))); // Hardcoded childId for demo
            },
            icon: const Icon(Icons.book),
            label: const Text("Write a Journal Entry"),
            style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15)),
          ),
          const SizedBox(height: 10),
          // App Usage Section
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                      const AppUsageScreen(childUid: 'child1'))); // Hardcoded childId for demo
            },
            icon: const Icon(Icons.bar_chart),
            label: const Text("View App Usage"),
            style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15)),
          ),
          const SizedBox(height: 10),
          // Reminders Section
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const ReminderScreen(childUid: 'child1')));
            },
            icon: const Icon(Icons.alarm),
            label: const Text("Set a Reminder"),
            style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15)),
          ),
        ],
      ),
    );
  }
}

class FlashcardTile extends StatefulWidget {
  final Map<String, dynamic> card;

  const FlashcardTile({super.key, required this.card});

  @override
  _FlashcardTileState createState() => _FlashcardTileState();
}

class _FlashcardTileState extends State<FlashcardTile> {
  bool _showAnswer = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 2,
      child: InkWell(
        onTap: () {
          setState(() {
            _showAnswer = !_showAnswer;
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Q: ${widget.card['q']}",
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              if (_showAnswer)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text("A: ${widget.card['a']}",
                      style: const TextStyle(fontStyle: FontStyle.italic)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ------------------ JOURNALING SCREEN ------------------
class JournalingScreen extends StatefulWidget {
  final String childUid;
  const JournalingScreen({super.key, required this.childUid});

  @override
  _JournalingScreenState createState() => _JournalingScreenState();
}

class _JournalingScreenState extends State<JournalingScreen> {
  final _goodController = TextEditingController();
  final _badController = TextEditingController();

  Future<void> _saveJournal() async {
    try {
      final good = _goodController.text.split(',').map((s) => s.trim()).toList();
      final bad = _badController.text.split(',').map((s) => s.trim()).toList();
      await HaloApi.saveJournal(
          childUid: widget.childUid, good: good, bad: bad);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Journal entry saved!")),
      );
      _goodController.clear();
      _badController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to save journal entry")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("My Journal")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text("How was your day?",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            TextField(
              controller: _goodController,
              decoration: const InputDecoration(
                labelText: "What went well today? (e.g., played with friends)",
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _badController,
              decoration: const InputDecoration(
                labelText: "What was difficult today? (e.g., got a bad grade)",
                border: OutlineInputBorder(),
                fillColor: Color.fromARGB(255, 255, 237, 237),
                filled: true,
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saveJournal,
              child: const Text("Save Journal"),
            ),
          ],
        ),
      ),
    );
  }
}

/// ------------------ APP USAGE SCREEN ------------------
class AppUsageScreen extends StatefulWidget {
  final String childUid;
  const AppUsageScreen({super.key, required this.childUid});

  @override
  _AppUsageScreenState createState() => _AppUsageScreenState();
}

class _AppUsageScreenState extends State<AppUsageScreen> {
  Map<String, dynamic>? _usageData;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadUsageData();
  }

  Future<void> _loadUsageData() async {
    try {
      final data = await HaloApi.getAppUsageSummary(widget.childUid);
      setState(() {
        _usageData = data;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        print("Error fetching app usage: $e");
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("App Usage Summary")),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: _usageData == null
            ? const Center(
          child: Text("No usage data available."),
        )
            : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Total Screen Time: ${_usageData!['total_seconds']} seconds",
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ...(_usageData!['summary'] as List<dynamic>)
                .map((item) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  children: [
                    Expanded(child: Text(item['package'])),
                    Text(item['emoji']),
                    const SizedBox(width: 10),
                    Text(item['bar']),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
}

/// ------------------ REMINDER SCREEN ------------------
class ReminderScreen extends StatefulWidget {
  final String childUid;
  const ReminderScreen({super.key, required this.childUid});

  @override
  _ReminderScreenState createState() => _ReminderScreenState();
}

class _ReminderScreenState extends State<ReminderScreen> {
  final _intervalController = TextEditingController();
  String? _selectedType;

  Future<void> _setReminder() async {
    if (_selectedType == null || _intervalController.text.isEmpty) {
      return;
    }
    try {
      await HaloApi.setReminder(
        childUid: widget.childUid,
        type: _selectedType!,
        intervalMinutes: int.parse(_intervalController.text),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Reminder set successfully!")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to set reminder")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Set a Reminder")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text("Reminder Type",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            DropdownButton<String>(
              value: _selectedType,
              hint: const Text("Select type..."),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedType = newValue;
                });
              },
              items: <String>['water_break', 'screen_time', 'study_break']
                  .map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _intervalController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Interval in minutes",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _setReminder,
              child: const Text("Set Reminder"),
            ),
          ],
        ),
      ),
    );
  }
}

/// ------------------ LOCATION DISPLAY FOR PARENT ------------------
class LocationDisplay extends StatefulWidget {
  final String childUid;
  const LocationDisplay({super.key, required this.childUid});

  @override
  _LocationDisplayState createState() => _LocationDisplayState();
}

class _LocationDisplayState extends State<LocationDisplay> {
  Map<String, dynamic>? _location;
  bool _loading = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _fetchLocation();
    _timer = Timer.periodic(const Duration(minutes: 1), (Timer t) => _fetchLocation());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetchLocation() async {
    setState(() => _loading = true);
    try {
      final locationData = await HaloApi.getChildLocation(widget.childUid);
      setState(() {
        _location = locationData;
        _loading = false;
      });
    } catch (e) {
      print("Error fetching location: $e");
      setState(() {
        _loading = false;
        _location = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (_loading) const CircularProgressIndicator(),
        if (!_loading && _location == null)
          const Text("No location data found."),
        if (_location != null)
          Card(
            elevation: 4,
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const Text("Child's Last Location",
                      style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Text("Latitude: ${_location!['lat']}"),
                  Text("Longitude: ${_location!['lng']}"),
                  Text("Timestamp: ${_location!['ts']}"),
                ],
              ),
            ),
          ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: _fetchLocation,
          child: const Text("Refresh Location"),
        ),
      ],
    );
  }
}

//api
import 'dart:convert';
import 'package:http/http.dart' as http;

class HaloApi {
  // Use http://10.0.2.2:8000 for Android emulator
  static const String baseUrl = "http://10.0.2.2:8000";

  // Get health check
  static Future<Map<String, dynamic>> health() async {
    final response = await http.get(Uri.parse("$baseUrl/health"));
    return jsonDecode(response.body);
  }

  // Get alerts for a specific parent
  static Future<List<dynamic>> getAlerts(String parentUid) async {
    final response =
    await http.get(Uri.parse("$baseUrl/parent/alerts/$parentUid"));
    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      return data['alerts'];
    } else {
      throw Exception('Failed to load alerts');
    }
  }

  // Mark an alert as acknowledged
  static Future<void> markAlertRead(String id) async {
    final response = await http.put(
      Uri.parse("$baseUrl/parent/alert/$id"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"acknowledged": true}),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to mark alert as acknowledged');
    }
  }

  // Report text from a child
  static Future<Map<String, dynamic>> reportText(String text,
      {required String childId}) async {
    final response = await http.post(
      Uri.parse("$baseUrl/child/report_text"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"child_uid": childId, "text_content": text}),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to report text');
    }
  }

  // NEW: Send SOS
  static Future<void> sendSos({required String childId}) async {
    final response = await http.post(
      Uri.parse("$baseUrl/child/sos"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"uid": childId}),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to send SOS');
    }
  }

  // NEW: Get flashcards
  static Future<List<dynamic>> getFlashcards() async {
    final response = await http.get(Uri.parse("$baseUrl/child/flashcards"));
    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      return data['cards'];
    } else {
      throw Exception('Failed to load flashcards');
    }
  }

  // NEW: Save journal entry
  static Future<void> saveJournal({
    required String childUid,
    required List<String> good,
    required List<String> bad,
  }) async {
    final response = await http.post(
      Uri.parse("$baseUrl/child/journal"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "uid": childUid,
        "good": good,
        "bad": bad,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to save journal');
    }
  }

  // NEW: Get app usage summary
  static Future<Map<String, dynamic>> getAppUsageSummary(String childUid) async {
    final response =
    await http.get(Uri.parse("$baseUrl/child/usage_summary/$childUid"));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to get app usage summary');
    }
  }

  // NEW: Set reminder
  static Future<void> setReminder({
    required String childUid,
    required String type,
    int? intervalMinutes,
    String? atTime,
  }) async {
    final response = await http.post(
      Uri.parse("$baseUrl/child/reminder"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "uid": childUid,
        "type": type,
        "interval_minutes": intervalMinutes,
        "at_time": atTime,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to set reminder');
    }
  }

  // NEW: Get child's last known location
  static Future<Map<String, dynamic>> getChildLocation(String childUid) async {
    final response = await http.get(
      Uri.parse("$baseUrl/parent/find_child/$childUid"),
    );
    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      return data['location'];
    } else {
      throw Exception('Failed to get child location');
    }
  }
}

//pubspec
name: halo_safety_dashboard

description: A parental control and child safety dashboard app

publish_to: 'none' # Remove this line if you plan to publish to pub.dev



version: 1.0.0+1



environment:

sdk: ">=3.5.0 <4.0.0"



dependencies:

http: ^1.2.2

flutter:

sdk: flutter

firebase_core: ^2.15.1

firebase_messaging: ^14.6.7



# Add your packages here

flutter_secure_storage: ^9.0.0

crypto: ^3.0.2



dev_dependencies:

flutter_test:

sdk: flutter

flutter_lints: ^5.0.0



flutter:

uses-material-design: true



# Uncomment if you add images, fonts, etc.

# assets:

# - assets/images/

# - assets/fonts/