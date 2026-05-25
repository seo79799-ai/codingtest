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
  // 단계 1: 상태 변수 정의 (기기 선택, 주소, 우편번호)
  String _selectedDevice = 'Computer';
  String _address = '';
  String _postcode = '';
  bool _isLoading = false;

  // Google Maps API Key - 실제 키로 교체 필요
  final String _apiKey = 'YOUR_GOOGLE_MAPS_API_KEY';

  /// 사용자의 위치 정보를 가져오고 주소로 변환하는 메인 함수
  Future<void> _handleLocationCheck() async {
    setState(() {
      _isLoading = true;
      _address = '';
      _postcode = '';
    });

    try {
      // 1. 위치 정보법 준수: 위치 서비스 활성화 및 권한 확인
      Position position = await _determinePosition();

      // 2. Google Reverse Geocoding API 호출
      await _fetchAddressFromCoords(position.latitude, position.longitude);
    } catch (e) {
      _showErrorDialog(e.toString());
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Geolocator를 이용해 현재 좌표를 가져오는 함수 (권한 요청 포함)
  Future<Position> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    // 위치 서비스 활성화 여부 확인
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('위치 서비스가 비활성화되어 있습니다.');
    }

    // 위치 권한 확인 및 요청
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

    // 현재 위치 가져오기 (High Accuracy 설정)
    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
  }

  /// 좌표를 Google Maps API를 통해 주소로 변환하는 함수
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

          // 도로명 주소 추출
          String roadAddress = firstResult['formatted_address'];

          // 우편번호 추출
          String postcode = '정보 없음';
          final addressComponents = firstResult['address_components'] as List;
          for (var component in addressComponents) {
            final types = component['types'] as List;
            if (types.contains('postal_code')) {
              postcode = component['long_name'];
              break;
            }
          }

          setState(() {
            // 기기 선택에 따른 접두사 추가
            _address = '[$_selectedDevice] $roadAddress';
            _postcode = postcode;
          });
        }
      } else {
        throw Exception('주소 변환 실패: ${data['status']}');
      }
    } else {
      throw Exception('네트워크 오류가 발생했습니다.');
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('오류'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('위치 정보 확인'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            // 단계 2: 기기 선택 UI
            // Note: RadioGroup pattern via Radio.adaptive and Row
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
            const Spacer(),
            // 단계 3: 큰 확인 버튼
            SizedBox(
              width: double.infinity,
              height: 80,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleLocationCheck,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(40),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        '현재 위치 확인할까요?',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
            const Spacer(),
            // 단계 4: 결과 표시 영역
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
                    '도로명 주소: $_address',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '우편번호: $_postcode',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
