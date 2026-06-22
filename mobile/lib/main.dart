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
  String _selectedDevice = '컴퓨터 위치';
  String _address = '';
  String _postalCode = '';
  bool _isLoading = false;

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
              // 1단계: 기기 선택 (RadioGroup 패턴)
              // ignore_for_file: deprecated_member_use
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

              // 2단계: 확인 버튼
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : () => _handleLocationCheck(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    textStyle: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3,
                          ),
                        )
                      : const Text('현재 위치 확인할까요?'),
                ),
              ),
              const SizedBox(height: 40),

              // 3단계: 결과 표시
              if (_address.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '도로명 주소: [$_selectedDevice] $_address',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '우편번호: $_postalCode',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  // 4단계: 위치 정보 접근 권한 동의 및 수집
  Future<void> _handleLocationCheck() async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    bool serviceEnabled;
    LocationPermission permission;

    // 서비스 활성화 확인
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showError(scaffoldMessenger, '위치 서비스가 비활성화되어 있습니다.');
      return;
    }

    // 권한 확인 및 요청 (위치정보법 준수 안내 포함)
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      // 사용자에게 동의 구함
      if (!mounted) return;
      final bool? proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('위치 정보 접근 권한 안내'),
          content: const Text('현재 위치의 주소와 우편번호를 확인하기 위해 위치 정보 수집 및 이용에 동의하십니까?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('거부'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('동의'),
            ),
          ],
        ),
      );

      if (proceed != true) return;

      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showError(scaffoldMessenger, '위치 권한이 거부되었습니다.');
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showError(scaffoldMessenger, '위치 권한이 영구적으로 거부되었습니다. 설정에서 권한을 허용해 주세요.');
      return;
    }

    setState(() {
      _isLoading = true;
      _address = '';
      _postalCode = '';
    });

    try {
      // 좌표 수집
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      // 5단계: Google Maps Reverse Geocoding API 호출
      await _reverseGeocode(scaffoldMessenger, position.latitude, position.longitude);
    } catch (e) {
      _showError(scaffoldMessenger, '위치 정보를 가져오는 데 실패했습니다: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _reverseGeocode(ScaffoldMessengerState scaffoldMessenger, double lat, double lng) async {
    const String apiKey = 'YOUR_GOOGLE_MAPS_API_KEY'; // 실제 사용 시 API 키 입력 필요
    final String url =
        'https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&key=$apiKey&language=ko';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && data['results'].isNotEmpty) {
          final result = data['results'][0];

          setState(() {
            _address = result['formatted_address'];

            // 우편번호 추출
            final components = result['address_components'] as List;
            _postalCode = '정보 없음';
            for (var component in components) {
              final types = component['types'] as List;
              if (types.contains('postal_code')) {
                _postalCode = component['long_name'];
                break;
              }
            }
          });
        } else {
          _showError(scaffoldMessenger, '주소를 찾을 수 없습니다: ${data['status']}');
        }
      } else {
        _showError(scaffoldMessenger, 'API 호출 실패: ${response.statusCode}');
      }
    } catch (e) {
      _showError(scaffoldMessenger, '통신 오류: $e');
    }
  }

  void _showError(ScaffoldMessengerState scaffoldMessenger, String message) {
    scaffoldMessenger.showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
