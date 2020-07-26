import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_smart_home_app/model/appliance.dart';
import 'package:flutter_smart_home_app/pages/user_profile_page.dart';
import 'package:flutter_smart_home_app/scopedModel/connectedModel.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/animation.dart';            
import 'dart:math';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:flutter_socket_io/flutter_socket_io.dart';
import 'package:flutter_socket_io/socket_io_manager.dart';
import 'dart:async';
import 'dart:convert';
import 'package:beacon_broadcast/beacon_broadcast.dart';
import 'package:flutter_beacon/flutter_beacon.dart';
import 'package:sensors/sensors.dart';


class ItemPoint{
  int response;
  int x;
  int y;
  int hasCovid = 0;
}
class TrainDateBeacon{
  double xGyro = 0.0; 
  double yGyro = 0.0; 
  double zGyro = 0.0;

  double xAc = 0.0; 
  double yAc = 0.0; 
  double zAc = 0.0; 

  double rssi;
  double txPower;
  double distance;
  
}

class HomePageBody extends StatefulWidget {
  HomePageBody(this.model);

  final ApplianceModel model;
  _HomePageBodyState createState() => _HomePageBodyState();
}

class _HomePageBodyState extends State<HomePageBody> with TickerProviderStateMixin {
  Animation  _pointAnimation;  
  Animation  _beaconAnimation;  
  double percent = 0.0;
  bool hasContact= false;
  var _listResultBeacon = [];
  GyroscopeEvent gyroEvent;
  AccelerometerEvent acEvent;

  AnimationController _pointAnimationController;  
  AnimationController _beaconAnimationController;  
  final Strategy strategy = Strategy.P2P_STAR;
  final String userName = Random().nextInt(10000).toString();
  final regions = <Region>[];
  SocketIO socketIO = SocketIOManager().createSocketIO("http://192.168.1.15:8765", "/");  

  List<ItemPoint> _points = new List<ItemPoint>();
  @override
    void initState(){
      super.initState();
      socketIO.init(); 
          socketIO.subscribe("message", _onRecMessage); 
          socketIO.subscribe("restore", _onRestart); 
          socketIO.subscribe("calculate", _onCalculate); 

      socketIO.connect(); 
      gyroscopeEvents.listen((GyroscopeEvent event) {
        gyroEvent = (event);
      });
      accelerometerEvents.listen((AccelerometerEvent event) {
        acEvent = (event);
      });

      discovery();

        //      double distance = pow( ((-69 - (r.rssi) )/(10 * N)), 10.0);

      _pointAnimationController = AnimationController(vsync: this, duration: Duration(milliseconds: 3200));
      _beaconAnimationController = AnimationController(vsync: this, duration: Duration(milliseconds: 3200));
      _beaconAnimation =
          Tween(begin: 1.0, end: 1.3).animate(_beaconAnimationController);
      _beaconAnimationController.forward();
      _beaconAnimationController.addStatusListener((AnimationStatus status) {
        if (status == AnimationStatus.completed) {
          _beaconAnimationController.repeat();
        }
      });
      _pointAnimation =
          Tween(begin: 1.0, end: 1.3).animate(_pointAnimationController);
      _pointAnimationController.forward();
      _pointAnimationController.addStatusListener((AnimationStatus status) {
        if (status == AnimationStatus.completed) {
          _pointAnimationController.repeat();
        }
      });
    }
    var distance = -1.0;

    void discovery() async {

     /* BeaconBroadcast()
        .setUUID('39ED98FF-2900-441A-802F-9C398FC199D2')
          .setMajorId(1)
          .setMinorId(100)
          .setTransmissionPower(-90) //optional
          .setIdentifier('com.example.waldo_app') //iOS-only, optional
          .setLayout('m:2-3=0215,i:4-19,i:20-21,i:22-23,p:24-24') 
          .setManufacturerId(0x004C) 
          .start();*/
      await flutterBeacon.initializeScanning;
      await flutterBeacon.initializeAndCheckScanning;

      regions.add(Region(identifier:'com.example'));
      flutterBeacon.monitoring(regions).listen((MonitoringResult result) {
        // result contains a region, event type and event state
        var tj = result.toJson;
        _listResultBeacon.add(tj);

      });
       flutterBeacon.ranging(regions).listen((RangingResult  result) {
        
        for(var i = 0; i <result.beacons.length ; i++){
          //calculate distance
          var item = result.beacons[i];
          var ratio = item.rssi*1.0/item.txPower;
          if (ratio < 1.0) {
            distance = pow(ratio,10.0);
          }else{
              distance =  (0.89976)*pow(ratio,7.7095) + 0.111;    
          }
          distance = distance * 0.732;

          TrainDateBeacon n = new TrainDateBeacon();
          n.xGyro = gyroEvent.x;
          n.yGyro = gyroEvent.y;
          n.zGyro = gyroEvent.z;
          n.xAc = acEvent.x;
          n.yAc = acEvent.y;
          n.zAc = acEvent.z;
          n.rssi = item.rssi*1.0;
          n.distance = distance;
          n.txPower = item.txPower*1.0;
          print(n.distance);
          socketIO.sendMessage("plain", '{"xGyro":${n.xGyro}, "yGyro":${n.yGyro}, "zGyro":${n.zGyro}, "xAc":${n.xAc}, "yAc":${n.yAc}, "zAc":${n.zAc}, "rssi":${n.rssi},  "distance":${n.distance}, "txPower":${n.txPower} }');
        }

      });
   
  }
  void _onRecMessage(data){
    
    setState(() {
      final body  = jsonDecode(data);
        ItemPoint itemPoint = ItemPoint();

        itemPoint.x = body['x'];
        itemPoint.y = body['y'];
        itemPoint.hasCovid = body['hasCovid'];
        itemPoint.response = body['response'];
        
        _points.add(itemPoint);
        if(validateContact()){
          hasContact=true;
        }else{
          hasContact=false;
        }
    });
    
  }
  bool validateContact(){
    for(var i=0; i<_points.length;i++){
      if(_points[i].hasCovid==1) return true;
    }
    return false;
  }
  void _onRestart(data){
      print(data);
    
    setState(() {
      hasContact=false;
        _points.clear();
    });
    
  }
  var isAdded = false;
  void _onCalculate(data){
      final body  = jsonDecode(data);
      double f = body['calculate']*1.0;
      if(f < 200.0){
          setState(() {
              percent=f;
          });
      }else if(f==201){
          setState(() {
              hasContact =true;
              _points[body['index']-1].hasCovid = 1;
          });
      }else if(f==202){
          setState(() {
              hasContact =true;
          });
      }else if(f==203){
        setState(() {
          if(!isAdded){
              ItemPoint it = ItemPoint();

              it.x = 0;
              it.y = 50;
              it.hasCovid = 0;
              _points.add(it);
          isAdded=true;
        }else{
          print(body['predict'] );
            _points[0].x = (body['predict'][0] > 0.5 ? 400 + (50*distance) : 200  - (50*distance)).round();
        }
              
        });

      }
   
  }
 
    @override
  void dispose() {
    super.dispose();
    _pointAnimationController?.dispose();
    _beaconAnimationController?.dispose();
  }
  Widget _upperContainer() {
    return Container(
      alignment: Alignment.topLeft,
      padding: EdgeInsets.all(0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'July 11 2019',
                    style: TextStyle(color: Colors.black),
                  ),
                  Text(
                    'Hola Mauricio!',
                    style:  GoogleFonts.varelaRound(
                      textStyle: TextStyle(color: Colors.black,fontSize:24, 
                        fontWeight:FontWeight.bold, letterSpacing: .2),
                    )
                  ),
                ],
              ),
              GestureDetector(
                child: CircleAvatar(
                  backgroundImage: NetworkImage(
                      'https://media-exp1.licdn.com/dms/image/C5103AQFhUEoHkOvRKQ/profile-displayphoto-shrink_200_200/0?e=1600905600&v=beta&t=JdVkagjgJ3MXjhYt7-Nh22YsOXCBRzoIBliy9MHYrLc'),
                ),
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(builder: (BuildContext context) => UserProfilePage()));
                },
              )
            ],
          )
        ],
      ),
    );
  }

  Widget indicator() {
    return Container(
      alignment: Alignment.center,
      padding: EdgeInsets.all(0),
      child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          CircularPercentIndicator(
                radius: 80.0,
                lineWidth: 8.0,
                animation: true,
                percent: 0.1,
                center: new Text(
                  "10%",
                  style:
                      new TextStyle(fontSize: 20.0),
                ),
                 footer: new Text(
                  "Casa",
                  style:
                      new TextStyle(fontWeight:FontWeight.bold, fontSize: 14.0),
                ),
                circularStrokeCap: CircularStrokeCap.round,
                progressColor: Color(0xddEABD4F),
              ),
               SizedBox(
                width: 16,
              ),
              CircularPercentIndicator(
                radius: 130.0,
                lineWidth: 10.0,
                animation: true,
                percent: percent*(hasContact?1.05:1),
                center: new Text(
                  "${(percent*100 * (hasContact?1.05:1)).round()}%",
                  style:
                      new TextStyle(fontSize: 28.0),
                ),
                 footer: new Text(
                  "Riesgo actual",

                  style:
                      new TextStyle(fontWeight:FontWeight.bold, fontSize: 18.0),
                ),
                circularStrokeCap: CircularStrokeCap.round,
                progressColor: Color(0xddEA2637),
              ),
               SizedBox(
                width: 16,
              ),
          CircularPercentIndicator(
                radius: 80.0,
                lineWidth: 8.0,
                animation: true,
                percent: 0.7,
                center: new Text(
                  "12%",
                  style:
                      new TextStyle(fontSize: 20.0),
                ),
                 footer: new Text(
                  "Trabajo",
                  style:
                      new TextStyle(fontWeight:FontWeight.bold, fontSize: 14.0),
                ),
                circularStrokeCap: CircularStrokeCap.round,
                progressColor: Color(0xdd4B4B59),
              )
        ]));
        
  }
 List<Widget> _buildPoints(){
   return _points.map((item)=> contactNearby(item.x, item.y, item.hasCovid)).toList();
 }
 Widget getNearbyContacts()
  {
    return new Stack(children: [..._buildPoints()]);
  }
  Widget getHistoryExposure(){
    return Container (
            alignment: Alignment.center,
        constraints: BoxConstraints(minWidth: 100, maxWidth: 420),
      child:Column(
      children : <Widget>[
        SizedBox(height:30),
          Text("Exposición Agosto", 
                      textAlign: TextAlign.left,
                      style:new TextStyle( color:Color(0xee000000))),
        SizedBox(height:10),
        Row(

           mainAxisAlignment: MainAxisAlignment.center,
        children : <Widget>[
          ...buildExposure()
        ]
      )]
    )
    );
  }
List<Widget> buildExposure(){
  List<Widget> list = [];
  List<Color> colorsList = [Color(0xfff5d002), 
    Color(0xfff5d002), Color(0xffe82e38), 
    Color(0xfff39620), Color(0xfff5d002)];
    
    list.add(CircleAvatar(
                radius: 20,
                backgroundColor:Colors.white,
                child:Icon(Icons.arrow_back_ios,color: Color(0xffa3a3a3)
                )));
  for(var i = 0; i < 5; i++){
    list.add( Padding(
    padding: EdgeInsets.all(6.0),
    child: 
                    CircleAvatar(
                radius: 20,
                backgroundColor:colorsList[i],
                child:CircleAvatar(
                  radius:19,
                  backgroundColor:colorsList[i],
                  child : Text("${20+i}",
                                        textAlign: TextAlign.center,
                                        style:new TextStyle(
                                        fontWeight:FontWeight.bold,
                                          color:Color(0xffffffff))
                              )
                ))
  )
                );
  }
   list.add(CircleAvatar(
                radius: 20,
                backgroundColor:Colors.white,
                child:Icon(Icons.arrow_forward_ios,color: Color(0xffa3a3a3)
                )));
  return list;
}
Widget contactNearby(int x, int y, int hasCovid){
  return 
  
      AnimatedPositioned(
        duration: Duration(seconds: 1),
      curve:  Curves.linear,
    left:x/2,top:y/4,child: Align(
            alignment: Alignment.center,
            child:  CircleAvatar(
              radius: 12,
              backgroundColor: (hasCovid==1? Color(0xddEA2637) : Color(0xff2d81ea)),
              child: CircleAvatar(
                radius: 11,
                backgroundColor: (hasCovid==1? Color(0xfff1d9db) : Color(0xffebf3fe)) ,
                child:CircleAvatar(
                radius: 7,
                backgroundColor: (hasCovid==1 ? Color(0xffd42823) : Color(0xff2d81ea)))
              ),
            )
          ));
}
 Widget getMyPosition() {

    return Container(
      width: MediaQuery.of(context).size.width,
      height: 100,
      child: Stack(
        children: <Widget>[
          getNearbyContacts(),
          Align(
            alignment: Alignment.center,
            child: 
             AnimatedBuilder(
                animation: _pointAnimationController,
                builder: (context, child){
                  return CircleAvatar(
                      radius: 24*_pointAnimation.value,
                      backgroundColor: Color(0x332a83e9),
                      child: CircleAvatar(
                        radius: 23*_pointAnimation.value,
                        backgroundColor: Color(0x33ebf3fe)
                      )
                    );
                }
              )
          ),
          Align(
            alignment: Alignment.center,
            child: CircleAvatar(
              radius: 12,
              backgroundColor: Color(0xffffffff),
              child: CircleAvatar(
                radius: 9,
                backgroundColor: Color(0xff2d81ea)
              ),
            ),
          )        ],
      ),
    );
  }
  Widget alertArea(bool hasContact){
    int _pointsCovid = 1;
    for(var t= 0; t < _points.length;t++){
      if(_points[t].hasCovid==1) _pointsCovid+=1;
    }
    var textContact = hasContact ? "Has tenido contacto cercano" : "No se detectaron contactos";
    var textCovid = hasContact ? "Basado en tus datos  has tenido contacto cercano con ${_pointsCovid} confirmados de COVID-19":
    "Basado en tus datos no has tenido contacto cercano con   confirmados de COVID-19";
    return AnimatedContainer(
        duration: Duration(seconds: 1),
  curve: Curves.fastOutSlowIn,

     padding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration:BoxDecoration(color: hasContact?Color(0xfffae0df):Color(0xffffffff),
            borderRadius: BorderRadius.circular(10),
      ),
        constraints: BoxConstraints(minWidth: 100, maxWidth: 280),
      child:Column(
      
      children:<Widget>[
        
                 Text(textContact, style:new TextStyle(fontWeight:FontWeight.bold)),
                      SizedBox(height:18),
                     Container(
                        constraints: BoxConstraints(minWidth: 100, maxWidth: 280),
                       child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[Text(textCovid,
                                        textAlign: TextAlign.center,
                                        style:new TextStyle(color:Color(0xff666666))
                              )]
                      )),
                      SizedBox(height:18),
                      Container(
                        constraints: BoxConstraints(minWidth: 100, maxWidth: 280),
                        child: Column(
                          children:<Widget>[
                            (hasContact?
                            _placeContainer('Tomar acciones',Color(0xffd32c18),false)
                            :
                            _placeContainer('Ver sintomas',Color(0xff526fff),false))
                          ])
                      )
      ]
    ));
  }
  Widget contactTracing() {
    return Column(children: <Widget>[Container(
                    padding: EdgeInsets.symmetric(horizontal: 30, vertical: 20),
                    decoration: BoxDecoration(
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                              blurRadius: 10,
                              offset: Offset(0, 10),
                              color: Color(0x002C80EE))
                        ],
                        border: Border.all(
                            width: 10,
                            style: BorderStyle.solid,
                            color: Color(0x002C80EE)),
                        borderRadius: BorderRadius.circular(10)),
                    child: getMyPosition(),
                  ), 
                    alertArea(hasContact)

                  ]);
  }
 Widget  _placeContainer(String title, Color color,bool leftIcon){
    return Column(children: <Widget>[
       Container(
         height: 50,
         width: MediaQuery.of(context).size.width - 70,
         padding: EdgeInsets.all(8),
         margin: EdgeInsets.symmetric(vertical: 8),
         decoration: BoxDecoration(borderRadius: BorderRadius.circular(15),
         color:color),
         child: Row(
           mainAxisAlignment: MainAxisAlignment.center,
           children: <Widget>[
           Text(title,
            textAlign: TextAlign.center,
            style: TextStyle(color: leftIcon ? Color(0xffa3a3a3) : Colors.white,fontSize: 18,fontWeight: FontWeight.w600),),
           leftIcon ? Icon(Icons.add,color: Color(0xffa3a3a3),)
           : Container()
         ],)
       )
    ],);
  }
  @override
  Widget build(BuildContext context) {
    return Column(children: <Widget>[
      Container(
        width: MediaQuery.of(context).size.width,
        padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 50,
            bottom: 30,
            left: 30,
            right: 30.0),
        child: _upperContainer(),
      ),
      indicator(),
          getHistoryExposure(),
      contactTracing()
    ]);
  }
}
