import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

// ignore_for_file: deprecated_member_use

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
        primarySwatch: Colors.green,
        useMaterial3: true,
      ),
      home: const LocationHome(),
    );
  }
}

class LocationHome extends StatefulWidget {
  const LocationHome({super.key});

  @override
  State<LocationHome> createState() => _LocationHomeState();
}

class _LocationHomeState extends State<LocationHome> {
  String _deviceType = 'computer'; // 기본값
  String _address = '[결과]';
  String _postcode = '[결과]';
  bool _isLoading = false;

  // [보안] 위치정보법 준수: 수집 전 사용자 동의 구하기 팝업
  Future<void> _requestLocationPermission() async {
    bool? consent = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('위치 정보 이용 동의'),
        content: const Text('정확한 주소 확인을 위해 위치 정보 접근 권한이 필요합니다. 동의하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('동의')),
        ],
      ),
    );

    if (consent == true) {
      _getCurrentLocation();
    }
  }

  // [위치 수집] geolocator 패키지 사용
  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoading = true;
      _address = '위치 확인 중...';
      _postcode = '위치 확인 중...';
    });

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        throw '위치 권한이 영구적으로 거부되었습니다.';
      }

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      _reverseGeocode(position.latitude, position.longitude);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _address = '오류: $e';
        _postcode = '-';
      });
    }
  }

  // [주소 변환] Google Maps Reverse Geocoding API 호출
  Future<void> _reverseGeocode(double lat, double lng) async {
    // 주의: 실제 서비스 시에는 백엔드를 통해 API Key를 숨겨야 합니다.
    const String apiKey = 'YOUR_GOOGLE_MAPS_API_KEY';
    final String url = 'https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&key=$apiKey&language=ko';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && data['results'].isNotEmpty) {
          final result = data['results'][0];
          final String formattedAddress = result['formatted_address'];

          String zipCode = '정보 없음';
          for (var component in result['address_components']) {
            if ((component['types'] as List).contains('postal_code')) {
              zipCode = component['long_name'];
              break;
            }
          }

          final prefix = _deviceType == 'computer' ? '[컴퓨터 위치] ' : '[휴대폰 위치] ';

          setState(() {
            _address = prefix + formattedAddress;
            _postcode = zipCode;
            _isLoading = false;
          });
        } else {
          throw '주소를 찾을 수 없습니다 (${data['status']})';
        }
      } else {
        throw 'API 호출 실패';
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _address = '오류: $e';
        _postcode = '-';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('위치 확인 서비스')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 기기 선택: 라디오 버튼
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Radio<String>(
                  value: 'computer',
                  groupValue: _deviceType,
                  onChanged: (value) => setState(() => _deviceType = value!),
                ),
                const Text('컴퓨터 위치'),
                const SizedBox(width: 20),
                Radio<String>(
                  value: 'mobile',
                  groupValue: _deviceType,
                  onChanged: (value) => setState(() => _deviceType = value!),
                ),
                const Text('휴대폰 위치'),
              ],
            ),
            const SizedBox(height: 40),

            // 확인 버튼: 중심에 큰 버튼
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _requestLocationPermission,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('현재 위치 확인할까요?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 40),

            // 결과 표시 영역
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(10),
                border: const Border(left: BorderSide(color: Colors.green, width: 5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('도로명 주소: $_address', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 10),
                  Text('우편번호: $_postcode', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
