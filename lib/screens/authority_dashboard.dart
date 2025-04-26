// lib/screens/authority_dashboard.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:open_file/open_file.dart';
import 'package:intl/intl.dart';
import '../models/road_issue.dart';
import '../models/authority_model.dart';
import '../services/authority_service.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';

// Define the color palette as constants
class AppColors {
  static const primaryColor = Color(0xFF20522F); // Dark green
  static const secondaryColor = Color(0xFF4D9C2D); // Light green
  static const white = Colors.white;
  static const lightGreen = Color(0xFFE8F5E9); // Light background
}

class AuthorityDashboard extends StatefulWidget {
  final Authority authority;

  const AuthorityDashboard({Key? key, required this.authority}) : super(key: key);

  @override
  _AuthorityDashboardState createState() => _AuthorityDashboardState();
}

class _AuthorityDashboardState extends State<AuthorityDashboard> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late AuthorityService _authorityService;
  String? _selectedType;
  String? _selectedTransportMode;
  int _minVerifications = 0;

  // For map filtering
  double _filterRadius = 5.0; // km
  LatLng? _filterCenter;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _authorityService = AuthorityService(authorityId: widget.authority.uid);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primaryColor,
        foregroundColor: AppColors.white, // Text color
        elevation: 2,
        title: Text(
          'Authority Dashboard - ${widget.authority.jurisdiction}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.white,
          labelColor: AppColors.white,
          unselectedLabelColor: AppColors.white.withOpacity(0.7),
          tabs: const [
            Tab(icon: Icon(Icons.list), text: 'Issues'),
            Tab(icon: Icon(Icons.map), text: 'Map View'),
            Tab(icon: Icon(Icons.analytics), text: 'Analytics'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              AuthService().signOut();
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
            },
          ),
        ],
      ),
      body: Container(
        color: AppColors.lightGreen.withOpacity(0.3), // Light background color
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildIssuesList(),
            _buildMapView(),
            _buildAnalyticsView(),
          ],
        ),
      ),
    );
  }

  Widget _buildIssuesList() {
    return Column(
      children: [
        _buildFilters(),
        Expanded(
          child: StreamBuilder<List<RoadIssue>>(
            stream: _getFilteredIssuesStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: AppColors.secondaryColor));
              }

              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              final issues = snapshot.data ?? [];

              if (issues.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.warning_amber_rounded, size: 48, color: AppColors.primaryColor.withOpacity(0.6)),
                      const SizedBox(height: 16),
                      const Text('No issues found.', style: TextStyle(fontSize: 16, color: AppColors.primaryColor)),
                    ],
                  ),
                );
              }

              return ListView.builder(
                itemCount: issues.length,
                itemBuilder: (context, index) {
                  final issue = issues[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      title: Text(
                        '${issue.type}: ${issue.description}',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryColor),
                      ),
                      subtitle: Text(
                        'Location: (${issue.latitude.toStringAsFixed(4)}, ${issue.longitude.toStringAsFixed(4)})\n'
                            'Reported: ${_formatDate(issue.timestamp)}\n'
                            'Transport: ${issue.transportMode} • Verifications: ${issue.verificationCount}',
                      ),
                      isThreeLine: true,
                      trailing: PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, color: AppColors.secondaryColor),
                        onSelected: (value) => _updateIssueStatus(issue.id, value),
                        itemBuilder: (context) => [
                          const PopupMenuItem(value: 'pending', child: Text('Mark Pending')),
                          const PopupMenuItem(value: 'in_progress', child: Text('Mark In Progress')),
                          const PopupMenuItem(value: 'resolved', child: Text('Mark Resolved')),
                        ],
                      ),
                      onTap: () => _showIssueDetailsDialog(issue),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Stream<List<RoadIssue>> _getFilteredIssuesStream() {
    // Apply filters based on selected criteria
    if (_selectedType != null) {
      return _authorityService.getIssuesByType(_selectedType!);
    } else if (_selectedTransportMode != null) {
      return _authorityService.getIssuesByTransportMode(_selectedTransportMode!);
    } else if (_minVerifications > 0) {
      return _authorityService.getIssuesByMinVerification(_minVerifications);
    } else {
      return _authorityService.getAllIssues();
    }
  }

  Widget _buildFilters() {
    return Card(
      margin: const EdgeInsets.all(8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      elevation: 2,
      color: AppColors.white,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Filter Issues:',
              style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryColor, fontSize: 16),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // Type filter
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.secondaryColor.withOpacity(0.4)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: DropdownButton<String>(
                      hint: const Text('Type', style: TextStyle(color: AppColors.primaryColor)),
                      value: _selectedType,
                      underline: const SizedBox(), // Remove underline
                      icon: const Icon(Icons.arrow_drop_down, color: AppColors.secondaryColor),
                      onChanged: (value) {
                        setState(() {
                          _selectedType = value;
                          _selectedTransportMode = null; // Reset other filters
                          _minVerifications = 0;
                        });
                      },
                      items: const [
                        DropdownMenuItem(value: 'Pothole', child: Text('Potholes')),
                        DropdownMenuItem(value: 'Road Cracks', child: Text('Road Cracks')),
                        DropdownMenuItem(value: 'Damaged Sign', child: Text('Damaged Sign')),
                        DropdownMenuItem(value: 'Flooded Road', child: Text('Flooding')),
                        DropdownMenuItem(value: 'Traffic', child: Text('Traffic Issues')),
                        DropdownMenuItem(value: 'Other', child: Text('Other Issues')),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Transport mode filter
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.secondaryColor.withOpacity(0.4)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: DropdownButton<String>(
                      hint: const Text('Transport Mode', style: TextStyle(color: AppColors.primaryColor)),
                      value: _selectedTransportMode,
                      underline: const SizedBox(), // Remove underline
                      icon: const Icon(Icons.arrow_drop_down, color: AppColors.secondaryColor),
                      onChanged: (value) {
                        setState(() {
                          _selectedTransportMode = value;
                          _selectedType = null; // Reset other filters
                          _minVerifications = 0;
                        });
                      },
                      items: const [
                        DropdownMenuItem(value: 'Car', child: Text('Car')),
                        DropdownMenuItem(value: 'Cycling', child: Text('Bicycle')),
                        DropdownMenuItem(value: 'Electric Vehicle', child: Text('Electric Vehicle')),
                        DropdownMenuItem(value: 'Public Transport', child: Text('Public Transport')),
                        DropdownMenuItem(value: 'Other', child: Text('Others')),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Verification filter
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.secondaryColor.withOpacity(0.4)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: DropdownButton<int>(
                      hint: const Text('Min Verifications', style: TextStyle(color: AppColors.primaryColor)),
                      value: _minVerifications > 0 ? _minVerifications : null,
                      underline: const SizedBox(), // Remove underline
                      icon: const Icon(Icons.arrow_drop_down, color: AppColors.secondaryColor),
                      onChanged: (value) {
                        setState(() {
                          _minVerifications = value ?? 0;
                          _selectedType = null; // Reset other filters
                          _selectedTransportMode = null;
                        });
                      },
                      items: [1, 2, 5, 10].map((int val) {
                        return DropdownMenuItem<int>(
                          value: val,
                          child: Text('$val+'),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Clear filters button
                  TextButton.icon(
                    icon: const Icon(Icons.clear, color: AppColors.secondaryColor),
                    label: const Text('Clear Filters', style: TextStyle(color: AppColors.secondaryColor)),
                    style: TextButton.styleFrom(
                      backgroundColor: AppColors.lightGreen,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () {
                      setState(() {
                        _selectedType = null;
                        _selectedTransportMode = null;
                        _minVerifications = 0;
                      });
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapView() {
    return StreamBuilder<List<RoadIssue>>(
      stream: _authorityService.getAllIssues(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.secondaryColor));
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final issues = snapshot.data ?? [];

        return Stack(
          children: [
            FlutterMap(
              options: MapOptions(
                initialCenter: issues.isNotEmpty
                    ? LatLng(issues.first.latitude, issues.first.longitude)
                    : LatLng(37.7749, -122.4194), // San Francisco fallback
                initialZoom: 13.0,
                onTap: (tapPosition, point) {
                  setState(() {
                    _filterCenter = point;
                  });
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                  subdomains: const ['a', 'b', 'c'],
                ),
                MarkerLayer(
                  markers: issues.map((issue) {
                    // Keep original color logic for markers
                    Color markerColor;
                    switch (issue.type) {
                      case 'Pothole':
                        markerColor = Colors.red;
                        break;
                      case 'Traffic':
                        markerColor = Colors.orange;
                        break;
                      case 'Damaged Sign':
                        markerColor = Colors.yellow[700] ?? Colors.yellow;
                        break;
                      case 'Flooded Road':
                        markerColor = Colors.lightBlue;
                        break;
                      case 'Road Cracks':
                        markerColor = Colors.purple;
                        break;
                      default:
                        markerColor = Colors.grey;
                    }

                    return Marker(
                      point: LatLng(issue.latitude, issue.longitude),
                      width: 80,
                      height: 80,
                      child: GestureDetector(
                        onTap: () => _showIssueDetailsDialog(issue),
                        child: Column(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: markerColor, // Keep original marker colors
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              padding: const EdgeInsets.all(8),
                              child: Text(
                                issue.verificationCount.toString(),
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const Icon(Icons.arrow_drop_down, color: Colors.black),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                if (_filterCenter != null)
                  CircleLayer(
                    circles: [
                      CircleMarker(
                        point: _filterCenter!,
                        radius: _filterRadius * 1000,
                        color: AppColors.secondaryColor.withOpacity(0.2),
                        borderColor: AppColors.secondaryColor,
                        borderStrokeWidth: 2,
                      ),
                    ],
                  ),
              ],
            ),


          ],
        );
      },
    );
  }

  Widget _buildNearbyIssuesList(List<RoadIssue> nearbyIssues) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Issues within ${_filterRadius.toStringAsFixed(1)} km',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.primaryColor),
          ),
          const Divider(color: AppColors.secondaryColor),
          const SizedBox(height: 8),
          Expanded(
            child: nearbyIssues.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.location_off, size: 48, color: AppColors.primaryColor.withOpacity(0.5)),
                  const SizedBox(height: 16),
                  const Text('No issues found in this area.', style: TextStyle(color: AppColors.primaryColor)),
                ],
              ),
            )
                : ListView.builder(
              itemCount: nearbyIssues.length,
              itemBuilder: (context, index) {
                final issue = nearbyIssues[index];
                return ListTile(
                  title: Text(issue.type, style: const TextStyle(color: AppColors.primaryColor)),
                  subtitle: Text(issue.description),
                  trailing: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.secondaryColor,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${issue.verificationCount}',
                      style: const TextStyle(color: AppColors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context); // Close bottom sheet
                    _showIssueDetailsDialog(issue);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsView() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _getAnalyticsData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.secondaryColor));
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final data = snapshot.data ?? {};
        final typeCounts = data['typeCounts'] as Map<String, int>?;
        final hotspots = data['hotspots'] as List<Map<String, dynamic>>?;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Analytics Dashboard',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primaryColor),
              ),
              const SizedBox(height: 16),

              // Issues by type
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.pie_chart, color: AppColors.primaryColor),
                          SizedBox(width: 8),
                          Text(
                            'Issues by Type',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryColor),
                          ),
                        ],
                      ),
                      const Divider(color: AppColors.secondaryColor),
                      const SizedBox(height: 16),
                      if (typeCounts != null && typeCounts.isNotEmpty)
                        ...typeCounts.entries.map((entry) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(child: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w500))),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppColors.secondaryColor,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        entry.value.toString(),
                                        style: const TextStyle(color: AppColors.white, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                LinearProgressIndicator(
                                  value: entry.value / typeCounts.values.reduce((a, b) => a > b ? a : b),
                                  backgroundColor: Colors.grey[200],
                                  valueColor: AlwaysStoppedAnimation<Color>(_getColorForType(entry.key)), // Keep original color logic
                                  minHeight: 8,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ],
                            ),
                          );
                        }).toList()
                      else
                        const Text('No data available'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Hotspots
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.location_on, color: AppColors.primaryColor),
                          SizedBox(width: 8),
                          Text(
                            'Top Issue Hotspots',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryColor),
                          ),
                        ],
                      ),
                      const Divider(color: AppColors.secondaryColor),
                      const SizedBox(height: 16),
                      if (hotspots != null && hotspots.isNotEmpty)
                        ...hotspots.take(5).map((hotspot) {
                          return Card(
                            elevation: 1,
                            margin: const EdgeInsets.only(bottom: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(color: AppColors.secondaryColor.withOpacity(0.3)),
                            ),
                            child: ListTile(
                              leading: Container(
                                decoration: const BoxDecoration(
                                  color: Colors.red, // Keep red for hotspots
                                  shape: BoxShape.circle,
                                ),
                                padding: const EdgeInsets.all(8),
                                child: Text(
                                  hotspot['count'].toString(),
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                              title: Text(
                                'Location (${hotspot['latitude'].toStringAsFixed(4)}, ${hotspot['longitude'].toStringAsFixed(4)})',
                                style: const TextStyle(fontWeight: FontWeight.w500),
                              ),
                              subtitle: Text('${hotspot['count']} issues reported'),
                              trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.secondaryColor),
                              onTap: () {
                                // Navigate to map and center on this location
                                _tabController.animateTo(1); // Switch to map tab
                                setState(() {
                                  _filterCenter = LatLng(hotspot['latitude'], hotspot['longitude']);
                                  _filterRadius = 1.0; // Start with a small radius
                                });
                              },
                            ),
                          );
                        }).toList()
                      else
                        const Text('No hotspots identified'),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Export options
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.file_download, color: AppColors.primaryColor),
                          SizedBox(width: 8),
                          Text(
                            'Export Reports',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryColor),
                          ),
                        ],
                      ),
                      const Divider(color: AppColors.secondaryColor),
                      const SizedBox(height: 16),
                      Center(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.picture_as_pdf),
                          label: const Text('PDF Report'),
                          style: ElevatedButton.styleFrom(
                            foregroundColor: AppColors.white,
                            backgroundColor: AppColors.primaryColor,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () => _generateAndDownloadPdfReport(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<Map<String, dynamic>> _getAnalyticsData() async {
    // Get type counts
    final typeCounts = await _authorityService.getMostReportedTypes();

    // Get hotspots (areas with high concentration of issues)
    final hotspots = await _authorityService.getHotspotAreas(100); // Grid size parameter

    return {
      'typeCounts': typeCounts,
      'hotspots': hotspots,
    };
  }

  Color _getColorForType(String type) {
    // Keep original color logic for issue types
    switch (type.toLowerCase()) {
      case 'pothole':
        return Colors.red;
      case 'road cracks':
        return Colors.orange;
      case 'damaged sign':
        return Colors.yellow[700] ?? Colors.yellow;
      case 'flooded road':
        return Colors.lightBlue;
      case 'traffic':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  void _showIssueDetailsDialog(RoadIssue issue) {
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
        title: Text(issue.type),
        content: SingleChildScrollView(
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
            Text('Description: ${issue.description}'),
            const SizedBox(height: 8),
            Text('Location: (${issue.latitude.toStringAsFixed(6)}, ${issue.longitude.toStringAsFixed(6)})'),
            const SizedBox(height: 8),
            Text('Reported: ${_formatDate(issue.timestamp)}'),
            const SizedBox(height: 8),
            Text('Transport Mode: ${issue.transportMode}'),
            const SizedBox(height: 8),
            Text('Verifications: ${issue.verificationCount}'),
            const SizedBox(height: 8),
            Text('Reported by: ${issue.userId}'),
            const SizedBox(height: 16),
            if (issue.imageBase64 != null)
        Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        const Text('Image:', style: TextStyle(fontWeight: FontWeight.bold)),
    const SizedBox(height: 8),
    ClipRRect(
    borderRadius: BorderRadius.circular(8),
    child: Image.memory(
    _decodeBase64Image(issue.imageBase64!),
    width: double.infinity,
      fit: BoxFit.cover,
    ),
    ),
        ],
        ),
                ],
            ),
        ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
            TextButton(
              onPressed: () {
                _updateIssueStatus(issue.id, 'resolved');
                Navigator.pop(context);
              },
              child: const Text('Mark Resolved'),
            ),
          ],
        ),
    );
  }

  Future<void> _updateIssueStatus(String issueId, String newStatus) async {
    try {
      await _authorityService.updateIssueStatus(issueId, newStatus);
      _showMessage('Issue status updated');
    } catch (e) {
      _showMessage('Error updating status: $e');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  Uint8List _decodeBase64Image(String base64String) {
    return base64Decode(base64String);
  }

  // PDF generation methods
  Future<void> _generateAndDownloadPdfReport() async {
    // Show loading indicator
    _showLoadingDialog('Generating PDF report...');

    try {
      // Get all issues - if a filter center is set, use that, otherwise get all issues
      List<RoadIssue> issues;
      String areaName = widget.authority.jurisdiction;

      if (_filterCenter != null) {
        issues = await _authorityService.getIssuesNearLocation(
          _filterCenter!.latitude,
          _filterCenter!.longitude,
          _filterRadius,
        );
        areaName = 'Selected area in ${widget.authority.jurisdiction}';
      } else {
        // Get all issues from the stream
        issues = await _authorityService.getAllIssues().first;
      }

      if (issues.isEmpty) {
        // Hide loading dialog
        Navigator.pop(context);
        _showMessage('No issues found to include in the report.');
        return;
      }

      // Generate the PDF bytes
      final pdfBytes = await _generatePdfReport(
        issues: issues,
        areaName: areaName,
        radiusKm: _filterCenter != null ? _filterRadius : 0,
      );

      // Hide loading dialog
      Navigator.pop(context);

      // Show options dialog
      _showPdfOptionsDialog(pdfBytes);
    } catch (e) {
      // Hide loading dialog
      Navigator.pop(context);
      _showMessage('Error generating report: $e');
    }
  }

  // Show loading dialog
  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              Text(message),
            ],
          ),
        );
      },
    );
  }

  // Show PDF options dialog
  void _showPdfOptionsDialog(Uint8List pdfBytes) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('PDF Report Generated'),
          content: const Text('Your report has been generated. What would you like to do with it?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _previewPdf(pdfBytes);
              },
              child: const Text('Preview'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                final now = DateTime.now();
                final fileName = 'road_issues_${widget.authority.jurisdiction.replaceAll(' ', '_')}_${now.millisecondsSinceEpoch}.pdf';
                _savePdfFile(pdfBytes, fileName);
              },
              child: const Text('Save & Open'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                final now = DateTime.now();
                final fileName = 'road_issues_${widget.authority.jurisdiction.replaceAll(' ', '_')}_${now.millisecondsSinceEpoch}.pdf';
                _sharePdf(pdfBytes, fileName);
              },
              child: const Text('Share'),
            ),
          ],
        );
      },
    );
  }

  // Generate PDF report
  Future<Uint8List> _generatePdfReport({
    required List<RoadIssue> issues,
    required String areaName,
    required double radiusKm,
  }) async {
    final pdf = pw.Document();

    // Load fonts
    final font = await PdfGoogleFonts.nunitoRegular();
    final fontBold = await PdfGoogleFonts.nunitoBold();
    final fontItalic = await PdfGoogleFonts.nunitoItalic();

    // Add a header/title page
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Center(
              child: pw.Column(
                children: [
                  pw.SizedBox(height: 40),
                  pw.Text(
                    'ROAD ISSUES REPORT',
                    style: pw.TextStyle(font: fontBold, fontSize: 24, color: PdfColors.blue900),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Text(
                    'Generated on ${DateFormat('MMMM dd, yyyy').format(DateTime.now())}',
                    style: pw.TextStyle(font: fontItalic, fontSize: 14, color: PdfColors.grey700),
                  ),
                  pw.SizedBox(height: 30),
                  pw.Container(
                    width: 100,
                    height: 2,
                    color: PdfColors.blue900,
                  ),
                  pw.SizedBox(height: 30),
                ],
              ),
            ),
            pw.Text(
              'Authority Information:',
              style: pw.TextStyle(font: fontBold, fontSize: 16, color: PdfColors.blue900),
            ),
            pw.SizedBox(height: 5),
            _buildPdfInfoRow('Jurisdiction:', widget.authority.jurisdiction, font, fontBold),
            _buildPdfInfoRow('Department:', widget.authority.department, font, fontBold),
            _buildPdfInfoRow('Authority ID:', widget.authority.uid, font, fontBold),
            _buildPdfInfoRow('Report Area:', areaName, font, fontBold),
            if (radiusKm > 0) _buildPdfInfoRow('Radius:', '$radiusKm km', font, fontBold),
            _buildPdfInfoRow('Total Issues:', '${issues.length}', font, fontBold),
            pw.SizedBox(height: 20),
            pw.Text(
              'Summary of Issues:',
              style: pw.TextStyle(font: fontBold, fontSize: 16, color: PdfColors.blue900),
            ),
            pw.SizedBox(height: 5),
            // Issue type summary
            _buildPdfIssueSummary(issues, font, fontBold),
            pw.SizedBox(height: 30),
            pw.Center(
              child: pw.Text(
                'This report contains detailed information about road issues reported in ${areaName}.',
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(font: font, fontSize: 12, color: PdfColors.grey700),
              ),
            ),
          ],
        ),
      ),
    );

    // Add issues detail pages
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Road Issues in ${widget.authority.jurisdiction}',
                  style: pw.TextStyle(font: fontBold, fontSize: 14),
                ),
                pw.Text(
                  'Page ${context.pageNumber} of ${context.pagesCount}',
                  style: pw.TextStyle(font: font, fontSize: 12),
                ),
              ],
            ),
            pw.Divider(),
          ],
        ),
        footer: (context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.Text(
              'Generated by triQna - ${DateFormat('MM/dd/yyyy').format(DateTime.now())}',
              style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey700),
            ),
          ],
        ),
        build: (context) => [
          pw.Table.fromTextArray(
            headerStyle: pw.TextStyle(font: fontBold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColors.blue900,
            ),
            cellStyle: pw.TextStyle(font: font),
            cellHeight: 40,
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerLeft,
              2: pw.Alignment.center,
              3: pw.Alignment.center,
              4: pw.Alignment.center,
            },
            headerPadding: const pw.EdgeInsets.all(5),
            cellPadding: const pw.EdgeInsets.all(5),
            headers: ['Type', 'Description', 'Verifications', 'Transport', 'Reported Date'],
            data: issues.map((issue) => [
              issue.type,
              issue.description,
              issue.verificationCount.toString(),
              issue.transportMode,
              DateFormat('MM/dd/yyyy').format(issue.timestamp),
            ]).toList(),
          ),
          pw.SizedBox(height: 20),
          // Detailed issue information for most verified issues
          pw.Header(
            level: 1,
            text: 'Highest Priority Issues',
            textStyle: pw.TextStyle(font: fontBold, fontSize: 18, color: PdfColors.blue900),
          ),
          pw.SizedBox(height: 10),
          ...issues.where((issue) => issue.verificationCount > 2) // Only high priority issues
              .take(5) // Limit to top 5
              .map((issue) => _buildPdfDetailedIssue(issue, font, fontBold))
              .toList(),
        ],
      ),
    );

    // Map visualization page
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Center(
              child: pw.Text(
                'Issue Locations Map',
                style: pw.TextStyle(font: fontBold, fontSize: 18, color: PdfColors.blue900),
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Center(
              child: pw.Container(
                width: 400,
                height: 400,
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey200,
                  border: pw.Border.all(color: PdfColors.grey400),
                ),
                child: pw.Center(
                  child: pw.Text(
                    'Map visualization is available in the app',
                    style: pw.TextStyle(font: fontItalic, fontSize: 12),
                  ),
                ),
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Text(
              'Issue Coordinates:',
              style: pw.TextStyle(font: fontBold, fontSize: 14),
            ),
            pw.SizedBox(height: 5),
            // Coordinates table
            pw.Table.fromTextArray(
              headerStyle: pw.TextStyle(font: fontBold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.blue900,
              ),
              cellStyle: pw.TextStyle(font: font),
              cellHeight: 30,
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.center,
                2: pw.Alignment.center,
              },
              headerPadding: const pw.EdgeInsets.all(5),
              cellPadding: const pw.EdgeInsets.all(5),
              headers: ['Issue Type', 'Latitude', 'Longitude'],
              data: issues.take(10).map((issue) => [
                issue.type,
                issue.latitude.toStringAsFixed(6),
                issue.longitude.toStringAsFixed(6),
              ]).toList(),
            ),
          ],
        ),
      ),
    );

    return pdf.save();
  }

  // Helper methods for PDF generation
  pw.Widget _buildPdfInfoRow(String label, String value, pw.Font font, pw.Font fontBold) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 5),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 100,
            child: pw.Text(
              label,
              style: pw.TextStyle(font: fontBold, fontSize: 12),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(font: font, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  // Build a summary of issues by type for PDF
  pw.Widget _buildPdfIssueSummary(List<RoadIssue> issues, pw.Font font, pw.Font fontBold) {
    // Count issues by type
    final typeCounts = <String, int>{};
    for (final issue in issues) {
      typeCounts[issue.type] = (typeCounts[issue.type] ?? 0) + 1;
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: typeCounts.entries.map((entry) {
        // Calculate percentage
        final percentage = issues.isEmpty ? 0 : (entry.value / issues.length * 100).toStringAsFixed(1);

        return pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 5),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                '${entry.key}: ${entry.value} (${percentage}%)',
                style: pw.TextStyle(font: fontBold, fontSize: 12),
              ),
              pw.SizedBox(height: 3),
              pw.Container(
                height: 10,
                child: pw.Row(
                  children: [
                    pw.Container(
                      width: issues.isEmpty ? 0 : (entry.value / issues.length * 200),
                      color: PdfColors.blue700,
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 5),
            ],
          ),
        );
      }).toList(),
    );
  }

  // Build a detailed issue block for PDF
  pw.Widget _buildPdfDetailedIssue(RoadIssue issue, pw.Font font, pw.Font fontBold) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 15),
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                issue.type,
                style: pw.TextStyle(font: fontBold, fontSize: 14, color: PdfColors.blue900),
              ),
              pw.Text(
                'Verifications: ${issue.verificationCount}',
                style: pw.TextStyle(font: fontBold, fontSize: 12, color: PdfColors.red),
              ),
            ],
          ),
          pw.Divider(),
          _buildPdfInfoRow('Description:', issue.description, font, fontBold),
          _buildPdfInfoRow('Transport Mode:', issue.transportMode, font, fontBold),
          _buildPdfInfoRow('Reported On:', DateFormat('MM/dd/yyyy HH:mm').format(issue.timestamp), font, fontBold),
          _buildPdfInfoRow('Coordinates:', '(${issue.latitude.toStringAsFixed(6)}, ${issue.longitude.toStringAsFixed(6)})', font, fontBold),
          _buildPdfInfoRow('Reporter ID:', issue.userId, font, fontBold),
        ],
      ),
    );
  }

  // Save the PDF file and open it
  Future<void> _savePdfFile(Uint8List bytes, String fileName) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes);

      await OpenFile.open(file.path);
      _showMessage('PDF saved to ${file.path}');
    } catch (e) {
      _showMessage('Error saving PDF: $e');
    }
  }

  // Share the PDF file
  Future<void> _sharePdf(Uint8List bytes, String fileName) async {
    try {
      await Printing.sharePdf(bytes: bytes, filename: fileName);
    } catch (e) {
      _showMessage('Error sharing PDF: $e');
    }
  }

  // Preview the PDF
  Future<void> _previewPdf(Uint8List bytes) async {
    try {
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => bytes,
      );
    } catch (e) {
      _showMessage('Error previewing PDF: $e');
    }
  }
}

