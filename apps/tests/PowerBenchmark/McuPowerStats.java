/**
 * Java-side application for testing serial port communication.
 * 
 *
 * @author John Jacobs <johnj@soe.ucsc.edu>
 * @date 
 */

import java.io.IOException;
import java.io.File;
import java.io.FileWriter;

import net.tinyos.message.*;
import net.tinyos.packet.*;
import net.tinyos.util.*;

public class McuPowerStats implements MessageListener {

	private MoteIF moteIF;

	static int STATE_TEST = 0xF0;
	static int STATE_END = 0xFF;
	static String stateTable[] = {"ACTIVE", "LPM0", "LMP1", "LMP2", "LMP3", "LPM4"};
	File outfile = null;
	FileWriter outwriter = null;
	
	public McuPowerStats(MoteIF moteIF, String outfname) {
		this.moteIF = moteIF;
		this.moteIF.registerListener(new McuPowerStatsMsg(), this);
		if (outfname != null) {
			try {
				outfile = new File(outfname);
				outwriter = new FileWriter(outfile);
			}
			catch (IOException ie) {
				System.out.println(ie.toString());
				System.exit(-1);
			}
		}
	}

	public void messageReceived(int to, Message message) {
		McuPowerStatsMsg msg = (McuPowerStatsMsg)message;
		System.out.print("Received packet ");
		if (msg.get_state() < stateTable.length) {
			System.out.print(stateTable[(int)msg.get_state()] + " ");
		}
		else if (msg.get_state() == STATE_TEST) {
			System.out.print("TEST ");
		}
		else if (msg.get_state() >= STATE_END) {
			System.out.println("END ");
		}
		System.out.print(msg.get_min() + " ");
		System.out.print(msg.get_max() + " ");
		System.out.print(msg.get_count() + " ");
		System.out.print(msg.get_total() + " ");
		System.out.print(msg.get_lastupdate() + "");
		System.out.println();
		if (outwriter != null) {
			try {
				if (msg.get_state() <= stateTable.length-1) {
					outwriter.write(msg.get_state() + " ");
					outwriter.write(msg.get_min() + " ");
					outwriter.write(msg.get_max() + " ");
					outwriter.write(msg.get_count() + " ");
					outwriter.write(msg.get_total() + " ");
					outwriter.write(msg.get_lastupdate() + "");
					outwriter.write('\n');
				}
				else if (msg.get_state() >= STATE_END) {
					outwriter.close();
				}
			}
			catch (IOException ie) {
				System.out.println(ie.toString());
				System.exit(-1);
			}
		}
		if (msg.get_state() >= STATE_END) {
			System.exit(0);
		}
	}
	
	private static void usage() {
		System.err.println("usage: McuPowerStats [-comm <source>]");
	}
	
	public static void main(String[] args) throws Exception {
		String source = null;
		String outfname = null;
		if (args.length >= 2) {
			int i;
			for (i = 0; i < args.length; i++) {
				if (args[i].equals("-comm")) {
					source = args[++i];
				}
				else if (args[i].equals("-out")) {
					outfname = args[++i];
				}
				else {
					usage();
					System.exit(1);
				}
			}
		}
		else if (args.length != 0) {
			usage();
			System.exit(1);
		}
		
		PhoenixSource phoenix;
		
		if (source == null) {
			phoenix = BuildSource.makePhoenix(PrintStreamMessenger.err);
		}
		else {
			phoenix = BuildSource.makePhoenix(source, PrintStreamMessenger.err);
		}

		MoteIF mif = new MoteIF(phoenix);
		McuPowerStats serial = new McuPowerStats(mif, outfname);
	}
}
