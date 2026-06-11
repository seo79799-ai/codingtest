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
      title: '위치 정보 확인 서비스',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String _deviceType = '컴퓨터'; // 기본값
  String _address = '도로명 주소: ';
  String _zipcode = '우편번호: ';
  bool _isLoading = false;

  // Google Maps API Key (실제 사용 시 유효한 키로 교체 필요)
  final String _apiKey = 'YOUR_GOOGLE_MAPS_API_KEY';

  // 1단계: 위치 정보 수집 및 주소 변환 로직
  Future<void> _checkLocation() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 2단계: 위치 서비스 활성화 여부 확인
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw '위치 서비스가 비활성화되어 있습니다.';
      }

      // 3단계: 위치 권한 확인 및 요청 (위치정보법 준수)
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

      // 4단계: 현재 좌표 가져오기
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      // 5단계: 구글 Reverse Geocoding API 호출
      final url = Uri.parse(
          'https://maps.googleapis.com/maps/api/geocode/json?latlng=${position.latitude},${position.longitude}&key=$_apiKey&language=ko');

      final response = await http.get(url);
      final data = json.decode(response.body);

      if (data['status'] == 'OK') {
        final result = data['results'][0];
        final formattedAddress = result['formatted_address'];

        // 우편번호 찾기
        String postalCode = '정보 없음';
        for (var component in result['address_components']) {
          List types = component['types'];
          if (types.contains('postal_code')) {
            postalCode = component['long_name'];
            break;
          }
        }

        // 6단계: 결과 UI 업데이트
        setState(() {
          _address = '도로명 주소: [$_deviceType] $formattedAddress';
          _zipcode = '우편번호: [$_deviceType] $postalCode';
        });
      } else {
        throw '주소를 변환할 수 없습니다: ${data['status']}';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('위치 정보 확인 서비스'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              // 7단계: 기기 선택 UI (라디오 버튼)
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

              // 8단계: 메인 확인 버튼
              ElevatedButton(
                onPressed: _isLoading ? null : _checkLocation,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                  textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text('현재 위치 확인할까요?'),
              ),
              const SizedBox(height: 40),

              // 9단계: 결과 표시 텍스트
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _address,
                      style: const TextStyle(fontSize: 16),
                      key: const Key('address_text'),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _zipcode,
                      style: const TextStyle(fontSize: 16),
                      key: const Key('zipcode_text'),
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
