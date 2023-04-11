USE CanalDoArtesanato_Production;

SELECT 'https://www.canaldoartesanato.com.br/Admin/User/Details/' + CAST(U.UserId AS VARCHAR) AS 'Link', 
U.FirstName + ' ' + U.LastName AS 'Nome', 
U.Email AS 'Endereço de e-mail', 
ISNULL(U.FixedPhone, 'Não informado') AS 'Telefone fixo',
ISNULL(U.MobilePhone, 'Não informado') AS 'Telefone celular',
CONVERT(VARCHAR, U.RegisterDate, 103) AS 'Data de cadastro', 
CONVERT(VARCHAR, U.LastAccessDate, 103) AS 'Data de último acesso',
CONVERT(VARCHAR, H.StartDate, 103) AS 'Data de alteração do estado financeiro',
CASE 
	WHEN H.FinancialState = 1 THEN 'Incompleto'
	WHEN H.FinancialState = 5 THEN 'Congelado'
	WHEN H.FinancialState = 6 THEN 'Cancelado'
END AS 'Status financeiro'
FROM Users AS U
INNER JOIN UsersFinancialStatesHistories AS H
ON U.UserId = H.UserId
WHERE U.HierarchyLevel = 3
AND H.EndDate IS NULL
AND H.FinancialState IN (5, 6)
AND U.RegisterDate >= '2016-01-01'
AND U.RegisterDate <= '2016-12-31'
ORDER BY H.StartDate;