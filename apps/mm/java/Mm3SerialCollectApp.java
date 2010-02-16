/*
 * Copyright (c) 2008 Stanford University.
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * - Redistributions of source code must retain the above copyright
 *   notice, this list of conditions and the following disclaimer.
 * - Redistributions in binary form must reproduce the above copyright
 *   notice, this list of conditions and the following disclaimer in the
 *   documentation and/or other materials provided with the
 *   distribution.
 * - Neither the name of the Stanford University nor the names of
 *   its contributors may be used to endorse or promote products derived
 *   from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
 * FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL STANFORD
 * UNIVERSITY OR ITS CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
 * STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
 * OF THE POSSIBILITY OF SUCH DAMAGE.
 */

/**
 * @author Kevin Klues <klueska@cs.stanford.edu>
 * @date March 3rd, 2008
 */

import net.tinyos.message.*;
import net.tinyos.util.*;
import java.io.*;
import java.util.Hashtable;
/**
*/

public class Mm3SerialCollectApp implements MessageListener {
  MoteIF mote;
  Hashtable Sensors = new Hashtable();

  /* Main entry point */
  void run() {

    mote = new MoteIF(PrintStreamMessenger.err);
    mote.registerListener(new CollectMsg(), this);

    Sensors.put(SensorConstants.SNS_ID_TEMP,  new Mm3Sensor(SensorConstants.SNS_ID_TEMP));
    Sensors.put(SensorConstants.SNS_ID_BATT,  new Mm3Sensor(SensorConstants.SNS_ID_BATT));
    Sensors.put(SensorConstants.SNS_ID_PTEMP, new Mm3Sensor(SensorConstants.SNS_ID_PTEMP));
    Sensors.put(SensorConstants.SNS_ID_MAG,   new Mm3Sensor(SensorConstants.SNS_ID_MAG));
    Sensors.put(SensorConstants.SNS_ID_SAL,   new Mm3Sensor(SensorConstants.SNS_ID_SAL));
    Sensors.put(SensorConstants.SNS_ID_ACCEL, new Mm3Sensor(SensorConstants.SNS_ID_ACCEL));
    Sensors.put(SensorConstants.SNS_ID_SPEED, new Mm3Sensor(SensorConstants.SNS_ID_SPEED));
    Sensors.put(SensorConstants.SNS_ID_PRESS, new Mm3Sensor(SensorConstants.SNS_ID_PRESS));

  }

  synchronized public void messageReceived(int dest_addr, Message msg) {
    if (msg instanceof CollectMsg) {
      DtSensorDataMsg sensorDataMsg = new DtSensorDataMsg(msg, 0);
      System.out.println(sensorDataMsg.get_id());
      ((Mm3Sensor)(Sensors.get((byte)sensorDataMsg.get_id()))).print((CollectMsg)msg); 
    }
  }

  public static void main(String[] args) {
    Mm3SerialCollectApp me = new Mm3SerialCollectApp();
    me.run();
  }
}
