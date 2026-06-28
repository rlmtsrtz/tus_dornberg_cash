import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'models/person.dart';
import 'models/penalty.dart';
import 'models/app_transaction.dart';
import 'services/firebase_service.dart';

// IMPORTANT: Insert your generated firebase_options.dart logic here or use the config directly
// Since I don't have the full flutterfire CLI output, I'll use the config from your message.

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyAQxuDNE32lHfFbGsBO-baKWUyX8Z9Rzcc",
      authDomain: "tus-dornberg-cash.firebaseapp.com",
      projectId: "tus-dornberg-cash",
      storageBucket: "tus-dornberg-cash.firebasestorage.app",
      messagingSenderId: "901821046390",
      appId: "1:901821046390:web:86e4536cd9dabbddf08957",
      measurementId: "G-9QXZ3T2EP4",
    ),
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TuS Dornberg Cash',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4CAF50)),
        useMaterial3: true,
      ),
      home: const MainNavigationPage(),
    );
  }
}

class MainNavigationPage extends StatefulWidget {
  const MainNavigationPage({super.key});

  @override
  State<MainNavigationPage> createState() => _MainNavigationPageState();
}

class _MainNavigationPageState extends State<MainNavigationPage> {
  int _selectedIndex = 0;
  bool _isAdmin = false;
  User? _user;

  @override
  void initState() {
    super.initState();
    FirebaseService.authStateChanges.listen((user) async {
      final isAdmin = await FirebaseService.isAdmin();
      setState(() {
        _user = user;
        _isAdmin = isAdmin;
      });
    });
  }

  void _showLoginDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Admin Login'),
        content: const Text('Möchtest du dich als Administrator anmelden?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              // Use signInWithPopup for Web if possible, or handle it in service
              await FirebaseService.signInWithGoogle();
            },
            child: const Text('Mit Google anmelden'),
          ),
        ],
      ),
    );
  }

  void _showAdminManagement() {
    final emailController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Admin-Verwaltung'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'Neue Admin E-Mail',
                  hintText: 'beispiel@gmail.com',
                ),
              ),
              const SizedBox(height: 16),
              const Text('Aktuelle Admins:', style: TextStyle(fontWeight: FontWeight.bold)),
              const Divider(),
              StreamBuilder<List<String>>(
                stream: FirebaseService.getAdminEmails(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const CircularProgressIndicator();
                  final admins = snapshot.data!;
                  return Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: admins.length,
                      itemBuilder: (context, index) {
                        final email = admins[index];
                        return ListTile(
                          title: Text(email, style: const TextStyle(fontSize: 14)),
                          trailing: email == 'felske.mirco@gmail.com'
                              ? null
                              : IconButton(
                                  icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                                  onPressed: () => FirebaseService.removeAdminEmail(email),
                                ),
                        );
                      },
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Schließen')),
          ElevatedButton(
            onPressed: () async {
              if (emailController.text.contains('@')) {
                await FirebaseService.addAdminEmail(emailController.text.trim().toLowerCase());
                emailController.clear();
              }
            },
            child: const Text('Hinzufügen'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      KassePage(isAdmin: _isAdmin),
      PersonenListPage(isAdmin: _isAdmin),
      StrafenListPage(isAdmin: _isAdmin),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset(
              'web/assets/logo.png',
              height: 40,
              errorBuilder: (context, error, stackTrace) => const Icon(Icons.money),
            ),
            const SizedBox(width: 12),
            const Text(
              'TuS Dornberg Cash',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFA5D6A7),
        actions: [
          if (_user == null)
            IconButton(
              icon: const Icon(Icons.login),
              onPressed: _showLoginDialog,
              tooltip: 'Admin Login',
            )
          else ...[
            if (_user?.email == 'felske.mirco@gmail.com')
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: _showAdminManagement,
                tooltip: 'Admin-Verwaltung',
              ),
            PopupMenuButton(
              icon: CircleAvatar(
                backgroundImage: _user!.photoURL != null ? NetworkImage(_user!.photoURL!) : null,
                child: _user!.photoURL == null ? const Icon(Icons.person) : null,
              ),
              itemBuilder: (context) => [
                PopupMenuItem(child: Text(_user!.email ?? '')),
                PopupMenuItem(
                  onTap: () => FirebaseService.signOut(),
                  child: const Text('Abmelden'),
                ),
              ],
            ),
          ],
        ],
      ),
      body: pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.money), label: 'Kasse'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Personen'),
          BottomNavigationBarItem(icon: Icon(Icons.gavel), label: 'Strafen'),
        ],
      ),
    );
  }
}

// --- KASSE PAGE ---

class KassePage extends StatefulWidget {
  final bool isAdmin;
  const KassePage({super.key, required this.isAdmin});

  @override
  State<KassePage> createState() => _KassePageState();
}

class _KassePageState extends State<KassePage> {
  DateTime _startDate = DateTime(DateTime.now().year, 6, 1);
  DateTime _endDate = DateTime(DateTime.now().year + 1, 5, 31);
  DateTime? _selectedMonthStart;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() async {
    final settings = await FirebaseService.getSettings();
    if (settings.containsKey('seasonStart') && settings.containsKey('seasonEnd')) {
      setState(() {
        _startDate = DateTime.parse(settings['seasonStart']!);
        _endDate = DateTime.parse(settings['seasonEnd']!);
      });
    }
  }

  void _showSeasonSettings() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
    );

    if (picked != null) {
      await FirebaseService.updateSettings({
        'seasonStart': picked.start.toIso8601String(),
        'seasonEnd': picked.end.toIso8601String(),
      });
      _loadSettings();
    }
  }

  double _calculateBalance(String personId, List<AppTransaction> transactions) {
    return transactions
        .where((t) => t.personId == personId)
        .where((t) {
          if (_selectedMonthStart != null) {
            return t.date.year == _selectedMonthStart!.year && 
                   t.date.month == _selectedMonthStart!.month;
          }
          return t.date.isAfter(_startDate.subtract(const Duration(seconds: 1))) &&
                 t.date.isBefore(_endDate.add(const Duration(days: 1)));
        })
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  List<DateTime> _getSeasonMonths() {
    List<DateTime> months = [];
    DateTime current = DateTime(_startDate.year, _startDate.month, 1);
    int count = 0;
    while (current.isBefore(_endDate) && count < 24) {
      months.add(current);
      current = DateTime(current.year, current.month + 1, 1);
      count++;
    }
    return months;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Person>>(
      stream: FirebaseService.getPeople(),
      builder: (context, peopleSnap) {
        return StreamBuilder<List<AppTransaction>>(
          stream: FirebaseService.getTransactions(),
          builder: (context, transSnap) {
            return StreamBuilder<List<Penalty>>(
              stream: FirebaseService.getPenalties(),
              builder: (context, penaltySnap) {
                if (!peopleSnap.hasData || !transSnap.hasData || !penaltySnap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final people = peopleSnap.data!..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
                final seasonMonths = _getSeasonMonths();

                return Scaffold(
                  body: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        color: const Color(0xFFF1F8E9),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Saison: ${DateFormat('dd.MM.yy').format(_startDate)} - ${DateFormat('dd.MM.yy').format(_endDate)}',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                if (widget.isAdmin)
                                  IconButton(
                                    icon: const Icon(Icons.calendar_month),
                                    onPressed: _showSeasonSettings,
                                  ),
                              ],
                            ),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  FilterChip(
                                    label: const Text('Gesamt'),
                                    selected: _selectedMonthStart == null,
                                    onSelected: (val) => setState(() => _selectedMonthStart = null),
                                    selectedColor: const Color(0xFFA5D6A7),
                                  ),
                                  const SizedBox(width: 8),
                                  ...seasonMonths.map((m) => Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: FilterChip(
                                      label: Text(DateFormat('MMM yy').format(m)),
                                      selected: _selectedMonthStart?.year == m.year && _selectedMonthStart?.month == m.month,
                                      onSelected: (val) => setState(() => _selectedMonthStart = val ? m : null),
                                      selectedColor: const Color(0xFFA5D6A7),
                                    ),
                                  )),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          itemCount: people.length,
                          itemBuilder: (context, index) {
                            final p = people[index];
                            final balance = _calculateBalance(p.id, transSnap.data!);
                            return InkWell(
                              onTap: () => _showHistory(context, p, transSnap.data!),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: const Color(0xFFA5D6A7),
                                  child: Text(p.name[0], style: const TextStyle(color: Colors.white)),
                                ),
                                title: Text(p.name),
                                trailing: Text(
                                  '${balance.toStringAsFixed(2).replaceAll('.', ',')} €',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: balance < 0 ? Colors.red : (balance > 0 ? Colors.green : Colors.black),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  floatingActionButton: widget.isAdmin
                      ? FloatingActionButton(
                          onPressed: () => _addTransaction(context, people, penaltySnap.data!),
                          backgroundColor: const Color(0xFF4CAF50),
                          child: const Icon(Icons.add, color: Colors.white),
                        )
                      : null,
                );
              },
            );
          },
        );
      },
    );
  }

  void _addTransaction(BuildContext context, List<Person> people, List<Penalty> penalties) {
    Person? selectedPerson;
    Penalty? selectedPenalty;
    String? selectedTag;
    DateTime selectedDate = DateTime.now();

    final allTags = penalties.expand((p) => p.tags).toSet().toList()..sort();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final filtered = selectedTag == null ? penalties : penalties.where((p) => p.tags.contains(selectedTag)).toList();
          return AlertDialog(
            title: const Text('Strafe/Zahlung buchen'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButton<Person>(
                          value: selectedPerson,
                          hint: const Text('Person'),
                          isExpanded: true,
                          onChanged: (val) => setDialogState(() => selectedPerson = val),
                          items: people.map((p) => DropdownMenuItem(value: p, child: Text(p.name))).toList(),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.calendar_today),
                        onPressed: () async {
                          final p = await showDatePicker(context: context, initialDate: selectedDate, firstDate: DateTime(2020), lastDate: DateTime(2030));
                          if (p != null) setDialogState(() => selectedDate = p);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 4,
                    children: [
                      ChoiceChip(label: const Text('Alle'), selected: selectedTag == null, onSelected: (_) => setDialogState(() => selectedTag = null)),
                      ...allTags.map((t) => ChoiceChip(label: Text(t), selected: selectedTag == t, onSelected: (v) => setDialogState(() => selectedTag = v ? t : null))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButton<Penalty>(
                          value: selectedPenalty,
                          hint: const Text('Strafe'),
                          isExpanded: true,
                          onChanged: (val) => setDialogState(() => selectedPenalty = val),
                          items: filtered.map((p) => DropdownMenuItem(value: p, child: Text(p.name))).toList(),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.account_balance_wallet, color: Colors.green),
                        onPressed: () {
                          if (selectedPerson == null) return;
                          _showTilgung(context, selectedPerson!, selectedDate);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
              ElevatedButton(
                onPressed: (selectedPerson == null || selectedPenalty == null)
                    ? null
                    : () async {
                        final t = AppTransaction(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          personId: selectedPerson!.id,
                          description: selectedPenalty!.name,
                          amount: -selectedPenalty!.amount,
                          date: selectedDate,
                        );
                        Navigator.pop(context);
                        await FirebaseService.addTransaction(t);
                      },
                child: const Text('Buchen'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showTilgung(BuildContext context, Person person, DateTime date) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Tilgung: ${person.name}'),
        content: TextField(controller: controller, decoration: const InputDecoration(labelText: 'Betrag (€)'), keyboardType: TextInputType.number),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(controller.text.replaceAll(',', '.')) ?? 0.0;
              if (amount > 0) {
                final t = AppTransaction(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  personId: person.id,
                  description: 'Tilgung',
                  amount: amount,
                  date: date,
                  isTilgung: true,
                );
                Navigator.pop(context);
                Navigator.pop(context);
                await FirebaseService.addTransaction(t);
              }
            },
            child: const Text('Speichern'),
          ),
        ],
      ),
    );
  }

  void _showHistory(BuildContext context, Person person, List<AppTransaction> transactions) {
    final history = transactions.where((t) => t.personId == person.id).toList();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Historie: ${person.name}'),
        content: SizedBox(
          width: double.maxFinite,
          child: history.isEmpty
              ? const Text('Keine Einträge.')
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: history.length,
                  itemBuilder: (context, index) {
                    final t = history[index];
                    return ListTile(
                      title: Text(t.description),
                      subtitle: Text(DateFormat('dd.MM.yy').format(t.date)),
                      trailing: Text('${t.amount.toStringAsFixed(2)} €', style: TextStyle(color: t.amount < 0 ? Colors.red : Colors.green)),
                    );
                  },
                ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Schließen'))],
      ),
    );
  }
}

// --- PERSONEN LIST PAGE ---

class PersonenListPage extends StatelessWidget {
  final bool isAdmin;
  const PersonenListPage({super.key, required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Person>>(
      stream: FirebaseService.getPeople(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final people = snapshot.data!;

        return Scaffold(
          body: Row(
            children: [
              Expanded(
                child: ListView.builder(
                  itemCount: people.length,
                  itemBuilder: (context, index) {
                    final p = people[index];
                    return isAdmin
                        ? Draggable<Person>(
                            data: p,
                            feedback: Material(elevation: 4, child: Container(padding: const EdgeInsets.all(16), color: Colors.green[100], child: Text(p.name))),
                            child: ListTile(
                              title: Text(p.name),
                              subtitle: Text(p.group.displayName),
                              trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => FirebaseService.deletePerson(p.id)),
                            ),
                          )
                        : ListTile(title: Text(p.name), subtitle: Text(p.group.displayName));
                  },
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: ListView(
                  children: PersonGroup.values.map((group) {
                    final groupPeople = people.where((p) => p.group == group).toList();
                    return isAdmin
                        ? DragTarget<Person>(
                            onAcceptWithDetails: (details) => FirebaseService.updatePersonGroup(details.data.id, group),
                            builder: (context, candidate, _) => Container(
                              margin: const EdgeInsets.all(8),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(8)),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(group.displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  Wrap(spacing: 4, children: groupPeople.map((p) => Chip(label: Text(p.name))).toList()),
                                ],
                              ),
                            ),
                          )
                        : Container(
                            margin: const EdgeInsets.all(8),
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(group.displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                Wrap(spacing: 4, children: groupPeople.map((p) => Chip(label: Text(p.name))).toList()),
                              ],
                            ),
                          );
                  }).toList(),
                ),
              ),
            ],
          ),
          floatingActionButton: isAdmin
              ? FloatingActionButton(
                  onPressed: () => _addPerson(context),
                  backgroundColor: const Color(0xFF4CAF50),
                  child: const Icon(Icons.add, color: Colors.white),
                )
              : null,
        );
      },
    );
  }

  void _addPerson(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Person hinzufügen'),
        content: TextField(controller: controller, decoration: const InputDecoration(labelText: 'Name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                final p = Person(id: DateTime.now().millisecondsSinceEpoch.toString(), name: controller.text, group: PersonGroup.ersatzbank);
                Navigator.pop(context);
                await FirebaseService.addPerson(p);
              }
            },
            child: const Text('Hinzufügen'),
          ),
        ],
      ),
    );
  }
}

// --- STRAFEN LIST PAGE ---

class StrafenListPage extends StatelessWidget {
  final bool isAdmin;
  const StrafenListPage({super.key, required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Penalty>>(
      stream: FirebaseService.getPenalties(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final penalties = snapshot.data!;

        return Scaffold(
          body: ListView.builder(
            itemCount: penalties.length,
            itemBuilder: (context, index) {
              final p = penalties[index];
              return ListTile(
                title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('${p.amount.toStringAsFixed(2)} €'),
                trailing: isAdmin ? IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => FirebaseService.deletePenalty(p.id)) : null,
              );
            },
          ),
          floatingActionButton: isAdmin
              ? FloatingActionButton(
                  onPressed: () => _addPenalty(context),
                  backgroundColor: const Color(0xFF4CAF50),
                  child: const Icon(Icons.add, color: Colors.white),
                )
              : null,
        );
      },
    );
  }

  void _addPenalty(BuildContext context) {
    final nameC = TextEditingController();
    final amountC = TextEditingController();
    final tagsC = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Strafe hinzufügen'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameC, decoration: const InputDecoration(labelText: 'Name')),
            TextField(controller: amountC, decoration: const InputDecoration(labelText: 'Betrag (€)'), keyboardType: TextInputType.number),
            TextField(controller: tagsC, decoration: const InputDecoration(labelText: 'Tags (komma-getrennt)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
          ElevatedButton(
            onPressed: () async {
              if (nameC.text.isNotEmpty) {
                final p = Penalty(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  name: nameC.text,
                  amount: double.tryParse(amountC.text) ?? 0.0,
                  tags: tagsC.text.split(',').map((e) => e.trim()).toList(),
                );
                Navigator.pop(context);
                await FirebaseService.addPenalty(p);
              }
            },
            child: const Text('Hinzufügen'),
          ),
        ],
      ),
    );
  }
}
