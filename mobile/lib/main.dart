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
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const LocationHomeScreen(),
    );
  }
}

class LocationHomeScreen extends StatefulWidget {
  const LocationHomeScreen({super.key});

  @override
  State<LocationHomeScreen> createState() => _LocationHomeScreenState();
}

class _LocationHomeScreenState extends State<LocationHomeScreen> {
  // 1단계: 기기 선택 상태 변수 (컴퓨터/휴대폰)
  String _selectedDevice = '컴퓨터';
  String _addressResult = '[결과 대기 중]';
  String _postcodeResult = '[결과 대기 중]';
  bool _isLoading = false;

  // 구글 맵스 API 키 (실제 사용 시 유효한 키로 교체 필요)
  final String _googleMapsApiKey = 'YOUR_GOOGLE_MAPS_API_KEY';

  /**
   * 2단계: 위치 정보 수집 및 주소 변환 메인 함수
   */
  Future<void> _handleLocationCheck() async {
    // 3단계: 위치 정보 수집 동의 확인 (위치정보법 준수)
    bool? consent = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('위치 정보 수집 동의'),
        content: const Text('현재 위치 정보를 수집하여 주소로 변환하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
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
      _addressResult = '위치를 찾는 중...';
      _postcodeResult = '확인 중...';
    });

    try {
      // 4단계: geolocator를 사용하여 현재 좌표 수집
      Position position = await _determinePosition();

      // 5단계: Google Reverse Geocoding API 호출
      await _convertCoordsToAddress(position.latitude, position.longitude);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('에러 발생: $e')),
      );
      _resetUI();
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /**
   * 6단계: 기기 위치 권한 확인 및 좌표 획득 로직
   */
  Future<Position> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('위치 서비스가 비활성화되어 있습니다.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('위치 권한이 거부되었습니다.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error('위치 권한이 영구적으로 거부되었습니다. 설정에서 변경해 주세요.');
    }

    // Deprecated 'desiredAccuracy' 대신 'locationSettings' 사용
    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
  }

  /**
   * 7단계: Google API를 통한 주소 변환 및 UI 업데이트
   */
  Future<void> _convertCoordsToAddress(double lat, double lng) async {
    final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&key=$_googleMapsApiKey&language=ko');

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['status'] == 'OK' && data['results'].isNotEmpty) {
        final result = data['results'][0];
        final formattedAddress = result['formatted_address'];
        String postalCode = '정보 없음';

        for (var component in result['address_components']) {
          List types = component['types'];
          if (types.contains('postal_code')) {
            postalCode = component['long_name'];
            break;
          }
        }

        setState(() {
          _addressResult = '[$_selectedDevice 위치] $formattedAddress';
          _postcodeResult = '[$_selectedDevice 위치] $postalCode';
        });
      } else {
        throw '주소 변환 결과가 없습니다 (${data['status']})';
      }
    } else {
      throw 'API 호출 실패 (상태 코드: ${response.statusCode})';
    }
  }

  void _resetUI() {
    setState(() {
      _addressResult = '[결과 대기 중]';
      _postcodeResult = '[결과 대기 중]';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('단순 위치 확인')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 8단계: 기기 선택 라디오 버튼 UI
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Radio<String>(
                    value: '컴퓨터',
                    groupValue: _selectedDevice,
                    onChanged: (value) => setState(() => _selectedDevice = value!),
                  ),
                  const Text('컴퓨터 위치'),
                  const SizedBox(width: 20),
                  Radio<String>(
                    value: '휴대폰',
                    groupValue: _selectedDevice,
                    onChanged: (value) => setState(() => _selectedDevice = value!),
                  ),
                  const Text('휴대폰 위치'),
                ],
              ),
              const SizedBox(height: 40),

              // 9단계: 핵심 확인 버튼 (크고 강조된 디자인)
              SizedBox(
                width: double.infinity,
                height: 80,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleLocationCheck,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          '현재 위치 확인할까요?',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
              const SizedBox(height: 50),

              // 10단계: 결과 표시 영역
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '도로명 주소: $_addressResult',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 15),
                    Text(
                      '우편번호: $_postcodeResult',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
