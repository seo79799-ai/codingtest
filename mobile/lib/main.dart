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
  // 1단계: 변수 설정 (기기 타입, 주소 결과, 우편번호)
  String _deviceType = '컴퓨터';
  String _roadAddress = '';
  String _zipCode = '';
  bool _isLoading = false;

  // Google Maps API 키 (실제 사용 시 본인의 API 키로 교체 필요)
  final String _apiKey = 'YOUR_GOOGLE_MAPS_API_KEY';

  // 2단계: 위치 권한 요청 및 좌표 수집 함수
  Future<void> _handleLocationCheck() async {
    setState(() {
      _isLoading = true;
      _roadAddress = '';
      _zipCode = '';
    });

    try {
      // 위치 서비스 활성화 여부 확인
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw '위치 서비스가 비활성화되어 있습니다.';
      }

      // 3단계: 위치 정보법 준수를 위한 사용자 권한 확인 및 요청
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

      // 4단계: 현재 좌표(위도, 경도) 가져오기
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      // 5단계: Google Reverse Geocoding API 호출
      await _fetchAddressFromCoords(position.latitude, position.longitude);
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

  // 6단계: API 연동 및 주소 변환 로직
  Future<void> _fetchAddressFromCoords(double lat, double lng) async {
    final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&key=$_apiKey&language=ko');

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['status'] == 'OK') {
        final results = data['results'] as List;
        if (results.isNotEmpty) {
          final firstResult = results[0];

          setState(() {
            // [Computer] 또는 [Mobile] 접두사 추가
            String prefix = _deviceType == '컴퓨터' ? '[Computer]' : '[Mobile]';
            _roadAddress = '$prefix ${firstResult['formatted_address']}';

            // 우편번호 추출
            final addressComponents = firstResult['address_components'] as List;
            final postalCodeObj = addressComponents.firstWhere(
              (comp) => (comp['types'] as List).contains('postal_code'),
              orElse: () => null,
            );

            _zipCode = postalCodeObj != null ? postalCodeObj['long_name'] : '정보 없음';
          });
        }
      } else {
        throw '주소를 찾을 수 없습니다: ${data['status']}';
      }
    } else {
      throw '서버 오류가 발생했습니다.';
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
              // 7단계: 기기 선택 라디오 버튼 UI
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

              // 8단계: 메인 확인 버튼 UI
              ElevatedButton(
                onPressed: _isLoading ? null : _handleLocationCheck,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text(
                        '현재 위치 확인할까요?',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
              ),
              const SizedBox(height: 40),

              // 9단계: 결과 표시 텍스트 영역
              if (_roadAddress.isNotEmpty) ...[
                Text(
                  '도로명 주소: $_roadAddress',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  '우편번호: $_zipCode',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
