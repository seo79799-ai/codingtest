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
      title: '위치 정보 확인',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const LocationScreen(),
    );
  }
}

class LocationScreen extends StatefulWidget {
  const LocationScreen({super.key});

  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  // 단계 1: 상태 변수 정의 (기기 선택, 결과 주소, 우편번호)
  String _selectedDevice = 'Computer';
  String _address = '';
  String _zipcode = '';
  bool _isLoading = false;

  // 단계 2: 위치 권한 요청 및 좌표 수집 (위치정보법 준수)
  Future<void> _handleLocationCheck() async {
    setState(() {
      _isLoading = true;
      _address = '';
      _zipcode = '';
    });

    try {
      bool serviceEnabled;
      LocationPermission permission;

      // 위치 서비스 활성화 여부 확인
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw '위치 서비스가 비활성화되어 있습니다.';
      }

      // 위치 권한 확인 및 요청
      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw '위치 권한이 거부되었습니다.';
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw '위치 권한이 영구적으로 거부되었습니다. 설정에서 변경해주세요.';
      }

      // 현재 좌표 수집
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      // 단계 3: 구글 Reverse Geocoding API 호출
      await _convertToAddress(position.latitude, position.longitude);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _convertToAddress(double lat, double lng) async {
    // 주의: 'YOUR_GOOGLE_MAPS_API_KEY'를 실제 API 키로 교체해야 합니다.
    const apiKey = 'YOUR_GOOGLE_MAPS_API_KEY';
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&key=$apiKey&language=ko',
    );

    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['status'] == 'OK') {
        final results = data['results'] as List;
        if (results.isNotEmpty) {
          final formattedAddress = results[0]['formatted_address'];
          String postalCode = '없음';

          final components = results[0]['address_components'] as List;
          for (var comp in components) {
            final types = comp['types'] as List;
            if (types.contains('postal_code')) {
              postalCode = comp['long_name'];
              break;
            }
          }

          setState(() {
            _address = '[$_selectedDevice] $formattedAddress';
            _zipcode = postalCode;
          });
        }
      } else {
        throw '주소 변환 실패: ${data['status']}';
      }
    } else {
      throw 'API 통신 오류가 발생했습니다.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 단계 4: 기기 선택 UI (라디오 버튼)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Radio<String>(
                    value: 'Computer',
                    groupValue: _selectedDevice,
                    onChanged: (value) => setState(() => _selectedDevice = value!),
                  ),
                  const Text('컴퓨터 위치'),
                  const SizedBox(width: 20),
                  Radio<String>(
                    value: 'Mobile',
                    groupValue: _selectedDevice,
                    onChanged: (value) => setState(() => _selectedDevice = value!),
                  ),
                  const Text('휴대폰 위치'),
                ],
              ),
              const SizedBox(height: 40),

              // 단계 5: 메인 확인 버튼
              ElevatedButton(
                onPressed: _isLoading ? null : _handleLocationCheck,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(50),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        '현재 위치 확인할까요?',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
              ),
              const SizedBox(height: 40),

              // 단계 6: 결과 표시 영역
              if (_address.isNotEmpty)
                Container(
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
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '우편번호: $_zipcode',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
