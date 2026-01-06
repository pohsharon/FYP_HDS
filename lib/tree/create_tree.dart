import 'dart:io';
import 'package:intl/intl.dart';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import 'package:fyp_hbs/theme/app_colors.dart';
import 'package:fyp_hbs/services/api/tree_api.dart';
import '../config.dart';
import 'package:another_flushbar/flushbar.dart';
import 'package:uuid/uuid.dart';
import 'package:fyp_hbs/models/tree_model.dart';
import 'package:fyp_hbs/utils/connectivity_helper.dart';
import 'package:fyp_hbs/tree/tree_details.dart';
import 'package:fyp_hbs/services/local%20database/tree_db.dart';

// Formatter that allows decimals and limits fractional digits
// e.g. DecimalTextInputFormatter(decimalRange: 2) allows up to 2 decimals
class DecimalTextInputFormatter extends TextInputFormatter {
  final int decimalRange;

  DecimalTextInputFormatter({this.decimalRange = 2}) : assert(decimalRange >= 0);

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    String text = newValue.text;
    if (text == '') return newValue;

    // Allow only digits and at most one decimal point. We intentionally do
    // not rewrite a leading '.' to '0.' so users can type ".5" without a
    // forced leading zero.
  final regExp = RegExp(r'^\d*\.?\d*$');
    if (!regExp.hasMatch(text)) {
      return oldValue;
    }

    if (decimalRange > 0 && text.contains('.')) {
      final parts = text.split('.');
      if (parts.length > 1 && parts[1].length > decimalRange) {
        return oldValue;
      }
    }

    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}

class CreateTreePage extends StatefulWidget {
  final Map<String, dynamic>? tree;

  const CreateTreePage({super.key, this.tree});

  @override
  _CreateTreePageState createState() => _CreateTreePageState();
}

class _CreateTreePageState extends State<CreateTreePage> {
  final _formKey = GlobalKey<FormState>();
  final plantingDateController = TextEditingController();
  final heightController = TextEditingController();
  final widthController = TextEditingController();
  final floweringPeriodController = TextEditingController();
  final TextEditingController speciesController = TextEditingController();

  List<Map<String, dynamic>> speciesList = [];
  String? selectedSpeciesId;

  File? _selectedImage;
  String? _existingThumbnailPath;

  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchSpecies().then((_) {
      if (widget.tree != null) {
        final tree = widget.tree!;
        plantingDateController.text = tree['planted_at'] ?? '';

        // Don't prefill with a leading 0 — treat null/0 as empty so the
        // user sees a blank input instead of '0' or '0.0'.
        final h = tree['height'];
        if (h == null) {
          heightController.text = '';
        } else if (h is num && h == 0) {
          heightController.text = '';
        } else {
          heightController.text = h.toString();
        }

        final w = tree['width'];
        if (w == null) {
          widthController.text = '';
        } else if (w is num && w == 0) {
          widthController.text = '';
        } else {
          widthController.text = w.toString();
        }

        floweringPeriodController.text =
            tree['flowering_period']?.toString() ?? '';
        selectedSpeciesId = tree['species']?['id']?.toString();
        _existingThumbnailPath = tree['thumbnail'];
      }
    });
  }

  @override
  void dispose() {
    plantingDateController.dispose();
    heightController.dispose();
    widthController.dispose();
    floweringPeriodController.dispose();
    speciesController.dispose();
    super.dispose();
  }

  Future<void> _fetchSpecies() async {
    try {
      final fetchedSpecies = await TreeApi.fetchSpecies();
      if (mounted) {
        setState(() {
          speciesList = fetchedSpecies;
          if (speciesList.isNotEmpty) {
            selectedSpeciesId = speciesList.first['id'].toString();
          }
        });
      }
    } catch (e) {
      if (mounted) {
        Flushbar(
          message: 'Error fetching species: $e',
          icon: const Icon(Icons.error, color: Colors.white),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 3),
          borderRadius: BorderRadius.circular(8),
          margin: const EdgeInsets.all(12),
        ).show(context);
      }
    }
  }

  Future<void> _pickImage() async {
    final online = await ConnectivityHelper.hasInternetConnection();
    if (!online) {
      await Flushbar(
        message: 'No internet — cannot pick image while offline',
        icon: const Icon(Icons.cloud_off, color: Colors.white),
        backgroundColor: Colors.orange.shade700,
        duration: const Duration(seconds: 2),
        borderRadius: BorderRadius.circular(12),
        margin: const EdgeInsets.all(12),
        flushbarPosition: FlushbarPosition.TOP,
      ).show(context);
      return;
    }

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 20,
    );

    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _saveTree() async {
    if (!_formKey.currentState!.validate() || selectedSpeciesId == null) {
      return;
    }

    dynamic createResp;
    try {
      setState(() => isLoading = true);

      // ✅ Check internet status
      final online = await ConnectivityHelper.hasInternetConnection();

      if (online) {
        // 🌐 ONLINE: Send to API as usual
        if (widget.tree == null) {
          createResp = await TreeApi.createTree(
            speciesId: selectedSpeciesId!,
            plantedAt: plantingDateController.text,
            height: double.parse(heightController.text),
            diameter: double.parse(widthController.text),
            floweringPeriod: floweringPeriodController.text,
            imageFile: _selectedImage,
          );
        } else {
          final resp = await TreeApi.updateTree(
            id: widget.tree!['id'].toString(),
            speciesId: selectedSpeciesId!,
            plantedAt: plantingDateController.text,
            height: double.parse(heightController.text),
            diameter: double.parse(widthController.text),
            latitude: (widget.tree != null && widget.tree!['latitude'] != null)
                ? double.tryParse(widget.tree!['latitude'].toString())
                : null,
            longitude: (widget.tree != null && widget.tree!['longitude'] != null)
                ? double.tryParse(widget.tree!['longitude'].toString())
                : null,
            floweringPeriod: floweringPeriodController.text,
            imageFile: _selectedImage,
          );

          // Update local cache so the local SQLite `trees` row reflects the
          // server-side change immediately. Use uuid when available, else id.
            try {
              final uuid = widget.tree!['uuid']?.toString() ?? widget.tree!['id']?.toString();
              if (uuid != null) {
                final changes = <String, dynamic>{
                  'species_id': selectedSpeciesId!,
                  'planted_at': plantingDateController.text,
                  'height': double.tryParse(heightController.text),
                  'diameter': double.tryParse(widthController.text),
                  'flowering_period': int.tryParse(floweringPeriodController.text),
                };

                // If server returned an updated timestamp, persist it locally so
                // future merges can compare timestamps correctly.
                try {
                  final serverUpdated = resp['updated_at'] ?? resp['updatedAt'];
                  if (serverUpdated != null) {
                    changes['updated_at'] = serverUpdated.toString();
                  }
                } catch (_) {}

                await TreeDB().updateTreeByUuid(uuid, changes, markPendingUpdate: false);
              }
            } catch (e) {
            // If local update fails, continue — it's non-fatal and will be
            // reconciled during the next sync.
            print('⚠️ Failed to update local tree row after online update: $e');
          }
        }

        await Flushbar(
          message:
              widget.tree == null
                  ? 'Tree created successfully'
                  : 'Tree updated successfully',
          icon: const Icon(Icons.check_circle, color: Colors.white),
          backgroundColor: Colors.green.shade700,
          duration: const Duration(seconds: 2),
          borderRadius: BorderRadius.circular(12),
          margin: const EdgeInsets.all(12),
          flushbarPosition: FlushbarPosition.TOP,
        ).show(context);

        if (!mounted) return;

        if (widget.tree == null) {
          final createdId = _extractCreatedId(createResp);
          if (createdId != null && createdId.isNotEmpty) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => TreeDetailsPage(
                  treeID: createdId,
                  refreshOnPop: true,
                ),
              ),
            );
          } else {
            Navigator.pop(context, {'refreshList': true});
          }
          return;
        } else {
          final idString =
              widget.tree!['uuid']?.toString() ?? widget.tree!['id']?.toString();
          Navigator.pop(context, {'updatedId': idString, 'refreshList': true});
          return;
        }
      } else {
        // 📴 OFFLINE: Save to Local DB instead. If we are editing an existing tree,
        // update the existing row and mark it as pending update. Otherwise insert a new offline row.
        if (widget.tree != null) {
          // Editing an existing tree while offline -> update local row by uuid
          final uuidExisting =
              widget.tree!['uuid']?.toString() ??
              widget.tree!['id']?.toString() ??
              const Uuid().v4();
          final changes = {
            'tree_tag':
                widget.tree!['tree_tag'] ??
                "Offline-${DateTime.now().millisecondsSinceEpoch}",
            'species_id': selectedSpeciesId!,
            'planted_at': plantingDateController.text,
            'height': double.tryParse(heightController.text),
            'diameter': double.tryParse(widthController.text),
            'flowering_period': int.tryParse(floweringPeriodController.text),
            // Do not clear thumbnail here; imageFile is stored separately in TreeModel.imageFile
          };
          // Mark local row as updated now so UI merge logic can compare timestamps
          changes['updated_at'] = DateTime.now().toIso8601String();

          final updatedRows = await TreeDB().updateTreeByUuid(
            uuidExisting,
            changes,
            markPendingUpdate: true,
          );
          print(
            '🌱 Offline edit saved locally for uuid=$uuidExisting (updated rows: $updatedRows)',
          );

          await Flushbar(
            message: 'No internet — changes saved locally and will be synced',
            icon: const Icon(Icons.cloud_off, color: Colors.white),
            backgroundColor: Colors.orange.shade700,
            duration: const Duration(seconds: 2),
            borderRadius: BorderRadius.circular(12),
            margin: const EdgeInsets.all(12),
            flushbarPosition: FlushbarPosition.TOP,
          ).show(context);

          if (!mounted) return;
          Navigator.pop(
            context,
            {'updatedId': uuidExisting, 'refreshList': true},
          );
          return;
        } else {
          // Creating a new offline tree
          final uuid = const Uuid().v4();
          // Derive a tree tag with the same style as online tags: <prefix>-<sequence>
          // e.g. D197-054 where 'D197' is the species code and sequence is 3 digits.
          String prefix = 'OFF';
          try {
            // Prefer using species code (e.g., D197 for Musang King)
            final found = speciesList.firstWhere((s) => s['id'].toString() == selectedSpeciesId);
            final code = (found['code']?.toString() ?? '').trim();
            if (code.isNotEmpty) {
              prefix = code;
            } else {
              // fallback: use species name initials
              final name = (found['name']?.toString() ?? 'OFF');
              prefix = name.split(' ').map((p) => p.isNotEmpty ? p[0] : '').join().toUpperCase();
            }
          } catch (_) {}

          // Calculate next sequence by scanning ALL existing trees regardless of species
          int nextSeq = 1;
          try {
            final existing = await TreeDB().fetchAllTrees();
            int maxSeq = 0;
            
            // Scan all trees and extract the highest sequence number
            for (final t in existing) {
              final tag = (t.treeTag ?? '').toString();
              if (tag.contains('-')) {
                final parts = tag.split('-');
                final seqStr = parts.last.replaceAll(RegExp(r'[^0-9]'), '');
                final val = int.tryParse(seqStr) ?? 0;
                if (val > maxSeq) maxSeq = val;
              }
            }

            nextSeq = maxSeq + 1;
          } catch (_) {}

          final seqPadded = nextSeq.toString().padLeft(3, '0');
          final derivedTag = '$prefix-$seqPadded';

          final offlineTree = TreeModel(
            uuid: uuid,
            treeTag: derivedTag,
            speciesId: selectedSpeciesId!,
            plantedAt: DateTime.parse(plantingDateController.text),
            height: double.tryParse(heightController.text),
            diameter: double.tryParse(widthController.text),
            floweringPeriod: int.tryParse(floweringPeriodController.text),
            synced: 0,
            imageFile: _selectedImage,
          );

          final insertedId = await TreeDB().insertTree(offlineTree);

          await Flushbar(
            message: 'No internet — tree saved locally',
            icon: const Icon(Icons.cloud_off, color: Colors.white),
            backgroundColor: Colors.orange.shade700,
            duration: const Duration(seconds: 2),
            borderRadius: BorderRadius.circular(12),
            margin: const EdgeInsets.all(12),
            flushbarPosition: FlushbarPosition.TOP,
          ).show(context);

          // Navigate directly to tree details for the newly created offline tree
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => TreeDetailsPage(
                treeID: uuid,
                refreshOnPop: true,
              ),
            ),
          );
          return;
        }
      }
    } catch (e) {
      Flushbar(
        message: 'Error: $e',
        icon: const Icon(Icons.error, color: Colors.white),
        backgroundColor: Colors.red.shade700,
        duration: const Duration(seconds: 3),
        borderRadius: BorderRadius.circular(8),
        margin: const EdgeInsets.all(12),
      ).show(context);
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  // Safely pull a tree id from diverse API response shapes.
  String? _extractCreatedId(dynamic resp) {
    if (resp == null) return null;
    try {
      if (resp is Map) {
        if (resp['id'] != null) return resp['id'].toString();
        if (resp['data'] is Map && resp['data']['id'] != null) {
          return resp['data']['id'].toString();
        }
        if (resp['tree'] is Map && resp['tree']['id'] != null) {
          return resp['tree']['id'].toString();
        }
      }
    } catch (_) {}
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          widget.tree != null ? 'Edit Tree' : 'Add Tree',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: AppColors.pakistanGreen,
        actions: widget.tree != null
            ? [
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.white),
                  onPressed: () async {
                    // Only reachable when editing an existing tree (widget.tree != null)
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Delete Tree'),
                        content: const Text(
                          'Are you sure you want to delete this tree?',
                        ),
                        backgroundColor: Colors.white,
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text(
                              'Delete',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      try {
                        final online =
                            await ConnectivityHelper.hasInternetConnection();
                        if (!online) {
                          await TreeDB().markAsPendingDelete(widget.tree!['uuid']);
                          if (!mounted) return;
                          await Flushbar(
                            message:
                                'Tree will be deleted when you are back online',
                          ).show(context);
                          // Single pop: return true to signal deletion/refresh
                          Navigator.pop(context, true);
                        } else {
                          await TreeApi.deleteTree(widget.tree!['id'].toString());
                          if (!mounted) return;
                          await Flushbar(
                            message: 'Tree deleted successfully',
                            icon: const Icon(Icons.check_circle, color: Colors.white),
                            backgroundColor: Colors.green.shade700,
                            duration: const Duration(seconds: 2),
                            borderRadius: BorderRadius.circular(12),
                            margin: const EdgeInsets.all(12),
                            flushbarPosition: FlushbarPosition.TOP,
                          ).show(context);
                          // Single pop: return true to signal deletion/refresh
                          Navigator.pop(context, true);
                        }
                      } catch (e) {
                        await Flushbar(
                          message: 'Error deleting tree: $e',
                          icon: const Icon(Icons.error, color: Colors.white),
                          backgroundColor: Colors.red.shade700,
                          duration: const Duration(seconds: 3),
                          borderRadius: BorderRadius.circular(8),
                          margin: const EdgeInsets.all(12),
                        ).show(context);
                      }
                    }
                  },
                ),
              ]
            : null,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 20),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              _buildImagePreview(),
              const SizedBox(height: 16),

              LayoutBuilder(
                builder: (context, constraints) {
                  final menuWidth = constraints.maxWidth;
                  return SizedBox(
                    width: double.infinity,
                    child: DropdownMenu<String>(
                      // ensure popup has a reasonable minimum width on larger screens
                      width: max(menuWidth, 360),
                      controller: speciesController,
                      requestFocusOnTap: true,
                      initialSelection: selectedSpeciesId,
                      label: const Text('Species'),
                      dropdownMenuEntries: speciesList
                          .map<DropdownMenuEntry<String>>(
                            (species) => DropdownMenuEntry(
                              value: species['id'].toString(),
                              label: species['name']?.toString() ?? '',
                            ),
                          )
                          .toList(),
                      onSelected: (String? v) {
                        if (v == null) return;
                        setState(() {
                          selectedSpeciesId = v;
                          try {
                            final found = speciesList.firstWhere((s) => s['id'].toString() == v);
                            speciesController.text = found['name']?.toString() ?? '';
                          } catch (_) {
                            speciesController.text = '';
                          }
                        });
                      },
                    ),
                  );
                },
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: plantingDateController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Planting Date',
                  suffixIcon: Icon(Icons.calendar_today),
                  filled: true,
                  fillColor: Colors.white,
                ),
                readOnly: true,
                onTap: () async {
                  final pickedDate = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                  );
                  if (pickedDate != null) {
                    plantingDateController.text = DateFormat(
                      'yyyy-MM-dd',
                    ).format(pickedDate);
                  }
                },
                validator:
                    (value) =>
                        value == null || value.isEmpty
                            ? 'Please pick a date'
                            : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: heightController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Initial Height (m)',
                  hintText: 'e.g. 2.5',
                  filled: true,
                  fillColor: Colors.white,
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [DecimalTextInputFormatter(decimalRange: 2)],
                validator:
                    (value) =>
                        value == null || value.isEmpty ? 'Enter height' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: widthController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Initial Width (m)',
                  hintText: 'e.g. 1.6',
                  filled: true,
                  fillColor: Colors.white,
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [DecimalTextInputFormatter(decimalRange: 2)],
                validator:
                    (value) =>
                        value == null || value.isEmpty ? 'Enter width' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: floweringPeriodController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Flowering Period',
                  filled: true,
                  fillColor: Colors.white,
                ),
                keyboardType: TextInputType.number,
                validator:
                    (value) =>
                        value == null || value.isEmpty
                            ? 'Enter flowering period'
                            : null,
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _saveTree,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.hunterGreen,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text(
                          'Save',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImagePreview() {
    // Use a fixed height container and Stack to allow the close button
    return GestureDetector(
      onTap: _pickImage,
      child: SizedBox(
        height: 180,
        width: double.infinity,
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child:
                  _selectedImage != null
                      ? Image.file(
                        _selectedImage!,
                        height: 180,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      )
                      : (_existingThumbnailPath != null &&
                          _existingThumbnailPath!.isNotEmpty)
                      ? Image.network(
                        _buildFullImageUrl(_existingThumbnailPath!), // ✅ FIXED
                        height: 180,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey[200],
                            height: 180,
                            width: double.infinity,
                            child: const Center(
                              child: Text('Image unavailable'),
                            ),
                          );
                        },
                      )
                      : Container(
                        height: 180,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey),
                        ),
                        child: const Center(child: Text('Tap to select image')),
                      ),
            ),

            if (_selectedImage != null ||
                (_existingThumbnailPath != null &&
                    _existingThumbnailPath!.isNotEmpty))
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedImage = null;
                      _existingThumbnailPath = null; // clear preview
                    });
                  },
                  child: const CircleAvatar(
                    radius: 14,
                    backgroundColor: Colors.black54,
                    child: Icon(Icons.close, color: Colors.white, size: 16),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _buildFullImageUrl(String path) {
    final baseUrl = Config.supabaseBaseUrl;
    return '$baseUrl/$path';
  }
}
