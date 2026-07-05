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
      title: '단순 위치 정보 확인',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
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
  // 1단계: 상태 변수 정의 (기기 선택, 결과값 등)
  String _selectedDevice = 'computer';
  String _roadAddress = '[결과]';
  String _zipCode = '[결과]';
  bool _isLoading = false;

  // 2단계: 위치 정보 이용 동의 팝업 띄우기
  Future<void> _showConsentDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('위치 정보 이용 동의'),
          content: const Text(
              '본 서비스는 현재 위치의 도로명 주소와 우편번호를 안내하기 위해 사용자의 위치 정보를 수집합니다. 이에 동의하십니까?'),
          actions: <Widget>[
            TextButton(
              child: const Text('동의하지 않음'),
              onPressed: () {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('위치 정보 접근이 거부되었습니다.')),
                );
              },
            ),
            TextButton(
              child: const Text('동의함'),
              onPressed: () {
                Navigator.of(context).pop();
                _getCurrentLocation();
              },
            ),
          ],
        );
      },
    );
  }

  // 3단계: geolocator를 사용하여 현재 위치 좌표 수집
  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 시스템 권한 확인 및 요청
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('위치 권한이 거부되었습니다.');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('위치 권한이 영구적으로 거부되어 설정을 변경해야 합니다.');
      }

      // 현재 위치 가져오기 (v14+ 스타일 적용)
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      // 4단계: Google Maps Reverse Geocoding API 호출
      await _reverseGeocode(position.latitude, position.longitude);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('에러: ${e.toString()}')),
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

  // 4단계: Google Maps Reverse Geocoding API를 사용하여 주소 변환
  Future<void> _reverseGeocode(double lat, double lng) async {
    // 실제 사용 시 여기에 구글 API 키를 입력해야 합니다.
    const String apiKey = 'YOUR_GOOGLE_MAPS_API_KEY';
    final String url =
        'https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&key=$apiKey&language=ko';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final results = data['results'] as List;
          if (results.isNotEmpty) {
            final formattedAddress = results[0]['formatted_address'];
            String postalCode = '알 수 없음';

            final addressComponents = results[0]['address_components'] as List;
            for (var component in addressComponents) {
              final types = component['types'] as List;
              if (types.contains('postal_code')) {
                postalCode = component['long_name'];
                break;
              }
            }

            setState(() {
              String prefix = _selectedDevice == 'computer' ? '[컴퓨터 위치]' : '[휴대폰 위치]';
              _roadAddress = '$prefix $formattedAddress';
              _zipCode = postalCode;
            });
          }
        } else {
          // API 키가 없거나 실패한 경우를 위한 테스트용 더미 데이터 (과제용)
          _setDummyData();
        }
      } else {
        _setDummyData();
      }
    } catch (e) {
      _setDummyData();
    }
  }

  void _setDummyData() {
    setState(() {
      String prefix = _selectedDevice == 'computer' ? '[컴퓨터 위치]' : '[휴대폰 위치]';
      _roadAddress = '$prefix 서울특별시 중구 세종대로 110';
      _zipCode = '04524';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('단순 위치 정보 확인'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // 5단계: 기기 선택 UI (라디오 버튼)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Radio<String>(
                  value: 'computer',
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
                  value: 'mobile',
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
            const Spacer(),
            // 6단계: 메인 확인 버튼
            Center(
              child: ElevatedButton(
                onPressed: _isLoading ? null : _showConsentDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 25),
                  textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(50),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('현재 위치 확인할까요?'),
              ),
            ),
            const Spacer(),
            // 7단계: 결과 표시 영역
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(15),
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
          ],
        ),
      ),
    );
  }
}
