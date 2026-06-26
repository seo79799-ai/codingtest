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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
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
  String _selectedDevice = '컴퓨터';
  String _roadAddress = '';
  String _zipCode = '';
  bool _isLoading = false;

  // 1단계: 위치 정보 접근 권한 동의 팝업 및 권한 획득 (위치정보법 준수)
  Future<bool> _handleLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('위치 서비스가 비활성화되어 있습니다. 설정에서 활성화해주세요.')),
        );
      }
      return false;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      // 명시적인 동의 팝업 표시
      if (mounted) {
        bool? consent = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('위치 정보 수집 동의'),
            content: const Text('현재 위치를 도로명 주소로 변환하기 위해 위치 정보에 접근합니다. 동의하십니까?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('거부')),
              TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('동의')),
            ],
          ),
        );
        if (consent != true) return false;
      }

      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('위치 권한이 거부되었습니다.')),
          );
        }
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('위치 권한이 영구적으로 거부되었습니다. 설정에서 변경해주세요.')),
        );
      }
      return false;
    }

    return true;
  }

  // 2단계: 위치 확인 및 주소 변환 로직
  Future<void> _getCurrentLocation() async {
    final hasPermission = await _handleLocationPermission();
    if (!hasPermission) return;

    setState(() {
      _isLoading = true;
      _roadAddress = '가져오는 중...';
      _zipCode = '가져오는 중...';
    });

    try {
      // 위도, 경도 수집
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      // 3단계: Google Maps Reverse Geocoding API 호출
      // YOUR_GOOGLE_MAPS_API_KEY를 실제 API 키로 변경해야 합니다.
      const apiKey = 'YOUR_GOOGLE_MAPS_API_KEY';
      final url = 'https://maps.googleapis.com/maps/api/geocode/json'
          '?latlng=${position.latitude},${position.longitude}'
          '&key=$apiKey'
          '&language=ko';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final results = data['results'] as List;
          if (results.isNotEmpty) {
            final formattedAddress = results[0]['formatted_address'];
            String zip = '정보 없음';

            final addressComponents = results[0]['address_components'] as List;
            for (var component in addressComponents) {
              final types = component['types'] as List;
              if (types.contains('postal_code')) {
                zip = component['long_name'];
                break;
              }
            }

            setState(() {
              _roadAddress = '[$_selectedDevice 위치] $formattedAddress';
              _zipCode = zip;
            });
          }
        } else {
          throw Exception('API Status: ${data['status']}');
        }
      } else {
        throw Exception('HTTP Error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint(e.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('주소를 가져오는 중 오류가 발생했습니다.')),
        );
      }
      setState(() {
        _roadAddress = '오류 발생';
        _zipCode = '오류 발생';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('단순 위치 정보 확인'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 기기 선택 라디오 버튼
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
            // 메인 확인 버튼
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _getCurrentLocation,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('현재 위치 확인할까요?'),
              ),
            ),
            const SizedBox(height: 40),
            // 결과 표시 영역
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
                    '도로명 주소: $_roadAddress',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '우편번호: $_zipCode',
                    style: const TextStyle(fontSize: 16),
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
// ignore_for_file: deprecated_member_use
