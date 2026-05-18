import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '단순 위치 정보 확인',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const LocationPage(),
    );
  }
}

class LocationPage extends StatefulWidget {
  const LocationPage({super.key});

  @override
  State<LocationPage> createState() => _LocationPageState();
}

class _LocationPageState extends State<LocationPage> {
  // 기기 선택 상태 (0: 컴퓨터, 1: 휴대폰)
  int _selectedDevice = 0;
  String _roadAddress = "-";
  String _zipCode = "-";
  bool _isLoading = false;

  // Google Maps API 키 (실제 키로 교체 필요)
  final String _googleMapsApiKey = "YOUR_API_KEY_HERE";

  // 단계 5: 위치 정보 권한 확인 및 좌표 수집
  Future<void> _handleLocationCheck() async {
    // 1. 사용자 동의 팝업 (위치정보법 준수)
    bool? consent = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("위치 정보 활용 동의"),
        content: const Text("위치 정보를 수집하여 주소로 변환하는 데 동의하십니까?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("취소")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("동의")),
        ],
      ),
    );

    if (consent != true) return;

    setState(() => _isLoading = true);

    try {
      // 2. 권한 확인 및 요청
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showMessage("위치 권한이 거부되었습니다.");
          return;
        }
      }

      // 3. 현재 위치 좌표 가져오기
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // 4. Reverse Geocoding API 호출
      await _fetchAddress(position.latitude, position.longitude);
    } catch (e) {
      _showMessage("위치 정보를 가져오는 중 오류가 발생했습니다.");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // 단계 5 계속: 구글 API를 통한 주소 변환
  Future<void> _fetchAddress(double lat, double lng) async {
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&key=$_googleMapsApiKey&language=ko'
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final results = data['results'] as List;
          if (results.isNotEmpty) {
            String roadAddr = results[0]['formatted_address'];
            String zip = "찾을 수 없음";

            final components = results[0]['address_components'] as List;
            for (var component in components) {
              final types = component['types'] as List;
              if (types.contains('postal_code')) {
                zip = component['long_name'];
                break;
              }
            }

            setState(() {
              _roadAddress = roadAddr;
              _zipCode = zip;
            });
          }
        } else {
          _showMessage("주소 변환 실패: ${data['status']}");
        }
      }
    } catch (e) {
      _showMessage("API 호출 중 오류가 발생했습니다.");
    }
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("단순 위치 정보 확인")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 단계 1: 기기 선택 (라디오 버튼 스타일의 토글)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Radio<int>(
                  value: 0,
                  groupValue: _selectedDevice,
                  onChanged: (val) => setState(() => _selectedDevice = val!),
                ),
                const Text("컴퓨터 위치"),
                const SizedBox(width: 20),
                Radio<int>(
                  value: 1,
                  groupValue: _selectedDevice,
                  onChanged: (val) => setState(() => _selectedDevice = val!),
                ),
                const Text("휴대폰 위치"),
              ],
            ),
            const SizedBox(height: 40),

            // 단계 2: 확인 버튼
            SizedBox(
              width: double.infinity,
              height: 80,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleLocationCheck,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("현재 위치 확인할까요?", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 40),

            // 단계 3: 결과 표시
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("도로명 주소: $_roadAddress", style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 10),
                  Text("우편번호: $_zipCode", style: const TextStyle(fontSize: 16)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
