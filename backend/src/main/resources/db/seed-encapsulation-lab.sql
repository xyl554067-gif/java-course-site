INSERT INTO code_snippet (lesson_id, language, title, code_text, explanation, runnable, expected_out, sort_order)
SELECT l.id, 'java', '账户余额的封装', 'class Account {
    private int balance;

    public boolean deposit(int amount) {
        if (amount <= 0 || amount > Integer.MAX_VALUE - balance) {
            return false;
        }
        balance += amount;
        return true;
    }

    public int getBalance() {
        return balance;
    }
}

public class AccountDemo {
    public static void main(String[] args) {
        Account account = new Account();
        System.out.println(account.deposit(100));
        System.out.println(account.deposit(-20));
        System.out.println(account.getBalance());
        // account.balance = -20; // 取消注释，观察 private 访问报错
    }
}',
       '先预测三行输出。运行后取消最后一行注释，观察直接访问 private 字段时的编译错误。', TRUE, 'true
false
100', 0
FROM lesson l
JOIN course_module m ON m.id = l.module_id
JOIN course c ON c.id = m.course_id
WHERE l.slug = 'oop-core' AND c.slug = 'java-mastery'
  AND NOT EXISTS (
    SELECT 1 FROM code_snippet s
    WHERE s.lesson_id = l.id AND s.language = 'java' AND s.title = '账户余额的封装'
  );
