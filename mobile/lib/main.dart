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
      title: '단순 위치 확인 서비스',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
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
  // 기기 선택 상태 (컴퓨터 또는 휴대폰)
  String _deviceType = '컴퓨터';

  // 결과 표시를 위한 상태 변수
  String _address = '확인 전';
  String _zipCode = '확인 전';
  bool _isLoading = false;

  // Google Maps API Key - 실제 사용 시 교체 필요
  final String _googleMapsApiKey = 'YOUR_GOOGLE_MAPS_API_KEY';

  /// 위치 정보 확인 절차 시작
  Future<void> _checkLocation() async {
    // 1. [위치정보법 준수] 동의 팝업 표시
    bool? consent = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('위치 정보 수집 동의'),
        content: const Text('사용자의 현재 위치를 수집하여 도로명 주소와 우편번호를 확인하시겠습니까?\n이 정보는 주소 확인 서비스에만 사용됩니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('거절'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('동의'),
          ),
        ],
      ),
    );

    if (consent != true) return;

    setState(() {
      _isLoading = true;
      _address = '가져오는 중...';
      _zipCode = '가져오는 중...';
    });

    try {
      // 2. 권한 확인 및 위치 수집 (geolocator 사용)
      Position position = await _getCurrentLocation();

      // 3. Reverse Geocoding 호출 (Google Maps API)
      await _reverseGeocode(position.latitude, position.longitude);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류 발생: ${e.toString()}')),
        );
      }
      setState(() {
        _address = '확인 실패';
        _zipCode = '확인 실패';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// geolocator를 사용하여 현재 위도/경도 획득
  Future<Position> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw '위치 서비스가 비활성화되어 있습니다.';
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw '위치 권한이 거부되었습니다.';
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw '위치 권한이 영구적으로 거부되어 설정을 변경해야 합니다.';
    }

    // 최신 버전 geolocator 문법: LocationSettings 사용
    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
  }

  /// Google Reverse Geocoding API를 통한 주소 변환
  Future<void> _reverseGeocode(double lat, double lng) async {
    // language=ko 파라미터를 추가하여 한국어 응답을 받음
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&key=$_googleMapsApiKey&language=ko'
    );

    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['status'] == 'OK' && data['results'].isNotEmpty) {
        final result = data['results'][0];
        final formattedAddress = result['formatted_address'];
        String zip = '제공되지 않음';

        // address_components에서 우편번호(postal_code) 추출
        for (var component in result['address_components']) {
          List types = component['types'];
          if (types.contains('postal_code')) {
            zip = component['long_name'];
            break;
          }
        }

        if (mounted) {
          setState(() {
            _address = '[$_deviceType 위치] $formattedAddress';
            _zipCode = zip;
          });
        }
      } else {
        throw '주소를 변환할 수 없습니다. (Status: ${data['status']})';
      }
    } else {
      throw '서버 응답 오류 (HTTP ${response.statusCode})';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('단순 위치 확인'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 1. 기기 선택 라디오 버튼
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Radio<String>(
                    value: '컴퓨터',
                    groupValue: _deviceType,
                    onChanged: (value) {
                      setState(() { _deviceType = value!; });
                    },
                  ),
                  const Text('컴퓨터 위치'),
                  const SizedBox(width: 20),
                  Radio<String>(
                    value: '휴대폰',
                    groupValue: _deviceType,
                    onChanged: (value) {
                      setState(() { _deviceType = value!; });
                    },
                  ),
                  const Text('휴대폰 위치'),
                ],
              ),
              const SizedBox(height: 40),

              // 2. 확인 버튼: 크고 명확하게 배치
              SizedBox(
                width: double.infinity,
                height: 80,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _checkLocation,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(40),
                    ),
                    textStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('현재 위치 확인할까요?'),
                ),
              ),
              const SizedBox(height: 50),

              // 3. 결과 표시 영역
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(15),
                  border: const Border(
                    left: BorderSide(color: Colors.blue, width: 8),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '도로명 주소: $_address',
                      style: const TextStyle(fontSize: 16, height: 1.5),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '우편번호: $_zipCode',
                      style: const TextStyle(fontSize: 16, height: 1.5),
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
// ignore_for_file: deprecated_member_use
