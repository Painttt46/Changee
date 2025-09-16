import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // Change this URL based on your deployment
  static const String _baseUrl = "http://10.0.2.2:8000"; // For Android emulator
  // static const String _baseUrl = "http://localhost:8000"; // For iOS simulator
  // static const String _baseUrl = "https://your-api-domain.com"; // For production

  static Future<Map<String, dynamic>?> predictImage(String imageUrl) async {
    final String apiUrl = "$_baseUrl/predict/";

    try {
      print("🔄 Sending request to: $apiUrl");
      print("📷 Image URL: $imageUrl");

      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
        body: json.encode({"image_url": imageUrl}),
      ).timeout(Duration(seconds: 30));

      print("📡 Response status: ${response.statusCode}");
      print("📄 Response body: ${response.body}");

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        return result;
      } else {
        print("❌ API Error: ${response.statusCode} - ${response.body}");
        return {
          "status": "error",
          "message": "เกิดข้อผิดพลาดจากเซิร์ฟเวอร์ (${response.statusCode})",
          "predicted_class": "เกิดข้อผิดพลาด",
          "confidence_score": "0%",
          "confidence_value": 0.0,
        };
      }
    } catch (e) {
      print("❌ Network Error: $e");
      return {
        "status": "error",
        "message": "ไม่สามารถเชื่อมต่อกับเซิร์ฟเวอร์ได้: $e",
        "predicted_class": "ไม่สามารถเชื่อมต่อได้",
        "confidence_score": "0%",
        "confidence_value": 0.0,
      };
    }
  }

  static String formatPredictionResult(Map<String, dynamic> result) {
    final status = result['status'] ?? 'unknown';
    final predictedClass = result['predicted_class'] ?? 'ไม่ทราบ';
    final confidenceScore = result['confidence_score'] ?? '0%';
    final message = result['message'] ?? '';

    if (status == 'success') {
      final topPredictions = result['top_3_predictions'] as List<dynamic>? ?? [];
      
      String formattedResult = "🎯 ผลการวิเคราะห์:\n\n";
      formattedResult += "🥇 โรคที่น่าจะเป็น: $predictedClass\n";
      formattedResult += "📊 ความมั่นใจ: $confidenceScore\n\n";
      
      if (topPredictions.length >= 3) {
        formattedResult += "📋 โรคที่เป็นไปได้ (เรียงตามความน่าจะเป็น):\n";
        for (int i = 0; i < 3 && i < topPredictions.length; i++) {
          final prediction = topPredictions[i];
          final className = prediction['class'] ?? 'ไม่ทราบ';
          final confidence = prediction['confidence'] ?? '0%';
          formattedResult += "${i + 1}. $className ($confidence)\n";
        }
      }
      
      formattedResult += "\n💡 คำแนะนำ:\n";
      formattedResult += "• ตรวจสอบข้อมูลเพิ่มเติมในหน้าองค์ความรู้\n";
      formattedResult += "• ปรึกษาผู้เชี่ยวชาญเพื่อยืนยันการวินิจฉัย\n";
      formattedResult += "• ดำเนินการรักษาตามคำแนะนำที่เหมาะสม";
      
      return formattedResult;
    } else if (status == 'low_confidence') {
      return "⚠️ การวิเคราะห์ไม่แน่นอน\n\n"
          "📊 ความมั่นใจ: $confidenceScore\n\n"
          "💭 $message\n\n"
          "📝 คำแนะนำ:\n"
          "• ถ่ายรูปใหม่ในที่แสงสว่างเพียงพอ\n"
          "• ถ่ายรูปใกล้ๆ กับใบที่มีอาการ\n"
          "• หลีกเลี่ยงการสั่นไหวของกล้อง\n"
          "• ตรวจสอบว่าใบข้าวอยู่ในโฟกัส";
    } else {
      return "❌ เกิดข้อผิดพลาด\n\n"
          "$message\n\n"
          "🔧 วิธีแก้ไข:\n"
          "• ตรวจสอบการเชื่อมต่ออินเทอร์เน็ต\n"
          "• ลองใหม่อีกครั้งในภายหลัง\n"
          "• ติดต่อผู้ดูแลระบบหากปัญหายังคงอยู่";
    }
  }

  static Future<String> predictImageAndFormat(String imageUrl) async {
    final result = await predictImage(imageUrl);
    if (result != null) {
      return formatPredictionResult(result);
    } else {
      return "❌ ไม่สามารถวิเคราะห์รูปภาพได้\n\n"
          "กรุณาลองใหม่อีกครั้งหรือติดต่อผู้ดูแลระบบ";
    }
  }

  static double? extractConfidenceValue(Map<String, dynamic>? result) {
    if (result == null) return null;
    return result['confidence_value'] as double?;
  }

  static Future<bool> checkServerHealth() async {
    try {
      final response = await http.get(
        Uri.parse("$_baseUrl/health"),
        headers: {"Accept": "application/json"},
      ).timeout(Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      print("❌ Health check failed: $e");
      return false;
    }
  }
}
