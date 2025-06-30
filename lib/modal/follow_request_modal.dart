// lib/modal/follow_request_modal.dart

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class FollowRequestModal extends StatefulWidget {
  final int requestId;
  final String requesterName;
  final VoidCallback? onResponseSent; // 응답 후 콜백

  const FollowRequestModal({
    Key? key,
    required this.requestId,
    required this.requesterName,
    this.onResponseSent,
  }) : super(key: key);

  @override
  _FollowRequestModalState createState() => _FollowRequestModalState();
}

class _FollowRequestModalState extends State<FollowRequestModal> {
  bool _isLoading = false;

  // API 서버 기본 URL 가져오기
  String _getApiBaseUrl() {
    String baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://localhost:8080/api';
    String? localIp = dotenv.env['LOCAL_IP'];

    if (Platform.isAndroid) {
      if (baseUrl.contains('localhost') &&
          localIp != null &&
          localIp.isNotEmpty) {
        return baseUrl.replaceAll('localhost', localIp);
      }
      if (baseUrl.contains('localhost')) {
        return baseUrl.replaceAll('localhost', '10.0.2.2');
      }
    }
    return baseUrl;
  }

  // 찾아가기 요청 응답
  Future<void> _respondToRequest(String response) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        _showSnackBar('로그인이 필요합니다');
        return;
      }

      final apiBaseUrl = _getApiBaseUrl();
      final httpResponse = await http.post(
        Uri.parse('$apiBaseUrl/follow/respond'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'request_id': widget.requestId,
          'response': response, // 'accept' or 'reject'
          'type': 'find_way', // 찾아가기 타입 추가
        }),
      );

      final data = json.decode(httpResponse.body);

      if (httpResponse.statusCode == 200) {
        final message =
            response == 'accept' ? '찾아가기 요청을 수락했습니다' : '찾아가기 요청을 거절했습니다';
        _showSnackBar(message);

        if (widget.onResponseSent != null) {
          widget.onResponseSent!();
        }
        Navigator.pop(context);
      } else {
        _showSnackBar(data['error'] ?? '응답 실패');
      }
    } catch (e) {
      print('찾아가기 응답 오류: $e');
      _showSnackBar('네트워크 오류가 발생했습니다');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 제목
            Text(
              '찾아가기 요청',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),

            // 요청 메시지
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: TextStyle(fontSize: 16, color: Colors.black87),
                children: [
                  TextSpan(
                    text: widget.requesterName,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  TextSpan(text: '님이 찾아가기를 요청했습니다.'),
                ],
              ),
            ),
            SizedBox(height: 12),

            // 허용 시간 안내
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Text(
                '허용 시간: 1시간',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.orange[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            SizedBox(height: 24),

            // 버튼들
            if (_isLoading)
              Center(child: CircularProgressIndicator())
            else
              Row(
                children: [
                  // 거절 버튼
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _respondToRequest('reject'),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(color: Colors.grey),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        '거절',
                        style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),

                  // 허용 버튼
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _respondToRequest('accept'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        '허용',
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
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
