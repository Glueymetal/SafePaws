import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FeedingDiagnosticScreen extends StatefulWidget {
  const FeedingDiagnosticScreen({super.key});

  @override
  State<FeedingDiagnosticScreen> createState() =>
      _FeedingDiagnosticScreenState();
}

class _FeedingDiagnosticScreenState extends State<FeedingDiagnosticScreen> {
  List<Map<String, dynamic>> _documents = [];
  bool _isLoading = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('feedings')
          .orderBy('timestamp', descending: true)
          .get();

      final docs = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'location': data['location'] ?? 'NO LOCATION',
          'timestamp': data['timestamp'],
          'fedBy': data['fedBy'] ?? 'unknown',
          'createdAt': data['createdAt'],
        };
      }).toList();

      setState(() {
        _documents = docs;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Firebase Diagnostic'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDocuments,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Error: $_error',
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                )
              : _documents.isEmpty
                  ? const Center(
                      child: Text('No documents found in feedings collection'))
                  : Column(
                      children: [
                        // Summary
                        Container(
                          padding: const EdgeInsets.all(16),
                          color: Colors.blue.shade50,
                          child: Column(
                            children: [
                              Text(
                                'Total Documents: ${_documents.length}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Unique Locations: ${_documents.map((d) => d['location']).toSet().length}',
                                style: const TextStyle(fontSize: 14),
                              ),
                            ],
                          ),
                        ),

                        // Location breakdown
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Documents by Location:',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ..._buildLocationBreakdown(),
                            ],
                          ),
                        ),

                        const Divider(),

                        // Document list
                        Expanded(
                          child: ListView.builder(
                            itemCount: _documents.length,
                            itemBuilder: (context, index) {
                              final doc = _documents[index];
                              return Card(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 4,
                                ),
                                child: ExpansionTile(
                                  title: Text(
                                    doc['location'] ?? 'NO LOCATION',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text(
                                    'Doc ID: ${doc['id']}',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          _buildInfoRow('Location',
                                              '"${doc['location']}"'),
                                          _buildInfoRow('Location Length',
                                              '${doc['location']?.toString().length ?? 0} chars'),
                                          _buildInfoRow(
                                              'Timestamp',
                                              doc['timestamp']?.toString() ??
                                                  'null'),
                                          _buildInfoRow(
                                              'Timestamp Type',
                                              doc['timestamp']
                                                      ?.runtimeType
                                                      .toString() ??
                                                  'null'),
                                          _buildInfoRow(
                                              'Fed By', doc['fedBy'] ?? 'null'),
                                          _buildInfoRow(
                                              'Created At',
                                              doc['createdAt']?.toString() ??
                                                  'null'),
                                          const SizedBox(height: 8),
                                          const Text(
                                            'Raw Data:',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade100,
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              doc.toString(),
                                              style: const TextStyle(
                                                fontSize: 10,
                                                fontFamily: 'monospace',
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
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

  List<Widget> _buildLocationBreakdown() {
    final locationCounts = <String, int>{};
    for (final doc in _documents) {
      final location = doc['location'] ?? 'NO LOCATION';
      locationCounts[location] = (locationCounts[location] ?? 0) + 1;
    }

    return locationCounts.entries.map((entry) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '"${entry.key}"',
                style: const TextStyle(fontFamily: 'monospace'),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.blue.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${entry.value} docs',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
