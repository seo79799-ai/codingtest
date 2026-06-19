import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:convert';

// ignore_for_file: deprecated_member_use

void main() {
  runApp(const SimpleLocationApp());
}

class SimpleLocationApp extends StatelessWidget {
  const SimpleLocationApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '심플 위치 확인',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        fontFamily: 'Pretendard',
      ),
      home: const LocationHomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class LocationHomeScreen extends StatefulWidget {
  const LocationHomeScreen({super.key});

  @override
  State<LocationHomeScreen> createState() => _LocationHomeScreenState();
}

class _LocationHomeScreenState extends State<LocationHomeScreen> {
  // 상태 변수
  String _address = "현재 위치를 확인해 보세요";
  String _zipcode = "";
  String _deviceType = "휴대폰";
  bool _isLoading = false;

  // Google Maps API Key (실제 키로 교체 필요)
  final String _googleMapsApiKey = "YOUR_GOOGLE_MAPS_API_KEY";

  /**
   * 1단계: 위치 권한 확인 및 좌표 수집
   */
  Future<void> _handleLocationService() async {
    setState(() {
      _isLoading = true;
      _address = "위치 정보를 가져오는 중...";
      _zipcode = "";
    });

    try {
      // 위치 서비스 활성화 여부 확인
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw '위치 서비스가 비활성화되어 있습니다.';
      }

      // 위치 정보법 준수: 권한 확인 및 요청
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw '위치 권한이 거부되었습니다.';
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw '위치 권한이 영구적으로 거부되었습니다. 설정에서 권한을 허용해 주세요.';
      }

      // 현재 좌표 가져오기
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      // 2단계: 역지오코딩 호출
      await _reverseGeocode(position.latitude, position.longitude);
    } catch (e) {
      setState(() {
        _address = e.toString();
        _isLoading = false;
      });
      _showErrorSnackBar(e.toString());
    }
  }

  /**
   * 2단계: Google Maps Reverse Geocoding API 호출
   */
  Future<void> _reverseGeocode(double lat, double lng) async {
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&key=$_googleMapsApiKey&language=ko'
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final result = data['results'][0];

          // 대한민국 문구 제거
          String formattedAddress = result['formatted_address'].toString().replaceAll("대한민국 ", "");
          String postalCode = "-";

          // 우편번호 추출
          for (var component in result['address_components']) {
            final types = component['types'] as List;
            if (types.contains('postal_code')) {
              postalCode = component['long_name'];
            }
          }

          setState(() {
            _address = formattedAddress;
            _zipcode = postalCode;
            _isLoading = false;
          });
        } else {
          throw '주소를 찾을 수 없습니다 (${data['status']})';
        }
      } else {
        throw 'API 호출 실패 (Status: ${response.statusCode})';
      }
    } catch (e) {
      setState(() {
        _address = "주소 변환 중 오류가 발생했습니다.";
        _isLoading = false;
      });
      _showErrorSnackBar(e.toString());
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('내 위치 확인', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      // AdSense 준수를 위한 추가 정보 Drawer
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.blueAccent),
              child: Text(
                '유용한 생활 정보',
                style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('도로명 주소 유래'),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('도로명 주소란?'),
                    content: const Text('2014년부터 전면 시행된 도로명 주소는 지번 중심에서 도로와 건물 번호 중심으로 바꾼 체계로, 위치 찾기의 편의성을 극대화한 시스템입니다.'),
                    actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('닫기'))],
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.emergency),
              title: const Text('긴급 연락처'),
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  builder: (context) => Container(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('긴급 연락처 바로걸기', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _emergencyBtn('112', '경찰', Colors.blue),
                            _emergencyBtn('119', '소방', Colors.red),
                            _emergencyBtn('110', '민원', Colors.orange),
                          ],
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
      body: Container(
        padding: const EdgeInsets.all(24.0),
        color: Colors.white,
        child: Column(
          children: [
            const SizedBox(height: 20),
            // 3단계: 기기 선택 UI
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Radio<String>(
                  value: "컴퓨터",
                  groupValue: _deviceType,
                  onChanged: (v) => setState(() => _deviceType = v!),
                ),
                const Text("컴퓨터 위치"),
                const SizedBox(width: 20),
                Radio<String>(
                  value: "휴대폰",
                  groupValue: _deviceType,
                  onChanged: (v) => setState(() => _deviceType = v!),
                ),
                const Text("휴대폰 위치"),
              ],
            ),
            const SizedBox(height: 30),
            // 4단계: 핵심 확인 버튼
            SizedBox(
              width: double.infinity,
              height: 70,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(35)),
                  elevation: 5,
                ),
                onPressed: _isLoading ? null : _handleLocationService,
                child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("현재 위치 확인할까요?", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 50),
            // 5단계: 결과 표시 영역
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("도로명 주소:", style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    Text(
                      _zipcode.isNotEmpty ? "[$_deviceType 위치] $_address" : _address,
                      style: const TextStyle(fontSize: 18, height: 1.4),
                    ),
                    const SizedBox(height: 24),
                    const Text("우편번호:", style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    Text(
                      _zipcode.isNotEmpty ? _zipcode : "-",
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    if (_zipcode.isNotEmpty)
                      Center(
                        child: OutlinedButton.icon(
                          onPressed: () => Share.share('현재 위치: $_address (우편번호: $_zipcode)'),
                          icon: const Icon(Icons.share),
                          label: const Text("위치 공유하기"),
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emergencyBtn(String number, String label, Color color) {
    return Column(
      children: [
        IconButton.filled(
          onPressed: () => launchUrl(Uri.parse('tel:$number')),
          icon: const Icon(Icons.phone),
          style: IconButton.styleFrom(backgroundColor: color),
          padding: const EdgeInsets.all(15),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(number, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
      ],
    );
  }
}
