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
      title: '심플 위치 확인 서비스',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const LocationHomePage(),
    );
  }
}

class LocationHomePage extends StatefulWidget {
  const LocationHomePage({super.key});

  @override
  State<LocationHomePage> createState() => _LocationHomePageState();
}

class _LocationHomePageState extends State<LocationHomePage> {
  // 기기 선택 상태: '컴퓨터' 또는 '휴대폰'
  String _selectedDevice = '컴퓨터';
  String _roadAddress = '[결과 대기 중]';
  String _zipCode = '[결과 대기 중]';
  bool _isLoading = false;

  // Google Maps API 키 (실제 키로 교체 필요)
  final String _googleMapsApiKey = 'YOUR_GOOGLE_MAPS_API_KEY';

  // 1단계: 위치 권한 요청 및 좌표 수집
  Future<void> _checkLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // 위치 서비스 활성화 여부 확인
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showErrorSnackBar('위치 서비스가 비활성화되어 있습니다.');
      return;
    }

    // 위치 정보 접근 권한 동의 구하기 (위치정보법 준수)
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showErrorSnackBar('위치 권한이 거부되었습니다.');
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showErrorSnackBar('위치 권한이 영구적으로 거부되었습니다. 설정에서 변경해 주세요.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 현재 위치 좌표 가져오기
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      // 2단계: Reverse Geocoding API 호출
      await _reverseGeocode(position.latitude, position.longitude);
    } catch (e) {
      _showErrorSnackBar('위치 정보를 가져오는 중 오류가 발생했습니다: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 3단계: 주소 변환 로직
  Future<void> _reverseGeocode(double lat, double lng) async {
    final url = 'https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&key=$_googleMapsApiKey&language=ko';

    try {
      final response = await http.get(Uri.parse(url));
      final data = json.decode(response.body);

      if (data['status'] == 'OK') {
        final results = data['results'] as List;
        if (results.isNotEmpty) {
          final firstResult = results[0];
          String formattedAddress = firstResult['formatted_address'];

          String zip = '정보 없음';
          final components = firstResult['address_components'] as List;
          for (var component in components) {
            final types = component['types'] as List;
            if (types.contains('postal_code')) {
              zip = component['long_name'];
              break;
            }
          }

          setState(() {
            // 4단계: 결과 표시 (기기 타입 접두사 포함)
            _roadAddress = '[$_selectedDevice] $formattedAddress';
            _zipCode = '[$_selectedDevice] $zip';
          });
        }
      } else {
        _showErrorSnackBar('주소 변환 실패: ${data['status']}');
      }
    } catch (e) {
      _showErrorSnackBar('API 호출 중 오류가 발생했습니다: $e');
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
        title: const Text('심플 위치 확인 서비스'),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 기기 선택 라디오 버튼
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Radio<String>(
                    value: '컴퓨터',
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
                    value: '휴대폰',
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

              // 메인 확인 버튼
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _checkLocation,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: const Text(
                        '현재 위치 확인할까요?',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ),
              const SizedBox(height: 50),

              // 결과 표시 영역
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Column(
                  children: [
                    Text(
                      '도로명 주소: $_roadAddress',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '우편번호: $_zipCode',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
