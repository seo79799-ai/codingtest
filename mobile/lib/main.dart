// ignore_for_file: deprecated_member_use

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
  // 1단계: 변수 설정 (기기 선택 및 결과 저장)
  String _deviceType = 'Computer';
  String _address = '';
  String _zipCode = '';
  bool _isLoading = false;

  // Google Maps API Key (사용자가 실제 키로 교체해야 함)
  final String _apiKey = 'YOUR_GOOGLE_MAPS_API_KEY';

  // 2단계: 위치 권한 확인 및 위치 정보 가져오기
  Future<void> _requestLocation() async {
    // 위치정보법 준수를 위한 사전 동의 확인 (다이얼로그)
    bool? consent = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('위치 정보 수집 동의'),
        content: const Text('위치 정보를 수집하여 주소를 확인하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('동의'),
          ),
        ],
      ),
    );

    if (consent != true) return;

    setState(() {
      _isLoading = true;
      _address = '';
      _zipCode = '';
    });

    try {
      // 위치 서비스 활성화 여부 확인
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw '위치 서비스가 비활성화되어 있습니다.';
      }

      // 위치 권한 확인 및 요청
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw '위치 권한이 거부되었습니다.';
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw '위치 권한이 영구적으로 거부되었습니다. 설정에서 변경해주세요.';
      }

      // 3단계: 현재 위치 좌표 수집 (locationSettings 사용)
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      // 4단계: Google Reverse Geocoding API 호출
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

  Future<void> _convertToAddress(double lat, double lng) async {
    final url = 'https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&key=$_apiKey&language=ko';

    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['status'] == 'OK') {
        final result = data['results'][0];
        String formattedAddress = result['formatted_address'];
        String postalCode = '정보 없음';

        for (var component in result['address_components']) {
          if ((component['types'] as List).contains('postal_code')) {
            postalCode = component['long_name'];
            break;
          }
        }

        setState(() {
          // 5단계: 결과 표시 ([기기명] 접두사 추가)
          _address = '도로명 주소: [$_deviceType] $formattedAddress';
          _zipCode = '우편번호: $postalCode';
        });
      } else {
        throw '주소 변환 실패: ${data['status']}';
      }
    } else {
      throw 'API 호출 실패';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('위치 정보 확인'),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 6단계: 기기 선택 UI (라디오 버튼)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Radio<String>(
                    value: 'Computer',
                    groupValue: _deviceType,
                    onChanged: (value) {
                      setState(() {
                        _deviceType = value!;
                      });
                    },
                  ),
                  const Text('컴퓨터 위치'),
                  const SizedBox(width: 20),
                  Radio<String>(
                    value: 'Mobile',
                    groupValue: _deviceType,
                    onChanged: (value) {
                      setState(() {
                        _deviceType = value!;
                      });
                    },
                  ),
                  const Text('휴대폰 위치'),
                ],
              ),
              const SizedBox(height: 30),

              // 7단계: 핵심 확인 버튼
              ElevatedButton(
                onPressed: _isLoading ? null : _requestLocation,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text(
                      '현재 위치 확인할까요?',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
              ),
              const SizedBox(height: 40),

              // 8단계: 결과 표시 영역
              if (_address.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    border: Border.all(color: Colors.blueAccent),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _address,
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _zipCode,
                        style: const TextStyle(fontSize: 16),
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
