import java.util.Scanner;

class Account {
    public int balance;

    Account(int balance) {
        this.balance = balance;
    }

    public boolean deposit(int amount) {
        balance += amount;
        return true;
    }
}

public class BankRefactor {
    public static void main(String[] args) {
        Scanner input = new Scanner(System.in);
        Account account = new Account(input.nextInt());
        System.out.println(account.deposit(input.nextInt()));
        System.out.println(account.balance);
    }
}
