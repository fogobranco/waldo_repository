import 'package:flutter/material.dart';
import 'package:flutter_smart_home_app/scopedModel/connectedModel.dart';
import 'package:scoped_model/scoped_model.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:splashscreen/splashscreen.dart';

import 'pages/home_page_body.dart';

void main(){
  runApp(new MaterialApp(
    home: new App(),
  ));
}
class App extends StatefulWidget {
  @override
  MyApp createState() => new MyApp();
}

class MyApp extends State<App>  {


  @override
  Widget build(BuildContext context) {
    return new SplashScreen(
      seconds: 10,
      navigateAfterSeconds: new AfterSplash(),
      image: new Image.network('https://i.pinimg.com/originals/4c/c9/fe/4cc9fee5e1f62f9f7aa41bcd0f04e8aa.jpg'),
      backgroundColor: Colors.white,
      styleTextUnderTheLoader: new TextStyle(),
      photoSize: 100.0,
      onClick: ()=>print("Flutter Egypt"),
      loaderColor: Colors.red
    );
    
  }
}

class AfterSplash extends StatelessWidget{
 final ApplianceModel model = ApplianceModel();

  @override
  Widget build(BuildContext context) {
  return  
    new Scaffold(
      body: ScopedModel<ApplianceModel>(
      model: model,
      child: MaterialApp(
      title: 'Waldo',
      theme: ThemeData(
        textTheme: GoogleFonts.varelaRoundTextTheme(
          Theme.of(context).textTheme,
        ),
        primarySwatch: Colors.yellow,
      ),
      home: MyHomePage(model),
    ),));
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage(this.model);

  final ApplianceModel model;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: Color(0xfffcfcfd),
        child:  HomePageBody(widget.model),)
    );
  }
}
