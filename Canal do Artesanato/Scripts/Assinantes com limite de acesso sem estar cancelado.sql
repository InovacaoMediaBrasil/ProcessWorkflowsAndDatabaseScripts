SELECT * 
FROM Users AS U
INNER JOIN UsersFinancialStatesHistories AS H
ON U.UserId = H.UserId
WHERE U.HierarchyLevel = 3 
AND U.ExpirationDate IS NOT NULL
AND H.EndDate IS NULL
AND H.FinancialState != 6