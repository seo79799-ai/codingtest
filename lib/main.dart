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
      title: '단순 위치 확인',
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
  // 1. 상태 변수 설정
  String _selectedDevice = 'computer';
  String _address = '결과 대기 중...';
  String _zipcode = '결과 대기 중...';
  bool _isLoading = false;

  // Google Maps API Key
  final String _googleMapsApiKey = 'YOUR_GOOGLE_MAPS_API_KEY';

  /**
   * [단계별 설명]
   * 1. 위치 권한 확인 및 요청: 기기의 GPS 접근 권한이 있는지 확인하고 없으면 요청합니다.
   * 2. 현재 좌표 수집: Geolocator를 이용해 위도, 경도를 가져옵니다.
   * 3. Reverse Geocoding 호출: Google API를 통해 좌표를 주소로 변환합니다.
   * 4. 결과 업데이트: 화면에 주소와 우편번호를 표시합니다.
   */
  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoading = true;
      _address = '위치 찾는 중...';
      _zipcode = '위치 찾는 중...';
    });

    try {
      // 1. 권한 체크
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

      // 2. 좌표 수집
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // 3. 주소 변환 (Reverse Geocoding)
      await _reverseGeocode(position.latitude, position.longitude);

    } catch (e) {
      setState(() {
        _address = '오류: $e';
        _zipcode = '-';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _reverseGeocode(double lat, double lng) async {
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&key=$_googleMapsApiKey&language=ko',
    );

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['status'] == 'OK') {
        final results = data['results'] as List;
        final formattedAddress = results[0]['formatted_address'];

        String postalCode = '정보 없음';
        final addressComponents = results[0]['address_components'] as List;
        for (var component in addressComponents) {
          final types = component['types'] as List;
          if (types.contains('postal_code')) {
            postalCode = component['long_name'];
            break;
          }
        }

        setState(() {
          _address = formattedAddress;
          _zipcode = postalCode;
        });
      } else {
        setState(() {
          _address = '주소를 찾을 수 없습니다. (${data['status']})';
          _zipcode = '-';
        });
      }
    } else {
      throw 'API 호출 실패';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 1. 기기 선택 (라디오 버튼 형태)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Radio<String>(
                    value: 'computer',
                    groupValue: _selectedDevice,
                    onChanged: (value) {
                      setState(() => _selectedDevice = value!);
                    },
                  ),
                  const Text('컴퓨터 위치'),
                  const SizedBox(width: 20),
                  Radio<String>(
                    value: 'mobile',
                    groupValue: _selectedDevice,
                    onChanged: (value) {
                      setState(() => _selectedDevice = value!);
                    },
                  ),
                  const Text('휴대폰 위치'),
                ],
              ),
              const SizedBox(height: 40),

              // 2. 확인 버튼
              SizedBox(
                width: double.infinity,
                height: 80,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _getCurrentLocation,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(40),
                    ),
                    elevation: 5,
                  ),
                  child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        '현재 위치 확인할까요?',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                ),
              ),
              const SizedBox(height: 40),

              // 3. 결과 표시
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        style: const TextStyle(fontSize: 18, color: Colors.black87),
                        children: [
                          const TextSpan(
                            text: '도로명 주소: ',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54),
                          ),
                          TextSpan(text: _address),
                        ],
                      ),
                    ),
                    const SizedBox(height: 15),
                    RichText(
                      text: TextSpan(
                        style: const TextStyle(fontSize: 18, color: Colors.black87),
                        children: [
                          const TextSpan(
                            text: '우편번호: ',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54),
                          ),
                          TextSpan(text: _zipcode),
                        ],
                      ),
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
