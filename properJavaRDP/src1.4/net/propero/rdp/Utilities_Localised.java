/* Utilities_Localised.java
 * Component: ProperJavaRDP
 * 
 * Revision: $Revision: 1.2 $
 * Author: $Author: telliott $
 * Date: $Date: 2005/09/27 14:15:39 $
 *
 * Copyright (c) 2005 Propero Limited
 *
 * Purpose: Java 1.4 specific extension of Utilities class
 */
package net.propero.rdp;

import java.awt.datatransfer.DataFlavor;
import java.util.StringTokenizer;

import net.propero.rdp.Utilities;

public class Utilities_Localised extends Utilities {

    public static DataFlavor imageFlavor = DataFlavor.imageFlavor;
    
    public static String strReplaceAll(String in, String find, String replace){
        return in.replaceAll(find, replace);
    }
    
    public static String[] split(String in, String splitWith){
        return in.split(splitWith);
    }
    
}
