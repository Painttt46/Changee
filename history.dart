import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  _HistoryPageState createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> with TickerProviderStateMixin {
  String _searchQuery = '';
  String _selectedFilter = 'ทั้งหมด';
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Responsive utilities
  bool _isTablet(BuildContext context) => MediaQuery.of(context).size.width >= 768;
  bool _isDesktop(BuildContext context) => MediaQuery.of(context).size.width >= 1024;
  double _getResponsivePadding(BuildContext context) => _isTablet(context) ? 32 : 20;
  int _getCrossAxisCount(BuildContext context) => _isDesktop(context) ? 3 : _isTablet(context) ? 2 : 1;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        body: _buildLoginPrompt(),
      );
    }

    final userId = currentUser.uid;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildHeader(),
          _buildSearchAndFilter(),
          Expanded(
            child: _buildHistoryList(userId),
          ),
        ],
      ),

    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Text(
        '📚 ประวัติการวิเคราะห์',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      centerTitle: true,
      backgroundColor: Colors.green[600],
      elevation: 0,
      actions: [
        IconButton(
          icon: Icon(Icons.analytics),
          onPressed: _showStatistics,
        ),
        PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'clear') {
              _showClearHistoryDialog();
            } else if (value == 'export') {
              _showExportDialog();
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'export',
              child: Row(
                children: [
                  Icon(Icons.download, color: Colors.blue[600]),
                  SizedBox(width: 8),
                  Text('ส่งออกข้อมูล'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'clear',
              child: Row(
                children: [
                  Icon(Icons.delete_sweep, color: Colors.red[600]),
                  SizedBox(width: 8),
                  Text('ล้างประวัติ'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHeader() {
    final isTablet = _isTablet(context);
    final padding = _getResponsivePadding(context);
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.green[600]!, Colors.green[400]!],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      padding: EdgeInsets.fromLTRB(padding, 0, padding, 30),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(isTablet ? 16 : 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(Icons.history, color: Colors.white, size: isTablet ? 36 : 30),
              ),
              SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ประวัติการวิเคราะห์',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isTablet ? 24 : 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'ดูผลการวิเคราะห์โรคข้าวที่ผ่านมา',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: isTablet ? 16 : 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    final padding = _getResponsivePadding(context);
    final isTablet = _isTablet(context);
    
    return Container(
      padding: EdgeInsets.all(padding),
      child: Column(
        children: [
          // Search Bar
          Container(
            constraints: BoxConstraints(maxWidth: isTablet ? 600 : double.infinity),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(25),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: TextField(
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: 'ค้นหาผลการวิเคราะห์...',
                prefixIcon: Icon(Icons.search, color: Colors.green[600]),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              ),
            ),
          ),
          SizedBox(height: 15),
          
          // Filter Chips
          Center(
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: ['ทั้งหมด', 'วันนี้', 'สัปดาห์นี้', 'เดือนนี้'].map((filter) {
                return FilterChip(
                  label: Text(filter),
                  selected: _selectedFilter == filter,
                  onSelected: (selected) => setState(() => _selectedFilter = filter),
                  backgroundColor: Colors.grey[200],
                  selectedColor: Colors.green[100],
                  labelStyle: TextStyle(
                    color: _selectedFilter == filter ? Colors.green[800] : Colors.grey[700],
                    fontWeight: FontWeight.w500,
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList(String userId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('predict_History')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildErrorState(snapshot.error.toString());
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState();
        }

        final allDocs = snapshot.data!.docs;
        final filteredDocs = _filterDocuments(allDocs, userId);

        if (filteredDocs.isEmpty) {
          return _buildEmptyState();
        }

        final crossAxisCount = _getCrossAxisCount(context);
        final padding = _getResponsivePadding(context);

        return FadeTransition(
          opacity: _fadeAnimation,
          child: crossAxisCount == 1 
            ? ListView.builder(
                padding: EdgeInsets.symmetric(horizontal: padding),
                itemCount: filteredDocs.length,
                itemBuilder: (context, index) {
                  final data = filteredDocs[index].data() as Map<String, dynamic>;
                  return _buildHistoryCard(data, index);
                },
              )
            : GridView.builder(
                padding: EdgeInsets.symmetric(horizontal: padding),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.85,
                ),
                itemCount: filteredDocs.length,
                itemBuilder: (context, index) {
                  final data = filteredDocs[index].data() as Map<String, dynamic>;
                  return _buildHistoryCard(data, index);
                },
              ),
        );
      },
    );
  }

  List<QueryDocumentSnapshot> _filterDocuments(List<QueryDocumentSnapshot> docs, String userId) {
    return docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      
      // Filter by user
      if (data['userId'] != userId) return false;
      
      // Filter by search query
      if (_searchQuery.isNotEmpty) {
        final prediction = (data['prediction'] ?? '').toString().toLowerCase();
        if (!prediction.contains(_searchQuery.toLowerCase())) return false;
      }
      
      // Filter by time period
      if (_selectedFilter != 'ทั้งหมด') {
        final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
        if (timestamp != null) {
          final now = DateTime.now();
          switch (_selectedFilter) {
            case 'วันนี้':
              if (!_isSameDay(timestamp, now)) return false;
              break;
            case 'สัปดาห์นี้':
              if (now.difference(timestamp).inDays > 7) return false;
              break;
            case 'เดือนนี้':
              if (now.difference(timestamp).inDays > 30) return false;
              break;
          }
        }
      }
      
      return true;
    }).toList();
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year && 
           date1.month == date2.month && 
           date1.day == date2.day;
  }

  Widget _buildHistoryCard(Map<String, dynamic> data, int index) {
    final imageUrl = data['imageUrl'] ?? '';
    final prediction = data['prediction'] ?? 'ไม่ทราบผล';
    final confidence = data['confidence'] as double?;
    final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
    final deviceInfo = data['deviceInfo'] ?? 'ไม่ทราบอุปกรณ์';
    final isTablet = _isTablet(context);
    final isDesktop = _isDesktop(context);

    final formattedTime = timestamp != null
        ? DateFormat('dd/MM/yyyy HH:mm').format(timestamp)
        : 'ไม่ทราบเวลา';

    // Determine status color based on prediction
    Color statusColor = Colors.green[600]!;
    IconData statusIcon = Icons.check_circle;
    if (prediction.contains('โรค') || prediction.contains('เสีย')) {
      statusColor = Colors.red[600]!;
      statusIcon = Icons.warning;
    }

    return Container(
      margin: EdgeInsets.only(bottom: isDesktop ? 0 : 16),
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.white, Colors.grey[50]!],
              ),
              border: Border.all(color: Colors.grey[200]!, width: 1),
            ),
            child: Column(
              children: [
                // Header
                Container(
                  padding: EdgeInsets.all(isTablet ? 20 : 16),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(isTablet ? 10 : 8),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(statusIcon, color: statusColor, size: isTablet ? 24 : 20),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              prediction,
                              style: TextStyle(
                                fontSize: isTablet ? 18 : 16,
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                              ),
                              maxLines: isDesktop ? 2 : 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              formattedTime,
                              style: TextStyle(
                                fontSize: isTablet ? 14 : 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '#${index + 1}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Content
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.all(isTablet ? 20 : 16),
                    child: isDesktop 
                      ? Column(
                          children: [
                            // Image
                            Expanded(
                              child: Hero(
                                tag: 'image_$index',
                                child: Container(
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 6,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: imageUrl.isNotEmpty
                                        ? Image.network(
                                            imageUrl,
                                            fit: BoxFit.cover,
                                            loadingBuilder: (context, child, loadingProgress) {
                                              if (loadingProgress == null) return child;
                                              return Container(
                                                color: Colors.grey[200],
                                                child: Center(
                                                  child: SizedBox(
                                                    width: 20,
                                                    height: 20,
                                                    child: CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                                                    ),
                                                  ),
                                                ),
                                              );
                                            },
                                            errorBuilder: (context, error, stackTrace) {
                                              return Container(
                                                color: Colors.grey[200],
                                                child: Icon(Icons.broken_image, color: Colors.grey[400], size: 30),
                                              );
                                            },
                                          )
                                        : Container(
                                            color: Colors.grey[200],
                                            child: Icon(Icons.image, color: Colors.grey[400], size: 30),
                                          ),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: 16),
                            
                            // Details
                            _buildDetailsSection(confidence, statusColor, deviceInfo),
                          ],
                        )
                      : Row(
                          children: [
                            // Image
                            Hero(
                              tag: 'image_$index',
                              child: Container(
                                width: isTablet ? 90 : 70,
                                height: isTablet ? 90 : 70,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 6,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: imageUrl.isNotEmpty
                                      ? Image.network(
                                          imageUrl,
                                          fit: BoxFit.cover,
                                          loadingBuilder: (context, child, loadingProgress) {
                                            if (loadingProgress == null) return child;
                                            return Container(
                                              color: Colors.grey[200],
                                              child: Center(
                                                child: SizedBox(
                                                  width: 20,
                                                  height: 20,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                          errorBuilder: (context, error, stackTrace) {
                                            return Container(
                                              color: Colors.grey[200],
                                              child: Icon(Icons.broken_image, color: Colors.grey[400], size: 30),
                                            );
                                          },
                                        )
                                      : Container(
                                          color: Colors.grey[200],
                                          child: Icon(Icons.image, color: Colors.grey[400], size: 30),
                                        ),
                                ),
                              ),
                            ),
                            SizedBox(width: 16),
                            
                            // Details
                            Expanded(
                              child: _buildDetailsSection(confidence, statusColor, deviceInfo),
                            ),
                          ],
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

  Widget _buildDetailsSection(double? confidence, Color statusColor, String deviceInfo) {
    final isTablet = _isTablet(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (confidence != null) ...[
          Row(
            children: [
              Icon(Icons.analytics, size: isTablet ? 18 : 16, color: Colors.blue[600]),
              SizedBox(width: 6),
              Text(
                'ความแม่นยำ',
                style: TextStyle(
                  fontSize: isTablet ? 14 : 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: LinearProgressIndicator(
                  value: confidence,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                  minHeight: isTablet ? 8 : 6,
                ),
              ),
              SizedBox(width: 8),
              Text(
                '${(confidence * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: isTablet ? 14 : 12,
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
        ],
        Row(
          children: [
            Icon(Icons.smartphone, size: isTablet ? 16 : 14, color: Colors.grey[500]),
            SizedBox(width: 6),
            Expanded(
              child: Text(
                deviceInfo,
                style: TextStyle(
                  fontSize: isTablet ? 13 : 11,
                  color: Colors.grey[600],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    final isTablet = _isTablet(context);
    final padding = _getResponsivePadding(context);
    
    return Center(
      child: Padding(
        padding: EdgeInsets.all(padding),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isTablet ? 600 : double.infinity),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(isTablet ? 50 : 40),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.green[100]!, Colors.green[50]!],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withOpacity(0.2),
                      blurRadius: 20,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.history,
                  size: isTablet ? 100 : 80,
                  color: Colors.green[600],
                ),
              ),
              SizedBox(height: 30),
              Text(
                'ยังไม่มีประวัติการวิเคราะห์',
                style: TextStyle(
                  fontSize: isTablet ? 26 : 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 12),
              Text(
                'เริ่มต้นด้วยการถ่ายรูปใบข้าว\nเพื่อวิเคราะห์โรคและสร้างประวัติ',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: isTablet ? 18 : 16,
                  color: Colors.grey[600],
                  height: 1.6,
                ),
              ),
              SizedBox(height: 40),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green[600]!, Colors.green[500]!],
                  ),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withOpacity(0.3),
                      blurRadius: 15,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pushNamed(context, '/camera'),
                  icon: Icon(Icons.camera_alt, size: isTablet ? 28 : 24),
                  label: Text(
                    'เริ่มวิเคราะห์',
                    style: TextStyle(fontSize: isTablet ? 18 : 16, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shadowColor: Colors.transparent,
                    padding: EdgeInsets.symmetric(horizontal: isTablet ? 50 : 40, vertical: isTablet ? 20 : 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 20),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  _buildFeatureChip('📸 ถ่ายรูป'),
                  _buildFeatureChip('🔍 วิเคราะห์'),
                  _buildFeatureChip('📊 ดูผล'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureChip(String text) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: Colors.green[700],
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.green[600]!),
          ),
          SizedBox(height: 20),
          Text(
            'กำลังโหลดประวัติ...',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 60,
            color: Colors.red[400],
          ),
          SizedBox(height: 20),
          Text(
            'เกิดข้อผิดพลาด',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.red[600],
            ),
          ),
          SizedBox(height: 10),
          Text(
            error,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => setState(() {}),
            icon: Icon(Icons.refresh),
            label: Text('ลองใหม่'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[600],
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginPrompt() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.login,
            size: 80,
            color: Colors.green[600],
          ),
          SizedBox(height: 20),
          Text(
            'กรุณาเข้าสู่ระบบ',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.green[800],
            ),
          ),
          SizedBox(height: 10),
          Text(
            'เพื่อดูประวัติการวิเคราะห์โรคข้าว',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 30),
          ElevatedButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/login'),
            icon: Icon(Icons.login),
            label: Text('เข้าสู่ระบบ'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[600],
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: Colors.grey[800]),
            ),
          ),
        ],
      ),
    );
  }

  void _showStatistics() {
    // TODO: Implement statistics dialog
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('ฟีเจอร์สถิติจะเปิดใช้งานเร็วๆ นี้'),
        backgroundColor: Colors.blue[600],
      ),
    );
  }

  void _showClearHistoryDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.red[600]),
            SizedBox(width: 10),
            Text('ล้างประวัติ'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('คุณต้องการลบประวัติการวิเคราะห์ทั้งหมดหรือไม่?'),
            SizedBox(height: 10),
            Text(
              'การดำเนินการนี้ไม่สามารถย้อนกลับได้',
              style: TextStyle(color: Colors.red[600], fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () => _clearHistory(),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red[600]),
            child: Text('ลบทั้งหมด', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _clearHistory() async {
    Navigator.pop(context);
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      final batch = FirebaseFirestore.instance.batch();
      final querySnapshot = await FirebaseFirestore.instance
          .collection('predict_History')
          .where('userId', isEqualTo: currentUser.uid)
          .get();

      for (var doc in querySnapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 10),
              Text('ลบประวัติเรียบร้อยแล้ว'),
            ],
          ),
          backgroundColor: Colors.green[600],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error, color: Colors.white),
              SizedBox(width: 10),
              Text('เกิดข้อผิดพลาด: ${e.toString()}'),
            ],
          ),
          backgroundColor: Colors.red[600],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  void _showExportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('ส่งออกข้อมูล'),
        content: Text('คุณต้องการส่งออกประวัติการวิเคราะห์หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Implement export functionality
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('ฟีเจอร์ส่งออกข้อมูลจะเปิดใช้งานเร็วๆ นี้'),
                  backgroundColor: Colors.blue[600],
                ),
              );
            },
            child: Text('ส่งออก'),
          ),
        ],
      ),
    );
  }
}
