class Account {
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
        // account.balance = -20; // 取消注释，观察编译报错。
    }
}
