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
  String _selectedDevice = 'Computer'; // 기본값: 컴퓨터 위치
  String _address = '';
  String _zipcode = '';
  final String _apiKey = 'YOUR_GOOGLE_MAPS_API_KEY'; // 구글 맵스 API 키를 입력하세요.

  // 1단계: 위치 권한 요청 및 좌표 수집 함수
  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // 위치 서비스 활성화 여부 확인
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showErrorSnackBar('위치 서비스가 비활성화되어 있습니다.');
      return;
    }

    // 2단계: 위치 정보 접근 권한 동의 구하기 (위치정보법 준수)
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
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

    // 3단계: 현재 좌표 가져오기
    try {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      _convertToAddress(position.latitude, position.longitude);
    } catch (e) {
      _showErrorSnackBar('위치 정보를 가져오는 중 오류가 발생했습니다: $e');
    }
  }

  // 4단계: Google Maps Reverse Geocoding API를 사용하여 주소 변환
  Future<void> _convertToAddress(double lat, double lng) async {
    final url =
        'https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&key=$_apiKey&language=ko';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final results = data['results'] as List;
          if (results.isNotEmpty) {
            // 도로명 주소 또는 첫 번째 결과 선택
            final result = results.firstWhere(
                (r) => (r['types'] as List).contains('street_address'),
                orElse: () => results[0]);

            String address = result['formatted_address'] ?? '주소를 찾을 수 없습니다.';
            String zipcode = '우편번호를 찾을 수 없습니다.';

            // 우편번호 추출
            for (var component in result['address_components']) {
              if ((component['types'] as List).contains('postal_code')) {
                zipcode = component['long_name'];
                break;
              }
            }

            setState(() {
              // 5단계: 결과 표시 (기기 선택에 따른 접두어 추가)
              String prefix = '[$_selectedDevice] ';
              _address = '$prefix$address';
              _zipcode = '$prefix$zipcode';
            });
          }
        } else {
          _showErrorSnackBar('주소 변환 실패: ${data['status']}');
        }
      } else {
        _showErrorSnackBar('서버 응답 오류: ${response.statusCode}');
      }
    } catch (e) {
      _showErrorSnackBar('주소 변환 중 오류가 발생했습니다: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('위치 정보 확인'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 기기 선택 UI (라디오 버튼)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Radio<String>(
                  value: 'Computer',
                  groupValue: _selectedDevice,
                  onChanged: (value) {
                    setState(() {
                      _selectedDevice = value!;
                    });
                  },
                ),
                const Text('컴퓨터 위치'),
                const SizedBox(width: 20),
                Radio<String>(
                  value: 'Mobile',
                  groupValue: _selectedDevice,
                  onChanged: (value) {
                    setState(() {
                      _selectedDevice = value!;
                    });
                  },
                ),
                const Text('휴대폰 위치'),
              ],
            ),
            const SizedBox(height: 40),
            // 확인 버튼
            SizedBox(
              width: double.infinity,
              height: 80,
              child: ElevatedButton(
                onPressed: _getCurrentLocation,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  '현재 위치 확인할까요?',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 40),
            // 결과 표시 영역
            Align(
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '도로명 주소: $_address',
                    style: const TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '우편번호: $_zipcode',
                    style: const TextStyle(fontSize: 18),
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
