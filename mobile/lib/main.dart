import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

void main() {
  runApp(const LocationServiceApp());
}

class LocationServiceApp extends StatelessWidget {
  const LocationServiceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '간편 위치 확인 서비스',
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

enum DeviceType { computer, mobile }

class _LocationHomePageState extends State<LocationHomePage> {
  DeviceType _selectedDevice = DeviceType.mobile;
  String _roadAddress = "-";
  String _zipCode = "-";
  bool _isLoading = false;

  /// 1단계: 위치 정보 접근 권한 확인 및 요청
  Future<bool> _handleLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('위치 서비스가 비활성화되어 있습니다. 설정에서 활성화해주세요.')));
      }
      return false;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('위치 권한이 거부되었습니다.')));
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

  /// 2단계: 현재 위치(위도, 경도) 수집
  Future<void> _getCurrentLocation() async {
    final hasPermission = await _handleLocationPermission();
    if (!hasPermission) return;

    setState(() {
      _isLoading = true;
    });

    try {
      Position position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ));

      // 3단계: Google Maps Reverse Geocoding API를 통해 주소 변환
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

  /// 3단계: 좌표를 주소로 변환 (Google Maps Reverse Geocoding API 호출)
  Future<void> _reverseGeocode(double lat, double lng) async {
    // 실제 운영 환경에서는 유효한 API 키가 필요합니다.
    const String apiKey = 'YOUR_API_KEY';
    final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&key=$apiKey&language=ko');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && data['results'].isNotEmpty) {
          final result = data['results'][0];
          String roadAddr = result['formatted_address'];
          String zip = "-";

          // address_components에서 postal_code 찾기
          for (var component in result['address_components']) {
            var types = component['types'] as List;
            if (types.contains('postal_code')) {
              zip = component['short_name'];
              break;
            }
          }

          setState(() {
            final prefix = _selectedDevice == DeviceType.computer ? '[PC] ' : '[Mobile] ';
            _roadAddress = prefix + roadAddr;
            _zipCode = zip;
          });
        } else {
          setState(() {
            final prefix = _selectedDevice == DeviceType.computer ? '[PC] ' : '[Mobile] ';
            _roadAddress = prefix + "주소를 찾을 수 없습니다. (API 키 확인 필요)";
            _zipCode = "-";
          });
        }
      }
    } catch (e) {
      debugPrint("API Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('주소 변환 중 오류가 발생했습니다.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('간편 위치 확인 서비스'),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              /// 기기 선택 (라디오 버튼)
              /// 검토 의견을 반영하여 표준 Radio 위젯을 사용하는 방식으로 수정했습니다.
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Radio<DeviceType>(
                    value: DeviceType.computer,
                    groupValue: _selectedDevice,
                    onChanged: (DeviceType? value) {
                      setState(() {
                        _selectedDevice = value!;
                      });
                    },
                  ),
                  const Text('컴퓨터 위치'),
                  const SizedBox(width: 20),
                  Radio<DeviceType>(
                    value: DeviceType.mobile,
                    groupValue: _selectedDevice,
                    onChanged: (DeviceType? value) {
                      setState(() {
                        _selectedDevice = value!;
                      });
                    },
                  ),
                  const Text('휴대폰 위치'),
                ],
              ),
              const SizedBox(height: 40),

              /// 확인 버튼
              ElevatedButton(
                onPressed: _isLoading ? null : _getCurrentLocation,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 40, vertical: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        '현재 위치 확인할까요?',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
              ),
              const SizedBox(height: 40),

              /// 결과 표시
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(15),
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
