import 'package:flutter/material.dart';
import 'package:tomapto/pages/friends/real_time_location_sharing.dart';

class FriendsShowModal extends StatelessWidget {
  final Map<String, dynamic> friend;
  final bool hasFollowRequest; // 추가된 파라미터

  const FriendsShowModal({
    Key? key,
    required this.friend,
    this.hasFollowRequest = false, // 추가된 파라미터
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 16.0),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 친구 위치 보기 버튼
            InkWell(
              onTap: () {
                Navigator.pop(context);
                // 실시간 위치 공유 페이지로 이동
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) =>
                            RealTimeLocationSharingPage(selectedFriend: friend),
                  ),
                );
              },
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.only(left: 16.0),
                  child: Row(
                    children: [
                      Text(
                        '친구 위치 보기',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      // 따라가기 요청이 있을 때 느낌표 표시
                      if (hasFollowRequest)
                        Container(
                          margin: EdgeInsets.only(left: 8),
                          padding: EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '!',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // 구분선
            Container(height: 1, color: Colors.grey[300]),

            // 친구 캘린더 보기 버튼
            InkWell(
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('캘린더 기능은 준비 중입니다')));
              },
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.only(left: 16.0),
                  child: Text(
                    '친구 캘린더 보기',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    textAlign: TextAlign.left,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 프로필을 클릭했을 때 모달을 표시하는 함수
void showFriendProfile(
  BuildContext context,
  Map<String, dynamic> friend, {
  bool hasFollowRequest = false,
}) {
  showDialog(
    context: context,
    builder:
        (context) => FriendsShowModal(
          friend: friend,
          hasFollowRequest: hasFollowRequest, // 추가된 파라미터 전달
        ),
  );
}
