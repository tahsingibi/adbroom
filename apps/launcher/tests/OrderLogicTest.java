import io.github.adbroom.launcher.OrderLogic;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.List;

public final class OrderLogicTest {
    static void equal(Object actual, Object expected) {
        if (!actual.equals(expected)) throw new AssertionError(actual + " != " + expected);
    }
    public static void main(String[] args) {
        equal(OrderLogic.reconcile(Arrays.asList("removed", "b", "a"), Arrays.asList("a", "b", "new")), Arrays.asList("b", "a", "new"));
        equal(OrderLogic.reconcile(Collections.emptyList(), Arrays.asList("b", "a")), Arrays.asList("b", "a"));
        equal(OrderLogic.reconcile(Arrays.asList("a", "a"), Arrays.asList("a", "b")), Arrays.asList("a", "b"));
        equal(OrderLogic.parse("com.tv.a,com.tv.b"), Arrays.asList("com.tv.a", "com.tv.b"));
        equal(OrderLogic.parse(""), Collections.emptyList());
        for (String invalid : Arrays.asList("com.a,com.a", "com.a,", "com.a;reboot", "com.a/Activity", "bad value")) {
            try { OrderLogic.parse(invalid); throw new AssertionError("Accepted " + invalid); }
            catch (IllegalArgumentException expected) {}
        }
        List<String> order = new ArrayList<>(Arrays.asList("a", "b", "c", "d"));
        equal(OrderLogic.move(order, 0, 3), true);
        equal(order, Arrays.asList("b", "c", "d", "a"));
        equal(OrderLogic.move(order, 3, 0), true);
        equal(order, Arrays.asList("a", "b", "c", "d"));
        equal(OrderLogic.move(order, 0, -1), false);
        equal(OrderLogic.move(order, 3, 4), false);
        equal(OrderLogic.move(order, 1, 1), false);
        equal(OrderLogic.encode(OrderLogic.parse("com.a,com.b")), "com.a,com.b");
        equal(OrderLogic.mergeVisible(Arrays.asList("hidden", "a", "b", "other"), Arrays.asList("b", "a")), Arrays.asList("hidden", "b", "a", "other"));
        equal(OrderLogic.mergeVisible(Arrays.asList("hidden", "a"), Collections.emptyList()), Arrays.asList("hidden", "a"));
        System.out.println("OrderLogic: all tests passed");
    }
}
