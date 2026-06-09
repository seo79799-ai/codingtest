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
      title: '위치 정보 확인 서비스',
      theme: ThemeData(
        primarySwatch: Colors.green,
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
  // Google Maps API Key (실제 사용 시 본인의 API 키로 교체해야 합니다)
  final String apiKey = 'YOUR_GOOGLE_MAPS_API_KEY';

  String selectedDevice = '컴퓨터';
  String roadAddress = '[결과]';
  String postCode = '[결과]';
  bool isLoading = false;

  // 1단계: 위치 정보 접근 권한 동의 구하기 및 좌표 수집
  Future<void> _handleLocationCheck() async {
    bool serviceEnabled;
    LocationPermission permission;

    // 위치 서비스 활성화 여부 확인
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('위치 서비스가 비활성화되어 있습니다.')),
      );
      return;
    }

    // 위치 권한 확인 및 요청 (위치정보법 준수)
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('위치 정보 접근 권한이 거부되었습니다.')),
        );
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('위치 권한이 영구적으로 거부되었습니다. 설정에서 변경해주세요.')),
      );
      return;
    }

    // 2단계: 좌표 수집
    setState(() {
      isLoading = true;
      roadAddress = '위치를 찾는 중...';
      postCode = '위치를 찾는 중...';
    });

    try {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      await _reverseGeocode(position.latitude, position.longitude);
    } catch (e) {
      setState(() {
        roadAddress = '[오류 발생]';
        postCode = '[오류 발생]';
        isLoading = false;
      });
    }
  }

  // 3단계: Google Maps Reverse Geocoding API를 통한 주소 변환
  Future<void> _reverseGeocode(double lat, double lng) async {
    final String url =
        'https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&key=$apiKey&language=ko';

    try {
      final response = await http.get(Uri.parse(url));
      final data = json.decode(response.body);

      if (data['status'] == 'OK') {
        final result = data['results'][0];
        final String address = result['formatted_address'];
        String zip = '[정보 없음]';

        // 결과에서 우편번호 추출
        for (var component in result['address_components']) {
          List types = component['types'];
          if (types.contains('postal_code')) {
            zip = component['long_name'];
            break;
          }
        }

        setState(() {
          // 4단계: 결과 표시 ([기기 선택] 접두사 추가)
          roadAddress = '[$selectedDevice] $address';
          postCode = zip;
          isLoading = false;
        });
      } else {
        throw Exception(data['error_message'] ?? '주소를 찾을 수 없습니다.');
      }
    } catch (e) {
      setState(() {
        roadAddress = '[오류] ${e.toString()}';
        postCode = '[오류]';
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('위치 정보 확인 서비스'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 1단계 UI: 기기 선택 (라디오 버튼)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Radio<String>(
                    value: '컴퓨터',
                    groupValue: selectedDevice,
                    onChanged: (value) {
                      setState(() {
                        selectedDevice = value!;
                      });
                    },
                  ),
                  const Text('컴퓨터 위치'),
                  const SizedBox(width: 20),
                  Radio<String>(
                    value: '휴대폰',
                    groupValue: selectedDevice,
                    onChanged: (value) {
                      setState(() {
                        selectedDevice = value!;
                      });
                    },
                  ),
                  const Text('휴대폰 위치'),
                ],
              ),
              const SizedBox(height: 40),

              // 2단계 UI: 확인 버튼
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _handleLocationCheck,
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: const Text(
                    '현재 위치 확인할까요?',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 40),

              // 3단계 UI: 결과 표시
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '도로명 주소: $roadAddress',
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '우편번호: $postCode',
                      style: const TextStyle(fontSize: 16),
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
