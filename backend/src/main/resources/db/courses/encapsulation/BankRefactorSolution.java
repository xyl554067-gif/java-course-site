import java.util.Scanner;

class Account {
    private int balance;

    Account(int balance) {
        this.balance = balance;
    }

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

public class BankRefactor {
    public static void main(String[] args) {
        Scanner input = new Scanner(System.in);
        Account account = new Account(input.nextInt());
        System.out.println(account.deposit(input.nextInt()));
        System.out.println(account.getBalance());
    }
}
