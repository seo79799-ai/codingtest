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
      title: '단순 위치 정보 확인 서비스',
      theme: ThemeData(
        primarySwatch: Colors.green,
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
  // 1단계: 기기 선택 변수 (기본값: 휴대폰)
  String _selectedDevice = 'Mobile';
  String _roadAddress = '';
  String _zipCode = '';
  bool _isLoading = false;

  // 구글 맵스 API 키 (실제 키로 교체 필요)
  final String _googleMapsApiKey = 'YOUR_API_KEY';

  /// 2단계: 위치 권한 확인 및 좌표 수집
  /// 위치정보법에 따라 명시적으로 권한을 요청합니다.
  Future<void> _checkLocation() async {
    setState(() {
      _isLoading = true;
      _roadAddress = '';
      _zipCode = '';
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
        throw '위치 권한이 영구적으로 거부되었습니다. 설정에서 변경해 주세요.';
      }

      // 현재 좌표 가져오기
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      // 3단계: 역지오코딩 (Reverse Geocoding) 수행
      await _reverseGeocode(position.latitude, position.longitude);
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

  /// 4단계: Google Maps Reverse Geocoding REST API를 이용한 주소 변환
  Future<void> _reverseGeocode(double lat, double lng) async {
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&key=$_googleMapsApiKey&language=ko&region=kr',
    );

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['status'] == 'OK' && data['results'].isNotEmpty) {
        final result = data['results'][0];
        String roadAddr = result['formatted_address'];
        String postal = '';

        // address_components에서 우편번호 추출
        for (var component in result['address_components']) {
          List types = component['types'];
          if (types.contains('postal_code')) {
            postal = component['long_name'];
            break;
          }
        }

        setState(() {
          _roadAddress = roadAddr;
          _zipCode = postal.isNotEmpty ? postal : '정보 없음';
        });
      } else {
        throw '주소를 찾을 수 없습니다: ${data['status']}';
      }
    } else {
      throw 'API 요청 실패 (상태 코드: ${response.statusCode})';
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
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 1단계: 기기 선택 UI (라디오 버튼)
              RadioGroup<String>(
                groupValue: _selectedDevice,
                onChanged: (value) {
                  setState(() {
                    _selectedDevice = value!;
                  });
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Radio<String>(
                      value: 'PC',
                    ),
                    const Text('컴퓨터 위치'),
                    const SizedBox(width: 20),
                    Radio<String>(
                      value: 'Mobile',
                    ),
                    const Text('휴대폰 위치'),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              // 5단계: 핵심 확인 버튼 (큼직하고 직관적인 디자인)
              SizedBox(
                width: double.infinity,
                height: 70,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _checkLocation,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(35),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          '현재 위치 확인할까요?',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 40),

              // 6단계: 결과 표시 영역
              if (_roadAddress.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '도로명 주소: $_roadAddress',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '우편번호: $_zipCode',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
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
