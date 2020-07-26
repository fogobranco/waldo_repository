
function prob(chance){
    return (Math.random()*100) < chance * 100;
  
  }

  function uuidv4() {
    return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
      var r = Math.random() * 16 | 0, v = c == 'x' ? r : (r & 0x3 | 0x8);
      return v.toString(16);
    });
  }
  

  var probCovid = 0.3,
      distanceInfection = 2;
  var infecteds ={};
  var circles = [],
        circle = {},
        radius=8,
        overlapping = false,
        NumCircles = 50,
        protection = 500,
        counter = 0,
        canvasWidth = window.innerWidth,
        canvasHeight = window.innerHeight;


        

  var me = {
    id:uuidv4(),
    x: 20,
    y: 20,
    r: radius,
    hasCovid:false,
    xVel : 1,
    yVel : 1,
    ratioMove : random(0,0.1),
    radians:  Math.random() * Math.PI * 2,
    hasLink:false ,
    probGetCovid : 0
  }
  function gColor(b){
        if(b) return "#ff9900";
        return "#2AC1A6";
  }
  function setup() {
  

    createCanvas(canvasWidth, canvasHeight);
  
    while (circles.length < NumCircles &&
           counter < protection) {
      circle = {
        id:uuidv4(),
        x: random(width) + radius,
        y: random(height) + radius,
        r: radius,
        hasCovid:false,
        xVel : random(-1,1),
        yVel : random(-1,1),
        ratioMove : random(0,0.1),
        radians:  Math.random() * Math.PI * 2,
        trailRadius: radius*6,
        hasLink:false,
        tracing : []
      };
      if(prob(probCovid)){
        circle.hasCovid=true;
      }
      overlapping = false;
      
      for (var i = 0; i < circles.length; i++) {
        var existing = circles[i];
        var d = dist(circle.x, circle.y, existing.x, existing.y)
        if (d < circle.r + existing.r || (circle.x < ( radius+10) || circle.x + radius+10> canvasWidth) || (circle.y < ( radius+10) || circle.y + radius+10> canvasHeight)) {
          overlapping = true;
          break;
        }
      }
      
      if (!overlapping) {
        circles.push(circle);      
      }
      
      counter++;
    }
    
  
  }

  function draw() {
    
    background("#233")
    
     for (var i = 0; i < circles.length; i++) {
        var c = circles[i];
        
       var probInfection = prob(0.05)
       let nearElems = [];
       
       if(c.hasCovid){
        var v = {x:c.x,y:c.y,r:c.trailRadius};
        if (prob(0.009))
            c.tracing.push(v); 
        if (c.tracing.length > 2) {
          c.tracing.splice(0, 1);
        }
        stroke('red');
        fill(0, 150);
        let rad = c.r*(2+distanceInfection);
        beginShape();
        for (var o = 0; o < c.tracing.length; o++) {
            var pos = c.tracing[o];
            ellipse(pos.x, pos.y,c.trailRadius,c.trailRadius);
        }
        endShape();
        
        noFill();
        ellipse( c.x , c.y, rad,rad);
    }

        for (var j = 0; j < circles.length; j++) {
            
            var ext = circles[j];
            let dx = ext.x - c.x;
            let dy = ext.y - c.y;
            let distance = sqrt(dx * dx + dy * dy);
            let minDist = ext.r + c.r;

            if(c.hasCovid)
                if (distance < minDist && probInfection) {
                    c.hasCovid=true;
                }
            if(!c.hasCovid){
                for(var k in ext.tracing){
                    var g = ext.tracing[k];
                    let distance = dist(g.x , g.y , c.x , c.y);
                    let minDist = g.r - c.r;
                    if (distance < minDist && prob(0.005)){
                        c.hasCovid= true
                    }
                }
            }

            if(distance < 100) {
                stroke('blue');
                line(c.x, c.y, ext.x, ext.y);
                nearElems.push(ext);
            }
        }
        if(nearElems.length>0){
            c.hasLink = true;
        }else{
            c.hasLink = false;
        }

        c.radians += c.ratioMove / Math.PI;
        c.x = c.x +  Math.sin(c.radians) * c.xVel * Math.sin(random(1,2)) ;
        c.y = c.y +  Math.cos(c.radians) * c.yVel * Math.sin(random(1,2));
     
    
        if(c.x < (0 + radius) || c.x + radius> canvasWidth){
            c.xVel = -c.xVel;
        }
        if(c.y< (0 + radius) || c.y + radius>= canvasHeight){
            c.yVel = -c.yVel;
        }
        
        

        noStroke();
        fill(gColor(c.hasCovid));
        text(c.hasCovid, c.x + 12, c.y + 12);
        ellipse( c.x , c.y, c.r*2, c.r*2);
        
        smooth()
    }
  }
  