import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class HistoryService {
  static const String _saveHistoryUrl =
      'https://asia-southeast1-hackathon-2026-482104.cloudfunctions.net/save_history';

  Future<void> saveScanHistory({
    required String deviceId,
    required XFile imageFile,
    required Map<String, dynamic> scanResult,
  }) async {
    var request = http.MultipartRequest('POST', Uri.parse(_saveHistoryUrl));
    request.fields['device_id'] = deviceId;
    request.files.add(
      await http.MultipartFile.fromPath(
        'image',
        imageFile.path,
        filename: imageFile.name,
      ),
    );
    request.fields['scan_result'] = jsonEncode(scanResult);
    await request.send();
  }
}
