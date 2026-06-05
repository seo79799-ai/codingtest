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
  // 기기 선택 상태 (컴퓨터 또는 휴대폰)
  String _selectedDevice = 'Computer';
  String _roadAddress = '도로명 주소: ';
  String _zipCode = '우편번호: ';
  bool _isLoading = false;

  // Google Maps API Key 플레이스홀더
  final String _googleMapsApiKey = 'YOUR_GOOGLE_MAPS_API_KEY';

  /// 위치 권한을 확인하고 요청하는 함수 (보안 및 법규 준수)
  Future<bool> _handleLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    // 위치 서비스 활성화 여부 확인
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('위치 서비스가 비활성화되어 있습니다. 설정에서 활성화해주세요.')));
      }
      return false;
    }

    // 현재 권한 상태 확인
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      // 권한이 거부된 경우 팝업을 통해 요청
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('위치 정보 접근 권한이 거부되었습니다.')));
        }
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('위치 권한이 영구적으로 거부되었습니다. 설정에서 변경해주세요.')));
      }
      return false;
    }

    return true;
  }

  /// 현재 위치를 가져와서 주소로 변환하는 메인 로직
  Future<void> _getCurrentLocation() async {
    final hasPermission = await _handleLocationPermission();
    if (!hasPermission) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // 1. 위도, 경도 좌표 수집
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      // 2. Reverse Geocoding API 호출
      await _reverseGeocode(position.latitude, position.longitude);
    } catch (e) {
      debugPrint(e.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('위치 정보를 가져오는 중 오류가 발생했습니다.')));
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 좌표를 주소 문자열로 변환 (Google Maps API 활용)
  Future<void> _reverseGeocode(double lat, double lng) async {
    final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&key=$_googleMapsApiKey&language=ko');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final result = data['results'][0];
          final String formattedAddress = result['formatted_address'];
          String zip = '';

          // address_components에서 우편번호 추출
          for (var component in result['address_components']) {
            final List types = component['types'];
            if (types.contains('postal_code')) {
              zip = component['long_name'];
              break;
            }
          }

          setState(() {
            // 결과 표시 (기기 접두사 포함)
            _roadAddress = '도로명 주소: [$_selectedDevice] $formattedAddress';
            _zipCode = '우편번호: $zip';
          });
        } else {
          throw Exception('API 응답 오류: ${data['status']}');
        }
      } else {
        throw Exception('네트워크 오류');
      }
    } catch (e) {
      debugPrint(e.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('주소 변환에 실패했습니다. (API 키 확인 필요)')));
      }
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
            children: <Widget>[
              // 1단계: 기기 선택 라디오 버튼 (RadioGroup 패턴)
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

              // 2단계: 중심 확인 버튼
              ElevatedButton(
                onPressed: _isLoading ? null : _getCurrentLocation,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                  textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text('현재 위치 확인할까요?'),
              ),
              const SizedBox(height: 40),

              // 3단계: 결과 표시 텍스트
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  border: Border.all(color: Colors.grey[400]!),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _roadAddress,
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _zipCode,
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
