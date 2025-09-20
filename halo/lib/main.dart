// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'halo_api.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const HaloApp());
}

class HaloApp extends StatelessWidget {
  const HaloApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HALO Safety MVP',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.indigo),
      home: const RoleSelectionScreen(),
    );
  }
}

/// Role Selection
class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("HALO — Role Select")),
      body: Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          ElevatedButton.icon(
            icon: const Icon(Icons.person),
            label: const Text("Parent Login"),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ParentLoginScreen())),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            icon: const Icon(Icons.child_care),
            label: const Text("Child Login / Register"),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChildEntryScreen())),
          ),
        ]),
      ),
    );
  }
}

/// Parent Login
class ParentLoginScreen extends StatefulWidget {
  const ParentLoginScreen({super.key});
  @override
  State<ParentLoginScreen> createState() => _ParentLoginScreenState();
}
class _ParentLoginScreenState extends State<ParentLoginScreen> {
  final _userCtrl = TextEditingController(text: "parent1");
  final _passCtrl = TextEditingController(text: "demo123");
  bool _loading = false;
  String? _error;
  Future<void> _login() async {
    setState(() { _loading = true; _error = null; });
    try {
      final uid = await HaloApi.parentLogin(_userCtrl.text.trim(), _passCtrl.text.trim());
      if (uid != null) {
        if (!mounted) return;
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ParentDashboard(parentUid: uid)));
      } else {
        setState(() => _error = "Invalid credentials");
      }
    } catch (e) {
      setState(() => _error = "Login failed: $e");
    } finally { setState(() => _loading = false); }
  }

  @override Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text("Parent Login")), body: Padding(padding: const EdgeInsets.all(20), child:
    Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      TextField(controller: _userCtrl, decoration: const InputDecoration(labelText: "Username")),
      const SizedBox(height: 8),
      TextField(controller: _passCtrl, decoration: const InputDecoration(labelText: "Password"), obscureText: true),
      const SizedBox(height: 12),
      if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
      const SizedBox(height: 12),
      ElevatedButton(onPressed: _loading ? null : _login, child: _loading ? const CircularProgressIndicator(color: Colors.white) : const Text("Login"))
    ]),
    ));
  }
}

/// Child Entry
class ChildEntryScreen extends StatelessWidget {
  const ChildEntryScreen({super.key});
  @override Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text("Child — Login / Register")), body: Center(child:
    Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      ElevatedButton(child: const Text("Existing Child Login"), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChildLoginScreen()))),
      const SizedBox(height: 12),
      ElevatedButton(child: const Text("Register New Child"), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChildRegisterScreen()))),
    ]),
    ));
  }
}

/// Child Login
class ChildLoginScreen extends StatefulWidget {
  const ChildLoginScreen({super.key});
  @override State<ChildLoginScreen> createState() => _ChildLoginScreenState();
}
class _ChildLoginScreenState extends State<ChildLoginScreen> {
  final _uidCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  Future<void> _login() async {
    final uid = _uidCtrl.text.trim();
    if (uid.isEmpty) { setState(() => _error = "Enter child UID"); return; }
    setState(() { _loading = true; _error = null; });
    try {
      final exists = await HaloApi.checkChildExists(uid);
      if (exists) {
        if (!mounted) return;
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ChildDashboard(childUid: uid)));
      } else {
        setState(() => _error = "Child not found.");
      }
    } catch (e) { setState(() => _error = "Error: $e"); } finally { setState(() => _loading = false); }
  }

  @override Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text("Child Login")), body: Padding(padding: const EdgeInsets.all(20), child:
    Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      TextField(controller: _uidCtrl, decoration: const InputDecoration(labelText: "Child UID (e.g., child1)")),
      const SizedBox(height: 12),
      if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
      const SizedBox(height: 12),
      ElevatedButton(onPressed: _loading ? null : _login, child: _loading ? const CircularProgressIndicator(color: Colors.white) : const Text("Login"))
    ]),
    ));
  }
}

/// Child Register
class ChildRegisterScreen extends StatefulWidget {
  const ChildRegisterScreen({super.key});
  @override State<ChildRegisterScreen> createState() => _ChildRegisterScreenState();
}
class _ChildRegisterScreenState extends State<ChildRegisterScreen> {
  final _uid = TextEditingController();
  final _name = TextEditingController();
  final _parent = TextEditingController();
  bool _loading = false;
  String? _error;
  Future<void> _register() async {
    final uid = _uid.text.trim();
    final name = _name.text.trim();
    final parent = _parent.text.trim();
    if (uid.isEmpty || name.isEmpty || parent.isEmpty) { setState(() => _error = "Fill all fields"); return; }
    setState(() { _loading = true; _error = null; });
    try {
      await HaloApi.registerChild(uid: uid, name: name, parentUid: parent);
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ChildDashboard(childUid: uid)));
    } catch (e) { setState(() => _error = "Register failed: $e"); } finally { setState(() => _loading = false); }
  }

  @override Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text("Register Child")), body: Padding(padding: const EdgeInsets.all(16), child:
    Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      TextField(controller: _uid, decoration: const InputDecoration(labelText: "Child UID")),
      const SizedBox(height: 8),
      TextField(controller: _name, decoration: const InputDecoration(labelText: "Name")),
      const SizedBox(height: 8),
      TextField(controller: _parent, decoration: const InputDecoration(labelText: "Parent UID")),
      const SizedBox(height: 12),
      if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
      const SizedBox(height: 12),
      ElevatedButton(onPressed: _loading ? null : _register, child: _loading ? const CircularProgressIndicator(color: Colors.white) : const Text("Register"))
    ]),
    ));
  }
}

/// Parent Dashboard
class ParentDashboard extends StatefulWidget {
  final String parentUid;
  const ParentDashboard({super.key, required this.parentUid});
  @override State<ParentDashboard> createState() => _ParentDashboardState();
}
class _ParentDashboardState extends State<ParentDashboard> {
  List<dynamic> _alerts = [];
  List<dynamic> _journals = [];
  List<dynamic> _trends = [];
  List<dynamic> _children = [];
  Map<String, dynamic> _usageByChild = {};
  List<dynamic> _messages = [];
  bool _loading = true;
  String? _selectedChildUid;
  final _msgCtrl = TextEditingController();

  @override void initState() { super.initState(); _loadAll(); }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      _children = await HaloApi.getChildren(widget.parentUid);
      _alerts = await HaloApi.getAlerts(widget.parentUid);
      _journals = await HaloApi.getChildJournals(widget.parentUid);
      _trends = await HaloApi.getAlertTrends(widget.parentUid);
      _messages = await HaloApi.getParentMessages(widget.parentUid);
      // load usage for each child
      _usageByChild.clear();
      for (var c in _children) {
        final uid = c['uid'] as String;
        final usage = await HaloApi.getUsageSummary(uid);
        _usageByChild[uid] = usage;
      }
      if (_children.isNotEmpty) _selectedChildUid = _children.first['uid'];
    } catch (e) {
      if (kDebugMode) print("LoadAll error: $e");
    } finally { setState(() => _loading = false); }
  }

  Future<void> _sendMessageToChild() async {
    if (_selectedChildUid == null || _msgCtrl.text.trim().isEmpty) return;
    final text = _msgCtrl.text.trim();
    await HaloApi.sendMessage(sender: widget.parentUid, recipient: _selectedChildUid!, text: text);
    _msgCtrl.clear();
    _messages = await HaloApi.getParentMessages(widget.parentUid);
    setState(() {});
  }

  Widget _buildUsageCard(String uid, Map usage) {
    final total = usage['total_seconds'] ?? 0;
    final unlocks = usage['unlock_count'] ?? 0;
    final summary = (usage['summary'] as List<dynamic>?) ?? [];
    final minutes = (total / 60).round();
    final sections = <PieChartSectionData>[];
    final colors = [Colors.blue, Colors.red, Colors.green, Colors.orange, Colors.purple];
    for (int i = 0; i < summary.length; i++) {
      final pkg = summary[i];
      final seconds = (pkg['seconds'] as num).toDouble();
      final pct = total > 0 ? seconds / (total as num) : 0.0;
      sections.add(PieChartSectionData(value: pct, title: "${pkg['package']}\n${(seconds).toInt()}s", radius: 40, color: colors[i % colors.length]));
    }
    return Card(elevation: 3, child: Padding(padding: const EdgeInsets.all(12), child:
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text("Usage — $uid", style: const TextStyle(fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      Text("Total screen time: $minutes min"),
      Text("Unlock count: $unlocks"),
      const SizedBox(height: 8),
      SizedBox(height: 140, child: PieChart(PieChartData(sections: sections, sectionsSpace: 2, centerSpaceRadius: 20))),
    ]),
    ));
  }

  Widget _buildTrends() {
    if (_trends.isEmpty) return const Text("No trend data");
    final spots = <FlSpot>[];
    for (int i = 0; i < _trends.length; i++) {
      spots.add(FlSpot(i.toDouble(), (_trends[i]['count'] as num).toDouble()));
    }
    return SizedBox(height: 160, child: LineChart(LineChartData(
      titlesData: FlTitlesData(show: true),
      gridData: FlGridData(show: true),
      borderData: FlBorderData(show: false),
      lineBarsData: [LineChartBarData(spots: spots, isCurved: true, dotData: FlDotData(show: true))],
    )));
  }

  @override Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: Text("Parent — ${widget.parentUid}"), actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _loadAll)]),
        body: _loading ? const Center(child: CircularProgressIndicator()) :
        RefreshIndicator(onRefresh: _loadAll, child: ListView(padding: const EdgeInsets.all(12), children: [
          Row(children: [
            Expanded(child: Card(elevation: 3, child: Padding(padding: const EdgeInsets.all(12), child:
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text("Alert Trends", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _buildTrends()
            ]),
            ))),
            const SizedBox(width: 8),
            Expanded(child: Card(elevation: 3, child: Padding(padding: const EdgeInsets.all(12), child:
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text("Messages", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              DropdownButton<String>(
                value: _selectedChildUid,
                hint: const Text("Select child"),
                items: _children.map<DropdownMenuItem<String>>((c) => DropdownMenuItem(value: c['uid'], child: Text("${c['name']} (${c['uid']})"))).toList(),
                onChanged: (v) => setState(() => _selectedChildUid = v),
              ),
              const SizedBox(height: 8),
              SizedBox(height: 120, child: ListView(children: _messages.map((m) => ListTile(
                title: Text(m['text']),
                subtitle: Text("${m['from']} → ${m['to']} • ${m['ts'].toString().substring(11,16)}"),
              )).toList())),
              Row(children: [
                Expanded(child: TextField(controller: _msgCtrl, decoration: const InputDecoration(hintText: "Type message..."))),
                IconButton(icon: const Icon(Icons.send), onPressed: _sendMessageToChild)
              ])
            ]),
            ))),
          ]),
          const SizedBox(height: 12),
          const Text("Alerts", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          ..._alerts.map((a) => Card(child: ListTile(
            leading: a['severity'] == 'high' ? const Icon(Icons.warning, color: Colors.red) : const Icon(Icons.info),
            title: Text("${a['type']} — ${a['child_uid']}"),
            subtitle: Text(a['text'] ?? ''),
            trailing: a['acknowledged'] == true ? const Chip(label: Text("Ack")) : TextButton(child: const Text("Acknowledge"), onPressed: () async {
              await HaloApi.acknowledgeAlert(a['id'], acknowledged: true);
              _loadAll();
            }),
          ))),
          const SizedBox(height: 12),
          const Text("Child Usage", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          if (_children.isEmpty) const Text("No children found"),
          ..._children.map((c) {
            final uid = c['uid'] as String;
            final usage = _usageByChild[uid] ?? {'total_seconds': 0, 'unlock_count': 0, 'summary': []};
            return _buildUsageCard(uid, usage);
          }).toList(),
          const SizedBox(height: 12),
          const Text("Journals", style: TextStyle(fontWeight: FontWeight.bold)),
          ..._journals.map((j) => Card(child: ListTile(
            leading: const Icon(Icons.book),
            title: Text("${j['uid']} — ${j['date']}"),
            subtitle: Text("Good: ${(j['good'] as List).join(', ')}\nBad: ${(j['bad'] as List).join(', ')}"),
          ))),
        ]))
    );
  }
}

/// Child Dashboard
class ChildDashboard extends StatefulWidget {
  final String childUid;
  const ChildDashboard({super.key, required this.childUid});
  @override State<ChildDashboard> createState() => _ChildDashboardState();
}
class _ChildDashboardState extends State<ChildDashboard> {
  List<dynamic> _reminders = [];
  List<dynamic> _usage = [];
  List<dynamic> _messages = [];
  bool _loading = true;
  final _msgCtrl = TextEditingController();

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _reminders = await HaloApi.getReminders(widget.childUid);
      final usageData = await HaloApi.getUsageSummary(widget.childUid);
      _usage = usageData['summary'] ?? [];
      _messages = await HaloApi.getChildMessages(widget.childUid);
    } catch (e) {
      if (kDebugMode) print("Child load error: $e");
    } finally { setState(() => _loading = false); }
  }

  Future<void> _sendMessageToParent() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    await HaloApi.sendMessage(sender: widget.childUid, recipient: "parent1", text: text);
    _msgCtrl.clear();
    _messages = await HaloApi.getChildMessages(widget.childUid);
    setState(() {});
  }

  Widget _buildUsagePie() {
    if (_usage.isEmpty) return const Text("No usage data");
    final total = _usage.fold<int>(0, (p, e) => p + (e['seconds'] as int));
    final sections = <PieChartSectionData>[];
    final colors = [Colors.red, Colors.blue, Colors.green, Colors.orange];
    for (int i = 0; i < _usage.length; i++) {
      final e = _usage[i];
      final value = (e['seconds'] as int) / (total == 0 ? 1 : total);
      sections.add(PieChartSectionData(value: value, title: "${e['package']}\n${e['seconds']}s", radius: 44, color: colors[i % colors.length]));
    }
    return SizedBox(height: 160, child: PieChart(PieChartData(sections: sections, centerSpaceRadius: 24)));
  }

  Future<void> _sendSos() async {
    try {
      await HaloApi.sendSos(childId: widget.childUid);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("SOS sent")));
    } catch (e) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("SOS failed: $e"))); }
  }

  Future<void> _setWater() async {
    try {
      await HaloApi.setReminder(childUid: widget.childUid, type: "water_break", intervalMinutes: 30);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Water reminder set")));
      _load();
    } catch (e) {}
  }

  @override Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: Text("Child — ${widget.childUid}")), body: _loading ? const Center(child: CircularProgressIndicator()) : Padding(padding: const EdgeInsets.all(12), child:
    Column(children: [
      Card(elevation: 3, child: Padding(padding: const EdgeInsets.all(12), child:
      Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text("Daily Tip", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text("Be kind online. Don't click suspicious links."),
        ])),
        ElevatedButton.icon(onPressed: _sendSos, icon: const Icon(Icons.emergency), label: const Text("SOS"), style: ElevatedButton.styleFrom(backgroundColor: Colors.red)),
      ]),
      )),
      const SizedBox(height: 8),
      Card(elevation: 3, child: Padding(padding: const EdgeInsets.all(12), child:
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text("App Usage", style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _buildUsagePie()
      ]),
      )),
      const SizedBox(height: 8),
      Row(children: [
        ElevatedButton.icon(onPressed: _setWater, icon: const Icon(Icons.water_drop), label: const Text("Water Break")),
        const SizedBox(width: 8),
        ElevatedButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => JournalingScreen(childUid: widget.childUid))), icon: const Icon(Icons.book), label: const Text("Write Journal")),
        const SizedBox(width: 8),
        ElevatedButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SafeBrowser(childUid: widget.childUid))), icon: const Icon(Icons.public), label: const Text("Safe Browser")),
      ]),
      const SizedBox(height: 12),
      const Text("Messages", style: TextStyle(fontWeight: FontWeight.bold)),
      const SizedBox(height: 6),
      Expanded(child: ListView(children: _messages.map((m) => ListTile(title: Text(m['text']), subtitle: Text("${m['from']} • ${m['ts'].toString().substring(11,16)}"))).toList())),
      Row(children: [
        Expanded(child: TextField(controller: _msgCtrl, decoration: const InputDecoration(hintText: "Message to parent"))),
        IconButton(icon: const Icon(Icons.send), onPressed: _sendMessageToParent)
      ])
    ]),
    ));
  }
}

/// Journaling
class JournalingScreen extends StatefulWidget {
  final String childUid;
  const JournalingScreen({super.key, required this.childUid});
  @override State<JournalingScreen> createState() => _JournalingScreenState();
}
class _JournalingScreenState extends State<JournalingScreen> {
  final _good = TextEditingController();
  final _bad = TextEditingController();
  bool _saving = false;
  Future<void> _save() async {
    final good = _good.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    final bad = _bad.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    setState(() => _saving = true);
    try {
      await HaloApi.saveJournal(childUid: widget.childUid, good: good, bad: bad);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Journal saved")));
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Save failed: $e"))); } finally { setState(() => _saving = false); }
  }
  @override Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text("My Journal")), body: Padding(padding: const EdgeInsets.all(12), child:
    Column(children: [
      TextField(controller: _good, maxLines: 3, decoration: const InputDecoration(labelText: "Good things (comma separated)")),
      const SizedBox(height: 8),
      TextField(controller: _bad, maxLines: 3, decoration: const InputDecoration(labelText: "Bad things (comma separated)")),
      const SizedBox(height: 12),
      ElevatedButton(onPressed: _saving ? null : _save, child: _saving ? const CircularProgressIndicator(color: Colors.white) : const Text("Save"))
    ]),
    ));
  }
}

/// Safe Browser
class SafeBrowser extends StatefulWidget {
  final String childUid;
  const SafeBrowser({super.key, required this.childUid});
  @override State<SafeBrowser> createState() => _SafeBrowserState();
}
class _SafeBrowserState extends State<SafeBrowser> {
  late final WebViewController _controller;
  @override void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(Uri.parse("https://www.wikipedia.org"));
  }
  @override Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text("Safe Browser")), body: WebViewWidget(controller: _controller));
  }
}
