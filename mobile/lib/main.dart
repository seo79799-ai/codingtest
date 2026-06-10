import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

// ignore_for_file: deprecated_member_use

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
      home: const LocationCheckScreen(),
    );
  }
}

class LocationCheckScreen extends StatefulWidget {
  const LocationCheckScreen({super.key});

  @override
  State<LocationCheckScreen> createState() => _LocationCheckScreenState();
}

class _LocationCheckScreenState extends State<LocationCheckScreen> {
  // 기기 선택 상태: 'Computer' 또는 'Mobile'
  String _selectedDevice = 'Computer';
  String _roadAddress = '';
  String _zipCode = '';
  bool _isLoading = false;

  // Google Maps API 키 (사용자 환경에 맞게 교체 필요)
  final String _apiKey = 'YOUR_GOOGLE_MAPS_API_KEY';

  // 1단계: 위치 정보 접근 권한 요청 및 좌표 수집 (위치정보법 준수)
  Future<void> _checkLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // 사용자에게 권한 동의를 구하는 팝업 형식의 확인 (간단하게 다이얼로그 사용)
    bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('위치 정보 수집 동의'),
        content: const Text('도로명 주소 조회를 위해 현재 위치 정보를 수집하는 것에 동의하십니까?'),
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

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
      _roadAddress = '';
      _zipCode = '';
    });

    try {
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('위치 서비스가 비활성화되어 있습니다.');
      }

      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('위치 권한이 거부되었습니다.');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('위치 권한이 영구적으로 거부되었습니다.');
      }

      // 좌표 가져오기
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      // 2단계: Google Maps Reverse Geocoding API 호출
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
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&key=$_apiKey&language=ko',
    );

    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['status'] == 'OK') {
        final result = data['results'][0];
        final formattedAddress = result['formatted_address'];

        String zip = '정보 없음';
        for (var component in result['address_components']) {
          final List types = component['types'];
          if (types.contains('postal_code')) {
            zip = component['long_name'];
            break;
          }
        }

        setState(() {
          String prefix = '[$_selectedDevice] ';
          _roadAddress = '$prefix$formattedAddress';
          _zipCode = '$prefix$zip';
        });
      } else {
        throw Exception('주소 변환 실패: ${data['status']}');
      }
    } else {
      throw Exception('API 호출 실패');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('위치 정보 확인')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 3단계: 기기 선택 UI (라디오 버튼)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Radio<String>(
                    value: 'Computer',
                    groupValue: _selectedDevice,
                    onChanged: (value) {
                      setState(() => _selectedDevice = value!);
                    },
                  ),
                  const Text('컴퓨터 위치'),
                  const SizedBox(width: 20),
                  Radio<String>(
                    value: 'Mobile',
                    groupValue: _selectedDevice,
                    onChanged: (value) {
                      setState(() => _selectedDevice = value!);
                    },
                  ),
                  const Text('휴대폰 위치'),
                ],
              ),
              const SizedBox(height: 40),

              // 4단계: 중심 확인 버튼
              ElevatedButton(
                onPressed: _isLoading ? null : _checkLocation,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                  textStyle: const TextStyle(fontSize: 20),
                ),
                child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text('현재 위치 확인할까요?'),
              ),
              const SizedBox(height: 40),

              // 5단계: 결과 표시
              if (_roadAddress.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '도로명 주소: $_roadAddress',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '우편번호: $_zipCode',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
