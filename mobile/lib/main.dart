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
  // 1단계: Google Maps API 키 설정 (사용자가 직접 입력해야 함)
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
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 기기 선택 (토글/라디오 버튼 형태)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Radio<String>(
                    value: '컴퓨터 위치',
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
                    value: '휴대폰 위치',
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
              const SizedBox(height: 40),

              // 확인 버튼
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleLocationRequest,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 25),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    _isLoading ? '확인 중...' : '현재 위치 확인할까요?',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 40),

              // 결과 표시
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '도로명 주소: $_address',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '우편번호: $_zipcode',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
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

  // 2단계: 위치 확인 버튼 핸들러 (권한 및 로직 호출)
  Future<void> _handleLocationRequest() async {
    // 위치 정보 수집 전 사용자 동의 확인 (팝업)
    bool? consent = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('위치 정보 이용 동의'),
        content: const Text('정확한 주소 확인을 위해 현재 위치 정보(GPS)를 수집하는 데 동의하시겠습니까?'),
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
    });

    try {
      // 3단계: geolocator를 사용하여 좌표 수집
      Position position = await _determinePosition();

      // 4단계: Google Maps Reverse Geocoding API 호출
      await _reverseGeocode(position.latitude, position.longitude);
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

  // 3단계 상세: 위치 권한 확인 및 현재 좌표 가져오기
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

    return await Geolocator.getCurrentPosition();
  }

  // 4단계 상세: Reverse Geocoding API 연동
  Future<void> _reverseGeocode(double lat, double lng) async {
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&key=$_googleMapsApiKey&language=ko'
    );

    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['status'] == 'OK' && data['results'].isNotEmpty) {
        final result = data['results'][0];
        final formattedAddress = result['formatted_address'];

        String postCode = '정보 없음';
        final addressComponents = result['address_components'] as List;
        for (var component in addressComponents) {
          final types = component['types'] as List;
          if (types.contains('postal_code')) {
            postCode = component['long_name'];
            break;
          }
        }

        setState(() {
          _address = formattedAddress;
          _zipcode = postCode;
        });
      } else if (data['status'] == 'REQUEST_DENIED') {
        throw 'API 키 오류. 코드를 확인해 주세요.';
      } else {
        throw '주소를 찾을 수 없습니다.';
      }
    } else {
      throw '네트워크 오류가 발생했습니다.';
    }
  }
}
