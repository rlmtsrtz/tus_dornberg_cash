import 'package:flutter/material.dart';
import 'models/person.dart';
import 'models/penalty.dart';
import 'services/google_sheets_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TuS Dornberg Cash',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
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
  int _selectedIndex = 1; // Start with People list

  static const List<Widget> _pages = [
    Center(child: Text('Kasse (Demnächst)')),
    PersonenListPage(),
    StrafenListPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TuS Dornberg Cash'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _pages[_selectedIndex],
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

class PersonenListPage extends StatefulWidget {
  const PersonenListPage({super.key});

  @override
  State<PersonenListPage> createState() => _PersonenListPageState();
}

class _PersonenListPageState extends State<PersonenListPage> {
  List<Person> _people = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPeople();
  }

  Future<void> _loadPeople() async {
    setState(() => _isLoading = true);
    final people = await GoogleSheetsService.getPeople();
    setState(() {
      _people = people;
      _isLoading = false;
    });
  }

  void _showAddPersonDialog() {
    final nameController = TextEditingController();
    PersonGroup selectedGroup = PersonGroup.ersatzbank; // Default to unassigned/bench

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Person hinzufügen'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name'),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              DropdownButton<PersonGroup>(
                value: selectedGroup,
                isExpanded: true,
                onChanged: (val) => setDialogState(() => selectedGroup = val!),
                items: PersonGroup.values.map((g) => DropdownMenuItem(
                  value: g,
                  child: Text(g.displayName),
                )).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isNotEmpty) {
                  final newPerson = Person(
                    id: DateTime.now().millisecondsSinceEpoch.toString(), 
                    name: name, 
                    group: selectedGroup
                  );
                  Navigator.pop(context);
                  setState(() => _isLoading = true);
                  await GoogleSheetsService.addPerson(newPerson);
                  _loadPeople();
                }
              },
              child: const Text('Hinzufügen'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      body: Row(
        children: [
          // Left Side: List of People
          Expanded(
            flex: 1,
            child: Container(
              color: Colors.grey[100],
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text('Personen', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _people.length,
                      itemBuilder: (context, index) {
                        final p = _people[index];
                        return Draggable<Person>(
                          data: p,
                          feedback: Material(
                            elevation: 4,
                            child: Container(
                              width: 200,
                              padding: const EdgeInsets.all(16),
                              color: Colors.blue[100],
                              child: Text(p.name),
                            ),
                          ),
                          childWhenDragging: Opacity(
                            opacity: 0.5,
                            child: ListTile(title: Text(p.name), subtitle: Text(p.group.displayName)),
                          ),
                          child: ListTile(
                            title: Text(p.name),
                            subtitle: Text(p.group.displayName),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                              onPressed: () async {
                                setState(() => _isLoading = true);
                                await GoogleSheetsService.deletePerson(p.id);
                                _loadPeople();
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          const VerticalDivider(width: 1),
          // Right Side: Group Buckets
          Expanded(
            flex: 1,
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text('Gruppen', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ),
                Expanded(
                  child: ListView(
                    children: PersonGroup.values.map((group) {
                      final groupPeople = _people.where((p) => p.group == group).toList();
                      return DragTarget<Person>(
                        onWillAccept: (data) => data?.group != group,
                        onAccept: (person) async {
                          setState(() => _isLoading = true);
                          await GoogleSheetsService.updatePersonGroup(person.id, group);
                          _loadPeople();
                        },
                        builder: (context, candidateData, rejectedData) {
                          return Container(
                            margin: const EdgeInsets.all(8),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: candidateData.isNotEmpty ? Colors.blue[50] : Colors.white,
                              border: Border.all(color: candidateData.isNotEmpty ? Colors.blue : Colors.grey[300]!),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(group.displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 4,
                                  runSpacing: 4,
                                  children: groupPeople.map((p) => Chip(
                                    label: Text(p.name, style: const TextStyle(fontSize: 12)),
                                    padding: EdgeInsets.zero,
                                    visualDensity: VisualDensity.compact,
                                  )).toList(),
                                ),
                                if (groupPeople.isEmpty)
                                  const Text('Keine Personen', style: TextStyle(color: Colors.grey, fontSize: 12)),
                              ],
                            ),
                          );
                        },
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddPersonDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class StrafenListPage extends StatefulWidget {
  const StrafenListPage({super.key});

  @override
  State<StrafenListPage> createState() => _StrafenListPageState();
}

class _StrafenListPageState extends State<StrafenListPage> {
  List<Penalty> _penalties = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPenalties();
  }

  Future<void> _loadPenalties() async {
    setState(() => _isLoading = true);
    final penalties = await GoogleSheetsService.getPenalties();
    setState(() {
      _penalties = penalties;
      _isLoading = false;
    });
  }

  void _showAddPenaltyDialog() {
    final nameController = TextEditingController();
    final amountController = TextEditingController();
    final tagController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Strafe hinzufügen'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Bezeichnung'),
              autofocus: true,
            ),
            TextField(
              controller: amountController,
              decoration: const InputDecoration(labelText: 'Höhe (€)'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            TextField(
              controller: tagController,
              decoration: const InputDecoration(labelText: 'Tags (kommagetrennt)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final amountStr = amountController.text.replaceAll(',', '.');
              final amount = double.tryParse(amountStr) ?? 0.0;
              final tags = tagController.text.isEmpty 
                  ? <String>[] 
                  : tagController.text.split(',').map((e) => e.trim()).toList();

              if (name.isNotEmpty) {
                final newPenalty = Penalty(
                  id: DateTime.now().millisecondsSinceEpoch.toString(), 
                  name: name, 
                  amount: amount,
                  tags: tags,
                );
                Navigator.pop(context);
                setState(() => _isLoading = true);
                await GoogleSheetsService.addPenalty(newPenalty);
                _loadPenalties();
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
    return Scaffold(
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : _penalties.isEmpty
            ? const Center(child: Text('Noch keine Strafen definiert.'))
            : ListView.builder(
              itemCount: _penalties.length,
              itemBuilder: (context, index) {
                final p = _penalties[index];
                return ListTile(
                  title: Text(p.name),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${p.amount.toStringAsFixed(2).replaceAll('.', ',')} €'),
                      if (p.tags.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Wrap(
                            spacing: 4,
                            children: p.tags.map((t) => Chip(
                              label: Text(t, style: const TextStyle(fontSize: 10)),
                              padding: EdgeInsets.zero,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                            )).toList(),
                          ),
                        ),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () async {
                      setState(() => _isLoading = true);
                      await GoogleSheetsService.deletePenalty(p.id);
                      _loadPenalties();
                    },
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddPenaltyDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
