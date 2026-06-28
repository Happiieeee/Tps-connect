import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import '../../core/services/api_service.dart';
import '../../config/api_config.dart';

class CreatePostScreen extends StatefulWidget {
  final String branchId;
  final List<dynamic> classes;
  const CreatePostScreen({
    super.key,
    required this.branchId,
    required this.classes,
  });

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final titleController = TextEditingController();
  final contentController = TextEditingController();
  String selectedCategory = 'homework';
  String? selectedClassId;
  List<String> uploadedFileUrls = [];
  bool isUploading = false;
  bool isPosting = false;

  final List<Map<String, String>> categories = [
    {'value': 'homework', 'label': '📚 Homework'},
    {'value': 'circular', 'label': '📢 Circular'},
    {'value': 'event', 'label': '🎉 Event'},
    {'value': 'photos', 'label': '📷 Photos'},
    {'value': 'holiday', 'label': '🏖️ Holiday'},
  ];

  Future<void> _pickAndUploadFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      allowMultiple: true,
    );

    if (result == null) return;

    setState(() => isUploading = true);

    try {
      for (final file in result.files) {
        if (file.path == null) continue;

        final user = FirebaseAuth.instance.currentUser!;
        final token = await user.getIdToken();

        final request = http.MultipartRequest(
          'POST',
          Uri.parse('${ApiConfig.baseUrl}/uploads'),
        );
        request.headers['Authorization'] = 'Bearer $token';
        request.files.add(await http.MultipartFile.fromPath('file', file.path!));

        final response = await request.send();
        final body = await response.stream.bytesToString();
        final data = jsonDecode(body);

        if (data['url'] != null) {
          setState(() => uploadedFileUrls.add(data['url']));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => isUploading = false);
    }
  }

  Future<void> _submitPost() async {
    if (titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title is required')),
      );
      return;
    }

    setState(() => isPosting = true);

    try {
      await ApiService.post('/posts', {
        'title': titleController.text.trim(),
        'content': contentController.text.trim(),
        'category': selectedCategory,
        'class_id': selectedClassId,
        'file_urls': uploadedFileUrls,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Post created!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to create post'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => isPosting = false);
    }
  }

  @override
  void dispose() {
    titleController.dispose();
    contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Post')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category selector
            const Text('Category', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: categories.map((cat) {
                final selected = selectedCategory == cat['value'];
                return ChoiceChip(
                  label: Text(cat['label']!),
                  selected: selected,
                  onSelected: (_) => setState(() => selectedCategory = cat['value']!),
                  selectedColor: Colors.blue.shade100,
                );
              }).toList(),
            ),

            const SizedBox(height: 16),

            // Target class
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Post to (leave empty for entire branch)',
                border: OutlineInputBorder(),
              ),
              value: selectedClassId,
              items: [
                const DropdownMenuItem(value: null, child: Text('Entire Branch')),
                ...widget.classes.map<DropdownMenuItem<String>>((c) =>
                    DropdownMenuItem(
                      value: c['class_id'].toString(),
                      child: Text(c['class_name']),
                    )),
              ],
              onChanged: (val) => setState(() => selectedClassId = val),
            ),

            const SizedBox(height: 16),

            // Title
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Title *',
                border: OutlineInputBorder(),
              ),
              maxLength: 200,
            ),

            const SizedBox(height: 12),

            // Content
            TextField(
              controller: contentController,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
              maxLines: 4,
            ),

            const SizedBox(height: 16),

            // File attachments
            const Text('Attachments', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 8),

            if (uploadedFileUrls.isNotEmpty)
              ...uploadedFileUrls.asMap().entries.map((entry) => ListTile(
                    leading: const Icon(Icons.attach_file, color: Colors.blue),
                    title: Text(
                      entry.value.split('/').last,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.close, color: Colors.red),
                      onPressed: () =>
                          setState(() => uploadedFileUrls.removeAt(entry.key)),
                    ),
                  )),

            OutlinedButton.icon(
              onPressed: isUploading ? null : _pickAndUploadFile,
              icon: isUploading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.upload_file),
              label: Text(isUploading ? 'Uploading...' : 'Attach File (PDF or Image)'),
            ),

            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isPosting ? null : _submitPost,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: isPosting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Post', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
