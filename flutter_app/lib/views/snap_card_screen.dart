// VaxTrace AI — SnapCard OCR Screen
// Camera → ML Kit OCR → Auto-fill child registration form

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/providers.dart';
import '../models/child.dart';
import '../theme.dart';

class SnapCardScreen extends ConsumerStatefulWidget {
  const SnapCardScreen({super.key});
  @override
  ConsumerState<SnapCardScreen> createState() => _SnapCardScreenState();
}

class _SnapCardScreenState extends ConsumerState<SnapCardScreen> {
  File? _capturedImage;
  final _nameCtrl = TextEditingController();
  final _guardianCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _villageCtrl = TextEditingController();
  final _distanceCtrl = TextEditingController(text: '0');
  DateTime? _lastDoseDate;
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _guardianCtrl.dispose();
    _phoneCtrl.dispose();
    _villageCtrl.dispose();
    _distanceCtrl.dispose();
    super.dispose();
  }

  Future<void> _captureImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 90,
      preferredCameraDevice: CameraDevice.rear,
    );
    if (picked == null) return;

    setState(() => _capturedImage = File(picked.path));

    // Run OCR
    final ocrNotifier = ref.read(ocrNotifierProvider.notifier);
    await ocrNotifier.scan(_capturedImage!);

    // Auto-fill form
    final ocrState = ref.read(ocrNotifierProvider);
    if (ocrState.result != null) {
      if (ocrState.result!.childName != null) {
        _nameCtrl.text = ocrState.result!.childName!;
      }
      if (ocrState.result!.lastDoseDate != null) {
        setState(() => _lastDoseDate = ocrState.result!.lastDoseDate);
      }
    }
  }

  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    setState(() => _capturedImage = File(picked.path));
    final ocrNotifier = ref.read(ocrNotifierProvider.notifier);
    await ocrNotifier.scan(_capturedImage!);
    final ocrState = ref.read(ocrNotifierProvider);
    if (ocrState.result?.childName != null) _nameCtrl.text = ocrState.result!.childName!;
    if (ocrState.result?.lastDoseDate != null) {
      setState(() => _lastDoseDate = ocrState.result!.lastDoseDate);
    }
  }

  Future<void> _saveChild() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final child = Child.createNew(
        name: _nameCtrl.text.trim(),
        dateOfBirth: DateTime.now().subtract(const Duration(days: 365)),
        guardianName: _guardianCtrl.text.trim(),
        guardianPhone: _phoneCtrl.text.trim(),
        villageId: _villageCtrl.text.trim().toLowerCase().replaceAll(' ', '_'),
        villageName: _villageCtrl.text.trim(),
        distanceFromClinicKm: double.tryParse(_distanceCtrl.text) ?? 0,
      );

      // Apply last dose date if captured
      final finalChild = _lastDoseDate != null
          ? child.copyWith(lastDoseDate: _lastDoseDate)
          : child;

      await ref.read(childrenProvider.notifier).addChild(finalChild);

      // Speak confirmation
      final lang = ref.read(languageProvider);
      final tts = ref.read(ttsServiceProvider);
      await tts.setLanguage(lang);
      await tts.speakVaccineReminder(finalChild);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${finalChild.name} registered successfully!'),
            backgroundColor: VaxColors.riskLow,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'),
            backgroundColor: VaxColors.riskCritical),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ocrState = ref.watch(ocrNotifierProvider);

    return Scaffold(
      backgroundColor: VaxColors.deepNavy,
      appBar: AppBar(
        title: Row(children: [
          const Icon(Icons.document_scanner, color: VaxColors.electricCyan, size: 22),
          const SizedBox(width: 8),
          const Text('SnapCard OCR'),
        ]),
        backgroundColor: VaxColors.navyDark,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Camera preview card
              GestureDetector(
                onTap: _captureImage,
                child: Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: VaxColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: ocrState.isProcessing
                          ? VaxColors.electricCyan
                          : VaxColors.navyLight,
                      width: 2,
                    ),
                  ),
                  child: _capturedImage != null
                      ? Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Image.file(_capturedImage!, fit: BoxFit.cover)),
                            if (ocrState.isProcessing)
                              Container(
                                decoration: BoxDecoration(
                                  color: VaxColors.deepNavy.withOpacity(0.7),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    CircularProgressIndicator(
                                        color: VaxColors.electricCyan),
                                    SizedBox(height: 12),
                                    Text('Extracting data...',
                                        style: TextStyle(
                                            color: VaxColors.electricCyan,
                                            fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                          ],
                        )
                      : const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.camera_alt,
                                color: VaxColors.electricCyan, size: 48),
                            SizedBox(height: 8),
                            Text('Tap to scan vaccination card',
                                style: TextStyle(color: VaxColors.textSecondary)),
                            Text('ML Kit OCR extracts details automatically',
                                style: TextStyle(
                                    color: VaxColors.textSecondary, fontSize: 12)),
                          ],
                        ),
                ),
              ),

              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: VaxColors.electricCyan,
                      side: const BorderSide(color: VaxColors.electricCyan),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _captureImage,
                    icon: const Icon(Icons.camera_alt, size: 18),
                    label: const Text('Camera'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: VaxColors.cyanLight,
                      side: const BorderSide(color: VaxColors.cyanLight),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _pickFromGallery,
                    icon: const Icon(Icons.photo_library, size: 18),
                    label: const Text('Gallery'),
                  ),
                ),
              ]),

              // OCR result banner
              if (ocrState.result != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: VaxColors.riskLow.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: VaxColors.riskLow.withOpacity(0.4)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.check_circle,
                        color: VaxColors.riskLow, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'OCR extracted: ${ocrState.result!.childName ?? "name"}'
                        '${ocrState.result!.lastDoseDate != null ? " · ${ocrState.result!.lastDoseDate!.day}/${ocrState.result!.lastDoseDate!.month}/${ocrState.result!.lastDoseDate!.year}" : ""}',
                        style: const TextStyle(
                            color: VaxColors.riskLow, fontSize: 13),
                      ),
                    ),
                  ]),
                ),
              ],

              const SizedBox(height: 24),
              const Text('Child Details',
                  style: TextStyle(
                      color: VaxColors.electricCyan,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      letterSpacing: 1)),
              const SizedBox(height: 12),

              _buildField(_nameCtrl, 'Child Name *', Icons.person,
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null),
              const SizedBox(height: 12),
              _buildField(_guardianCtrl, 'Guardian Name *', Icons.supervised_user_circle,
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null),
              const SizedBox(height: 12),
              _buildField(_phoneCtrl, 'Guardian Phone *', Icons.phone,
                  keyboard: TextInputType.phone,
                  validator: (v) => v == null || v.length < 10 ? 'Enter valid phone' : null),
              const SizedBox(height: 12),
              _buildField(_villageCtrl, 'Village / Area *', Icons.location_on,
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null),
              const SizedBox(height: 12),
              _buildField(_distanceCtrl, 'Distance from Clinic (km)',
                  Icons.directions_walk, keyboard: TextInputType.number),
              const SizedBox(height: 12),

              // Last dose date
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _lastDoseDate ?? DateTime.now(),
                    firstDate: DateTime(2010),
                    lastDate: DateTime.now(),
                    builder: (ctx, child) => Theme(
                      data: ThemeData.dark().copyWith(
                        colorScheme: const ColorScheme.dark(
                          primary: VaxColors.electricCyan,
                          surface: VaxColors.surface,
                        ),
                      ),
                      child: child!,
                    ),
                  );
                  if (picked != null) setState(() => _lastDoseDate = picked);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
                  decoration: BoxDecoration(
                    color: VaxColors.surfaceLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(children: [
                    const Icon(Icons.vaccines, color: VaxColors.electricCyan, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _lastDoseDate != null
                            ? 'Last Dose: ${_lastDoseDate!.day}/${_lastDoseDate!.month}/${_lastDoseDate!.year}'
                            : 'Last Dose Date (optional)',
                        style: TextStyle(
                          color: _lastDoseDate != null
                              ? VaxColors.white : VaxColors.textSecondary,
                        ),
                      ),
                    ),
                    const Icon(Icons.calendar_today,
                        color: VaxColors.textSecondary, size: 18),
                  ]),
                ),
              ),

              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveChild,
                  icon: _isSaving
                      ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: VaxColors.deepNavy))
                      : const Icon(Icons.save),
                  label: const Text('Save Child Record',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(
    TextEditingController ctrl, String label, IconData icon, {
    TextInputType keyboard = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboard,
      style: const TextStyle(color: VaxColors.white),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: VaxColors.electricCyan, size: 20),
      ),
    );
  }
}
