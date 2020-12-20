DECLARE 
@RemoveUserId INT,
@UpdateUserId INT;

/* =============== Altere as duas variavéis abaixo apenas! =============== */
/* Usuário que foi criado por último, que será removido do sistema */
SET @RemoveUserId = 0;

/* Usuário que vai permancer no sistema*/
SET @UpdateUserId = 0;

/* ======================================================================= */





/* ================= Não altere as linhas a partir daqui ================= */

/* Transfere pagamentos */
UPDATE Transactions SET UserId = @UpdateUserId WHERE UserId = @RemoveUserId;
UPDATE TransactionsPayments SET UserId = @UpdateUserId WHERE UserId = @RemoveUserId;
UPDATE TransactionsBankBills SET UserId = @UpdateUserId WHERE UserId = @RemoveUserId;
/* Altera o status atual do usuário que vai finalizado, será usado o estado do usuário duplicado (que será removido) */
UPDATE UsersFinancialStatesHistories SET EndDate = GETDATE() WHERE EndDate IS NULL AND UserId = @RemoveUserId;
/* Copia o histórico de estados financeiros */
UPDATE TransactionsRecurringPayments SET UserId = @UpdateUserId WHERE UserId = @RemoveUserId;
/* Remove os como soube do usuário que será apagado - sem copiar ele para o antigo */
DELETE FROM UsersHowKnows WHERE SubscriberId = @RemoveUserId;
/* Remove o usuário que deve ser apagado*/
DELETE FROM Users WHERE UserId = @RemoveUserId;