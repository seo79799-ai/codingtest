import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '단순 위치 정보 확인 서비스',
      theme: ThemeData(
        primarySwatch: Colors.green,
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
  final String _googleMapsApiKey = 'YOUR_GOOGLE_MAPS_API_KEY';

  String _address = '-';
  String _zipcode = '-';
  bool _isLoading = false;
  String _selectedDevice = '컴퓨터 위치';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('위치 정보 확인'),
        centerTitle: true,
      ),
      drawer: _buildDrawer(),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Radio<String>(
                    value: '컴퓨터 위치',
                    groupValue: _selectedDevice,
                    onChanged: (value) => setState(() => _selectedDevice = value!),
                  ),
                  const Text('컴퓨터 위치'),
                  const SizedBox(width: 20),
                  Radio<String>(
                    value: '휴대폰 위치',
                    groupValue: _selectedDevice,
                    onChanged: (value) => setState(() => _selectedDevice = value!),
                  ),
                  const Text('휴대폰 위치'),
                ],
              ),
              const SizedBox(height: 40),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleLocationRequest,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 25),
                  ),
                  child: Text(
                    _isLoading ? '확인 중...' : '현재 위치 확인할까요?',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 40),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('우편번호', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          Text(_zipcode, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    const VerticalDivider(color: Colors.grey),
                    Expanded(
                      flex: 5,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('도로명 주소', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          Text(_address, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              if (_address != '-')
                TextButton.icon(
                  onPressed: () => Share.share('나의 현재 위치: $_address (우편번호: $_zipcode)'),
                  icon: const Icon(Icons.share),
                  label: const Text('위치 공유하기'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: Colors.green),
            child: Text('상세 정보 및 메뉴', style: TextStyle(color: Colors.white, fontSize: 24)),
          ),
          ListTile(
            title: const Text('📖 도로명 주소의 역사와 문화'),
            onTap: () => _showInfoDialog('도로명 주소 정보', '도로명은 지역의 지명, 역사성, 특성 등을 반영하여 지어집니다.\n\n- 대로: 40m/8차로 이상\n- 로: 12~40m/2~7차로\n- 길: 소규모 도로'),
          ),
          ListTile(
            title: const Text('🚨 안전 및 응급 상황 대처'),
            onTap: () => _showInfoDialog('안전 가이드', '산악/해안 등 건물이 없는 곳에서는 "국가지점번호"를 활용하세요.\n\n📞 긴급전화: 119\n🏥 응급의료정보: E-Gen 앱 활용'),
          ),
          ListTile(
            title: const Text('🍴 주변 맛집 찾기'),
            onTap: () async {
              if (_address == '-') {
                _showInfoDialog('알림', '먼저 위치를 확인해 주세요.');
                return;
              }
              final url = Uri.parse('https://map.naver.com/v5/search/${Uri.encodeComponent('$_address 맛집')}');
              if (await canLaunchUrl(url)) await launchUrl(url);
            },
          ),
        ],
      ),
    );
  }

  void _showInfoDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('닫기'))],
      ),
    );
  }

  Future<void> _handleLocationRequest() async {
    bool? consent = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('위치 정보 이용 동의'),
        content: const Text('정확한 주소 확인을 위해 현재 위치 정보(GPS)를 수집하는 데 동의하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('동의')),
        ],
      ),
    );

    if (consent != true) return;

    setState(() => _isLoading = true);
    try {
      Position position = await _determinePosition();
      await _reverseGeocode(position.latitude, position.longitude);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('오류: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<Position> _determinePosition() async {
    bool enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) return Future.error('위치 서비스 비활성화');
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return Future.error('권한 거부');
    }
    return await Geolocator.getCurrentPosition();
  }

  Future<void> _reverseGeocode(double lat, double lng) async {
    final url = Uri.parse('https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&key=$_googleMapsApiKey&language=ko');
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['status'] == 'OK' && data['results'].isNotEmpty) {
        final result = data['results'][0];
        String postCode = '정보 없음';
        for (var component in result['address_components']) {
          if (List.from(component['types']).contains('postal_code')) {
            postCode = component['long_name'];
            break;
          }
        }
        setState(() {
          _address = result['formatted_address'];
          _zipcode = postCode;
        });
      }
    }
  }
}
