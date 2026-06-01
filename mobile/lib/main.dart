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
      title: '단순한 위치 정보 확인',
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
  // 상태 변수: 기기 선택, 주소, 우편번호, 로딩 상태
  String _deviceType = 'Computer';
  String _address = '도로명 주소: ';
  String _zipCode = '우편번호: ';
  bool _isLoading = false;

  // Google Maps API 키 (실제 키로 교체 필요)
  final String _apiKey = 'YOUR_GOOGLE_MAPS_API_KEY';

  /// [단계별 설명] 위치 정보를 가져오고 주소로 변환하는 핵심 함수
  Future<void> _checkLocation() async {
    setState(() {
      _isLoading = true;
      _address = '도로명 주소: 가져오는 중...';
      _zipCode = '우편번호: 가져오는 중...';
    });

    try {
      // 1단계: 위치 정보 접근 권한 동의 구하기 (보안 및 법규 준수)
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showError('위치 권한이 거부되었습니다.');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showError('위치 권한이 영구적으로 거부되었습니다. 설정에서 변경해 주세요.');
        return;
      }

      // 2단계: 기기의 현재 위치 좌표(위도, 경도) 수집
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      // 3단계: Google Maps Reverse Geocoding API를 통한 주소 변환
      // language=ko 파라미터를 추가하여 한국어 결과를 보장합니다.
      final response = await http.get(Uri.parse(
          'https://maps.googleapis.com/maps/api/geocode/json?latlng=${position.latitude},${position.longitude}&key=$_apiKey&language=ko'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final results = data['results'] as List;
          if (results.isNotEmpty) {
            // 가장 정확한 첫 번째 결과 선택
            String formattedAddress = results[0]['formatted_address'];
            String postalCode = '정보 없음';

            // 4단계: 결과 데이터에서 우편번호 추출
            final addressComponents = results[0]['address_components'] as List;
            for (var component in addressComponents) {
              final types = component['types'] as List;
              if (types.contains('postal_code')) {
                postalCode = component['long_name'];
                break;
              }
            }

            // 5단계: 화면에 결과 업데이트 (기기 선택 접두어 포함)
            setState(() {
              _address = '도로명 주소: [$_deviceType] $formattedAddress';
              _zipCode = '우편번호: $postalCode';
            });
          }
        } else {
          _showError('주소를 찾을 수 없습니다 (${data['status']})');
        }
      } else {
        _showError('서버 통신 오류가 발생했습니다.');
      }
    } catch (e) {
      _showError('오류 발생: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 오류 발생 시 메시지 표시 및 상태 초기화
  void _showError(String message) {
    setState(() {
      _address = '도로명 주소: 오류';
      _zipCode = '우편번호: -';
      _isLoading = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
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
              // UI 구성 1: 기기 선택 라디오 버튼
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Radio<String>(
                    value: 'Computer',
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
                    value: 'Mobile',
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

              // UI 구성 2: 현재 위치 확인 메인 버튼
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _checkLocation,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: Text(
                    _isLoading ? '확인 중...' : '현재 위치 확인할까요?',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 40),

              // UI 구성 3: 결과 표시 텍스트 영역
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: Colors.grey.shade300)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _address,
                      style: const TextStyle(fontSize: 16, color: Colors.black87, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _zipCode,
                      style: const TextStyle(fontSize: 16, color: Colors.black87, fontWeight: FontWeight.bold),
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
