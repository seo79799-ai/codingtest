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
      title: '단순 위치 확인',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
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
  String _deviceType = '컴퓨터'; // 기본값
  String _address = '-';
  String _zipcode = '-';
  bool _isLoading = false;

  // 단계 1: 위치 정보 수집 전 동의 팝업 (위치정보법 준수)
  Future<bool> _showConsentDialog() async {
    return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('위치 정보 이용 동의'),
            content: const Text('현재 위치 정보를 수집하여 주소를 확인하시겠습니까?\n이 정보는 주소 변환 목적으로만 사용됩니다.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('거절'),
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

  // 단계 2: Geolocation을 이용한 좌표 수집 및 주소 변환
  Future<void> _handleGetLocation() async {
    final hasConsent = await _showConsentDialog();
    if (!hasConsent) return;

    setState(() => _isLoading = true);

    try {
      // 권한 확인
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

      // Google Maps Reverse Geocoding API 호출
      await _convertToAddress(position.latitude, position.longitude);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 단계 3: Google Maps Reverse Geocoding API 호출 (REST)
  Future<void> _convertToAddress(double lat, double lng) async {
    const apiKey = 'YOUR_GOOGLE_MAPS_API_KEY';
    final url = 'https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&language=ko&key=$apiKey';

    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['status'] == 'OK' && data['results'].isNotEmpty) {
        final result = data['results'][0];

        setState(() {
          _address = '[$_deviceType 위치] ${result['formatted_address']}';

          // 우편번호 찾기
          _zipcode = '-';
          final components = result['address_components'] as List;
          for (var comp in components) {
            final types = comp['types'] as List;
            if (types.contains('postal_code')) {
              _zipcode = comp['long_name'];
              break;
            }
          }
        });
      } else {
        throw '주소를 찾을 수 없습니다.';
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
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 기기 선택 UI
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Radio<String>(
                    value: '컴퓨터',
                    groupValue: _deviceType,
                    onChanged: (value) => setState(() => _deviceType = value!),
                  ),
                  const Text('컴퓨터 위치'),
                  const SizedBox(width: 20),
                  Radio<String>(
                    value: '휴대폰',
                    groupValue: _deviceType,
                    onChanged: (value) => setState(() => _deviceType = value!),
                  ),
                  const Text('휴대폰 위치'),
                ],
              ),
              const SizedBox(height: 40),

              // 중심 확인 버튼
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleGetLocation,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('현재 위치 확인할까요?'),
                ),
              ),
              const SizedBox(height: 40),

              // 결과 표시 영역
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '도로명 주소: $_address',
                      style: const TextStyle(fontSize: 16, color: Colors.green),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '우편번호: $_zipcode',
                      style: const TextStyle(fontSize: 16, color: Colors.green),
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
