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
      title: '위치 정보 확인 서비스',
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
  // 기기 선택 상태: 'computer' 또는 'mobile'
  String _selectedDevice = 'mobile';
  String _address = '';
  String _zipCode = '';
  bool _isLoading = false;

  // 1단계: 위치 정보 제공 동의 및 권한 요청
  Future<bool> _handleLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    // 위치 서비스 활성화 여부 확인
    serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!mounted) return false;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    if (!serviceEnabled) {
      messenger.showSnackBar(
        const SnackBar(content: Text('위치 서비스가 비활성화되어 있습니다. 설정에서 켜주세요.')),
      );
      return false;
    }

    if (!mounted) return false;

    // 위치 정보법 준수를 위한 동의 팝업 (사용자에게 목적 설명)
    bool? consent = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('위치 정보 수집 동의'),
        content: const Text('정확한 주소 확인을 위해 현재 위치 정보를 수집합니다. 동의하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => navigator.pop(false), child: const Text('거부')),
          TextButton(onPressed: () => navigator.pop(true), child: const Text('동의')),
        ],
      ),
    );

    if (consent != true) return false;

    // 시스템 권한 요청
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          messenger.showSnackBar(
            const SnackBar(content: Text('위치 권한이 거부되었습니다.')),
          );
        }
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('위치 권한이 영구적으로 거부되었습니다. 설정에서 변경해주세요.')),
        );
      }
      return false;
    }

    return true;
  }

  // 2단계: 현재 위치 가져오기 및 주소 변환
  Future<void> _getCurrentLocation() async {
    final hasPermission = await _handleLocationPermission();
    if (!hasPermission) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // 좌표 수집
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      // 3단계: Google Maps Reverse Geocoding API 호출
      await _convertToAddress(position.latitude, position.longitude);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류 발생: $e')),
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

  Future<void> _convertToAddress(double lat, double lng) async {
    const apiKey = 'YOUR_GOOGLE_MAPS_API_KEY'; // 실제 API 키로 대체 필요
    final url = 'https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&key=$apiKey&language=ko';

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['status'] == 'OK') {
        final result = data['results'][0];
        final prefix = _selectedDevice == 'computer' ? '[컴퓨터 위치] ' : '[휴대폰 위치] ';

        String zip = '정보 없음';
        for (var component in result['address_components']) {
          if ((component['types'] as List).contains('postal_code')) {
            zip = component['long_name'];
            break;
          }
        }

        setState(() {
          _address = prefix + result['formatted_address'];
          _zipCode = zip;
        });
      } else {
        throw Exception('Geocoding 실패: ${data['status']}');
      }
    } else {
      throw Exception('API 호출 실패');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 기기 선택 UI
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Radio<String>(
                      value: 'computer',
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
                      value: 'mobile',
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
                const SizedBox(height: 50),

                // 메인 확인 버튼
                ElevatedButton(
                  onPressed: _isLoading ? null : _getCurrentLocation,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        '현재 위치 확인할까요?',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                ),
                const SizedBox(height: 50),

                // 결과 표시 영역
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '도로명 주소: $_address',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '우편번호: $_zipCode',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
