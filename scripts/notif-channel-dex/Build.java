import brut.androlib.smali.SmaliBuilder;
import com.android.tools.smali.dexlib2.Opcodes;
import com.android.tools.smali.dexlib2.writer.builder.DexBuilder;
import com.android.tools.smali.dexlib2.writer.io.FileDataStore;
import java.io.File;

public class Build {
    public static void main(String[] a) throws Exception {
        int api = Integer.parseInt(a[1]);
        DexBuilder db = new DexBuilder(new Opcodes(api));
        SmaliBuilder sb = new SmaliBuilder(api);
        walk(new File(a[0]), sb, db);
        File out = new File(a[2]);
        out.delete();
        db.writeTo(new FileDataStore(out));
        System.out.println("wrote " + out + " " + out.length() + " bytes");
    }
    static void walk(File d, SmaliBuilder sb, DexBuilder db) {
        File[] fs = d.listFiles();
        if (fs == null) return;
        for (File f : fs) {
            if (f.isDirectory()) walk(f, sb, db);
            else if (f.getName().endsWith(".smali")) sb.buildFile(f, db);
        }
    }
}
