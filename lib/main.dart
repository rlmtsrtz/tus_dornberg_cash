import 'package:flutter/material.dart';
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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'TuS Dornberg Cash Home'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;
  bool _isLoading = false;

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  Future<void> _saveToSheets() async {
    setState(() {
      _isLoading = true;
    });

    final success = await GoogleSheetsService.saveNumber(_counter);

    if (mounted) {
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success 
            ? 'Erfolgreich in Google Sheets gespeichert!' 
            : 'Fehler beim Speichern. Prüfe die URL!'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'Aktueller Zählerstand:',
            ),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _saveToSheets,
              icon: _isLoading 
                ? const SizedBox(
                    width: 20, 
                    height: 20, 
                    child: CircularProgressIndicator(strokeWidth: 2)
                  )
                : const Icon(Icons.cloud_upload),
              label: const Text('In Google Sheet speichern'),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Erhöhen',
        child: const Icon(Icons.add),
      ),
    );
  }
}
