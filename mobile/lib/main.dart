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
      title: '현재 위치 확인 서비스',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const LocationPage(),
    );
  }
}

class LocationPage extends StatefulWidget {
  const LocationPage({super.key});

  @override
  State<LocationPage> createState() => _LocationPageState();
}

class _LocationPageState extends State<LocationPage> {
  // 기기 선택 상태: 'computer' 또는 'mobile'
  String _selectedDevice = 'computer';

  // 결과 상태
  String _roadAddress = '[결과 기다리는 중]';
  String _postalCode = '[결과 기다리는 중]';
  bool _isLoading = false;

  // 구글 맵 API 키 (실제 키로 교체 필요)
  final String _googleMapsApiKey = 'YOUR_GOOGLE_MAPS_API_KEY';

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
              // 1. 기기 선택 영역 (라디오 버튼)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text('컴퓨터 위치'),
                      value: 'computer',
                      groupValue: _selectedDevice,
                      onChanged: (value) {
                        setState(() {
                          _selectedDevice = value!;
                        });
                      },
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text('휴대폰 위치'),
                      value: 'mobile',
                      groupValue: _selectedDevice,
                      onChanged: (value) {
                        setState(() {
                          _selectedDevice = value!;
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),

              // 2. 확인 버튼
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleCheckLocation,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
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

              // 3. 결과 표시 영역
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
                      style: const TextStyle(fontSize: 16, height: 1.5),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '우편번호: $_postalCode',
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

  // 위치 확인 핸들러
  Future<void> _handleCheckLocation() async {
    // 1단계: 위치 정보 접근 권한 동의 확인 (사용자 정의 팝업은 모바일 시스템 권한 팝업으로 대체되거나 추가 가능)
    bool serviceEnabled;
    LocationPermission permission;

    // 위치 서비스 활성화 여부 확인
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('위치 서비스가 비활성화되어 있습니다. 설정에서 활성화해 주세요.')),
        );
      }
      return;
    }

    // 권한 확인 및 요청
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
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
          const SnackBar(content: Text('위치 권한이 영구적으로 거부되었습니다. 설정에서 변경해 주세요.')),
        );
      }
      return;
    }

    // UI 업데이트를 위한 로딩 상태 활성화
    setState(() {
      _isLoading = true;
      _roadAddress = '위치 정보를 수집 중...';
      _postalCode = '위치 정보를 수집 중...';
    });

    try {
      // 2단계: 현재 위치 좌표 수집
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      // 3단계: (다음 단계에서 구현) Google Maps API 호출
      await _fetchAddressFromCoordinates(position.latitude, position.longitude);

    } catch (e) {
      if (mounted) {
        setState(() {
          _roadAddress = '오류 발생: $e';
          _postalCode = '오류 발생';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // 주소 변환 함수 (Google Maps Reverse Geocoding API 연동)
  Future<void> _fetchAddressFromCoordinates(double lat, double lng) async {
    final url = 'https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&key=$_googleMapsApiKey&language=ko';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK') {
          final results = data['results'] as List;
          if (results.isNotEmpty) {
            // 1. 도로명 주소 추출
            final formattedAddress = results[0]['formatted_address'];

            // 2. 우편번호 추출 (address_components 내 postal_code 타입 검색)
            String postCode = '우편번호 없음';
            final components = results[0]['address_components'] as List;
            for (var component in components) {
              final types = component['types'] as List;
              if (types.contains('postal_code')) {
                postCode = component['long_name'];
                break;
              }
            }

            if (mounted) {
              setState(() {
                String prefix = _selectedDevice == 'computer' ? '[컴퓨터 위치]' : '[휴대폰 위치]';
                _roadAddress = '$prefix $formattedAddress';
                _postalCode = postCode;
              });
            }
          }
        } else {
          throw Exception('API 응답 오류: ${data['status']}');
        }
      } else {
        throw Exception('HTTP 요청 실패: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _roadAddress = '주소 변환 중 오류 발생';
          _postalCode = '확인 불가';
        });
      }
      rethrow;
    }
  }
}
