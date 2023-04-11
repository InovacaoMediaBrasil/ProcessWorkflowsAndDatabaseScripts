USE CanalDoArtesanato_Production;

SELECT * FROM Transactions WHERE BankBillId IS NULL AND Method IN (3, 9, 10)