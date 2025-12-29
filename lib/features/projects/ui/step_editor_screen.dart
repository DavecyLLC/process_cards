import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/widgets/fullscreen_image_viewer.dart';
import '../data/models/project.dart';
import '../data/models/step_item.dart';
import '../logic/steps_controller.dart';

class StepEditorScreen extends ConsumerStatefulWidget {
  final Project project;
  final StepItem? step;

  const StepEditorScreen({
    super.key,
    required this.project,
    this.step,
  });

  @override
  ConsumerState<StepEditorScreen> createState() => _StepEditorScreenState();
}

class _StepEditorScreenState extends ConsumerState<StepEditorScreen> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _picker = ImagePicker();

  File? _pickedImage;
  bool _removeExistingImage = false;

  @override
  void initState() {
    super.initState();
    _title.text = widget.step?.title ?? '';
    _desc.text = widget.step?.description ?? '';
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _pickFromCamera() async {
    final x = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (x == null) return;

    setState(() {
      _pickedImage = File(x.path);
      _removeExistingImage = false;
    });
  }

  Future<void> _pickFromGallery() async {
    final x = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (x == null) return;

    setState(() {
      _pickedImage = File(x.path);
      _removeExistingImage = false;
    });
  }

  Future<void> _save() async {
    final stepsCtl = ref.read(stepsControllerProvider(widget.project.uid).notifier);

    if (widget.step != null) {
      await stepsCtl.updateStep(
        project: widget.project,
        step: widget.step!,
        title: _title.text,
        description: _desc.text,
        newPickedImage: _pickedImage,
        removeImage: _removeExistingImage,
      );
    } else {
      await stepsCtl.addStep(
        project: widget.project,
        title: _title.text,
        description: _desc.text,
        pickedImage: _pickedImage,
      );
    }

    if (mounted) Navigator.pop(context);
  }

  void _dismissKeyboard() => FocusManager.instance.primaryFocus?.unfocus();

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.step != null;
    final stepNo = isEdit ? (widget.step!.order + 1) : null;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _dismissKeyboard,
      child: Scaffold(
        appBar: AppBar(
          title: Text(isEdit ? 'Edit Step' : 'New Step'),
          actions: [
            TextButton(
              onPressed: _save,
              child: const Text('Save'),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(12),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEdit ? 'Step $stepNo' : 'Step',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _title,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Step title',
                        hintText: 'e.g., Prepare materials',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _desc,
                      maxLines: 6,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        hintText: 'Describe this step…',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Photo', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _pickFromCamera,
                            icon: const Icon(Icons.photo_camera_outlined),
                            label: const Text('Camera'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _pickFromGallery,
                            icon: const Icon(Icons.photo_library_outlined),
                            label: const Text('Gallery'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (widget.step?.imagePath != null && _pickedImage == null)
                      SwitchListTile(
                        value: _removeExistingImage,
                        onChanged: (v) => setState(() => _removeExistingImage = v),
                        title: const Text('Remove existing image'),
                      ),
                    const SizedBox(height: 8),
                    _preview(context),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _preview(BuildContext context) {
    if (_pickedImage != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.file(
          _pickedImage!,
          height: 220,
          width: double.infinity,
          fit: BoxFit.cover,
        ),
      );
    }

    final existingPath = widget.step?.imagePath;
    final hasExisting = existingPath != null && existingPath.isNotEmpty && !_removeExistingImage;

    if (hasExisting) {
      final heroTag = 'step-image-${widget.step!.uid}';

      return GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => FullscreenImageViewer(
                imagePath: existingPath!,
                heroTag: heroTag,
              ),
            ),
          );
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Hero(
            tag: heroTag,
            child: Image.file(
              File(existingPath!),
              height: 220,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) {
                return Container(
                  height: 220,
                  alignment: Alignment.center,
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: const Icon(Icons.broken_image_outlined),
                );
              },
            ),
          ),
        ),
      );
    }

    return Container(
      height: 220,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(Icons.image_outlined, size: 42),
    );
  }
}
