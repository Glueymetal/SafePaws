import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/firestore_service.dart';
import '../services/analytics_service.dart';

class AddReportScreen extends StatefulWidget {
  const AddReportScreen({super.key});

  @override
  State<AddReportScreen> createState() => _AddReportScreenState();
}

class _AddReportScreenState extends State<AddReportScreen> {
  final FirestoreService firestoreService = FirestoreService();
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _dogCountController =
      TextEditingController(text: '1');

  String? location;
  int dogCount = 1;
  String condition = 'lowPresence';
  String description = '';

  final Map<String, Map<String, dynamic>> campusLocations = {
    'Clock Tower': {'lat': 12.752724, 'lng': 80.196404},
    'Main Canteen': {'lat': 12.753242388969374, 'lng': 80.19462529900647},
    'Sports Complex': {'lat': 12.752944160414897, 'lng': 80.19396547559492},
    'Academic Block 1': {'lat': 12.752102906578527, 'lng': 80.19229066556564},
    'Academic Block 2': {'lat': 12.751496221296424, 'lng': 80.19258517703302},
    'Academic Block 3': {'lat': 12.752684111785046, 'lng': 80.19247275257061},
  };

  @override
  void initState() {
    super.initState();
    // 🎯 Track when user starts adding a report
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final analytics = Provider.of<AnalyticsService>(context, listen: false);
      analytics.logEvent(name: 'dog_report_started');
    });
  }

  @override
  void dispose() {
    _dogCountController.dispose();
    super.dispose();
  }

  void _updateDogCount(int newCount) {
    setState(() {
      dogCount = newCount.clamp(1, 99); // Allow up to 99 dogs
      _dogCountController.text = dogCount.toString();

      // Auto-suggest condition
      if (dogCount >= 8) {
        if (condition != 'danger') condition = 'danger';
      } else if (dogCount >= 5) {
        if (condition == 'lowPresence') {
          condition = 'highPresence';
        }
      }
    });
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_circle,
                    color: Colors.green.shade700,
                    size: 50,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Success!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'SourGummy',
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Your report has been submitted successfully.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.black54),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFC4A484),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      Navigator.of(context).pop(); // Close dialog
                      Navigator.of(context).pop(); // Back to home
                    },
                    child: const Text(
                      'Done',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final analytics = Provider.of<AnalyticsService>(context, listen: false);

    return WillPopScope(
      onWillPop: () async {
        // 🎯 Track when user cancels report
        analytics.logEvent(name: 'dog_report_cancelled');
        return true;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFFFF8E1),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () {
              // 🎯 Track back button press
              analytics.logEvent(name: 'dog_report_cancelled');
              Navigator.pop(context);
            },
          ),
          title: const Text(
            'Add Dog Report',
            style: TextStyle(
              fontFamily: 'SourGummy',
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Location
                  const Text(
                    'Location',
                    style: TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                        fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: location,
                    hint: const Text('Select a location'),
                    isExpanded: true,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                            color: Color(0xFFC4A484), width: 2),
                      ),
                    ),
                    items: campusLocations.keys.map((loc) {
                      return DropdownMenuItem(value: loc, child: Text(loc));
                    }).toList(),
                    onChanged: (value) {
                      setState(() => location = value);
                      // 🎯 Track location selection
                      analytics.logEvent(
                        name: 'location_selected',
                        parameters: {'location': value ?? 'unknown'},
                      );
                    },
                    validator: (value) =>
                        value == null ? 'Please select a location' : null,
                  ),

                  const SizedBox(height: 24),

                  // Dog Count - ✅ UPDATED WITH EDITABLE TEXT FIELD
                  const Text(
                    'Dog Count',
                    style: TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                        fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Slider(
                            value: dogCount.toDouble().clamp(1, 10),
                            min: 1,
                            max: 10,
                            divisions: 9,
                            label: dogCount <= 10 ? dogCount.toString() : '10+',
                            activeColor: const Color(0xFFC4A484),
                            inactiveColor: Colors.grey.shade300,
                            onChanged: (value) {
                              _updateDogCount(value.toInt());
                            },
                            onChangeEnd: (value) {
                              // 🎯 Track dog count selection
                              analytics.logEvent(
                                name: 'dog_count_changed',
                                parameters: {
                                  'count': value.toInt(),
                                  'method': 'slider'
                                },
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        // ✅ EDITABLE TEXT FIELD
                        Container(
                          width: 60,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFFC4A484),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: TextField(
                              controller: _dogCountController,
                              textAlign: TextAlign.center,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(2),
                              ],
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                              ),
                              onChanged: (value) {
                                if (value.isEmpty) return;
                                final newCount = int.tryParse(value);
                                if (newCount != null && newCount >= 1) {
                                  _updateDogCount(newCount);
                                }
                              },
                              onSubmitted: (value) {
                                final newCount = int.tryParse(value);
                                if (newCount == null || newCount < 1) {
                                  _updateDogCount(1);
                                }
                                // 🎯 Track manual input
                                analytics.logEvent(
                                  name: 'dog_count_changed',
                                  parameters: {
                                    'count': dogCount,
                                    'method': 'manual'
                                  },
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Helper text
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 4),
                    child: Text(
                      'Use slider or tap the number to type',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Condition
                  const Text(
                    'Condition',
                    style: TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                        fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: condition,
                    isExpanded: true,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                            color: Color(0xFFC4A484), width: 2),
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(
                          value: 'lowPresence',
                          child: Text('Low Presence (Safe)')),
                      DropdownMenuItem(
                          value: 'highPresence',
                          child: Text('High Presence (Caution)')),
                      DropdownMenuItem(
                          value: 'danger',
                          child: Text('Danger (Aggressive / Injured)')),
                    ],
                    onChanged: (value) {
                      setState(() => condition = value!);
                      // 🎯 Track condition selection
                      analytics.logEvent(
                        name: 'condition_selected',
                        parameters: {'condition': value ?? 'unknown'},
                      );
                    },
                  ),

                  const SizedBox(height: 24),

                  // Notes
                  const Text(
                    'Notes / Description (optional)',
                    style: TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                        fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    maxLines: 4,
                    onChanged: (value) => description = value,
                    decoration: InputDecoration(
                      hintText: 'Add any additional details...',
                      hintStyle: TextStyle(color: Colors.grey.shade400),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.all(16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                            color: Color(0xFFC4A484), width: 2),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFC4A484),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                      onPressed: () async {
                        if (_formKey.currentState!.validate()) {
                          bool proceed = true;

                          if (dogCount >= 5 && condition == 'lowPresence') {
                            // 🎯 Track mismatch warning shown
                            analytics.logEvent(
                              name: 'condition_mismatch_warning',
                              parameters: {
                                'dog_count': dogCount,
                                'condition': condition,
                              },
                            );

                            proceed = await showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Check your report'),
                                    content: const Text(
                                        'You selected Low Presence but the dog count is high. Do you want to proceed anyway?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () {
                                          // 🎯 Track user chose to fix
                                          analytics.logEvent(
                                            name: 'condition_mismatch_fixed',
                                          );
                                          Navigator.of(context).pop(false);
                                        },
                                        child: const Text('Fix'),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          // 🎯 Track user proceeded anyway
                                          analytics.logEvent(
                                            name: 'condition_mismatch_ignored',
                                          );
                                          Navigator.of(context).pop(true);
                                        },
                                        child: const Text('Submit Anyway'),
                                      ),
                                    ],
                                  ),
                                ) ??
                                false;
                          }

                          if (!proceed) return;

                          final coords = campusLocations[location!]!;

                          try {
                            await firestoreService.addReport(
                              location: location!,
                              dogCount: dogCount,
                              condition: condition,
                              description: description,
                              latitude: coords['lat'],
                              longitude: coords['lng'],
                            );

                            // 🎯 Track successful submission
                            analytics.logEvent(
                              name: 'dog_report_submitted',
                              parameters: {
                                'location': location!,
                                'dog_count': dogCount,
                                'condition': condition,
                                'has_description': description.isNotEmpty,
                              },
                            );

                            if (context.mounted) _showSuccessDialog();
                          } catch (e) {
                            // 🎯 Track submission error
                            analytics.logEvent(
                              name: 'dog_report_error',
                              parameters: {
                                'error_type': 'submission_failed',
                                'error_message': e.toString(),
                              },
                            );

                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Failed to submit report: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        }
                      },
                      child: const Text(
                        'Submit Report',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
