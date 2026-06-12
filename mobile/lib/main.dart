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
      title: '심플 위치 확인',
      theme: ThemeData(
        primarySwatch: Colors.blue,
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
  // 단계 1: 기기 선택 상태 관리
  String _selectedDevice = 'Computer';
  String _roadAddress = '[결과 대기 중]';
  String _zipCode = '[결과 대기 중]';
  bool _isLoading = false;

  // Google Maps API Key (실제 키로 교체 필요)
  final String _apiKey = 'YOUR_GOOGLE_MAPS_API_KEY';

  // 단계 4: 위치 권한 요청 및 좌표 수집
  Future<void> _handleLocationCheck() async {
    setState(() {
      _isLoading = true;
      _roadAddress = '위치 확인 중...';
      _zipCode = '위치 확인 중...';
    });

    try {
      // 1. 위치 서비스 활성화 여부 확인
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw '위치 서비스가 비활성화되어 있습니다.';
      }

      // 2. 위치 정보 접근 권한 확인 및 요청 (위치정보법 준수)
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

      // 3. 현재 좌표 가져오기
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      // 단계 5: Google Maps API 연동 및 주소 변환
      await _fetchAddress(position.latitude, position.longitude);
    } catch (e) {
      setState(() {
        _roadAddress = '오류: $e';
        _zipCode = '오류 발생';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchAddress(double lat, double lng) async {
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&key=$_apiKey&language=ko'
    );

    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['status'] == 'OK') {
        String address = "정보 없음";
        String zip = "정보 없음";

        if (data['results'].isNotEmpty) {
          address = data['results'][0]['formatted_address'];

          final components = data['results'][0]['address_components'] as List;
          for (var comp in components) {
            final types = comp['types'] as List;
            if (types.contains('postal_code')) {
              zip = comp['long_name'];
              break;
            }
          }
        }

        setState(() {
          _roadAddress = '[$_selectedDevice] $address';
          _zipCode = zip;
        });
      } else {
        throw 'API 오류: ${data['status']}';
      }
    } else {
      throw '서버 연결 실패';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('위치 정보 서비스'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 단계 2: 기기 선택 UI
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Radio<String>(
                  value: 'Computer',
                  groupValue: _selectedDevice,
                  onChanged: (value) {
                    setState(() { _selectedDevice = value!; });
                  },
                ),
                const Text('컴퓨터 위치'),
                const SizedBox(width: 20),
                Radio<String>(
                  value: 'Mobile',
                  groupValue: _selectedDevice,
                  onChanged: (value) {
                    setState(() { _selectedDevice = value!; });
                  },
                ),
                const Text('휴대폰 위치'),
              ],
            ),
            const SizedBox(height: 30),

            // 단계 3: 확인 버튼
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleLocationCheck,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('현재 위치 확인할까요?'),
              ),
            ),
            const SizedBox(height: 40),

            // 단계 6: 결과 표시 영역
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(10),
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
          ],
        ),
      ),
    );
  }
}
