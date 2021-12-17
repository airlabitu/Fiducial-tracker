// ToDo
// move midi mapped values outside fiducial object
// make mapping code coherent
// write better comments
// implement OSC option

import processing.video.*;
import boofcv.processing.*;
import java.util.*;
import georegression.struct.shapes.Polygon2D_F64;
import georegression.struct.point.Point2D_F64;
import themidibus.*;          // library for Midi communication
import java.util.*;
import controlP5.*;


MidiBus myBus; // MIDI object for sending MIDI to Ableton Live

Capture cam;
SimpleFiducial detector;

HashMap<String, FiducialObject> FiducialObjects = new HashMap<String, FiducialObject>();

int trackingCenterX, trackingCenterY;
int maxDist;
boolean sendMIDI = true;

ControlP5 cp5;

boolean videoSetup = false;
boolean midiSetup = false;


void setup() {
  
  size(640, 440);

  //size(960, 540);
  cp5 = new ControlP5(this);
  PFont f = createFont("Verdana",12);
  ControlFont cf = new ControlFont(f);
  cp5.setFont(cf);
  
  
  List videoDevices = Arrays.asList(Capture.list());
  cp5.addScrollableList("video_devices")
     .setPosition(10, 50)
     .setSize(300, 400)
     .setBarHeight(30)
     .setItemHeight(30)
     .addItems(videoDevices)
     ;
  
  
  List midiDevices = Arrays.asList(MidiBus.availableOutputs());
  cp5.addScrollableList("midi_devices")
     .setPosition(330, 50)
     .setSize(300, 400)
     .setBarHeight(30)
     .setItemHeight(30)
     .addItems(midiDevices)
     ;
  
  cp5.addCheckBox("midi_checkbox")
                .setPosition(10, 10)
                .setSize(20, 20)
                .addItem("midi", 0)
                ;
     
}

void draw() {
  
  
  if (!(videoSetup && midiSetup)) {
    background(0);
    return;
  }
  
  if (cam.available() == true) {        

    cam.read();

    List<FiducialFound> found = detector.detect(cam);

    image(cam, 0, 0);

    String fiducial_info = "";

    for ( FiducialFound fiducial : found ) {
      println("FS: ", found.size());
      float angle;
      int x, y;
      int id;

      // get ID
      id = (int)fiducial.getId();
      //if (id == 1) return; // to prevent it from failing when adding id 1 by mistake in beginning of program
      // getting fiducials center coordinate
      x = width-(int)fiducial.getImageLocation().getX(); // switch side when filming from below
      y = (int)fiducial.getImageLocation().getY();

      // calculating angle
      if (fiducial.getFiducialToCamera().getR().getData()[1] < 0) {
        angle = map((float)fiducial.getFiducialToCamera().getR().getData()[0], 1, -1, 0, 180);
      } else {
        angle = map((float)fiducial.getFiducialToCamera().getR().getData()[0], -1, 1, 180, 360);
      }

      if (!FiducialObjects.containsKey(""+id)) FiducialObjects.put(""+id, new FiducialObject(id)); // add object if not already existing

      FiducialObject fiducial_obj = FiducialObjects.get(""+id);

      // send midi 'on' messages
      if (!fiducial_obj.isActive) {
        fiducial_obj.isActive = true;
        if (sendMIDI) myBus.sendControllerChange(0, id+3, 127); // send midi data parameter order (channel, number, value)
      }

      fiducial_obj.framesSinceActive = 0;

      fiducial_obj.x = x;
      fiducial_obj.y = y;
      fiducial_obj.setSelfRotation((int)angle);

      fiducial_obj.trackingCenterRotation = (int)getRotation(fiducial_obj.x, fiducial_obj.y, trackingCenterX, trackingCenterY);
      fiducial_obj.trackingCenterRotation = constrain((int)map(fiducial_obj.trackingCenterRotation, 0, 359, 0, 127), 0, 127); // mapping value to MIDI scale
      fiducial_obj.trackingCenterDistance = (int)dist(fiducial_obj.x, fiducial_obj.y, trackingCenterX, trackingCenterY);
      fiducial_obj.trackingCenterDistance = constrain((int)map(fiducial_obj.trackingCenterDistance, 0, maxDist, 0, 127), 0, 127);

      // send out midi
      if (sendMIDI) {
        myBus.sendControllerChange(0, id, fiducial_obj.trackingCenterRotation); // send midi data parameter order (channel, number, value)
        myBus.sendControllerChange(0, id+1, fiducial_obj.trackingCenterDistance); // send midi data parameter order (channel, number, value)
        myBus.sendControllerChange(0, id+2, fiducial_obj.midiRotationVal); // send midi data parameter order (channel, number, value)

      }
      x = (int)fiducial.getImageLocation().getX(); // switch back before visializing things
      
      
      // draw Fiducial marker tracking data
      // visualize
      fill(255, 0, 255);
      textSize(20);
      ellipse(x, y, 10, 10);
      text("angle: " + (int)angle +"\nid: " + id, x+40, y);


      fiducial_info += "\nID: " + id + "\nGlobal rotation: " + fiducial_obj.trackingCenterRotation + "\nDist to center: " + fiducial_obj.trackingCenterDistance + "\nOwn rotation: " + fiducial_obj.midiRotationVal + "\non/off: " + fiducial_obj.isActive + "\non/off fade: " + fiducial_obj.isActiveFade + "\n\n";

    }

    // change object activ states and send MIDI 'off' messages + 'on/off' fade messages
    for (Map.Entry me : FiducialObjects.entrySet()) {
      FiducialObject fiducial_obj = FiducialObjects.get(me.getKey());
      fiducial_obj.framesSinceActive++;

      if (fiducial_obj.framesSinceActive > 60 && fiducial_obj.isActive == true) {
        fiducial_obj.isActive = false;
        // send MIDI off message
        if (sendMIDI) myBus.sendControllerChange(0, fiducial_obj.id+3, 0); // send midi data parameter order (channel, number, value)
      }
      // send midi on/off fade message
      fiducial_obj.updateFade();
      if (sendMIDI) myBus.sendControllerChange(0, fiducial_obj.id+4, int(fiducial_obj.isActiveFade)); // send midi data parameter order (channel, number, value)
    }


    fill(255);
    textSize(10);
    text(fiducial_info, 10, 50);
    textSize(15);
    text("FPS: " + (int)frameRate, width-70, 20);
    noFill();
    strokeWeight(1);
    stroke(255, 0, 0);
    line(trackingCenterX-10, trackingCenterY, trackingCenterX+10, trackingCenterY);
    line(trackingCenterX, trackingCenterY-10, trackingCenterX, trackingCenterY+10);
    ellipse(trackingCenterX, trackingCenterY, maxDist*2, maxDist*2);

  }
  
}

void video_devices(int n) {  
  int deviceIndex = n;
  
  cp5.get(ScrollableList.class, "video_devices").remove();
  
  // Open up the camera so that it has a video feed to process
  initializeCamera(int(1920/2), int(1080/2), deviceIndex);
  surface.setSize(cam.width, cam.height);
  detector = Boof.fiducialSquareBinaryRobust(0.1);
  //detector = Boof.fiducialSquareBinary(0.1,100);
  detector.guessCrappyIntrinsic(cam.width, cam.height);
  
  // set tracking area origin
  trackingCenterX = cam.width/2;
  trackingCenterY = cam.height/2;

  maxDist = (int)dist(trackingCenterX, trackingCenterY, width, height);
  
  videoSetup = true;
}


void midi_checkbox(float [] value){
  sendMIDI = boolean((int)value[0]);
}


void midi_devices(int n) {    
  cp5.get(ScrollableList.class, "midi_devices").remove();

  myBus = new MidiBus(this, -1, n); // Create a new MidiBus with no input device and "Bus 1" as the output device.
  
  midiSetup = true;  
}



void initializeCamera( int desiredWidth, int desiredHeight, int deviceIndex_) {
  String[] cameras = Capture.list();
  for (int i = 0; i < Capture.list().length; i++) {
    println(Capture.list()[i]);
  }

  if (cameras.length == 0) {
    println("There are no cameras available for capture.");
    exit();
  } else {

    cam = new Capture(this, desiredWidth, desiredHeight, Capture.list()[deviceIndex_]);
    cam.start();
  }
}


// method that calculates rotation of one point around another
float getRotation(float x1, float y1, float x2, float y2) {

  PVector a = new PVector(x1, y1);   // point a
  PVector b = new PVector(x2, y2);   // point b
  PVector r = new PVector(0, -100);  // reference point

  b.sub(a);             // move point b
  a.sub(a);             // move point a

  // calculate rotation
  float angle = degrees(r.angleBetween(r, b));
  if (b.x < 0) { // turn result around if b is on the left side of a
    angle = 360 - angle;
  }
  return angle; // return angle
}

void keyReleased() {
  if (key == 'd') maxDist = (int)dist(trackingCenterX, trackingCenterY, mouseX, mouseY);
  if (key == 'm') sendMIDI = !sendMIDI;
  if (key == 'o') {
    trackingCenterX = mouseX;
    trackingCenterY = mouseY;
  }
}
