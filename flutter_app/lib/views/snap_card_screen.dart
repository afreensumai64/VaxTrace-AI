// VaxTrace AI — SnapCard OCR Screen
// Camera → ML Kit OCR → Auto-fill child registration form

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/providers.dart';
import '../models/child.dart';
import '../services/ocr_service.dart';
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
  final _vaccineCtrl = TextEditingController();
  DateTime? _lastDoseDate;
  DateTime? _dateOfBirth;
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _guardianCtrl.dispose();
    _phoneCtrl.dispose();
    _villageCtrl.dispose();
    _distanceCtrl.dispose();
    _vaccineCtrl.dispose();
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

    _applyOcrResult();
  }

  void _applyOcrResult() {
    final result = ref.read(ocrNotifierProvider).result;
    if (result == null) return;
    if (result.childName != null) _nameCtrl.text = result.childName!;
    if (result.guardianName != null) _guardianCtrl.text = result.guardianName!;
    if (result.vaccineName != null) _vaccineCtrl.text = result.vaccineName!;
    setState(() {
      if (result.lastDoseDate != null) _lastDoseDate = result.lastDoseDate;
      if (result.dateOfBirth != null) _dateOfBirth = result.dateOfBirth;
    });
  }

  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    setState(() => _capturedImage = File(picked.path));
    final ocrNotifier = ref.read(ocrNotifierProvider.notifier);
    await ocrNotifier.scan(_capturedImage!);
    _applyOcrResult();
  }

  Future<void> _saveChild() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final child = Child.createNew(
        name: _nameCtrl.text.trim(),
        dateOfBirth: _dateOfBirth ?? DateTime.now().subtract(const Duration(days: 365)),
        guardianName: _guardianCtrl.text.trim(),
        guardianPhone: _phoneCtrl.text.trim(),
        villageId: _villageCtrl.text.trim().toLowerCase().replaceAll(' ', '_'),
        villageName: _villageCtrl.text.trim(),
        distanceFromClinicKm: double.tryParse(_distanceCtrl.text) ?? 0,
      );

      final finalChild = child.copyWith(
        lastDoseDate: _lastDoseDate,
        lastVaccineName: _vaccineCtrl.text.trim().isNotEmpty ? _vaccineCtrl.text.trim() : null,
      );

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

              // OCR confirm card
              if (ocrState.result != null) ...[
                const SizedBox(height: 14),
                _OcrConfirmCard(result: ocrState.result!),
              ],
              if (ocrState.error != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: VaxColors.riskCritical.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: VaxColors.riskCritical.withOpacity(0.4)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.error_outline, color: VaxColors.riskCritical, size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text('OCR failed — fill form manually',
                        style: const TextStyle(color: VaxColors.riskCritical, fontSize: 12))),
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
              _buildField(_vaccineCtrl, 'Last Vaccine Given', Icons.vaccines),
              const SizedBox(height: 12),

              // Date of birth
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _dateOfBirth ?? DateTime.now().subtract(const Duration(days: 365)),
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
                  if (picked != null) setState(() => _dateOfBirth = picked);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
                  decoration: BoxDecoration(
                    color: VaxColors.surfaceLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(children: [
                    const Icon(Icons.cake, color: VaxColors.electricCyan, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _dateOfBirth != null
                            ? 'Date of Birth: ${_dateOfBirth!.day}/${_dateOfBirth!.month}/${_dateOfBirth!.year}'
                            : 'Date of Birth (optional)',
                        style: TextStyle(
                          color: _dateOfBirth != null ? VaxColors.white : VaxColors.textSecondary,
                        ),
                      ),
                    ),
                    const Icon(Icons.calendar_today, color: VaxColors.textSecondary, size: 18),
                  ]),
                ),
              ),
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

// ─────────────────────────────────────────────
// OCR Confirm Card — shows extracted fields with tick marks
// ─────────────────────────────────────────────

class _OcrConfirmCard extends StatelessWidget {
  final OcrResult result;
  const _OcrConfirmCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final fields = <({String label, String? value})>[
      (label: 'Child Name', value: result.childName),
      (label: 'Guardian', value: result.guardianName),
      (label: 'Vaccine', value: result.vaccineName),
      (label: 'Last Dose', value: result.lastDoseDate != null
          ? '${result.lastDoseDate!.day}/${result.lastDoseDate!.month}/${result.lastDoseDate!.year}'
          : null),
      (label: 'Date of Birth', value: result.dateOfBirth != null
          ? '${result.dateOfBirth!.day}/${result.dateOfBirth!.month}/${result.dateOfBirth!.year}'
          : null),
    ];
    final extracted = fields.where((f) => f.value != null).toList();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: VaxColors.riskLow.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: VaxColors.riskLow.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.auto_awesome, color: VaxColors.electricCyan, size: 16),
            const SizedBox(width: 6),
            Text(
              extracted.isEmpty
                  ? 'OCR complete — fill fields manually'
                  : 'OCR extracted ${extracted.length} field${extracted.length == 1 ? "" : "s"} — review below',
              style: const TextStyle(
                  color: VaxColors.electricCyan,
                  fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ]),
          if (extracted.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...extracted.map((f) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(children: [
                const Icon(Icons.check_circle, color: VaxColors.riskLow, size: 14),
                const SizedBox(width: 6),
                Text('${f.label}: ',
                    style: const TextStyle(color: VaxColors.textSecondary, fontSize: 12)),
                Expanded(
                  child: Text(f.value!,
                      style: const TextStyle(color: VaxColors.white,
                          fontWeight: FontWeight.w600, fontSize: 12),
                      overflow: TextOverflow.ellipsis),
                ),
              ]),
            )),
            const SizedBox(height: 6),
            const Text('Fields auto-filled below — edit if incorrect',
                style: TextStyle(color: VaxColors.textSecondary, fontSize: 11)),
          ],
        ],
      ),
    );
  }
}
