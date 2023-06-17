import 'dart:async';
import 'package:geolocator/geolocator.dart';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const GpsMapApp(),
    );
  }
}

// 화면을 만들기전에 지도 띄우는 법
// google_maps_flutter쓰면됨. 플러터 공식.

class GpsMapApp extends StatefulWidget {
  const GpsMapApp({super.key});

  @override
  State<GpsMapApp> createState() => GpsMapAppState();
}

class GpsMapAppState extends State<GpsMapApp> {
  final Completer<GoogleMapController> _controller =
      Completer<GoogleMapController>();

  // 구글플렉스 위치
  // static const CameraPosition _kGooglePlex = CameraPosition(
  //   target: LatLng(37.42796133580664, -122.085749655962),
  //   zoom: 14.4746,
  // );

  int _polylineIdCounter = 0;
  Set<Polyline> _polylines = {};
  LatLng? _prevPosition;

  CameraPosition? _initialCameraPosition;

  @override
  void initState() {
    super.initState();
    init();
  }

  Future<void> init() async {
    // 위치를 이걸로 얻음, 초기화를 이걸로 할 수 있음
    final position = await _determinePosition();

    // 이걸로 화면 그리기.
    _initialCameraPosition = CameraPosition(
      target: LatLng(position.latitude, position.longitude),
      zoom: 17,
    );

    setState(() {});

    // 기본값 , 원하면 세밀하게 조정 가능
    const locationSettings = LocationSettings();
    Geolocator.getPositionStream(locationSettings: locationSettings)
        // 그릴 수 있지만 리슨이라는걸 사용해서 데이터 처리할 수 있음
        .listen((Position position) {
      _polylineIdCounter++;
      final polylineId = PolylineId('$_polylineIdCounter');
      // 폴리라인을 쌓아줘야함.
      final polyline = Polyline(
        polylineId: polylineId,
        color: Colors.red,
        width: 3,
        // 아이디도 알아야하고 새로 바뀐 위도 경도 값도 알아야함
        points: [
          _prevPosition ?? _initialCameraPosition!.target,
          LatLng(position.latitude, position.longitude),
        ],
      );
      // 폴리라인이 변경될 때 set스테이트를 해줘야 반영이 됨.
      setState(() {
        _polylines.add(polyline);
        _prevPosition = LatLng(position.latitude, position.longitude);
      });
      _moveCamera(position);
    });

    //print(position.toString());
  }

  // 구글 맵은 컨트롤러를 통해서 화면 갱신을 하는 애임.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _initialCameraPosition == null
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : GoogleMap(
              // 사용하고자하는 타입 지정. nomal로하면 위성이미지가 아님.
              mapType: MapType.normal,
              // 삼항연산자로 널체크해도 인식 못함. 느낌표 붙여서 처리.
              initialCameraPosition: _initialCameraPosition!,
              onMapCreated: (GoogleMapController controller) {
                _controller.complete(controller);
              },
              polylines: _polylines,
            ),
      // floatingActionButton: FloatingActionButton.extended(
      //   onPressed: _goToTheLake,
      //   label: const Text('To the lake!'),
      //   icon: const Icon(Icons.directions_boat),
      // ),
    );
  }

  Future<void> _moveCamera(Position position) async {
    final GoogleMapController controller = await _controller.future;
    // 카메라 따라오게 작업 / 스트림 형태로 포지션 들어옴.
    final position = await Geolocator.getCurrentPosition();
    final cameraPosition = CameraPosition(
      target: LatLng(position.latitude, position.longitude),
      zoom: 17,
    );
    // set포지션으로 To the lake! 누르면 감.
    await controller
        .animateCamera(CameraUpdate.newCameraPosition(cameraPosition));
  }

  // 위치 정보 퍼미션을 꺼놓으면 false가 나옴.
  Future<Position> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services are not enabled don't continue
      // accessing the position and request users of the
      // App to enable the location services.
      return Future.error('Location services are disabled.');
    }

    // 위치권한이 있는지 확인
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Permissions are denied, next time you could try
        // requesting permissions again (this is also where
        // Android's shouldShowRequestPermissionRationale
        // returned true. According to Android guidelines
        // your App should show an explanatory UI now.
        return Future.error('Location permissions are denied');
      }
    }

    // 거부가 두번이상 되면 더이상 안물음.
    if (permission == LocationPermission.deniedForever) {
      // Permissions are denied forever, handle appropriately.
      return Future.error(
          'Location permissions are permanently denied, we cannot request permissions.');
    }

    // 거부가 안됐으면 여기와서 포지션 얻음
    // When we reach here, permissions are granted and we can
    // continue accessing the position of the device.
    // 현재 위치는 결국 이 코드다.
    return await Geolocator.getCurrentPosition();
  }
}
