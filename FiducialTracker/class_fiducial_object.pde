class FiducialObject{
  
  float x;
  float y;
  
  int id;
  
  boolean isActive;
  
  float isActiveFade;
  float isActiverFadeStep;
  
  int framesSinceActive;
  
  int lastAngle;
  int angle;
  int angleMove;
  int midiAngle;
  
  int rotationVal;
  int midiRotationVal;
  
  PVector lastVector;
  PVector currentVector;
  
  int trackingCenterRotation;
  int trackingCenterDistance;
  

  FiducialObject(int id_){
    id = id_;
    
    lastAngle = -1;
    isActive = true;
    isActiveFade = 127;
    isActiverFadeStep = 2.5;
    
    println("Object added: ", id);
    
  }
  
  void setSelfRotation(int angle_){
    angle = angle_;
    
    if (lastAngle == -1) lastAngle = angle; // this alignes last and current for first call to the function for this object    
    
    lastVector = new PVector(0, -100);
    lastVector.rotate(radians(lastAngle));
    currentVector = new PVector(0, -100);
    currentVector.rotate(radians(angle));
  
    angleMove = int(degrees(lastVector.angleBetween(lastVector,currentVector))); // total rotational move
    
    if (angle < lastAngle) rotationVal = constrain(rotationVal + angleMove*3, 0, 359); // rotation one direction
    else if (angle > lastAngle) rotationVal = constrain(rotationVal - angleMove*3, 0, 359); // rotation the other direction
    midiRotationVal = int(map(rotationVal, 0, 359, 127, 0)); // map to midi
    
    lastAngle = angle;

  }
  
  void updateFade(){
    if (isActive) isActiveFade = constrain(isActiveFade+isActiverFadeStep, 0, 127);
    else isActiveFade = constrain(isActiveFade-isActiverFadeStep, 0, 127);
  }

}
