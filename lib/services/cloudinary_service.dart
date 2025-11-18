import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'dart:convert';

class CloudinaryService {
  static const cloudName = "dx5pjbz8m";
  static const apiKey = "679941767555469";
  static const apiSecret = "LmE78sUCgFl4bcLuOvdGDw8OaEU";

  static Future<String?> subirImagen(File file) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    final String signatureData = "timestamp=$timestamp$apiSecret";
    final signature = sha1.convert(utf8.encode(signatureData)).toString();

    final url = Uri.parse(
      "https://api.cloudinary.com/v1_1/$cloudName/image/upload",
    );

    final request = http.MultipartRequest('POST', url);

    request.fields['api_key'] = apiKey;
    request.fields['timestamp'] = timestamp.toString();
    request.fields['signature'] = signature;
    request.files.add(await http.MultipartFile.fromPath('file', file.path));

    final response = await request.send();

    if (response.statusCode == 200) {
      final body = await response.stream.bytesToString();
      final data = jsonDecode(body);
      return data["secure_url"]; // URL final de la imagen
    }

    print('Error subiendo a Cloudinary: ${response.statusCode}');
    return null;
  }
}
