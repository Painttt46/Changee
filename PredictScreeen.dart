import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image/image.dart' as img;
import 'api_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PredictScreeen extends StatefulWidget {
  @override
  _PredictScreeenState createState() => _PredictScreeenState();
}

class _PredictScreeenState extends State<PredictScreeen> with TickerProviderStateMixin {
  File? _image;
  final ImagePicker _picker = ImagePicker();
  String? _predictionResult;
  double? _confidence;
  bool _isLoading = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    
    _pulseController = AnimationController(
      duration: Duration(seconds: 2),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    _animationController.forward();
    _checkServerHealth();
  }

  Future<void> _checkServerHealth() async {
    final isHealthy = await ApiService.checkServerHealth();
    if (!isHealthy) {
      _showErrorSnackBar('⚠️ ไม่สามารถเชื่อมต่อกับเซิร์ฟเวอร์ได้ กรุณาตรวจสอบการเชื่อมต่ออินเทอร์เน็ต');
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 2048,  // Higher quality for better API processing
        maxHeight: 2048,
        imageQuality: 95, // Higher quality since API will handle optimization
      );

      if (pickedFile != null) {
        setState(() {
          _image = File(pickedFile.path);
          _predictionResult = null;
          _confidence = null;
        });
        _animationController.reset();
        _animationController.forward();
      }
    } catch (e) {
      _showErrorSnackBar('เกิดข้อผิดพลาดในการเลือกรูปภาพ');
    }
  }

  Future<void> _uploadAndPredictImage() async {
    final user = FirebaseAuth.instance.currentUser;
    if (_image == null || user == null) {
      _showErrorSnackBar('กรุณาเลือกรูปภาพและเข้าสู่ระบบ');
      return;
    }

    setState(() => _isLoading = true);
    _pulseController.repeat(reverse: true);

    try {
      // Show progress dialog
      _showProgressDialog();

      // Upload original image - let API handle resizing for optimal quality
      String fileName = 'uploads/${user.uid}/${DateTime.now().millisecondsSinceEpoch}.jpg';
      Reference storageRef = FirebaseStorage.instance.ref().child(fileName);

      UploadTask uploadTask = storageRef.putFile(_image!);
      await uploadTask.whenComplete(() => null);

      String downloadURL = await storageRef.getDownloadURL();

      await _predictImage(downloadURL);

      // Save to history with additional metadata
      await FirebaseFirestore.instance.collection('predict_History').add({
        'imageUrl': downloadURL,
        'prediction': _predictionResult,
        'confidence': _confidence,
        'timestamp': FieldValue.serverTimestamp(),
        'userId': user.uid,
        'deviceInfo': 'Mobile App',
        'imageSize': '${_image!.lengthSync()} bytes',
      });

      Navigator.of(context).pop(); // Close progress dialog
      _showSuccessSnackBar('🎉 วิเคราะห์สำเร็จ!');

      setState(() {
        _image = null;
      });
    } catch (e) {
      Navigator.of(context).pop(); // Close progress dialog
      print('Upload error: $e');
      _showErrorSnackBar('❌ เกิดข้อผิดพลาดในการอัปโหลด');
    } finally {
      setState(() => _isLoading = false);
      _pulseController.stop();
    }
  }

  void _showProgressDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.green[600]!),
              strokeWidth: 3,
            ),
            SizedBox(height: 20),
            Text(
              'กำลังวิเคราะห์รูปภาพ...',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            SizedBox(height: 10),
            Text(
              'กรุณารอสักครู่',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  // Removed _resizeImage function - API handles optimal resizing

  Future<void> _predictImage(String imageUrl) async {
    try {
      final result = await ApiService.predictImage(imageUrl);
      
      if (result != null) {
        final formattedResult = ApiService.formatPredictionResult(result);
        final confidenceValue = ApiService.extractConfidenceValue(result);
        
        setState(() {
          _predictionResult = formattedResult;
          _confidence = confidenceValue;
        });

        _showPredictionDialog(_predictionResult!, imageUrl);
      } else {
        throw Exception("ไม่ได้รับผลลัพธ์จากเซิร์ฟเวอร์");
      }
    } catch (e) {
      print('Prediction error: $e');
      _showErrorSnackBar('❌ เกิดข้อผิดพลาดในการวิเคราะห์: $e');
    }
  }

  void _showPredictionDialog(String predictionResult, String imageUrl) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 16,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.green[50]!, Colors.white],
              ),
            ),
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green[600],
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Icon(Icons.psychology, color: Colors.white, size: 30),
                ),
                SizedBox(height: 16),
                Text(
                  '🧠 ผลการวิเคราะห์',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[800],
                  ),
                ),
                SizedBox(height: 20),
                
                // Image with border
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: Offset(0, 5),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: Image.network(
                      imageUrl,
                      height: 200,
                      width: 200,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          height: 200,
                          width: 200,
                          child: Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                  : null,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                SizedBox(height: 20),
                
                // Prediction result card
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green[200]!),
                  ),
                  child: Column(
                    children: [
                      Text(
                        predictionResult,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[800],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (_confidence != null) ...[
                        SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.verified, color: Colors.green[600], size: 20),
                            SizedBox(width: 8),
                            Text(
                              'ความแม่นยำ: ${(_confidence! * 100).toStringAsFixed(1)}%',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.green[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: _confidence,
                          backgroundColor: Colors.green[100],
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.green[600]!),
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(height: 24),
                
                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(Icons.check_circle),
                        label: Text("ตกลง"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[600],
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          Navigator.pushNamed(
                            context,
                            '/googlemap',
                            arguments: {
                              'description': predictionResult,
                              'imageUrl': imageUrl,
                              'confidence': _confidence,
                            },
                          );
                        },
                        icon: Icon(Icons.map),
                        label: Text("เพิ่มในแผนที่"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[600],
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildImagePreview() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        height: 300,
        width: double.infinity,
        margin: EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 15,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: _image == null ? _buildEmptyImageContainer() : _buildImageContainer(),
      ),
    );
  }

  Widget _buildEmptyImageContainer() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.green[50]!, Colors.green[100]!],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.green[200]!, width: 2, style: BorderStyle.solid),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _pulseAnimation.value,
                child: Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.green[600],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.add_a_photo, size: 40, color: Colors.white),
                ),
              );
            },
          ),
          SizedBox(height: 20),
          Text(
            '📸 เลือกรูปภาพใบข้าว',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.green[800],
            ),
          ),
          SizedBox(height: 8),
          Text(
            'กดปุ่มด้านล่างเพื่อเลือกรูปภาพ\nจากแกลเลอรี่หรือถ่ายรูปใหม่',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.green[600],
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageContainer() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.green[300]!, width: 3),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(17),
        child: Stack(
          children: [
            Image.file(
              _image!,
              height: 300,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: IconButton(
                  icon: Icon(Icons.close, color: Colors.white),
                  onPressed: () {
                    setState(() {
                      _image = null;
                      _predictionResult = null;
                      _confidence = null;
                    });
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          // Image selection buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _pickImage(ImageSource.gallery),
                  icon: Icon(Icons.photo_library),
                  label: Text("แกลเลอรี่"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple[100],
                    foregroundColor: Colors.purple[800],
                    padding: EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    elevation: 5,
                  ),
                ),
              ),
              SizedBox(width: 15),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _pickImage(ImageSource.camera),
                  icon: Icon(Icons.camera_alt),
                  label: Text("กล้อง"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[100],
                    foregroundColor: Colors.orange[800],
                    padding: EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    elevation: 5,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          
          // Predict button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: (_image == null || _isLoading) ? null : _uploadAndPredictImage,
              icon: _isLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Icon(Icons.psychology),
              label: Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  _isLoading ? "กำลังวิเคราะห์..." : "🧠 วิเคราะห์โรคข้าว",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _image == null ? Colors.grey[400] : Colors.green[600],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                elevation: _image == null ? 0 : 8,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 10),
            Text(message),
          ],
        ),
        backgroundColor: Colors.green[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error, color: Colors.white),
            SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          '🌾 วิเคราะห์โรคข้าว',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.green[600],
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.history),
            onPressed: () => Navigator.pushNamed(context, '/history'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header gradient
            Container(
              height: 50,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.green[600]!, Colors.transparent],
                ),
              ),
            ),
            
            SizedBox(height: 20),
            
            // Instructions card
            Container(
              margin: EdgeInsets.symmetric(horizontal: 20),
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: Colors.blue[600]),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'ถ่ายรูปใบข้าวที่มีอาการผิดปกติ\nเพื่อให้ AI วิเคราะห์โรคและแนะนำการรักษา',
                      style: TextStyle(
                        color: Colors.blue[800],
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            SizedBox(height: 30),
            
            // Image preview
            _buildImagePreview(),
            
            SizedBox(height: 40),
            
            // Action buttons
            _buildActionButtons(),
            
            SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
