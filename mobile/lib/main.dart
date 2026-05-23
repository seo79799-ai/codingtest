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
      title: '단순 위치 정보 서비스',
      theme: ThemeData(
        primarySwatch: Colors.blue,
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
  // 1단계: 기기 선택 상태 관리
  String _selectedDevice = 'Computer';
  String _roadAddress = '';
  String _zipCode = '';
  bool _isLoading = false;

  // Google Maps API 키 (사용자가 자신의 키를 입력해야 함)
  final String _googleMapsApiKey = 'YOUR_GOOGLE_MAPS_API_KEY';

  // 4단계: 위치 정보 접근 권한 동의 및 좌표 수집
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

    // 위치 권한 확인 및 요청 (보안 및 법규 준수)
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

    setState(() {
      _isLoading = true;
    });

    try {
      // 5단계: Geolocator 패키지를 사용하여 좌표 수집
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      await _reverseGeocode(position.latitude, position.longitude);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류 발생: $e')),
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

  // 6단계: Google Maps Reverse Geocoding API를 통한 주소 변환
  Future<void> _reverseGeocode(double lat, double lng) async {
    final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&key=$_googleMapsApiKey&language=ko');

    try {
      final response = await http.get(url);
      final data = json.decode(response.body);

      if (data['status'] == 'OK') {
        String roadAddr = '정보 없음';
        String zip = '정보 없음';

        if (data['results'].isNotEmpty) {
          roadAddr = data['results'][0]['formatted_address'];

          final components = data['results'][0]['address_components'] as List;
          final zipComp = components.firstWhere(
            (comp) => (comp['types'] as List).contains('postal_code'),
            orElse: () => null,
          );
          if (zipComp != null) {
            zip = zipComp['long_name'];
          }
        }

        if (mounted) {
          setState(() {
            // 7단계: 결과 화면 출력 (기기 접두사 포함)
            String prefix = _selectedDevice == 'Computer' ? '[Computer] ' : '[Mobile] ';
            _roadAddress = '$prefix$roadAddr';
            _zipCode = zip;
          });
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('주소 변환 실패: ${data['status']}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('API 호출 중 오류 발생: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('단순 위치 정보 서비스'),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 1단계: 기기 선택 (라디오 버튼)
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
              const SizedBox(height: 40),

              // 2단계: 확인 버튼
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

              // 3단계: 결과 표시 영역
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '도로명 주소: $_roadAddress',
                      style: const TextStyle(fontSize: 18),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '우편번호: $_zipCode',
                      style: const TextStyle(fontSize: 18),
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
