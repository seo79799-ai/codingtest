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
      title: '단순 위치 정보 확인',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: const LocationScreen(),
    );
  }
}

class LocationScreen extends StatefulWidget {
  const LocationScreen({super.key});

  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  // 1단계: 기기 선택 상태 관리
  String _selectedDevice = '컴퓨터 위치';
  String _address = '[결과 대기 중]';
  String _zipCode = '[결과 대기 중]';
  bool _isLoading = false;

  // Google Maps API Key (실제 키로 교체 필요)
  final String _googleMapsApiKey = 'YOUR_GOOGLE_MAPS_API_KEY';

  // 4단계: 위치 정보 접근 권한 동의 및 수집
  Future<void> _handleLocationCheck() async {
    // 위치 서비스 활성화 여부 확인
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('위치 서비스가 비활성화되어 있습니다.')),
        );
      }
      return;
    }

    // 권한 확인 및 요청
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      // 팝업을 통한 명시적 동의 요청 (위치정보법 준수)
      if (mounted) {
        bool? consent = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('위치 정보 수집 동의'),
            content: const Text('현재 위치를 확인하여 주소를 제공하기 위해 위치 정보 접근 권한이 필요합니다. 동의하시겠습니까?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('거절')),
              TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('동의')),
            ],
          ),
        );

        if (consent != true) return;
      }

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
          const SnackBar(content: Text('위치 권한이 영구적으로 거부되었습니다. 설정에서 변경해주세요.')),
        );
      }
      return;
    }

    // 5단계: 현재 좌표 수집
    setState(() => _isLoading = true);
    try {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      await _reverseGeocode(position.latitude, position.longitude);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('위치 정보를 가져오는 중 오류 발생: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // 6단계: Google Reverse Geocoding API 연동 (language=ko 파라미터 추가)
  Future<void> _reverseGeocode(double lat, double lng) async {
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&key=$_googleMapsApiKey&language=ko'
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final result = data['results'][0];
          String formattedAddress = result['formatted_address'];
          String zip = '정보 없음';

          for (var component in result['address_components']) {
            final types = List<String>.from(component['types']);
            if (types.contains('postal_code')) {
              zip = component['long_name'];
              break;
            }
          }

          setState(() {
            _address = '[$_selectedDevice] $formattedAddress';
            _zipCode = zip;
          });
        } else {
          throw Exception('API 상태 오류: ${data['status']}');
        }
      } else {
        throw Exception('HTTP 오류: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('위치 정보 확인'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 1단계: 기기 선택 (라디오 버튼)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Radio<String>(
                  value: '컴퓨터 위치',
                  groupValue: _selectedDevice,
                  onChanged: (value) {
                    setState(() => _selectedDevice = value!);
                  },
                ),
                const Text('컴퓨터 위치'),
                const SizedBox(width: 20),
                Radio<String>(
                  value: '휴대폰 위치',
                  groupValue: _selectedDevice,
                  onChanged: (value) {
                    setState(() => _selectedDevice = value!);
                  },
                ),
                const Text('휴대폰 위치'),
              ],
            ),
            const SizedBox(height: 40),

            // 2단계: 확인 버튼 (중심에 배치)
            SizedBox(
              width: double.infinity,
              height: 80,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleLocationCheck,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
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
            const SizedBox(height: 40),

            // 3단계: 결과 표시 영역
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey[300]!),
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
                    '우편번호: $_zipCode',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
