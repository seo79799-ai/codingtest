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
      home: const LocationCheckPage(),
    );
  }
}

class LocationCheckPage extends StatefulWidget {
  const LocationCheckPage({super.key});

  @override
  State<LocationCheckPage> createState() => _LocationCheckPageState();
}

class _LocationCheckPageState extends State<LocationCheckPage> {
  // 기기 선택 상태: 'Computer' 또는 'Mobile'
  String _deviceType = 'Computer';
  String _roadAddress = '[결과 대기 중]';
  String _zipCode = '[결과 대기 중]';
  bool _isLoading = false;

  // Google Maps API Key (placeholder)
  final String _apiKey = 'YOUR_GOOGLE_MAPS_API_KEY';

  // 1단계: 위치 권한 요청 및 좌표 수집
  Future<void> _checkLocation() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 위치 서비스 활성화 여부 확인
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw '위치 서비스가 비활성화되어 있습니다.';
      }

      // 위치 권한 확인 및 요청 (위치정보법 준수)
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw '위치 권한이 거부되었습니다.';
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw '위치 권한이 영구적으로 거부되었습니다. 설정에서 변경해 주세요.';
      }

      // 현재 위치 가져오기
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      // 2단계: Reverse Geocoding API 호출
      await _convertToAddress(position.latitude, position.longitude);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // 2단계 상세: 좌표를 주소로 변환
  Future<void> _convertToAddress(double lat, double lng) async {
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&key=$_apiKey&language=ko',
    );

    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['status'] == 'OK') {
        final results = data['results'] as List;
        if (results.isNotEmpty) {
          final firstResult = results[0];
          String address = firstResult['formatted_address'];
          String zip = '우편번호 없음';

          // 우편번호 구성 요소 찾기
          final components = firstResult['address_components'] as List;
          for (var comp in components) {
            final types = comp['types'] as List;
            if (types.contains('postal_code')) {
              zip = comp['long_name'];
              break;
            }
          }

          setState(() {
            String prefix = _deviceType == 'Computer' ? '[컴퓨터] ' : '[모바일] ';
            _roadAddress = prefix + address;
            _zipCode = zip;
          });
        }
      } else {
        throw '주소를 변환할 수 없습니다. (상태: ${data['status']})';
      }
    } else {
      throw '서버 통신 오류가 발생했습니다.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📍 현재 위치 정보 확인'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // 1단계 UI: 기기 선택 (Radio)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Radio<String>(
                  value: 'Computer',
                  groupValue: _deviceType,
                  onChanged: (value) {
                    setState(() => _deviceType = value!);
                  },
                ),
                const Text('컴퓨터 위치'),
                const SizedBox(width: 20),
                Radio<String>(
                  value: 'Mobile',
                  groupValue: _deviceType,
                  onChanged: (value) {
                    setState(() => _deviceType = value!);
                  },
                ),
                const Text('휴대폰 위치'),
              ],
            ),
            const SizedBox(height: 30),

            // 2단계 UI: 확인 버튼
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _checkLocation,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        '현재 위치 확인할까요?',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
            const SizedBox(height: 40),

            // 3단계 UI: 결과 표시
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '도로명 주소: $_roadAddress',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '우편번호: $_zipCode',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),
            // 부가 정보 섹션
            const Align(
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('💡 도로명 주소란?', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('도로에 이름을 붙이고 건물에 번호를 붙여 표기하는 주소 체계입니다.'),
                  SizedBox(height: 15),
                  Text('🚑 안전 및 생활 정보', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('비상시 인근 119 안전센터나 경찰서 위치 파악에 유용합니다.'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
