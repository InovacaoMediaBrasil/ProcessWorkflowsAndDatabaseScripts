USE CanalDoArtesanato_Production;

SELECT
U.UserId AS 'Código', U.FirstName + ' ' + U.LastName AS 'Nome', U.Email AS 'Endereço de e-mail', 
ISNULL(U.FixedPhone,'Não informado') AS 'Telefone fixo', 
ISNULL(U.MobilePhone,'Não informado') AS  'Telefone celular',
CONVERT(VARCHAR, U.RegisterDate, 103) AS 'Data de cadastro',
CONVERT(VARCHAR, U.LastAccessDate, 103) AS 'Data do último acesso',
CONVERT(VARCHAR, H.StartDate, 103) AS 'Data do estado financeiro',
(CASE
WHEN H.FinancialState = 1 THEN 'Incompleto'
WHEN H.FinancialState = 3 THEN 'Assinante'
WHEN H.FinancialState = 4 THEN 'Aguardando pagamento'
WHEN H.FinancialState = 5 THEN 'Congelado'
WHEN H.FinancialState = 6 THEN 'Cancelado'
END) AS 'Estado financeiro' 
FROM Users AS U
INNER JOIN CallsScheduler AS C
ON C.UserId = U.UserId
INNER JOIN UsersFinancialStatesHistories AS H
ON H.UserId = U.UserId
WHERE H.EndDate IS NULL
AND C.Result = 0
ORDER BY H.StartDate;