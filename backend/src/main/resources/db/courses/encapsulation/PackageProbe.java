class Account {
    private int balance = 100;

    public int getBalance() {
        return balance;
    }

    String branchCode() {
        return "BANK";
    }
}

public class PackageProbe {
    public static void main(String[] args) {
        Account account = new Account();
        System.out.println(account.branchCode());
        System.out.println(account.getBalance());
    }
}
