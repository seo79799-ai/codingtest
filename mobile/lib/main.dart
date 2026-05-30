import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '현재 위치 정보 확인',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const LocationHome(),
    );
  }
}

class LocationHome extends StatefulWidget {
  const LocationHome({super.key});

  @override
  State<LocationHome> createState() => _LocationHomeState();
}

class _LocationHomeState extends State<LocationHome> {
  // 기기 선택 상태: 'Computer' 또는 'Mobile'
  String _selectedDevice = 'Computer';
  String _address = '도로명 주소: ';
  String _zipcode = '우편번호: ';
  bool _isLoading = false;

  final String _googleMapsApiKey = 'YOUR_GOOGLE_MAPS_API_KEY';

  /**
   * 1단계: 위치 권한 요청 및 좌표 수집
   * 위치정보법 준수를 위해 명시적인 동의 팝업을 먼저 띄웁니다.
   */
  Future<void> _handleLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('위치 서비스가 비활성화되어 있습니다.')),
        );
      }
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      // 명시적 동의 확인 팝업
      bool? consent = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('위치 정보 수집 동의'),
          content: const Text('정확한 주소 확인을 위해 위치 정보 접근 권한이 필요합니다. 동의하시겠습니까?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('동의')),
          ],
        ),
      );

      if (consent != true) return;

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
          const SnackBar(content: Text('위치 권한이 영구적으로 거부되었습니다. 설정에서 변경해 주세요.')),
        );
      }
      return;
    }

    _getCurrentLocation();
  }

  /**
   * 2단계: 위도, 경도 좌표 가져오기
   */
  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoading = true;
      _address = '도로명 주소: 위치를 찾는 중...';
      _zipcode = '우편번호: 확인 중...';
    });

    try {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      _reverseGeocode(position.latitude, position.longitude);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _address = '도로명 주소: 오류 발생';
      });
    }
  }

  /**
   * 3단계: Google Reverse Geocoding API 호출
   */
  Future<void> _reverseGeocode(double lat, double lng) async {
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&key=$_googleMapsApiKey&language=ko',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final results = data['results'] as List;
          if (results.isNotEmpty) {
            String formattedAddress = results[0]['formatted_address'];
            String postalCode = '';

            final components = results[0]['address_components'] as List;
            for (var comp in components) {
              final types = comp['types'] as List;
              if (types.contains('postal_code')) {
                postalCode = comp['long_name'];
                break;
              }
            }

            setState(() {
              String prefix = _selectedDevice == 'Computer' ? '[Computer]' : '[Mobile]';
              _address = '도로명 주소: $prefix $formattedAddress';
              _zipcode = '우편번호: ${postalCode.isNotEmpty ? postalCode : "정보 없음"}';
            });
          }
        } else {
          setState(() => _address = '도로명 주소: 변환 실패 (${data['status']})');
        }
      }
    } catch (e) {
      setState(() => _address = '도로명 주소: 네트워크 오류');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('위치 정보 서비스'),
        centerTitle: true,
      ),
      // Drawer (AdSense 준수 및 추가 정보 제공)
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: const BoxDecoration(color: Colors.blue),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text('추가 정보 및 안내', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                  SizedBox(height: 10),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('도로명 주소란?'),
              subtitle: const Text('도로명과 건물번호로 표기하는 주소 체계입니다.'),
            ),
            const Divider(),
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('긴급 신고 안내', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
            ),
            ListTile(
              leading: const Icon(Icons.fire_truck),
              title: const Text('화재·구조·구급 (119)'),
              onTap: () => launchUrl(Uri.parse('tel:119')),
            ),
            ListTile(
              leading: const Icon(Icons.local_police),
              title: const Text('범죄신고 (112)'),
              onTap: () => launchUrl(Uri.parse('tel:112')),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.restaurant),
              title: const Text('주변 맛집 검색'),
              onTap: () => launchUrl(Uri.parse('https://www.google.com/maps/search/맛집/'), mode: LaunchMode.externalApplication),
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('내 위치 공유하기'),
              onTap: () {
                if (_address.contains('위치를 찾는 중') || _address == '도로명 주소: ') {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('공유할 위치 정보가 없습니다.')));
                } else {
                  Share.share('제 현재 위치는 $_address 입니다.');
                }
              },
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 4단계: 기기 선택 (RadioGroup 패턴)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Radio<String>(
                  value: 'Computer',
                  groupValue: _selectedDevice,
                  onChanged: (value) => setState(() => _selectedDevice = value!),
                ),
                const Text('컴퓨터 위치'),
                const SizedBox(width: 20),
                Radio<String>(
                  value: 'Mobile',
                  groupValue: _selectedDevice,
                  onChanged: (value) => setState(() => _selectedDevice = value!),
                ),
                const Text('휴대폰 위치'),
              ],
            ),
            const SizedBox(height: 40),

            // 5단계: 중심 확인 버튼
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleLocationPermission,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('현재 위치 확인할까요?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 40),

            // 6단계: 결과 표시 영역
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_address, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 10),
                  Text(_zipcode, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
