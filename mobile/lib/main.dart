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
      title: '단순 위치 확인 서비스',
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
  String _deviceType = "컴퓨터"; // 기본값
  String _address = "-";
  String _zipcode = "-";
  bool _isLoading = false;

  // 단계 1: 위치 정보 수집 동의 팝업 및 권한 확인
  Future<void> _checkLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // 단계 1-1: 위치 서비스 활성화 여부 확인
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(
        const SnackBar(content: Text('위치 서비스가 비활성화되어 있습니다. 설정에서 켜주세요.')),
      );
      return;
    }

    // 단계 1-2: 위치 정보 수집 전 사용자 동의 (위치정보법 준수)
    // geolocator에서 기본으로 시스템 팝업을 띄우지만,
    // 법률 준수를 위해 앱 수준에서 한 번 더 명시적 안내 팝업을 띄우는 것이 좋습니다.
    bool? consent = await (mounted ? showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('위치 정보 수집 동의'),
        content: const Text('정확한 주소 확인을 위해 현재 위치 정보를 수집하는 것에 동의하십니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('거부')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('동의')),
        ],
      ),
    ) : Future.value(false));

    if (!mounted || consent != true) return;

    // 단계 1-3: 시스템 권한 요청
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (!mounted) return;
        final messenger = ScaffoldMessenger.of(context);
        messenger.showSnackBar(
          const SnackBar(content: Text('위치 권한이 거부되었습니다.')),
        );
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(
        const SnackBar(content: Text('위치 권한이 영구적으로 거부되었습니다. 설정에서 변경해주세요.')),
      );
      return;
    }

    // 단계 2: geolocator 패키지를 통한 좌표(위도, 경도) 수집
    setState(() {
      _isLoading = true;
      _address = "가져오는 중...";
      _zipcode = "가져오는 중...";
    });

    try {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high)
      );

      // 단계 3: Google Maps Reverse Geocoding API 호출
      await _reverseGeocode(position.latitude, position.longitude);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('위치 획득 실패: $e')),
      );
      setState(() {
        _isLoading = false;
        _address = "오류 발생";
        _zipcode = "오류 발생";
      });
    }
  }

  // Google Maps Geocoding API 연동 함수
  Future<void> _reverseGeocode(double lat, double lng) async {
    // 실제 운영 시 YOUR_API_KEY를 입력해야 합니다.
    const String apiKey = "YOUR_API_KEY";
    final String url =
      "https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&language=ko&key=$apiKey";

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final results = data['results'] as List;
          if (results.isNotEmpty) {
            final result = results[0];

            // 단계 4: 결과 데이터 추출 및 UI 업데이트
            String formattedAddress = "[$_deviceType 위치] ${result['formatted_address']}";
            String postalCode = "-";

            final addressComponents = result['address_components'] as List;
            for (var component in addressComponents) {
              final types = component['types'] as List;
              if (types.contains('postal_code')) {
                postalCode = component['long_name'];
                break;
              }
            }

            setState(() {
              _address = formattedAddress;
              _zipcode = postalCode;
              _isLoading = false;
            });
          }
        } else {
          throw Exception(data['status']);
        }
      } else {
        throw Exception("API 호출 실패");
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _address = "주소 변환 실패";
        _zipcode = "-";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('단순 위치 확인 서비스'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 단계 1: 기기 선택 UI (라디오 버튼)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Radio<String>(
                  value: "컴퓨터",
                  groupValue: _deviceType,
                  onChanged: (value) {
                    setState(() => _deviceType = value!);
                  },
                ),
                const Text("컴퓨터 위치"),
                const SizedBox(width: 20),
                Radio<String>(
                  value: "휴대폰",
                  groupValue: _deviceType,
                  onChanged: (value) {
                    setState(() => _deviceType = value!);
                  },
                ),
                const Text("휴대폰 위치"),
              ],
            ),
            const SizedBox(height: 40),

            // 단계 2: 확인 버튼 (중심에 크게 배치)
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
                ),
                child: Text(
                  _isLoading ? '확인 중...' : '현재 위치 확인할까요?',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 40),

            // 단계 3: 결과 표시 영역
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
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(color: Colors.black, fontSize: 16),
                      children: [
                        const TextSpan(text: "도로명 주소: ", style: TextStyle(fontWeight: FontWeight.bold)),
                        TextSpan(text: _address),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(color: Colors.black, fontSize: 16),
                      children: [
                        const TextSpan(text: "우편번호: ", style: TextStyle(fontWeight: FontWeight.bold)),
                        TextSpan(text: _zipcode),
                      ],
                    ),
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
