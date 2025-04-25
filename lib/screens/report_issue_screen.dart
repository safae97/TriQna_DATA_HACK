import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

class ReportIssueScreen extends StatefulWidget {
  final LatLng userLocation;

  const ReportIssueScreen({Key? key, required this.userLocation}) : super(key: key);
  @override
  State<ReportIssueScreen> createState() => _ReportIssueScreenState();
}

class _ReportIssueScreenState extends State<ReportIssueScreen> {
  final _formKey = GlobalKey<FormState>();
  File? _imageFile;
  bool _isSubmitting = false;
  final ImagePicker _imagePicker = ImagePicker();
  String _description = '';
  String _issueType = 'Pothole';
  String _transportMode = 'Walking';
  LatLng _selectedLocation = const LatLng(0, 0);

  final List<String> _issueTypes = [
    'Pothole',
    'Traffic',
    'Damaged Sign',
    'Flooded Road',
    'Road Cracks',
    'Other'
  ];

  final List<String> _transportModes = [
    'Walking',
    'Cycling',
    'Public Transport',
    'Electric Vehicle',
    'Car',
    'Other'
  ];

  @override
  void initState() {
    super.initState();
    _selectedLocation = widget.userLocation;
  }

  Future<void> _takePhoto() async {
    final XFile? image = await _imagePicker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 85,
    );
    if (image != null) {
      setState(() {
        _imageFile = File(image.path);
      });
    }
  }
  String? _convertImageToBase64() {
    if (_imageFile == null) return null;

    try {
      // Read the image file as bytes
      List<int> imageBytes = _imageFile!.readAsBytesSync();

      // Convert bytes to base64 string
      String base64Image = base64Encode(imageBytes);

      return base64Image;
    } catch (e) {
      print('Error converting image to base64: $e');
      return null;
    }
  }

  Future<void> _pickPhoto() async {
    final XFile? image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 85,
    );
    if (image != null) {
      setState(() {
        _imageFile = File(image.path);
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition();
      setState(() {
        _selectedLocation = LatLng(position.latitude, position.longitude);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location updated successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error getting location: $e')),
      );
    }
  }

  Future<void> _submitReport() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      if (_imageFile == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please add a photo of the issue')),
        );
        return;
      }

      setState(() {
        _isSubmitting = true;
      });

      try {
        // Convert image to base64 string
        String? base64Image = _convertImageToBase64();

        await FirebaseFirestore.instance.collection('roadIssues').add({
          'userId': FirebaseAuth.instance.currentUser!.uid,
          'description': _description,
          'type': _issueType,
          'transportMode': _transportMode,
          'latitude': _selectedLocation.latitude,
          'longitude': _selectedLocation.longitude,
          'imageBase64': base64Image, // Store base64 encoded image
          'timestamp': DateTime.now(),
          'verificationCount': 0,
          'status': 'pending',
        });

        await _addEcoRewards();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Issue reported successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error submitting report: $e')),
        );
      } finally {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<String?> _uploadImage() async {
    if (_imageFile == null) return null;
    try {
      String fileName = 'issue_${DateTime.now().millisecondsSinceEpoch}.jpg';
      Reference storageRef = FirebaseStorage.instance.ref().child('issue_images').child(fileName);
      UploadTask uploadTask = storageRef.putFile(_imageFile!);
      TaskSnapshot snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print('Error uploading image: $e');
      return null;
    }
  }

  Future<void> _addEcoRewards() async {
    String? userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId == null) {
      print('Cannot add eco rewards: No user logged in');
      return;
    }

    int rewardPoints = 0;
    switch (_transportMode) {
      case 'Walking':
        rewardPoints = 20;
        break;
      case 'Cycling':
        rewardPoints = 15;
        break;
      case 'Public Transport':
        rewardPoints = 10;
        break;
      case 'Electric Vehicle':
        rewardPoints = 5;
        break;
      default:
        rewardPoints = 2;
    }

    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).set({
        'ecoPoints': FieldValue.increment(rewardPoints),
      }, SetOptions(merge: true));

      print('Added $rewardPoints eco-points to user $userId');
    } catch (e) {
      print('Error adding eco rewards: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Report Road Issue',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF3498DB),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isSubmitting
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text('Submitting your report...'),
          ],
        ),
      )
          : SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildImagePicker(),
                const SizedBox(height: 20),
                _buildSectionTitle('Issue Type'),
                _buildDropdown(
                  value: _issueType,
                  items: _issueTypes,
                  onChanged: (value) {
                    setState(() {
                      _issueType = value!;
                    });
                  },
                ),
                const SizedBox(height: 20),
                _buildSectionTitle('Description'),
                TextFormField(
                  decoration: InputDecoration(
                    hintText: 'Describe the issue in detail',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: Colors.grey[100],
                  ),
                  maxLines: 3,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a description';
                    }
                    return null;
                  },
                  onSaved: (value) {
                    _description = value ?? '';
                  },
                ),
                const SizedBox(height: 20),
                _buildSectionTitle('Location'),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Lat: ${_selectedLocation.latitude.toStringAsFixed(5)}\nLng: ${_selectedLocation.longitude.toStringAsFixed(5)}',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _getCurrentLocation,
                      icon: const Icon(Icons.my_location),
                      label: const Text('Update'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3498DB),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildSectionTitle('Transport Mode (Earn eco-rewards!)'),
                _buildDropdown(
                  value: _transportMode,
                  items: _transportModes,
                  onChanged: (value) {
                    setState(() {
                      _transportMode = value!;
                    });
                  },
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _submitReport,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2ECC71),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'SUBMIT REPORT',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String value,
    required List<String> items,
    required void Function(String?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey[100],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          items: items.map((String item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(item),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildImagePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Add Photo'),
        Container(
          height: 200,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: _imageFile == null
              ? Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.add_a_photo,
                size: 50,
                color: Colors.grey,
              ),
              const SizedBox(height: 10),
              const Text(
                'Tap to add a photo of the issue',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: _takePhoto,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Camera'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3498DB),
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 20),
                  ElevatedButton.icon(
                    onPressed: _pickPhoto,
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Gallery'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3498DB),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          )
              : Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  _imageFile!,
                  width: double.infinity,
                  height: 200,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _imageFile = null;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}