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
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const LocationHomePage(),
    );
  }
}

class LocationHomePage extends StatefulWidget {
  const LocationHomePage({super.key});

  @override
  State<LocationHomePage> createState() => _LocationHomePageState();
}

class _LocationHomePageState extends State<LocationHomePage> {
  // 기기 선택 상태: 'Computer' 또는 'Mobile'
  String _selectedDevice = 'Computer';

  // 결과 표시용 변수
  String _roadAddress = '[결과 기다리는 중...]';
  String _zipCode = '[결과 기다리는 중...]';

  // 1단계: 위치 정보 접근 권한 요청 및 좌표 수집
  Future<void> _checkLocation() async {
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

    // 위치정보법 준수를 위해 명시적으로 권한 요청 팝업을 띄움
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

    // 현재 위치 가져오기
    try {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      // 2단계: Google Maps Reverse Geocoding API 호출
      await _getReverseGeocode(position.latitude, position.longitude);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('위치 정보를 가져오는 중 오류 발생: $e')),
        );
      }
    }
  }

  // 2단계: Google Maps Reverse Geocoding API를 사용하여 좌표를 주소로 변환
  Future<void> _getReverseGeocode(double lat, double lng) async {
    const String apiKey = 'YOUR_API_KEY'; // 실제 API 키로 교체 필요
    final String url =
        'https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&key=$apiKey&language=ko';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && data['results'].isNotEmpty) {
          final result = data['results'][0];
          String formattedAddress = result['formatted_address'];
          String postalCode = '';

          // 주소 구성 요소에서 우편번호 추출
          for (var component in result['address_components']) {
            final List types = component['types'];
            if (types.contains('postal_code')) {
              postalCode = component['long_name'];
              break;
            }
          }

          // 기기 선택에 따른 접두사 추가
          final prefix = _selectedDevice == 'Computer' ? '[컴퓨터] ' : '[휴대폰] ';

          // 3단계: 결과 업데이트
          setState(() {
            _roadAddress = '$prefix$formattedAddress';
            _zipCode = postalCode.isNotEmpty ? postalCode : '정보 없음';
          });
        } else {
          setState(() {
            _roadAddress = '주소를 찾을 수 없습니다.';
            _zipCode = '정보 없음';
          });
        }
      } else {
        throw Exception('API 호출 실패');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('주소 변환 중 오류 발생: $e')),
        );
      }
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
              // 기기 선택: 라디오 버튼
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Radio<String>(
                    value: 'Computer',
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
                    value: 'Mobile',
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
              const SizedBox(height: 30),

              // 확인 버튼
              ElevatedButton(
                onPressed: _checkLocation,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                  textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                child: const Text('현재 위치 확인할까요?'),
              ),
              const SizedBox(height: 40),

              // 결과 표시
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    Text(
                      '도로명 주소: $_roadAddress',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '우편번호: $_zipCode',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
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
