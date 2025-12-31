import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'services/device_id_service.dart';

// Model class for health warning
class HealthWarning {
  final String ingredient;
  final String summary;
  final String warningType;
  final double riskScore;

  HealthWarning({
    required this.ingredient,
    required this.summary,
    required this.warningType,
    required this.riskScore,
  });

  factory HealthWarning.fromJson(Map<String, dynamic> json) {
    return HealthWarning(
      ingredient: json['ingredient'] ?? '',
      summary: json['summary'] ?? '',
      warningType: json['warning_type'] ?? '',
      riskScore: (json['risk_score'] ?? 0).toDouble(),
    );
  }
}

// Model class for history item
class HistoryItem {
  final String id;
  final int createdAt;
  final String imageUrl;
  final List<HealthWarning> healthWarnings;
  final List<String> ingredients;

  HistoryItem({
    required this.id,
    required this.createdAt,
    required this.imageUrl,
    required this.healthWarnings,
    required this.ingredients,
  });

  factory HistoryItem.fromJson(Map<String, dynamic> json) {
    final warningsList = (json['health_warnings'] as List<dynamic>?)
            ?.map((w) => HealthWarning.fromJson(w as Map<String, dynamic>))
            .toList() ??
        [];

    final ingredientsList = (json['ingredients'] as List<dynamic>?)
            ?.map((i) => i.toString())
            .toList() ??
        [];

    return HistoryItem(
      id: json['id'] ?? '',
      createdAt: json['created_at'] ?? 0,
      imageUrl: json['image_url'] ?? '',
      healthWarnings: warningsList,
      ingredients: ingredientsList,
    );
  }

  // Get primary summary (first warning)
  String get primarySummary {
    if (healthWarnings.isEmpty) return 'Không có cảnh báo';
    return healthWarnings.first.summary;
  }

  // Get primary ingredient (first warning)
  String get primaryIngredient {
    if (healthWarnings.isEmpty) return '';
    return healthWarnings.first.ingredient;
  }

  // Get additional warnings count
  int get additionalWarningsCount {
    if (healthWarnings.length <= 1) return 0;
    return healthWarnings.length - 1;
  }

  // Check if has warnings
  bool get hasWarnings => healthWarnings.isNotEmpty;

  // Format date time
  String get formattedTime {
    final dateTime = DateTime.fromMillisecondsSinceEpoch(createdAt);
    return DateFormat('HH:mm').format(dateTime);
  }

  String get formattedDate {
    final dateTime = DateTime.fromMillisecondsSinceEpoch(createdAt);
    // Format manually to avoid locale initialization issue
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final day = dateTime.day.toString().padLeft(2, '0');
    final month = months[dateTime.month - 1];
    final year = dateTime.year.toString();
    return '$day $month $year';
  }
}

class HistoryTab extends StatefulWidget {
  const HistoryTab({super.key});

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  bool _isLoading = true;
  String? _errorMessage;
  List<HistoryItem> _historyItems = [];

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final deviceId = await DeviceIdService().getDeviceId();

      final url = Uri.parse(
        'https://asia-southeast1-hackathon-2026-482104.cloudfunctions.net/get_history?device_id=$deviceId',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final parsed = jsonDecode(response.body) as Map<String, dynamic>;
        if (parsed['success'] == true) {
          final historyList = (parsed['history'] as List<dynamic>?)
                  ?.map((item) =>
                      HistoryItem.fromJson(item as Map<String, dynamic>))
                  .toList() ??
              [];

          setState(() {
            _historyItems = historyList;
            _isLoading = false;
          });
        } else {
          setState(() {
            _errorMessage = 'API trả về lỗi';
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _errorMessage = 'Lỗi HTTP: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'Lịch sử',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black),
            onPressed: _fetchHistory,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Đang tải lịch sử...',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              const Text(
                'Lỗi kết nối',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _fetchHistory,
                icon: const Icon(Icons.refresh),
                label: const Text('Thử lại'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.pink,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_historyItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              size: 80,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'Chưa có lịch sử quét',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _historyItems.length,
      itemBuilder: (context, index) {
        return _buildHistoryCard(_historyItems[index]);
      },
    );
  }

  Widget _buildHistoryCard(HistoryItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 60,
                height: 60,
                color: Colors.grey.shade200,
                child: item.imageUrl.isNotEmpty
                    ? Image.network(
                        item.imageUrl,
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            Icons.image_not_supported,
                            color: Colors.grey.shade400,
                            size: 30,
                          );
                        },
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                value: loadingProgress.expectedTotalBytes !=
                                        null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                    : null,
                              ),
                            ),
                          );
                        },
                      )
                    : Icon(
                        Icons.document_scanner,
                        color: Colors.grey.shade400,
                        size: 30,
                      ),
              ),
            ),
            const SizedBox(width: 16),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Summary with additional count
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.primarySummary,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (item.additionalWarningsCount > 0) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '+${item.additionalWarningsCount}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.orange.shade700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Ingredient
                  Text(
                    item.primaryIngredient.isNotEmpty
                        ? item.primaryIngredient
                        : 'Không xác định',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // Time and Date
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  item.formattedTime,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.formattedDate,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
