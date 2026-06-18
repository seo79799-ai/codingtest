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
      title: '단순 위치 정보 확인',
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
  // 기기 선택 상태 (컴퓨터 또는 휴대폰)
  String _selectedDevice = '컴퓨터';
  String _address = '[대기 중]';
  String _zipcode = '[대기 중]';
  bool _isLoading = false;

  // 1단계: 위치 정보 접근 권한 확인 및 요청
  Future<void> _checkPermissionAndGetLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // 위치 서비스 활성화 여부 확인
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('위치 서비스가 비활성화되어 있습니다.')),
        );
      }
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      // 사용자에게 명시적으로 동의를 구하는 팝업
      if (mounted) {
        bool? consent = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('위치 정보 접근 권한 동의'),
            content: const Text('정확한 주소 확인을 위해 위치 정보 접근 권한이 필요합니다. 동의하시겠습니까?'),
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
      }

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

    // 2단계: 현재 위치 좌표 수집
    setState(() => _isLoading = true);
    try {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      await _reverseGeocode(position.latitude, position.longitude);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('위치 정보를 가져오는 중 오류 발생: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 3단계: Google Maps Reverse Geocoding API를 이용한 주소 변환
  Future<void> _reverseGeocode(double lat, double lng) async {
    const String apiKey = 'YOUR_GOOGLE_MAPS_API_KEY'; // 실제 API 키로 교체 필요
    final String url =
        'https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&key=$apiKey&language=ko';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && data['results'].isNotEmpty) {
          final result = data['results'][0];

          // 도로명 주소
          String formattedAddress = result['formatted_address'];

          // 우편번호 추출
          String postalCode = '정보 없음';
          for (var component in result['address_components']) {
            final types = List<String>.from(component['types']);
            if (types.contains('postal_code')) {
              postalCode = component['long_name'];
              break;
            }
          }

          if (mounted) {
            setState(() {
              _address = '[$_selectedDevice 위치] $formattedAddress';
              _zipcode = postalCode;
            });
          }
        } else {
          throw Exception('주소를 찾을 수 없습니다.');
        }
      } else {
        throw Exception('API 호출 실패');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('주소 변환 실패: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('단순 위치 정보 확인')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 4단계: 기기 선택 라디오 버튼
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Radio<String>(
                    value: '컴퓨터',
                    groupValue: _selectedDevice,
                    onChanged: (value) {
                      setState(() => _selectedDevice = value!);
                    },
                  ),
                  const Text('컴퓨터 위치'),
                  const SizedBox(width: 20),
                  Radio<String>(
                    value: '휴대폰',
                    groupValue: _selectedDevice,
                    onChanged: (value) {
                      setState(() => _selectedDevice = value!);
                    },
                  ),
                  const Text('휴대폰 위치'),
                ],
              ),
              const SizedBox(height: 40),

              // 5단계: 메인 확인 버튼
              ElevatedButton(
                onPressed: _isLoading ? null : _checkPermissionAndGetLocation,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                  textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text('현재 위치 확인할까요?'),
              ),
              const SizedBox(height: 40),

              // 6단계: 결과 표시 영역
              Text(
                '도로명 주소: $_address',
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                '우편번호: $_zipcode',
                style: const TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
