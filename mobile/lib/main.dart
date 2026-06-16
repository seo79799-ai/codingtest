// ignore_for_file: deprecated_member_use
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
      title: '위치 정보 확인 서비스',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const LocationScreen(),
    );
  }
}

class LocationScreen extends StatefulWidget {
  const LocationScreen({super.key});

  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  // 1단계: 기기 선택 상태 관리 (컴퓨터 위치 / 휴대폰 위치)
  String _selectedDevice = '컴퓨터 위치';
  String _address = '도로명 주소: ';
  String _zipcode = '우편번호: ';
  bool _isLoading = false;

  // Google Maps API Key (실제 키로 교체 필요)
  final String _apiKey = 'YOUR_GOOGLE_MAPS_API_KEY';

  // 2단계: 위치 권한 확인 및 요청 (위치정보법 준수)
  Future<void> _handleLocationCheck() async {
    bool serviceEnabled;
    LocationPermission permission;

    // 서비스 활성화 확인
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('위치 서비스가 비활성화되어 있습니다.')),
        );
      }
      return;
    }

    // 권한 확인 및 요청
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      // 사용자에게 동의를 구하는 팝업 노출
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('위치 권한이 거부되었습니다.')),
          );
        }
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('위치 권한이 영구적으로 거부되었습니다. 설정에서 변경해주세요.')),
        );
      }
      return;
    }

    // 모든 권한이 승인되면 위치 정보 수집 시작
    _getCurrentLocation();
  }

  // 3단계: 현재 좌표 수집
  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoading = true;
      _address = '도로명 주소: 로딩 중...';
      _zipcode = '우편번호: 로딩 중...';
    });

    try {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      // 4단계: Reverse Geocoding API 호출 (주소 변환)
      await _reverseGeocode(position.latitude, position.longitude);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _address = '도로명 주소: 에러 발생';
        _zipcode = '우편번호: 에러 발생';
      });
    }
  }

  Future<void> _reverseGeocode(double lat, double lng) async {
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&key=$_apiKey&language=ko'
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final result = data['results'][0];
          final formattedAddress = result['formatted_address'];

          String postalCode = '검색 실패';
          final List components = result['address_components'];
          for (var component in components) {
            final List types = component['types'];
            if (types.contains('postal_code')) {
              postalCode = component['long_name'];
              break;
            }
          }

          setState(() {
            // 요구사항: [결과] 형식에 맞춰 기기 타입 포함 출력
            _address = '도로명 주소: [$_selectedDevice] $formattedAddress';
            _zipcode = '우편번호: $postalCode';
            _isLoading = false;
          });
        } else {
          throw Exception('Geocoding failed');
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _address = '도로명 주소: 변환 실패';
        _zipcode = '우편번호: 변환 실패';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('위치 정보 확인 서비스'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 5단계: 기기 선택 UI (라디오 버튼)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Radio<String>(
                  value: '컴퓨터 위치',
                  groupValue: _selectedDevice,
                  onChanged: (value) {
                    setState(() { _selectedDevice = value!; });
                  },
                ),
                const Text('컴퓨터 위치'),
                const SizedBox(width: 20),
                Radio<String>(
                  value: '휴대폰 위치',
                  groupValue: _selectedDevice,
                  onChanged: (value) {
                    setState(() { _selectedDevice = value!; });
                  },
                ),
                const Text('휴대폰 위치'),
              ],
            ),
            const SizedBox(height: 40),

            // 6단계: 큰 확인 버튼
            SizedBox(
              width: double.infinity,
              height: 70,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleLocationCheck,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('현재 위치 확인할까요?'),
              ),
            ),
            const SizedBox(height: 40),

            // 7단계: 결과 표시 텍스트
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _address,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _zipcode,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
