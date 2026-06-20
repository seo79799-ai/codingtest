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
      title: '단순 위치 정보 확인 서비스',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
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
  // 기기 선택 상태: '컴퓨터' 또는 '휴대폰'
  String _deviceType = '컴퓨터';
  String _address = '[대기 중]';
  String _postcode = '[대기 중]';
  bool _isLoading = false;

  // 1단계: 위치 정보 접근 권한 요청 및 위치 수집 (위치정보법 준수)
  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoading = true;
      _address = '위치 찾는 중...';
      _postcode = '확인 중...';
    });

    try {
      // 위치 서비스 활성화 확인
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw '위치 서비스가 비활성화되어 있습니다.';
      }

      // 권한 확인 및 요청
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

      // 현재 위치 좌표 획득
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      // 2단계: Google Maps Reverse Geocoding API 호출
      await _reverseGeocode(position.latitude, position.longitude);
    } catch (e) {
      setState(() {
        _address = '오류: ${e.toString()}';
        _postcode = '-';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 3단계: 좌표를 주소로 변환하는 비즈니스 로직
  Future<void> _reverseGeocode(double lat, double lng) async {
    // 자신의 API 키로 대체 필요
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
            String postalCode = '정보 없음';

            // address_components에서 우편번호 추출
            final components = results[0]['address_components'] as List;
            for (var component in components) {
              final types = component['types'] as List;
              if (types.contains('postal_code')) {
                postalCode = component['long_name'];
                break;
              }
            }

            setState(() {
              _address = '[$_deviceType 위치] $formattedAddress';
              _postcode = postalCode;
            });
          }
        } else {
          throw 'Geocoder 오류: ${data['status']}';
        }
      } else {
        throw 'API 호출 실패';
      }
    } catch (e) {
      throw '주소 변환 실패: $e';
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
              // 4단계: 기기 선택 UI (라디오 버튼)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Radio<String>(
                    value: '컴퓨터',
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
                    value: '휴대폰',
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
              const SizedBox(height: 40),

              // 5단계: 중심 확인 버튼
              SizedBox(
                width: double.infinity,
                height: 80,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _getCurrentLocation,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(40),
                    ),
                  ),
                  child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        '현재 위치 확인할까요?',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                ),
              ),
              const SizedBox(height: 40),

              // 6단계: 결과 표시 영역
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '도로명 주소: $_address',
                      style: const TextStyle(fontSize: 16, height: 1.5),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '우편번호: $_postcode',
                      style: const TextStyle(fontSize: 16, height: 1.5),
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
