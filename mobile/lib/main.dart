import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// ignore_for_file: deprecated_member_use

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
        primarySwatch: Colors.green,
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

enum DeviceType { computer, mobile }

class _LocationPageState extends State<LocationPage> {
  DeviceType _selectedDevice = DeviceType.computer;
  String _address = "도로명 주소: ";
  String _zipcode = "우편번호: ";
  bool _isLoading = false;

  // 구글 맵스 API 키 (플레이스홀더)
  final String _googleMapsApiKey = "YOUR_GOOGLE_MAPS_API_KEY";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('위치 정보 확인 서비스'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 단계 1: 기기 선택 UI (RadioListTile)
            const Text("기기를 선택해 주세요", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            RadioListTile<DeviceType>(
              title: const Text('컴퓨터 위치'),
              value: DeviceType.computer,
              groupValue: _selectedDevice,
              onChanged: (DeviceType? value) {
                setState(() {
                  _selectedDevice = value!;
                });
              },
            ),
            RadioListTile<DeviceType>(
              title: const Text('휴대폰 위치'),
              value: DeviceType.mobile,
              groupValue: _selectedDevice,
              onChanged: (DeviceType? value) {
                setState(() {
                  _selectedDevice = value!;
                });
              },
            ),
            const SizedBox(height: 30),

            // 단계 2: 위치 확인 버튼
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleLocationRequest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(
                  _isLoading ? "위치 확인 중..." : "현재 위치 확인할까요?",
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 30),

            // 단계 3: 결과 표시 영역
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(_address, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Text(_zipcode, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 단계 4: 위치 수집 및 주소 변환 통합 핸들러
  Future<void> _handleLocationRequest() async {
    // 1. 위치 정보 접근 권한 확인 및 요청 (위치정보법 준수)
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showErrorSnackBar('위치 서비스가 비활성화되어 있습니다.');
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      // 팝업을 통해 명시적 권한 요청
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showErrorSnackBar('위치 권한이 거부되었습니다.');
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showErrorSnackBar('위치 권한이 영구적으로 거부되었습니다. 설정에서 허용해 주세요.');
      return;
    }

    // 2. 좌표 수집 시작
    setState(() {
      _isLoading = true;
    });

    try {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high)
      );

      // 3. Reverse Geocoding API 호출
      await _reverseGeocode(position.latitude, position.longitude);
    } catch (e) {
      _showErrorSnackBar('위치 정보를 가져오는 중 오류 발생: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 단계 5: Google Reverse Geocoding API 연동 (HTTP)
  Future<void> _reverseGeocode(double lat, double lng) async {
    final String deviceLabel = _selectedDevice == DeviceType.computer ? "[Computer]" : "[Mobile]";
    final String url = "https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&key=$_googleMapsApiKey&language=ko";

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && data['results'].isNotEmpty) {
          final result = data['results'][0];
          final String formattedAddress = result['formatted_address'];

          // 우편번호 추출
          String postalCode = "정보 없음";
          final addressComponents = result['address_components'] as List;
          for (var component in addressComponents) {
            final types = component['types'] as List;
            if (types.contains('postal_code')) {
              postalCode = component['long_name'];
              break;
            }
          }

          setState(() {
            _address = "도로명 주소: $deviceLabel $formattedAddress";
            _zipcode = "우편번호: $postalCode";
          });
        } else {
          _showErrorSnackBar('주소를 찾을 수 없습니다: ${data['status']}');
        }
      } else {
        _showErrorSnackBar('API 서버 오류: ${response.statusCode}');
      }
    } catch (e) {
      _showErrorSnackBar('주소 변환 중 오류 발생: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}
