import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

class CloudinaryService {
  static const String cloudName = 'dg21tf3ju';
  static const String apiKey = '748937183226452';
  static const String apiSecret = '-8A8WOxKUQeaG1ZVjLMfCXyLpVA';

  static const String _uploadUrl =
      'https://api.cloudinary.com/v1_1/$cloudName/image/upload';

  /// Uploads an image file to Cloudinary and returns the secure URL.
  static Future<String> uploadImage(File imageFile) async {
    try {
      final int timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      // Generate signature: sha1(timestamp={timestamp}{apiSecret})
      final String toSign = 'timestamp=$timestamp$apiSecret';
      final signature = sha1.convert(utf8.encode(toSign)).toString();

      final request = http.MultipartRequest('POST', Uri.parse(_uploadUrl));

      request.fields['api_key'] = apiKey;
      request.fields['timestamp'] = timestamp.toString();
      request.fields['signature'] = signature;

      request.files.add(
        await http.MultipartFile.fromPath('file', imageFile.path),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        final String imageUrl = jsonResponse['secure_url'];
        return imageUrl;
      } else {
        throw Exception(
            'Upload failed (${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      throw Exception('Error uploading image: $e');
    }
  }
}
