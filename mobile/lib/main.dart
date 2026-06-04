import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '위치 정보 확인 서비스',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const LocationServicePage(),
    );
  }
}

class LocationServicePage extends StatefulWidget {
  const LocationServicePage({super.key});

  @override
  State<LocationServicePage> createState() => _LocationServicePageState();
}

enum DeviceType { computer, mobile }

class _LocationServicePageState extends State<LocationServicePage> {
  // 1단계: 기기 선택 상태 관리
  DeviceType _selectedDevice = DeviceType.computer;
  String _address = "-";
  String _zipcode = "-";
  bool _isLoading = false;

  // Google Maps API Key (실제 키로 교체 필요)
  final String _apiKey = 'YOUR_GOOGLE_MAPS_API_KEY';

  /**
   * 위치 정보를 수집하고 주소로 변환하는 메인 함수
   */
  Future<void> _handleLocationCheck() async {
    // 2단계: 위치 정보 접근 권한 확인 및 요청 (위치정보법 준수)
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showMessage("위치 서비스가 비활성화되어 있습니다.");
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showMessage("위치 권한이 거부되었습니다.");
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showMessage("위치 권한이 영구적으로 거부되었습니다. 설정에서 변경해 주세요.");
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 3단계: 현재 위치 좌표 수집 (고정확도 설정)
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      // 4단계: Google Maps Reverse Geocoding API 호출 (한국어 설정)
      final String prefix = _selectedDevice == DeviceType.computer ? "[Computer] " : "[Mobile] ";
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json?latlng=${position.latitude},${position.longitude}&key=$_apiKey&language=ko'
      );

      final response = await http.get(url);
      final data = json.decode(response.body);

      if (data['status'] == 'OK') {
        String roadAddr = "주소를 찾을 수 없습니다.";
        String zip = "우편번호 없음";

        if (data['results'].isNotEmpty) {
          final result = data['results'][0];
          roadAddr = prefix + result['formatted_address'];

          // 우편번호 추출
          final components = result['address_components'] as List;
          final postComponent = components.firstWhere(
            (c) => (c['types'] as List).contains('postal_code'),
            orElse: () => null,
          );
          if (postComponent != null) {
            zip = postComponent['long_name'];
          }
        }

        // 5단계: 결과 표시
        setState(() {
          _address = roadAddr;
          _zipcode = zip;
        });
      } else {
        _showMessage("주소 변환 실패: ${data['status']}");
      }
    } catch (e) {
      _showMessage("오류가 발생했습니다: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('위치 정보 확인 서비스')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 1-1단계: 기기 선택 UI (Radio 사용)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Radio<DeviceType>(
                  value: DeviceType.computer,
                  groupValue: _selectedDevice,
                  onChanged: (value) => setState(() => _selectedDevice = value!),
                ),
                const Text('컴퓨터 위치'),
                const SizedBox(width: 20),
                Radio<DeviceType>(
                  value: DeviceType.mobile,
                  groupValue: _selectedDevice,
                  onChanged: (value) => setState(() => _selectedDevice = value!),
                ),
                const Text('휴대폰 위치'),
              ],
            ),
            const SizedBox(height: 40),

            // 2-1단계: 메인 확인 버튼
            SizedBox(
              width: double.infinity,
              height: 80,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleLocationCheck,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("현재 위치 확인할까요?", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ),
            ),

            const SizedBox(height: 40),

            // 3-1단계: 결과 표시 영역
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("도로명 주소: $_address", style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 10),
                  Text("우편번호: $_zipcode", style: const TextStyle(fontSize: 16)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
