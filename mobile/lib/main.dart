// ignore_for_file: deprecated_member_use

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const LocationServiceApp());
}

class LocationServiceApp extends StatelessWidget {
  const LocationServiceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '단순 위치 확인 서비스',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
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
  // 단계 1: 기기 선택 상태 정의
  String _selectedDevice = '컴퓨터 위치';
  String _address = '-';
  String _zipcode = '-';
  bool _isLoading = false;

  // 실제 서비스 시에는 YOUR_API_KEY를 유효한 구글 API 키로 대체해야 합니다.
  final String _googleApiKey = 'YOUR_API_KEY';

  /// 단계 2: 위치 정보 수집 전 사용자 동의 확인 팝업
  Future<bool> _showConsentDialog() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('위치 정보 수집 동의'),
            content: const Text('서비스 제공을 위해 현재 위치 정보를 수집합니다. 동의하시겠습니까?'),
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
        ) ??
        false;
  }

  /// 단계 3: 위치 정보 획득 및 주소 변환 메인 함수
  Future<void> _checkLocation() async {
    // 동의 확인
    final hasConsent = await _showConsentDialog();
    if (!hasConsent) return;

    setState(() {
      _isLoading = true;
      _address = '가져오는 중...';
      _zipcode = '가져오는 중...';
    });

    try {
      // 시스템 권한 확인 및 요청
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw '위치 권한이 거부되었습니다.';
        }
      }

      // 현재 좌표 가져오기
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      // 구글 Reverse Geocoding API 호출
      await _reverseGeocode(position.latitude, position.longitude);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류: $e')),
        );
      }
      setState(() {
        _address = '오류 발생';
        _zipcode = '-';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Google Reverse Geocoding API를 사용하여 좌표를 주소로 변환
  Future<void> _reverseGeocode(double lat, double lng) async {
    final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&key=$_googleApiKey&language=ko');

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['status'] == 'OK') {
        final results = data['results'] as List;
        if (results.isNotEmpty) {
          final formattedAddress = results[0]['formatted_address'];
          String postalCode = '-';

          // 우편번호 추출
          final components = results[0]['address_components'] as List;
          for (var component in components) {
            final types = component['types'] as List;
            if (types.contains('postal_code')) {
              postalCode = component['long_name'];
              break;
            }
          }

          setState(() {
            _address = '[$_selectedDevice] $formattedAddress';
            _zipcode = postalCode;
          });
          return;
        }
      }
      throw '주소를 찾을 수 없습니다. (Status: ${data['status']})';
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
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 기기 선택 (라디오 버튼)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Radio<String>(
                  value: '컴퓨터 위치',
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
                  value: '휴대폰 위치',
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
              height: 60,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _checkLocation,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('현재 위치 확인할까요?'),
              ),
            ),
            const SizedBox(height: 40),

            // 결과 표시
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '도로명 주소: $_address',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '우편번호: $_zipcode',
                    style: const TextStyle(fontSize: 16),
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
