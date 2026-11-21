import java.nio.charset.StandardCharsets;
import java.util.Base64;
import javax.crypto.Cipher;
import javax.crypto.spec.IvParameterSpec;
import javax.crypto.spec.SecretKeySpec;
import java.security.Security;
import org.bouncycastle.jce.provider.BouncyCastleProvider;
public class AndroidAesVectors {
    public static void main(String[] args) throws Exception {
        Security.addProvider(new BouncyCastleProvider());
        String[] inputs = {"", "13800138000", "password123", "1234567890abcdef", "1234567890abcdef1234567890abcdef", "中文密码123"};
        byte[] key = "gww417038_x8888x".getBytes(StandardCharsets.UTF_8);
        System.out.print("[");
        for (int i = 0; i < inputs.length; i++) {
            Cipher cipher = Cipher.getInstance("AES/CBC/ZeroBytePadding", "BC");
            cipher.init(Cipher.ENCRYPT_MODE, new SecretKeySpec(key, "AES"), new IvParameterSpec(key));
            String base64 = Base64.getEncoder().encodeToString(cipher.doFinal(inputs[i].getBytes(StandardCharsets.UTF_8)));
            if (i > 0) System.out.print(",");
            System.out.print("{\"plain\":\"" + inputs[i] + "\",\"base64\":\"" + base64 + "\"}");
        }
        System.out.println("]");
    }
}
