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
      title: '단순 위치 정보 확인',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
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
  // 1단계: 기기 선택 변수 (기본값: 컴퓨터 위치)
  String _deviceType = '컴퓨터';
  String _address = '대기 중...';
  String _postcode = '대기 중...';
  bool _isLoading = false;

  final String _googleApiKey = 'YOUR_GOOGLE_MAPS_API_KEY';

  /**
   * 위치 정보를 확인하고 주소로 변환하는 메인 함수
   */
  Future<void> _checkLocation() async {
    // 2단계: 위치 정보 접근 권한 동의 확인 (위치정보법 준수)
    bool confirmed = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('위치 정보 접근 동의'),
        content: const Text('정확한 도로명 주소 변환을 위해 현재 위치 정보에 접근하시겠습니까?'),
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
    ) ?? false;

    if (!confirmed) return;

    setState(() {
      _isLoading = true;
      _address = '위치 수집 중...';
      _postcode = '';
    });

    try {
      // 3단계: geolocator를 사용하여 현재 위치 수집
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw '위치 권한이 거부되었습니다.';
        }
      }

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      // 4단계: Google Reverse Geocoding API 호출
      await _reverseGeocode(position.latitude, position.longitude);
    } catch (e) {
      setState(() {
        _address = '오류 발생: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /**
   * 구글 API를 사용하여 좌표를 한국 도로명 주소로 변환
   */
  Future<void> _reverseGeocode(double lat, double lng) async {
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&key=$_googleApiKey&language=ko'
    );

    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['status'] == 'OK') {
        final result = data['results'][0];
        String formattedAddress = result['formatted_address'];
        String zipCode = '';

        for (var component in result['address_components']) {
          if (component['types'].contains('postal_code')) {
            zipCode = component['long_name'];
            break;
          }
        }

        setState(() {
          _address = '도로명 주소: [$_deviceType 위치] $formattedAddress';
          _postcode = '우편번호: $zipCode';
        });
      } else {
        throw 'API 응답 오류: ${data['status']}';
      }
    } else {
      throw '네트워크 오류';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('단순 위치 정보 확인'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 5단계: 기기 선택 라디오 버튼 (RadioGroup 패턴)
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

              // 6단계: 중앙 확인 버튼
              SizedBox(
                width: double.infinity,
                height: 80,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                    side: BorderSide.none,
                    borderRadius: BorderRadius.circular(40),
                    ),
                  ),
                  onPressed: _isLoading ? null : _checkLocation,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          '현재 위치 확인할까요?',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
              const SizedBox(height: 40),

              // 7단계: 결과 표시 영역
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _address,
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _postcode,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),
              // 8단계: 추가 정보 (AdSense 및 정보 제공용)
              const Divider(),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '💡 알고 계셨나요?',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '우리나라의 도로명 주소는 도로에 이름을 붙이고 건물에 번호를 붙여 체계적으로 관리됩니다. 위급 상황 시 119나 112에 현재 위치를 정확히 알리는 데 매우 중요합니다.',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
